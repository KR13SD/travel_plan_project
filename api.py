# api.py
from dotenv import load_dotenv
load_dotenv()

import json
import logging
import os
import re
import sys
import time
import uuid
from contextlib import asynccontextmanager
from datetime import datetime
from typing import List, Optional, Literal

import uvicorn
from fastapi import FastAPI, HTTPException, Request, Response
from pydantic import BaseModel, Field
from zoneinfo import ZoneInfo

# Google GenAI
from google import genai
from google.genai.errors import ServerError


# ============================ Logging ============================
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("task_planner")


# ============================ Schemas ============================
Priority = Literal["Low", "Medium", "High"]


class SubTask(BaseModel):
    name: str = Field(description="ชื่องานย่อย", example="รวบรวมข้อมูลยอดขาย")
    description: str = Field(
        description="รายละเอียด/ขั้นตอนเพิ่มเติมของงานย่อย",
        example="ดึงรายงานยอดขายจากระบบ ERP และ Excel ของสาขา",
    )


class PlanOut(BaseModel):
    task_name: str = Field(description="หัวข้อหลักของแผนงาน", example="เตรียมพรีเซนต์ยอดขายประจำสัปดาห์")
    start_date: str = Field(description="YYYY-MM-DD", example="2025-09-01")
    end_date: str = Field(description="YYYY-MM-DD", example="2025-09-05")
    priority: Priority = Field(description="ระดับความสำคัญของงาน", example="High")
    subtasks: List[SubTask] = Field(
        description="รายการงานย่อย 3–10 รายการ",
        example=[
            {"name": "รวบรวมข้อมูลยอดขาย", "description": "ดึงรายงานยอดขายจาก ERP และไฟล์ Excel"},
            {"name": "จัดทำสไลด์นำเสนอ", "description": "ออกแบบโครงสไลด์และใส่ข้อมูลยอดขาย"},
            {"name": "ซ้อมการนำเสนอ", "description": "ซ้อมพูดตามสไลด์และจับเวลา"},
        ],
    )


class FeasibilityMeta(BaseModel):
    feasible: bool = Field(description="แผนนี้ทำได้จริงหรือไม่ (หลังตรวจเบื้องต้น)")
    difficulty: Literal["EASY", "MEDIUM", "HARD", "IMPOSSIBLE"]
    warnings: List[str] = Field(default_factory=list, description="คำเตือน/ข้อควรระวัง")
    reasons: List[str] = Field(default_factory=list, description="เหตุผล/หลักฐานการประเมิน")


class PlanResponse(BaseModel):
    plan: PlanOut
    feasibility: FeasibilityMeta


class UserRequest(BaseModel):
    input: str = Field(
        description="คำสั่งภาษาธรรมชาติที่อยากให้แปลงเป็นแผนงาน",
        example="ช่วยสร้าง to-do list สำหรับการเตรียมพรีเซนต์ยอดขายประจำสัปดาห์ให้หน่อย จะพรีเซนต์วันศุกร์นี้",
    )
    target_language: Optional[str] = Field(
        default=None,
        description="ภาษาเป้าหมายของแผน เช่น 'Thai', 'English' ถ้าไม่ระบุจะตามภาษาของคำขอ",
    )


class CombinedOut(BaseModel):
    intent: Literal["TASK_PLANNING", "NOT_TASK_PLANNING", "INCOMPLETE", "UNSAFE"]
    confidence: float = Field(ge=0.0, le=1.0)
    reason: str
    plan: Optional[PlanOut] = None


# ============================ Helpers ============================
TH_TZ = ZoneInfo("Asia/Bangkok")

# Heuristic invalid input
_MIN_LEN = 8
_GIBBERISH_RE = re.compile(r"^[^A-Za-zก-๙0-9]+$")
_REPEAT_KEY_SMASH_RE = re.compile(r"(.)\1{4,}")
_LOW_ALPHA_RATIO_THRESHOLD = 0.2


def is_probably_gibberish(text: str) -> bool:
    t = (text or "").strip()
    if len(t) < _MIN_LEN:
        return True
    if _GIBBERISH_RE.match(t):
        return True
    if _REPEAT_KEY_SMASH_RE.search(t):
        return True
    letters = re.findall(r"[A-Za-zก-๙]", t)
    ratio = len(letters) / max(len(t), 1)
    return ratio < _LOW_ALPHA_RATIO_THRESHOLD


