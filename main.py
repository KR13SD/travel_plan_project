from dotenv import load_dotenv
load_dotenv()

import os
import re
import sys
import json
import asyncio
import logging
import requests
from datetime import datetime

from urllib.parse import quote_plus
from typing import List, Optional, Literal

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from pydantic import BaseModel, Field, ValidationError

from google import genai
from google.genai import types

# -----------------------------------------------------------------------------
# Settings (รวม env ทั้งหมดไว้ที่เดียว)
# -----------------------------------------------------------------------------
class Settings:
    """รวม environment variables ทั้งหมดไว้ที่เดียว"""
    GEMINI_MODEL_HIGH: str = os.getenv("GEMINI_MODEL_HIGH", "gemini-3-flash-preview")
    GEMINI_MODEL_MED: str = os.getenv("GEMINI_MODEL_MED", "gemini-2.5-flash")
    GEMINI_MODEL_LOW: str = os.getenv("GEMINI_MODEL_LOW", "gemini-2.5-flash-lite")
    GOOGLE_CLOUD_API_KEY: Optional[str] = os.getenv("GOOGLE_CLOUD_API_KEY")
    CX_ID: Optional[str] = os.getenv("CX_ID")
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO").upper()
    MAX_INPUT_LENGTH: int = int(os.getenv("MAX_INPUT_LENGTH", "2000"))