def _has_placeholder(text: Optional[str]) -> bool:
    if text is None:
        return True
    t = str(text).strip().lower()
    return t in {"", "tbd", "n/a", "na", "-", "ยังไม่กำหนด", "ไม่ทราบ"}


def make_combined_prompt(user_text: str, today_iso: str, lang: Optional[str]) -> str:
    if lang:
        lang_instruction = (
            f"The entire JSON output, including all string values inside `plan` (like `task_name` and `subtasks`), "
            f"must be written in {lang}. Use that language consistently."
        )
    else:
        lang_instruction = (
            "Detect the user's request language automatically and respond in that same language. "
            "The entire JSON output, including all string values inside `plan`, must be in the user's request language. "
            "If the request mixes languages, use the predominant language."
        )

    prompt = f"""
You are a single-call intent classifier and task planner for the Task Planner API.

Return ONLY one JSON object with these top-level fields:
- intent: one of ["TASK_PLANNING","NOT_TASK_PLANNING","INCOMPLETE","UNSAFE"]
- confidence: number in [0,1]
- reason: short explanation of your intent decision
- plan: either a valid plan object (see schema below) or null

{lang_instruction}

Rules for classification:
- TASK_PLANNING: The user asks to create a plan/to-do/task schedule with a goal/outcome.
- NOT_TASK_PLANNING: Unrelated to making a plan or tasks.
- INCOMPLETE: Too vague to create a proper plan (missing goal/timeframe/critical context).
- UNSAFE: Inappropriate (violence/hate/self-harm/illegal/etc.).

Rules for plan generation:
- If intent is UNSAFE: do not generate a plan; set plan to null.
- If intent is NOT_TASK_PLANNING: do not generate a plan; set plan to null.
- If intent is INCOMPLETE: do not generate a plan; set plan to null.
- If intent is TASK_PLANNING: generate a complete plan.

Hard constraints for the plan:
- Current date is {today_iso} (Asia/Bangkok).
- Do not invent precise dates if ambiguous; infer conservatively based on current date.
- `start_date` and `end_date` are YYYY-MM-DD with start_date <= end_date.
- `priority` is one of "Low","Medium","High" based on urgency/deadline.
- Create 3-10 clear, actionable subtasks.
- `subtasks` is an array of objects: each has `name` and `description`.

Schema for `plan` (when not null):
{{
  "task_name": string,
  "start_date": string (YYYY-MM-DD),
  "end_date": string (YYYY-MM-DD),
  "priority": "Low" | "Medium" | "High",
  "subtasks": [ {{ "name": string, "description": string }}, ... ]
}}

Only output the final JSON with keys: intent, confidence, reason, plan.

User's request:
{user_text}
"""
    return prompt.strip()


def assess_feasibility(plan: PlanOut) -> FeasibilityMeta:
    """
    ประเมินความเป็นไปได้สองชั้น:
    - IMPOSSIBLE (feasible=False): โครงสร้างไม่ถูกต้อง/ข้อมูลไม่ครบ/วันที่ผิดรูปแบบ เป็นต้น
    - HARD/MEDIUM/EASY (feasible=True): ผ่านขั้นต่ำแต่มีระดับความยากต่างกัน
    """
    reasons: List[str] = []
    warnings: List[str] = []

    # ----- Hard errors -> IMPOSSIBLE -----
    if _has_placeholder(plan.task_name):
        reasons.append("task_name is empty or placeholder")

    sd = ed = None
    if _has_placeholder(plan.start_date) or _has_placeholder(plan.end_date):
        reasons.append("date fields are empty or placeholder")
    else:
        try:
            sd = datetime.fromisoformat(plan.start_date).date()
            ed = datetime.fromisoformat(plan.end_date).date()
        except Exception:
            reasons.append("dates are not valid ISO format (YYYY-MM-DD)")
        if sd and ed and sd > ed:
            reasons.append("start_date is after end_date")

    n = len(plan.subtasks or [])
    if n < 3 or n > 10:
        reasons.append("subtasks count must be between 3 and 10")

    if plan.subtasks:
        for i, st in enumerate(plan.subtasks, 1):
            if _has_placeholder(st.name) or _has_placeholder(st.description):
                reasons.append(f"subtask #{i} has empty or placeholder fields")
            elif len(st.name.strip()) < 2 or len(st.description.strip()) < 4:
                reasons.append(f"subtask #{i} fields too short")

    if reasons:
        return FeasibilityMeta(
            feasible=False,
            difficulty="IMPOSSIBLE",
            warnings=warnings,
            reasons=reasons,
        )

    # ----- Heuristic difficulty (ยัง feasible แต่เสี่ยง) -----
    days = (ed - sd).days + 1 if sd and ed else 1
    tasks = n
    tasks_per_day = tasks / max(days, 1)

    if days <= 1 and tasks >= 5:
        warnings.append("กรอบเวลา 1 วัน แต่งานย่อย >= 5 รายการ")
    if tasks_per_day > 3:
        warnings.append(f"งานต่อวันสูง ({tasks_per_day:.1f}) อาจทำไม่ทัน")
    if plan.priority == "High" and days > 14:
        warnings.append("priority=High แต่ระยะเวลากว่า 14 วัน—ทบทวนความเร่งด่วน")

    if not warnings:
        difficulty = "EASY" if tasks_per_day <= 1.5 else "MEDIUM"
    else:
        difficulty = "HARD"

    return FeasibilityMeta(
        feasible=True,
        difficulty=difficulty,
        warnings=warnings,
        reasons=["ผ่านเกณฑ์ขั้นต่ำ"] + (["พบความเสี่ยง"] if warnings else []),
    )


# ============================ App ============================
API_DESCRIPTION = """
**ผู้ช่วยวางแผนงานอัจฉริยะ (Task Planner Assistant)**

รับคำขอภาษาธรรมชาติและแปลงเป็นแผนงาน (JSON) ด้วย Google Gemini โดยรองรับ soft-fail:
- ถ้าแผนยากมาก/เสี่ยงสูง -> ยังส่งแผนกลับ พร้อม feasibility metadata
- ถ้าแผนเป็นไปไม่ได้ -> เลือก strict/soft ได้ด้วย allow_soft หรือ SOFT_FEASIBILITY_DEFAULT
"""


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("FastAPI startup")
    yield
    logger.info("FastAPI shutdown")


app = FastAPI(
    title="Task Planner API (FastAPI + Gemini)",
    version="2.0.0",
    description=API_DESCRIPTION,
    lifespan=lifespan,
)


# ============ Middleware: access log + timing ============
@app.middleware("http")
async def log_requests(request: Request, call_next):
    req_id = str(uuid.uuid4())[:8]
    request.state.req_id = req_id
    start = time.perf_counter()
    client_ip = getattr(request.client, "host", "-")

    logger.info(f"[{req_id}] ▶ {request.method} {request.url.path} from {client_ip}")
    try:
        response = await call_next(request)
        elapsed_ms = (time.perf_counter() - start) * 1000
        response.headers["X-Request-ID"] = req_id
        response.headers["X-Process-Time-ms"] = f"{elapsed_ms:.1f}"
        logger.info(f"[{req_id}] ◀ {request.method} {request.url.path} -> {response.status_code} in {elapsed_ms:.1f} ms")
        return response
    except Exception:
        elapsed_ms = (time.perf_counter() - start) * 1000
        logger.exception(f"[{req_id}] ✖ Unhandled error after {elapsed_ms:.1f} ms")
        raise