settings = Settings()

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
logging.basicConfig(
    level=settings.LOG_LEVEL,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("Travel Planner")

# -----------------------------------------------------------------------------
# Schemas (Pydantic)
# -----------------------------------------------------------------------------
Status = Literal["success", "error"]
PlaceType = Literal["hotel", "attraction", "restaurant", "other"]
Intent = Literal["travel_reasonable", "travel_unreasonable", "not_travel"]
NewPlanCheck = Literal["new_plan", "old_plan", "plan_warnings"]

class CheckResponse(BaseModel):
    intent: Intent = Field(..., description="Intent ที่ตรวจพบ: ใช้ 'travel_reasonable' เมื่อข้อความเกี่ยวกับท่องเที่ยวและสมเหตุสมผล, 'travel_unreasonable' เมื่อเกี่ยวกับท่องเที่ยวแต่ทำจริงได้ยาก, หรือ 'not_travel' เมื่อไม่ใช่เรื่องท่องเที่ยว")
    description: str = Field(..., description="อธิบายเหตุผล 1 ประโยค เช่น 'เป็นคำขอวางแผนท่องเที่ยวจังหวัดเชียงใหม่ที่ทำได้จริง'")

class MakePlan(BaseModel):
    input: str = Field(..., description="คำสั่งจากผู้ใช้เพื่อสร้างแผนการเดินทาง (ภาษาไทย)", examples=["วางแผนไปเที่ยวทะเลที่จังหวัดจันทบุรี"])
    options: int = Field(default=1, ge=1, le=3, description="จำนวนตัวเลือกแผนการเดินทางที่ต้องการให้ระบบส่งกลับ (กำหนดได้ 1-3)")

class ChangePlan(BaseModel):
    input: Optional[str] = Field(None, description="คำสั่งหรือเงื่อนไขเพิ่มเติมที่ต้องการให้ปรับในแผน หากปล่อยว่างให้ระบบตรวจและแก้อัตโนมัติ")
    olddata: str = Field(..., description="ข้อมูลแผนการเดินทางเดิม (JSON/ข้อความ) ที่ต้องการให้ระบบนำมาแก้ไข อาจผ่านการแก้ไขด้วยตนเองมาแล้ว")

class Coordinates(BaseModel):
    lat: float = Field(..., description="ละติจูดของสถานที่ (ระบบพิกัด WGS84)")
    lng: float = Field(..., description="ลองจิจูดของสถานที่ (ระบบพิกัด WGS84)")

class PlaceDetail(BaseModel):
    type: PlaceType = Field(..., description="ประเภทของสถานที่: 'hotel', 'attraction', 'restaurant' หรือ 'other'")
    name: str = Field(..., description="ชื่อสถานที่จริงที่เฉพาะเจาะจง เช่น 'วัดพระแก้ว' หรือ 'ร้านเจ๊ไฝ' ห้ามใช้คำกว้าง เช่น 'วัดใกล้เคียง' หรือ 'ร้านอาหารท้องถิ่น'")
    short_description: str = Field(..., description="สรุปจุดเด่น 1-2 ประโยค เช่น 'วัดเก่าแก่สไตล์ล้านนา วิวพระอาทิตย์ตกสวยงาม'")
    notes: Optional[str] = Field(None, description="หมายเหตุเพิ่มเติม เช่น วิธีเดินทางจากจุดก่อนหน้า หรือคำแนะนำพิเศษ")
    opening_hours: Optional[str] = Field(None, description="เวลาเปิด-ปิดหรือช่วงเวลาบริการ เช่น 'Mon-Sun 10:00-18:00' พร้อมข้อยกเว้นถ้ามี")
    price_info: Optional[str] = Field(None, description="ข้อมูลราคาโดยรวม เช่น ค่าเข้าชม หรือช่วงราคาเมนู (บาท)")
    reservation_recommended: Optional[bool] = Field(None, description="ระบุ true หากควรจองล่วงหน้า แม้ไม่ใช่ข้อบังคับ")

    coordinates: Optional[Coordinates] = Field(None, description="พิกัดละติจูด/ลองจิจูดของสถานที่ (ระบุเมื่อมั่นใจ)")
    google_maps_url: Optional[str] = Field(None, description="ลิงก์ Google Maps ของสถานที่ (หากมี)")
    image_url: Optional[List[str]] = Field(None, description="รายการ URL รูปภาพประกอบสถานที่")

    isnewplan: Optional[NewPlanCheck] = Field(None, description="สถานะของรายการนี้ภายในแผน: 'new_plan', 'old_plan' หรือ 'plan_warnings'")
    des_warnings: Optional[str] = Field(None, description="คำเตือนหรือรายละเอียดปัญหาเกี่ยวกับสถานที่/กิจกรรมนี้")

class ItineraryStop(BaseModel):
    order_in_day: int = Field(..., description="ลำดับกิจกรรมในวันนั้น (เริ่มที่ 1 และเรียงตามเวลา)")
    places: PlaceDetail = Field(..., description="รายละเอียดสถานที่หลักที่ใช้สำหรับจุดกิจกรรมนี้")
    start_time: Optional[str] = Field(None, description="เวลาเริ่มกิจกรรมในรูปแบบ HH:MM (เวลาท้องถิ่น)")
    stay_duration: Optional[int] = Field(None, description="ระยะเวลาที่แนะนำให้ใช้ในกิจกรรม/สถานที่นี้ (นาที)")

class DayPlan(BaseModel):
    day_index: int = Field(..., description="หมายเลขวันที่ในทริป (วันแรกมีค่า 1)")
    summary: Optional[str] = Field(..., description="สรุปธีม ไฮไลต์ หรือย่านหลักของวัน เช่น 'ย่านเมืองเก่า + พิพิธภัณฑ์'")
    stops: List[ItineraryStop] = Field(..., description="รายการกิจกรรมของวันนั้น เรียงตามลำดับเวลา")

class OutputPlan(BaseModel):
    name: Optional[str] = Field(..., description="ชื่อหรือหัวข้อของแผนทริปนี้")
    overview: Optional[str] = Field(..., description="สรุปภาพรวม 2-3 ประโยค ครอบคลุมไฮไลต์หลัก จุดเด่นของแต่ละวัน และกลุ่มเป้าหมาย")
    budget_price: Optional[float] = Field(None, description="งบประมาณรวมโดยประมาณของแผน (บาท)")
    style: Optional[str] = Field(..., description="คำอธิบายสั้น ๆ ของสไตล์ทริป (เช่น leisure, adventure)")
    itinerary: List[DayPlan] = Field(..., description="รายละเอียดแผนรายวัน ครอบคลุมลำดับเวลาและสถานที่ในแต่ละวัน")
    warnings: Optional[List[str]] = Field(None, description="รายการคำเตือนหรือข้อควรทราบเกี่ยวกับทริปนี้")

class PlanResponse(BaseModel):
    status: Status = Field(..., description="สถานะการตอบกลับ: 'success' เมื่อประมวลผลได้ หรือ 'error' เมื่อเกิดปัญหา")
    description: str = Field(..., description="ข้อความสรุปผลลัพธ์ หรืออธิบายสาเหตุเมื่อเกิดข้อผิดพลาด")
    plan_output: Optional[List[OutputPlan]] = Field(None, description="รายการแผนการท่องเที่ยวที่สร้างตามลำดับแนะนำ หรือ None หากเกิด error")
    hotel_output: Optional[List[List[PlaceDetail]]] = Field(None, description="รายการโรงแรมที่จับคู่กับแต่ละแผน (index เดียวกับ plan_output) หรือ None หากเกิด error")

# -----------------------------------------------------------------------------
# System Instructions
# -----------------------------------------------------------------------------
PLANNER_CHECK = """
คุณมีหน้าที่จำแนก intent ของข้อความผู้ใช้ โดยพิจารณา 2 ส่วน:
1) Intent — ข้อความเกี่ยวกับการท่องเที่ยว/สถานที่/ร้านอาหารหรือไม่
2) Validity — รายละเอียดทำได้จริงหรือไม่

กฎ:
- รองรับเฉพาะการท่องเที่ยวในประเทศไทยเท่านั้น
- ถ้าผู้ใช้ไม่ระบุประเทศ ให้ถือว่าหมายถึงประเทศไทย
- ถ้าระบุต่างประเทศ ให้จัดเป็น travel_unreasonable
- ห้ามสร้างแผนจริง ให้ตอบเป็น intent + description เท่านั้น

ตัวอย่าง:
- "อยากไปเที่ยวเชียงใหม่ 3 วัน" → travel_reasonable (วางแผนเชียงใหม่ ทำได้จริง)
- "อยากไปดาวอังคารพรุ่งนี้" → travel_unreasonable (เป็นไปไม่ได้)
- "ช่วยเขียนโค้ด Python ให้หน่อย" → not_travel (ไม่เกี่ยวกับท่องเที่ยว)
- "แนะนำร้านอาหารอร่อยหน่อย" → travel_reasonable (ถือว่าในไทย)
- "อยากไปปารีส" → travel_unreasonable (ไม่ใช่ประเทศไทย)
"""

PLANNER_INSTRUCTIONS = """
คุณคือผู้ช่วยวางแผนการท่องเที่ยว (Travel Planner AI) แบบ one-shot ตอบเป็น JSON ตามโครงสร้าง PlanResponse เท่านั้น ห้ามมีข้อความอื่นปะปน

ข้อกำหนดสำคัญ:
- เฉพาะประเทศไทยเท่านั้น ทุกสถานที่ต้องอยู่ในประเทศไทย
- ตอบในภาษาเดียวกับที่ผู้ใช้พิมพ์มา รองรับเฉพาะภาษาไทยและภาษาอังกฤษ หากเป็นภาษาอื่นให้ fallback เป็นภาษาไทย
- ห้ามรวมโรงแรมไว้ใน itinerary — โรงแรมใส่เฉพาะใน hotel_output (1-3 แห่งต่อแผน ใกล้ย่านท่องเที่ยวหลัก)
- ใส่เฉพาะจุดหมาย/กิจกรรมที่ทำ ณ สถานที่ ห้ามใส่การเดินทาง/ออกเดินทาง
- การเดินทางระหว่างจุดให้บันทึกใน notes ของจุดถัดไป

กฎลอจิก (ส่วนที่ schema ไม่ได้ครอบคลุม):
- จัดลำดับกิจกรรมคำนึงถึง: เวลาเปิด-ปิด, ระยะทางระหว่างจุด, เวลาพัก
- กรอก opening_hours, price_info, reservation_recommended เมื่อมีข้อมูลที่เชื่อถือได้เท่านั้น ถ้าไม่แน่ใจใช้ None
- เพิ่ม warnings เมื่อข้อมูลอาจเปลี่ยนแปลง หรือมีข้อจำกัดตามฤดูกาล

การตีความคำขอผู้ใช้ (สำคัญมาก):
- ถ้าผู้ใช้ระบุจำนวนสถานที่ (เช่น "แวะ 2 ที่") ให้ใส่เฉพาะจำนวนที่ขอ ห้ามเพิ่มจุดหมายเองโดยพลการ
- ปรับจำนวนวันให้เหมาะสมกับจำนวนสถานที่ (เช่น 2-3 ที่ = 1 วัน, 4-6 ที่ = 2 วัน)
- ห้าม "ยืด" แผนให้ยาวกว่าที่ผู้ใช้ต้องการ ถ้าเที่ยวได้จบใน 1 วัน ให้ทำ 1 วัน
- จำนวน OutputPlan ใน plan_output ต้องตรงกับจำนวน options ที่กำหนด ห้ามสร้างเกิน

ค่าเริ่มต้น (ใช้เมื่อผู้ใช้ไม่ได้ระบุเท่านั้น):
- ระยะเวลา: ประมาณจากจำนวนสถานที่ (ไม่ใช่ 2 วันเสมอ)
- สไตล์ leisure/chill, สถานที่ยอดนิยม
- ขนส่งสาธารณะเป็นหลัก, โรงแรม 3-4 ดาว
- ประมาณงบรวม (THB) ใส่ใน budget_price
- hotel_output: แนะนำโรงแรมเสมอ 1-3 แห่งต่อแผน ไม่ว่าจะเป็นทริปกี่วัน (ผู้ใช้เลือกเอง)

ฟิลด์ที่ระบบเติมให้อัตโนมัติ (ตั้งเป็น None เสมอ):
- coordinates, google_maps_url, image_url → ระบบจะเติมให้ทีหลังจาก API ภายนอก ห้าม AI กรอกเอง

ข้อห้าม:
- ห้ามสร้างข้อมูลเท็จ — ถ้าไม่แน่ใจให้ใช้ None
- ห้ามส่งข้อความใด ๆ นอกเหนือจาก JSON
"""

CHANGE_PLANNER_INSTRUCTIONS = """
คุณคือผู้ช่วยแก้ไขและตรวจสอบแผนท่องเที่ยวของประเทศไทย ตอบเป็น JSON ตาม PlanResponse เท่านั้น

อินพุต: (1) คำสั่งแก้ไขจากผู้ใช้ (อาจว่าง) และ (2) แผนเดิมในรูปแบบ JSON

โหมดทำงาน:
- มีคำสั่ง → ปรับแผนตามคำสั่งอย่างเคร่งครัด
- ไม่มีคำสั่ง (auto-fix) → ตรวจและแก้ไข:
  • ปรับ start_time, stay_duration, order_in_day ให้สมเหตุสมผลตามลำดับเวลาและระยะทาง
  • เติมข้อมูลที่หายไป (notes, opening_hours, price_info) เมื่อมีข้อมูลที่เชื่อถือได้
  • เพิ่ม warnings เมื่อพบความเสี่ยงหรือข้อมูลไม่ชัด

กฎสำคัญ:
- เฉพาะประเทศไทย ห้ามเพิ่มสถานที่ต่างประเทศ
- ตอบในภาษาเดียวกับที่แผนเดิมใช้ (ยึดตามภาษาของ plan ที่ส่งมา)
- รักษาการแก้ไข manual ของผู้ใช้ เว้นแต่ผิดข้อเท็จจริง
- ห้ามใส่โรงแรมใน itinerary (โรงแรมอยู่ใน hotel_output เท่านั้น)
- ห้ามลบข้อมูลที่ผู้ใช้ระบุไว้หากไม่ขัดข้อเท็จจริง
- plan_output ต้องมีแผนเดียว (หรือ [] หากไม่สามารถสร้างได้)
- hotel_output แนะนำ 1-3 แห่ง ใกล้ย่านท่องเที่ยวหลัก
- coordinates, google_maps_url, image_url → ตั้งเป็น None เสมอ (ระบบเติมให้อัตโนมัติ)
- ห้ามสร้างข้อมูลเท็จ ถ้าไม่รู้ให้ใช้ None
"""

SEARCH_INSTRUCTIONS = """
คุณคือผู้ช่วยค้นหาข้อมูลการท่องเที่ยว (Research Agent) ที่ใช้ Google Search เพื่อรวบรวมข้อมูลพื้นฐานสำหรับสร้างแผนการเดินทางในประเทศไทยเท่านั้น

เป้าหมาย: ค้นหาสถานที่จริงอย่างน้อย 8-12 แห่ง ที่หลากหลายประเภท ครอบคลุมทั้ง สถานที่ท่องเที่ยว ร้านอาหาร/คาเฟ่ และโรงแรม

แนวทาง:
- ใช้คำสำคัญจากโจทย์ (จังหวัด ย่าน สไตล์ งบประมาณ ช่วงเวลา) ค้นหาสถานที่จริงในประเทศไทย
- รวบรวมข้อมูลที่ตรวจสอบได้สำหรับแต่ละสถานที่: เวลาเปิด-ปิด, ราคา, หมายเหตุ/ข้อจำกัด, จุดเด่น
- หากไม่พบข้อมูลที่แน่ชัด ให้ระบุว่า "ไม่ทราบ โปรดตรวจสอบ" โดยไม่เดา
- ข้ามสถานที่ที่ไม่อยู่ในประเทศไทยหรือไม่ตรงกับโจทย์
- ไม่ต้องเก็บประวัติศาสตร์ยาว รีวิว หรือข้อมูลที่ไม่เกี่ยวกับการวางแผน
- ไม่ต้องสร้างแผนการเดินทาง เพียงส่งต่อข้อมูลดิบ

รูปแบบคำตอบ (plain text แบ่งหมวด):

[สถานที่ท่องเที่ยว]
- ชื่อสถานที่ | เวลาทำการ | ค่าเข้าชม | จุดเด่นสั้น ๆ | หมายเหตุ

[ร้านอาหาร/คาเฟ่]
- ชื่อร้าน | ประเภท | ช่วงราคา | จุดเด่น | ต้องจองไหม

[โรงแรมแนะนำ]
- ชื่อโรงแรม | ระดับดาว | ช่วงราคา/คืน | จุดเด่น/ทำเล

[คำเตือน/ข้อควรทราบ]
- ข้อมูลที่อาจเปลี่ยนแปลง หรือข้อจำกัดตามฤดูกาล
"""

# -----------------------------------------------------------------------------
# Shared Helpers
# -----------------------------------------------------------------------------
_FALLBACK_IMAGES: List[str] = ["https://upload.wikimedia.org/wikipedia/commons/7/70/The_Blue_Marble%2C_AS17-148-22727.jpg"] * 3


def _error_response(description: str) -> PlanResponse:
    """สร้าง PlanResponse แบบ error (ใช้แทนการเขียนซ้ำ)"""
    return PlanResponse(status="error", description=description, plan_output=None, hotel_output=None)


def _call_gemini_json(
    model: str,
    prompt: str,
    system_instruction: str,
    schema: type,
    caller_name: str = "gemini",
) -> tuple[Optional[str], Optional[BaseModel]]:
    """เรียก Gemini ด้วย JSON schema แล้ว return (error_description | None, parsed_result | None)"""
    client = genai.Client()
    resp = client.models.generate_content(
        model=model,
        contents=prompt,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=schema,
            system_instruction=system_instruction,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        ),
    )
    raw = (resp.text or "").strip()
    if not raw:
        return "Output Error", None
    try:
        parsed = schema(**json.loads(raw))
    except (ValidationError, json.JSONDecodeError) as exc:
        logger.error(f"{caller_name}: schema/json error: {exc}")
        return "Schema Validation Error", None
    return None, parsed


# -----------------------------------------------------------------------------
# Helpers — External Data
# -----------------------------------------------------------------------------
def get_image(name: str) -> tuple[Optional[str], List[str]]:
    """ค้นหารูปภาพจาก Google Custom Search API — คืน (error_msg | None, image_urls)"""
    url = "https://www.googleapis.com/customsearch/v1"
    params = {
        "q": name,
        "cx": settings.CX_ID,
        "key": settings.GOOGLE_CLOUD_API_KEY,
        "searchType": "image",
        "num": 3,
        "safe": "active",
    }

    try:
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()

        if "error" in data:
            return f"Google API Error: {data['error']['message']}", _FALLBACK_IMAGES

        if "items" not in data:
            return f"ไม่พบรูปภาพสำหรับคำว่า: {name}", _FALLBACK_IMAGES

        image_urls = [item["link"] for item in data["items"]]
        return None, image_urls

    except Exception as e:
        return f"เกิดข้อผิดพลาดของระบบ: {e}", _FALLBACK_IMAGES


def get_map_url(name: str) -> str:
    """สร้าง Google Maps search URL จากชื่อสถานที่"""
    return f"https://www.google.com/maps/search/?api=1&query={quote_plus(name or '')}"


def get_coordinates(name: str) -> Optional[Coordinates]:
    """พยายามดึงพิกัดจาก Google Maps redirect"""
    try:
        encoded_name = quote_plus(name or "")
        url = f"https://www.google.com/maps/search/?api=1&query={encoded_name}"
        headers = {"User-Agent": "Mozilla/5.0"}
        response = requests.get(url, headers=headers, allow_redirects=False, timeout=10)
        matches = re.findall(r"(?<=center=)(.*?)(?=&)", response.text)
        if matches:
            lat, lon = matches[0].split("%2C")
            return Coordinates(lat=float(lat), lng=float(lon))
        else:
            logger.warning(f"Coordinates: Could not find coordinates in redirect for '{name}'")
            return None
    except Exception:
        logger.warning(f"Coordinates: Could not find coordinates in redirect for '{name}'")
        return None