# ============================ Endpoints ============================
@app.get("/")
async def root():
    return {"status": "Hello"}


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/plan", response_model=PlanResponse)
async def plan_endpoint(
    req: UserRequest,
    request: Request,
    response: Response,
    allow_soft: Optional[bool] = None,
):
    req_id = getattr(request.state, "req_id", "-")
    logger.info(f"[{req_id}] Received /plan with input length={len(req.input)}")

    # Today (Asia/Bangkok)
    today_iso = datetime.now(TH_TZ).date().isoformat()

    # API Key & model checks
    google_api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
    if not google_api_key:
        logger.error(f"[{req_id}] Missing GOOGLE_API_KEY/GEMINI_API_KEY")
        raise HTTPException(status_code=500, detail="Missing GOOGLE_API_KEY environment variable")

    model_name = os.getenv("GEMINI_MODEL")
    if not model_name:
        logger.error(f"[{req_id}] Missing GEMINI_MODEL")
        raise HTTPException(status_code=500, detail="Missing GEMINI_MODEL environment variable")

    # Pre-validation: gibberish
    user_text = req.input or ""
    if is_probably_gibberish(user_text):
        logger.info(f"[{req_id}] Reject invalid input (gibberish/too short)")
        raise HTTPException(
            status_code=422,
            detail={
                "error": "invalid_input",
                "message": "คำขอไม่ชัดเจน กรุณาอธิบายสิ่งที่อยากให้วางแผน พร้อมช่วงเวลา/เดดไลน์คร่าว ๆ",
                "examples": [
                    "ช่วยวางแผนเตรียมพรีเซนต์ยอดขายประจำสัปดาห์ จะพรีเซนต์วันศุกร์นี้",
                    "วางแผนอ่านหนังสือสอบวิชาคณิต ภายใน 10 วัน",
                    "ช่วยจัดตารางออกกำลังกาย 4 สัปดาห์ เน้นลดไขมัน",
                ],
            },
        )

    # Build prompt & config
    config = {
        "response_mime_type": "application/json",
        "response_schema": CombinedOut,
    }
    prompt = make_combined_prompt(user_text, today_iso, lang=req.target_language)

    # Create client
    client = genai.Client(api_key=google_api_key)

    # Call model (with fallback)
    try:
        logger.info(f"[{req_id}] Calling Gemini model={model_name}")
        t0 = time.perf_counter()
        resp = client.models.generate_content(model=model_name, contents=prompt, config=config)
        logger.info(f"[{req_id}] Gemini responded in {(time.perf_counter() - t0) * 1000:.1f} ms")
    except ServerError as se:
        status_code = getattr(se, "status_code", None)
        provider_status = None
        try:
            provider_status = (getattr(se, "response_json", {}) or {}).get("error", {}).get("status")
        except Exception:
            provider_status = None

        fb_model = os.getenv("GEMINI_FALLBACK_MODEL")
        if status_code in (429, 503) and fb_model and fb_model != model_name:
            logger.warning(f"[{req_id}] {status_code} {provider_status} -> trying fallback={fb_model}")
            try:
                t1 = time.perf_counter()
                resp = client.models.generate_content(model=fb_model, contents=prompt, config=config)
                logger.info(f"[{req_id}] Fallback responded in {(time.perf_counter() - t1) * 1000:.1f} ms")
            except Exception:
                logger.exception(f"[{req_id}] Fallback also failed")
                raise HTTPException(
                    status_code=503 if status_code == 503 else 429 if status_code == 429 else 502,
                    detail={
                        "error": "upstream_unavailable",
                        "message": "บริการโมเดลภายนอกไม่พร้อมใช้งาน โปรดลองใหม่ภายหลัง",
                        "provider_status": provider_status,
                    },
                )
        else:
            logger.exception(f"[{req_id}] Gemini API error (status={status_code}, {provider_status})")
            http_status = 503 if status_code == 503 else 429 if status_code == 429 else 502
            raise HTTPException(
                status_code=http_status,
                detail={
                    "error": "upstream_unavailable" if http_status in (429, 503) else "upstream_error",
                    "message": "บริการโมเดลภายนอกไม่พร้อมใช้งาน โปรดลองใหม่ภายหลัง"
                    if http_status in (429, 503)
                    else f"Gemini API error",
                    "provider_status": provider_status,
                },
            )
    except Exception as e:
        logger.exception(f"[{req_id}] Gemini API error: {e}")
        raise HTTPException(status_code=502, detail=f"Gemini API error: {e}")

    # Parse model output
    combined: Optional[CombinedOut] = getattr(resp, "parsed", None)
    if not combined:
        logger.warning(f"[{req_id}] No .parsed -> try parse resp.text")
        try:
            combined = CombinedOut(**json.loads(resp.text))
        except Exception:
            logger.exception(f"[{req_id}] Failed to parse CombinedOut")
            raise HTTPException(status_code=500, detail="Failed to parse model response into CombinedOut schema")

    logger.info(f"[{req_id}] intent={combined.intent} conf={combined.confidence:.2f} reason={combined.reason}")

    # Intent gating
    if combined.intent == "UNSAFE":
        logger.warning(f"[{req_id}] unsafe content: {combined.reason}")
        raise HTTPException(
            status_code=400,
            detail={
                "error": "unsafe_content",
                "message": "คำขอมีเนื้อหาที่ไม่เหมาะสม ไม่สามารถดำเนินการได้",
                "classifier_reason": combined.reason,
            },
        )

    if combined.intent in ("NOT_TASK_PLANNING", "INCOMPLETE"):
        raise HTTPException(
            status_code=422,
            detail={
                "error": "not_task_planning_or_incomplete",
                "message": "คำขอยังไม่ชัดเจนพอสำหรับการวางแผน กรุณาระบุเป้าหมายและกรอบเวลา",
                "classifier_reason": combined.reason,
                "hints": [
                    "เป้าหมาย/หัวข้อที่ต้องการวางแผนคืออะไร",
                    "กรอบเวลาเริ่ม–สิ้นสุด หรือเดดไลน์",
                    "เงื่อนไข/ข้อจำกัดสำคัญ (เช่น งบประมาณ, ทรัพยากร, ช่องทาง)",
                ],
            },
        )

    if not combined.plan:
        logger.error(f"[{req_id}] Missing plan in acceptable intent")
        raise HTTPException(status_code=500, detail="Model did not return a plan for acceptable intent")

    # Feasibility (soft-fail)
    soft_default = os.getenv("SOFT_FEASIBILITY_DEFAULT", "true").lower() == "true"
    allow_soft = soft_default if allow_soft is None else bool(allow_soft)

    meta = assess_feasibility(combined.plan)

    # Attach headers for observability/edge routing
    response.headers["X-Plan-Feasible"] = "true" if meta.feasible else "false"
    response.headers["X-Plan-Difficulty"] = meta.difficulty
    if meta.warnings:
        response.headers["X-Plan-Warnings"] = "; ".join(meta.warnings)[:512]

    if not meta.feasible and not allow_soft:
        logger.warning(f"[{req_id}] IMPOSSIBLE -> strict 422, reasons={meta.reasons}")
        raise HTTPException(
            status_code=422,
            detail={
                "error": "plan_infeasible",
                "message": "แผนนี้เป็นไปไม่ได้ตามเกณฑ์ขั้นต่ำ โปรดแก้ไขข้อมูลให้ถูกต้อง",
                "reasons": meta.reasons,
                "hints": [
                    "ระบุช่วงวันที่ที่ชัดเจน (YYYY-MM-DD) และให้ start_date <= end_date",
                    "ปรับจำนวนงานย่อยให้อยู่ในช่วง 3–10 รายการ",
                    "เติมรายละเอียดที่ว่าง/placeholder ให้ครบถ้วน",
                ],
            },
        )

    logger.info(f"[{req_id}] return plan with feasibility={meta.difficulty} soft_allowed={allow_soft}")
    return PlanResponse(plan=combined.plan, feasibility=meta)


# ============================ Entrypoint ============================
if __name__ == "__main__":
    uvicorn.run(
        app,
        host=os.getenv("HOST", "127.0.0.1"),
        port=int(os.getenv("PORT", "8000")),
        log_level=LOG_LEVEL.lower(),
        access_log=True,
    )

# ============================ วิธีการรัน ============================
# 1) pip install fastapi uvicorn pydantic google-genai python-dotenv
# 2) ตั้งค่า .env อย่างน้อย:
#       GOOGLE_API_KEY="YOUR_API_KEY_HERE"     # หรือ GEMINI_API_KEY (fallback)
#       GEMINI_MODEL="gemini-1.5-pro"
#       LOG_LEVEL="INFO"
#       SOFT_FEASIBILITY_DEFAULT="true"        # เปิด soft-fail เป็นค่าเริ่มต้น
# 3) รันแอป:
#       python api.py
# 4) ใช้งาน:
#       POST http://127.0.0.1:8000/plan?allow_soft=true
#       Swagger UI: http://127.0.0.1:8000/docs
#       ReDoc:      http://127.0.0.1:8000/redoc