def enrich_place_detail(p: PlaceDetail) -> PlaceDetail:
    """เติมข้อมูลที่ขาด (พิกัด, แผนที่, รูปภาพ) ให้ PlaceDetail"""
    try:
        if p.coordinates is None:
            coords = get_coordinates(p.name)
            if coords:
                p.coordinates = coords
        if not p.google_maps_url:
            p.google_maps_url = get_map_url(p.name)
        if not p.image_url and settings.GOOGLE_CLOUD_API_KEY and settings.CX_ID:
            error, img = get_image(p.name)
            if error:
                logger.warning(error)
            p.image_url = img if img else None
    except Exception as e:
        logger.warning(f"enrich_place_detail: error for '{p.name}': {e}")
    return p


def enrich_all_places(plan: PlanResponse) -> PlanResponse:
    """เติมข้อมูลสถานที่ในทั้งแผน (เฉพาะรายการใหม่)"""
    try:
        if plan.plan_output:
            for option in plan.plan_output:
                for day in option.itinerary:
                    for stop in day.stops:
                        if stop.places and (stop.places.isnewplan is None or stop.places.isnewplan == "new_plan"):
                            stop.places = enrich_place_detail(stop.places)
        if plan.hotel_output:
            enriched_hotels: List[List[PlaceDetail]] = []
            for hotel_list in plan.hotel_output:
                current: List[PlaceDetail] = []
                for hotel in hotel_list:
                    if hotel.isnewplan is None or hotel.isnewplan == "new_plan":
                        current.append(enrich_place_detail(hotel))
                    else:
                        current.append(hotel)
                enriched_hotels.append(current)
            plan.hotel_output = enriched_hotels
    except Exception as e:
        logger.warning(f"enrich_all_places: {e}")
    return plan

# -----------------------------------------------------------------------------
# Google Research (เปิด tools เฉพาะเฟสนี้)
# -----------------------------------------------------------------------------
def research_from_user_input(user_input: str) -> str:
    client = genai.Client()
    google_search_tool = types.Tool(google_search=types.GoogleSearch())

    now = datetime.now()
    current_date = now.strftime("%Y-%m-%d")

    prompt = (
        f"วันที่ปัจจุบัน: {current_date}\n"
        f"โจทย์ของผู้ใช้:\n{user_input}\n\n"
        "หน้าที่ของคุณ (ต้องใช้ google_search_tool ในการค้นหา):\n"
        "- ค้นหาสถานที่อย่างน้อย 8-12 แห่ง รวม: สถานที่ท่องเที่ยว, ร้านอาหาร/คาเฟ่, โรงแรม\n"
        "- วิเคราะห์คำสำคัญจากโจทย์ (จังหวัด ย่าน สไตล์ทริป งบประมาณ ช่วงเวลา ฯลฯ)\n"
        "- หากผู้ใช้ไม่ระบุช่วงเวลา ให้ถือว่าทริปอยู่ในช่วงปัจจุบัน\n"
        "- หากระบุช่วงเวลาแล้ว ให้โฟกัสข้อมูลของช่วงนั้น พร้อมตรวจสอบเทรนด์หรือกิจกรรมเด่นตามฤดูกาล\n"
        "- จัดผลลัพธ์แบ่งตามหมวด: [สถานที่ท่องเที่ยว] [ร้านอาหาร/คาเฟ่] [โรงแรมแนะนำ] [คำเตือน/ข้อควรทราบ]\n"
        "- สรุปผลเป็นข้อความ plain text เพื่อนำไปใช้สร้างแผนต่อ โดยไม่สร้างแผนเอง"
    )

    resp = client.models.generate_content(
        model=settings.GEMINI_MODEL_MED,
        contents=prompt,
        config=types.GenerateContentConfig(
            system_instruction=SEARCH_INSTRUCTIONS,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
            tools=[google_search_tool],
        ),
    )

    return (resp.text or "").strip()

# -----------------------------------------------------------------------------
# Gemini helpers (ไม่มี tools ในเฟสสร้าง/แก้แผน)
# -----------------------------------------------------------------------------
def intent_check(user_input: str) -> CheckResponse:
    err, result = _call_gemini_json(
        model=settings.GEMINI_MODEL_LOW,
        prompt=user_input,
        system_instruction=PLANNER_CHECK,
        schema=CheckResponse,
        caller_name="intent_check",
    )
    if err or result is None:
        raise ValueError(f"intent_check: {err or 'empty response'}")
    return result


def create_plan(user_input: str, research: str = "", options: int = 1) -> PlanResponse:
    options = max(1, min(options, 3))
    research_text = research.strip() if research and research.strip() else "(ไม่มีข้อมูลเพิ่มเติมจากการค้นหา)"
    current_date = datetime.now().strftime("%Y-%m-%d")
    prompt = f"""โหมดสร้างแผนท่องเที่ยวใหม่
วันที่ปัจจุบัน: {current_date}
คำขอของผู้ใช้:
{user_input}

จำนวนตัวเลือกแผน (options): {options}
→ plan_output ต้องมีความยาวเท่ากับ {options} เท่านั้น ห้ามสร้างเกินหรือน้อยกว่า
→ hotel_output ต้องมีจำนวนลิสต์เท่ากับ plan_output (จับคู่ index)

--- ข้อมูลจาก Google Search (ใช้เป็นแหล่งอ้างอิง ห้ามสร้างข้อมูลเกินนี้) ---
{research_text}
--- สิ้นสุดข้อมูลสืบค้น ---

โปรดสร้างแผนตามข้อกำหนดที่ได้รับ โดยใช้ข้อมูลจากการสืบค้นข้างต้นเป็นหลัก และเพิ่มคำเตือนเมื่อจำเป็น"""

    err, plan = _call_gemini_json(
        model=settings.GEMINI_MODEL_HIGH,
        prompt=prompt,
        system_instruction=PLANNER_INSTRUCTIONS,
        schema=PlanResponse,
        caller_name="create_plan",
    )
    if err or plan is None:
        return _error_response(err or "Output Error")
    return plan


def modify_plan_with_ai(instruction: Optional[str], old_json_text: str, research: str = "") -> PlanResponse:
    instruction_text = (instruction or "").strip()
    user_instruction = instruction_text if instruction_text else "(auto-fix mode: ไม่มีคำสั่งเพิ่มเติม)"
    research_text = research.strip() if research and research.strip() else "(ไม่มีข้อมูลเพิ่มเติมจากการค้นหา)"
    current_date = datetime.now().strftime("%Y-%m-%d")
    prompt = f"""โหมดแก้ไขแผนท่องเที่ยว
วันที่ปัจจุบัน: {current_date}
Instruction จากผู้ใช้: {user_instruction}

--- แผนเดิม (JSON) ---
{old_json_text}
--- สิ้นสุดแผนเดิม ---

--- ข้อมูลจาก Google Search ---
{research_text}
--- สิ้นสุดข้อมูลสืบค้น ---
"""

    err, new_plan = _call_gemini_json(
        model=settings.GEMINI_MODEL_HIGH,
        prompt=prompt,
        system_instruction=CHANGE_PLANNER_INSTRUCTIONS,
        schema=PlanResponse,
        caller_name="modify_plan_with_ai",
    )
    if err or new_plan is None:
        return _error_response(err or "Output Error")
    return new_plan

# -----------------------------------------------------------------------------
# Token & Quota Optimization
# -----------------------------------------------------------------------------
def extract_and_strip_old_plan(olddata_text: str) -> tuple[str, dict]:
    """สกัดข้อมูลพิกัด/ลิงก์ออกเพื่อประหยัด Token และเก็บไว้คืนค่าทีหลังเพื่อประหยัด Quota API"""
    old_places_map = {}
    try:
        data = json.loads(olddata_text)
        if "plan_output" in data:
            for plan in data["plan_output"]:
                if "itinerary" in plan:
                    for day in plan["itinerary"]:
                        if "stops" in day:
                            for stop in day["stops"]:
                                if "places" in stop and stop["places"]:
                                    p = stop["places"]
                                    name = p.get("name")
                                    if name:
                                        old_places_map[name] = {
                                            "coordinates": p.get("coordinates"),
                                            "google_maps_url": p.get("google_maps_url"),
                                            "image_url": p.get("image_url")
                                        }
                                        p["coordinates"] = None
                                        p["google_maps_url"] = None
                                        p["image_url"] = None

        if "hotel_output" in data:
            for hotel_list in data["hotel_output"]:
                for h in hotel_list:
                    name = h.get("name")
                    if name:
                        old_places_map[name] = {
                            "coordinates": h.get("coordinates"),
                            "google_maps_url": h.get("google_maps_url"),
                            "image_url": h.get("image_url")
                        }
                        h["coordinates"] = None
                        h["google_maps_url"] = None
                        h["image_url"] = None
                        
        return json.dumps(data, ensure_ascii=False), old_places_map
    except Exception as e:
        logger.warning(f"extract_and_strip_old_plan error: {e}")
        return olddata_text, old_places_map


def restore_old_places(plan: PlanResponse, old_places_map: dict) -> PlanResponse:
    """คืนค่าพิกัด/ลิงก์ให้กับสถานที่เดิม เพื่อจะได้ไม่ต้องเรียก Google API ใหม่ (ประหยัด Quota)"""
    try:
        if plan.plan_output:
            for option in plan.plan_output:
                for day in option.itinerary:
                    for stop in day.stops:
                        if stop.places and stop.places.name in old_places_map:
                            cached = old_places_map[stop.places.name]
                            if cached.get("coordinates"):
                                c = cached["coordinates"]
                                if isinstance(c, dict) and "lat" in c and "lng" in c:
                                    stop.places.coordinates = Coordinates(lat=c["lat"], lng=c["lng"])
                            if cached.get("google_maps_url"):
                                stop.places.google_maps_url = cached["google_maps_url"]
                            if cached.get("image_url"):
                                stop.places.image_url = cached["image_url"]

        if plan.hotel_output:
            for hotel_list in plan.hotel_output:
                for h in hotel_list:
                    if h.name in old_places_map:
                        cached = old_places_map[h.name]
                        if cached.get("coordinates"):
                            c = cached["coordinates"]
                            if isinstance(c, dict) and "lat" in c and "lng" in c:
                                h.coordinates = Coordinates(lat=c["lat"], lng=c["lng"])
                        if cached.get("google_maps_url"):
                            h.google_maps_url = cached["google_maps_url"]
                        if cached.get("image_url"):
                            h.image_url = cached["image_url"]
    except Exception as e:
        logger.warning(f"restore_old_places error: {e}")
    return plan

# -----------------------------------------------------------------------------
# Orchestrators (intent → research → plan/change → enrich)
# -----------------------------------------------------------------------------
def planner_makeplan(user_input: str, options: int = 1) -> PlanResponse:
    if not user_input:
        return _error_response("Input Error: empty input")
    try:
        options = max(1, min(options, 3))
        ic = intent_check(user_input)
        logger.info(f"intent = {ic.intent} : {ic.description}")
        if ic.intent != "travel_reasonable":
            return _error_response(ic.description)

        # 1) สืบค้นก่อน (เปิด tools)
        research = research_from_user_input(user_input)

        # 2) ให้โมเดลสร้างแผนด้วย schema โดยอาศัยบริบทสืบค้น (ไม่เปิด tools)
        plan = create_plan(user_input, research=research, options=options)
        if plan.status != "success":
            return plan

        # 3) เติมข้อมูล
        plan = enrich_all_places(plan)

        return plan
    except Exception as e:
        logger.error(f"planner_makeplan error: {e}")
        return _error_response("Output Error")


def planner_changeplan(instruction: Optional[str], olddata: str) -> PlanResponse:
    if not olddata:
        return _error_response("Input Error: olddata is empty")
    try:
        # 1) ดึงข้อมูลเดิมเก็บไว้ และลดขนาด JSON ที่ส่งไปให้ AI (ประหยัด Token)

        logger.info(f"Instruction: {instruction}")
        logger.info(f"Olddata: {olddata[:200]}... (len={len(olddata)})")

        pass

        stripped_olddata, old_places_map = extract_and_strip_old_plan(olddata)
        logger.info(f"Stripped {len(old_places_map)} places from olddata to save tokens")
        logger.info("=== STRIPPED OLDDATA ===")
        # 2) แก้แผนโดยมีบริบทสืบค้น และ JSON ที่เล็กลง

        new_plan = modify_plan_with_ai(instruction, stripped_olddata)

        logger.info("=== AI RAW RESULT ===")
        logger.info(new_plan.model_dump_json(indent=2))

        if new_plan.status != "success":
            return new_plan

        # 3) คืนค่าข้อมูลที่ดึงไว้ ให้กับสถานที่เดิม (ประหยัด Quota API)
        new_plan = restore_old_places(new_plan, old_places_map)

        # 4) เติมข้อมูลเฉพาะสถานที่ใหม่ (ที่ไม่มีใน cached)
        new_plan = enrich_all_places(new_plan)

        return new_plan
    except Exception as e:
        logger.error(f"planner_changeplan error: {e}")
        return _error_response("Output Error")

# -----------------------------------------------------------------------------
# FastAPI
# -----------------------------------------------------------------------------
app = FastAPI(
    title="Travel Planner API",
    version="1.0.0",
    description="AI-powered travel itinerary planner for Thailand",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    logger.info("ROOT CHECK")
    return {"message": "Hello World"}


@app.get("/health")
async def health():
    logger.info("HEALTH CHECK")
    return {"status": "ok"}


@app.post("/makeplan", response_model=PlanResponse)
async def makeplan(request: MakePlan):
    user_input = (request.input or "").strip()
    options = max(1, min(request.options, 3))

    if len(user_input) > settings.MAX_INPUT_LENGTH:
        return _error_response(f"Input too long (max {settings.MAX_INPUT_LENGTH} characters)")

    logger.info(
        f"MakePlan: input len={len(user_input)} preview='{user_input.replace(chr(10), ' ')[:100]}' options={options}"
    )
    return await asyncio.to_thread(planner_makeplan, user_input, options)


@app.post("/changeplan", response_model=PlanResponse)
async def changeplan(request: ChangePlan):
    logger.info(request)
    instruction = (request.input or "").strip() if request.input else None
    olddata = (request.olddata or "").strip()
    has_instruction = "Yes" if instruction else "No (auto-fix mode)"
    logger.info(f"ChangePlan: has_instruction={has_instruction} olddata len={len(olddata)}")
    return await asyncio.to_thread(planner_changeplan, instruction, olddata)

# -----------------------------------------------------------------------------
# Entrypoint
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)

