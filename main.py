from dotenv import load_dotenv
load_dotenv()

import os
import re
import sys
import json
import logging
import requests
from datetime import datetime

from urllib.parse import quote_plus
from typing import List, Optional, Literal

import uvicorn
from fastapi import FastAPI

from pydantic import BaseModel, Field, ValidationError

from google import genai
from google.genai import types

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("Travel Planner")

# -----------------------------------------------------------------------------
# Constants / Config
# -----------------------------------------------------------------------------
GEMINI_MODEL_HIGH = os.getenv("GEMINI_MODEL_HIGH", "gemini-2.5-flash")
GEMINI_MODEL_LOW = os.getenv("GEMINI_MODEL_LOW", "gemini-2.5-flash-lite")

GOOGLE_CLOUD_API_KEY = os.getenv("GOOGLE_CLOUD_API_KEY", None)
CX_ID = os.getenv("CX_ID", None)

# -----------------------------------------------------------------------------
# Schemas (Pydantic)
# -----------------------------------------------------------------------------
Status = Literal["success", "error"]
PlaceType = Literal["hotel", "attraction", "restaurant", "other"]
Intent = Literal["travel_reasonable", "travel_unreasonable", "not_travel"]
NewPlanCheck = Literal["new_plan", "old_plan", "plan_warnings"]

class CheckResponse(BaseModel):
    intent: Intent = Field(..., description="Intent ที่ตรวจพบ: ใช้ 'travel_reasonable' เมื่อข้อความเกี่ยวกับท่องเที่ยวและสมเหตุสมผล, 'travel_unreasonable' เมื่อเกี่ยวกับท่องเที่ยวแต่ทำจริงได้ยาก, หรือ 'not_travel' เมื่อไม่ใช่เรื่องท่องเที่ยว")
    description: str = Field(..., description="ข้อความสั้น ๆ อธิบายเหตุผลที่เลือก intent ดังกล่าว (ภาษาไทย กระชับ)")

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
    name: str = Field(..., description="ชื่อสถานที่จริงตามที่ใช้ทั่วไป (คงรูปภาษา/การสะกด)")
    short_description: str = Field(..., description="สรุปจุดเด่นหรือประสบการณ์ที่สถานที่นี้มอบให้แบบกระชับ")
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
    overview: Optional[str] = Field(..., description="สรุปภาพรวมของแผน เช่น ไฮไลต์ จุดโฟกัส หรือกลุ่มเป้าหมาย")
    budget_price: Optional[float] = Field(None, description="งบประมาณรวมโดยประมาณของแผน (บาท)")
    style: Optional[str] = Field(..., description="คำอธิบายสั้น ๆ ของสไตล์ทริป (เช่น leisure, adventure)")
    itinerary: List[DayPlan] = Field(..., description="รายละเอียดแผนรายวัน ครอบคลุมลำดับเวลาและสถานที่ในแต่ละวัน")
    warnings: Optional[List[str]] = Field(None, description="รายการคำเตือนหรือข้อควรทราบเกี่ยวกับทริปนี้")

class PlanResponse(BaseModel):
    status: Status = Field(..., description="สถานะการตอบกลับ: 'success' เมื่อประมวลผลได้ หรือ 'error' เมื่อเกิดปัญหา")
    description: str = Field(..., description="ข้อความสรุปผลลัพธ์ หรืออธิบายสาเหตุเมื่อเกิดข้อผิดพลาด")
    plan_output: Optional[List[OutputPlan]] = Field(None, description="รายการแผนการท่องเที่ยวที่สร้างตามลำดับแนะนำ หรือ None หากเกิด error")
    hotel_output: Optional[List[List[PlaceDetail]]] = Field(None, description="รายการโรงแรมที่จับคู่กับแต่ละแผน (index เดียวกับ plan_output) หรือ None หากเกิด error")

# -------- Weather Schemas --------
class WeatherRequest(BaseModel):
    lat: Optional[float] = Field(..., description="ละติจูดของตำแหน่งที่ต้องการพยากรณ์ (เช่น 18.7883)", examples=[18.7883])
    lng: Optional[float] = Field(..., description="ลองจิจูดของตำแหน่งที่ต้องการพยากรณ์ (เช่น 98.9853)", examples=[98.9853])
    days: Optional[int] = Field(..., description="จำนวนวันพยากรณ์ที่ต้องการ (เลือกได้ 1-14 วัน)", examples=[3])

class WeatherDay(BaseModel):
    date: str = Field(..., description="วันที่ของพยากรณ์ในรูปแบบ YYYY-MM-DD")
    temp_max_c: Optional[float] = Field(None, description="อุณหภูมิสูงสุดโดยประมาณของวันนั้น (°C)")
    temp_min_c: Optional[float] = Field(None, description="อุณหภูมิต่ำสุดโดยประมาณของวันนั้น (°C)")
    precip_prob_max: Optional[float] = Field(None, description="โอกาสสูงสุดของฝนตกในวันนั้น (%)")
    precip_sum_mm: Optional[float] = Field(None, description="ปริมาณน้ำฝนรวมโดยประมาณในวันนั้น (มิลลิเมตร)")

class WeatherResponse(BaseModel):
    status: Status = Field(..., description="สถานะการตอบกลับ: 'success' หรือ 'error'")
    description: str = Field(..., description="สรุปผลการพยากรณ์ หรืออธิบายข้อผิดพลาดที่เกิดขึ้น")
    coordinates: Optional[Coordinates] = Field(None, description="พิกัดที่ใช้เป็นแหล่งอ้างอิงสำหรับผลพยากรณ์ (หากระบุ)")
    daily: List[WeatherDay] = Field(default_factory=list, description="รายการข้อมูลพยากรณ์อากาศรายวัน")

# -----------------------------------------------------------------------------
# System Instructions
# -----------------------------------------------------------------------------
PLANNER_CHECK = """
AI ตัวนี้มีหน้าที่ตรวจสอบข้อความจากผู้ใช้เพื่อจำแนกว่าข้อความนั้นเกี่ยวข้องกับการวางแผนการท่องเที่ยวหรือไม่ โดยใช้หลักการทำงานสองส่วนคือ Intent และ Validity
- Intent: หากข้อความสื่อถึงการท่องเที่ยว เช่น การวางแผนเดินทาง การถามหาสถานที่หรือร้านอาหาร ให้จัดเป็นหมวดการท่องเที่ยว มิฉะนั้นถือว่าไม่เกี่ยวข้อง
- Validity: พิจารณาความสมเหตุสมผลของรายละเอียด หากข้อมูลทำได้จริง เช่น วัน เวลา สถานที่ หรือกิจกรรมที่เหมาะสม ให้จัดเป็น travel_reasonable ถ้าเป็นไปไม่ได้ เช่น ท่องเที่ยวอวกาศพรุ่งนี้ หรือเที่ยวทั่วโลกภายในหนึ่งวัน ให้จัดเป็น travel_unreasonable หากข้อความไม่เข้าประเด็นท่องเที่ยวหรือคลุมเครือเกินไป ให้จัดเป็น not_travel
ผลลัพธ์การจำแนกต้องสรุปในรูปแบบ intent และ description ที่สั้น กระชับ และชัดเจน โดยไม่สร้างแผนการเดินทางจริง
ข้อกำหนดสำคัญ: ระบบนี้รองรับเฉพาะการท่องเที่ยวในประเทศไทยเท่านั้น
- ถ้าผู้ใช้ไม่ระบุประเทศ ให้ถือว่าหมายถึงประเทศไทย
"""

PLANNER_INSTRUCTIONS = """
คุณคือผู้ช่วยวางแผนการท่องเที่ยว (Travel Planner AI) แบบ one-shot
ภารกิจหลัก: สร้าง JSON ตามโครงสร้าง PlanResponse ที่มีแผนการเดินทางและรายการโรงแรมจากคำสั่งครั้งเดียวของผู้ใช้ โดยห้ามมีข้อความอื่นปะปน

ข้อกำหนดสูงสุด:
- วางแผนการท่องเที่ยวเฉพาะประเทศไทยเท่านั้น ทุกสถานที่ต้องอยู่ในประเทศไทย
- ใช้ภาษาไทยที่ชัดเจน รักษาชื่อเฉพาะ/ลิงก์ตามต้นฉบับ ห้ามดัดแปลงชื่อสถานที่
- ให้ใส่เฉพาะจุดหมายหรือกิจกรรมที่ทำ ณ สถานที่นั้น ห้ามบรรยายการเดินทางหรือใส่จุดที่เป็นการเดินทางกลับ/ออกเดินทาง
- อย่ารวมโรงแรมไว้ใน itinerary; โรงแรมให้แสดงเฉพาะใน hotel_output

กติกาทั่วไป:
- รักษาความถูกต้องของข้อมูล หากไม่มั่นใจให้เพิ่มคำเตือนใน warnings
- รูปแบบเวลาต้องเป็น "HH:MM" และตัวเลขใช้นิพจน์ตัวเลขจริง
- ถ้าต้องระบุการเดินทางระหว่างจุด ให้บันทึกใน PlaceDetail.notes ของจุดถัดไป เช่น "เดิน 10 นาทีจากจุดก่อนหน้า"
- ทุก PlaceDetail.name ต้องเป็นชื่อสถานที่จริง ห้ามใช้คำกว้าง ๆ เช่น "ร้านอาหารท้องถิ่น" หรือกิจกรรมทั่วไป

ค่าเริ่มต้นเมื่อข้อมูลไม่ครบ:
- ระยะเวลา 2 วัน
- สไตล์ทริป leisure/chill เลือกสถานที่ยอดนิยมเหมาะกับมือใหม่
- การเดินทางใช้ขนส่งสาธารณะเป็นหลัก (หรือแท็กซี่/เดิน ถ้าเหมาะสม)
- โรงแรมระดับ 3-4 ดาว ใกล้โซนเที่ยวหลัก
- ประมาณการงบรวม (THB) ใส่ใน budget_price

รูปแบบเอาต์พุต (PlanResponse):
- ต้องตอบเป็น JSON เท่านั้น โดยมีฟิลด์ status, description, plan_output, hotel_output
- plan_output: ลิสต์ของ OutputPlan (เรียงตามลำดับแนะนำ); หาก error ให้ตั้งเป็น None
- hotel_output: ลิสต์ของลิสต์ PlaceDetail.type="hotel" จับคู่กับแต่ละแผน (1-3 แห่งต่อแผน). หากไม่มีโรงแรมให้ใช้ลิสต์ว่าง หรือให้ None เมื่อ error

ข้อกำหนดสำหรับ OutputPlan.itinerary:
- ต้องมีอย่างน้อย 1 วัน เรียงตามเวลา
- DayPlan ต้องระบุ day_index และ summary ของธีม/ย่านในวันนั้น
- ItineraryStop ต้องมี order_in_day (เริ่มที่ 1 เพิ่มทีละ 1), start_time ("HH:MM"), stay_duration (นาที) และ places
- PlaceDetail.type ต้องเป็น "attraction" | "restaurant" | "other" สำหรับ itinerary
- PlaceDetail ต้องให้ short_description สั้นกระชับ และ notes สำหรับคำแนะนำ/การเดินทางจากจุดก่อนหน้าเมื่อจำเป็น
- opening_hours, price_info, reservation_recommended ควรกรอกเมื่อมีข้อมูลที่เชื่อถือได้
- coordinates, google_maps_url, image_url, isnewplan, des_warnings ให้กรอกตามข้อมูลจริง หากไม่มี/ไม่มั่นใจให้ตั้งเป็น None
- จัดลำดับคำนึงถึงเวลาเปิด-ปิด ระยะเวลาเที่ยว ระยะทาง และเวลาพัก

ข้อกำหนดสำหรับ hotel_output:
- แนะนำโรงแรม 1-3 แห่งต่อแผน (PlaceDetail.type="hotel") ใกล้ย่านท่องเที่ยวหลัก/สถานีขนส่ง
- ให้ short_description เน้นจุดเด่นสำหรับนักท่องเที่ยว และ notes ถ้ามีข้อมูลเพิ่มเติม เช่น ใกล้ BTS/ชายหาด
- ใส่ google_maps_url ที่ค้นหาได้จริง และตั้ง reservation_recommended เป็น true หากควรจองล่วงหน้า
- หากไม่มีข้อมูลโรงแรมที่เชื่อถือได้ให้ใช้ลิสต์ว่าง และระบุคำเตือนใน warnings

ความไม่แน่ใจและคำเตือน:
- หากเวลาเปิด-ปิด/ราคา/สถานะการจองอาจเปลี่ยน ให้เพิ่มข้อความเตือนใน plan_output.warnings
- ถ้าข้อมูลบางส่วนไม่แน่ใจ ให้ใส่ข้อความเช่น "อาจเปลี่ยนแปลง/โปรดตรวจสอบล่าสุด" อย่างชัดเจน

ข้อห้าม:
- ห้ามสร้างข้อมูลเท็จหรือพิกัด/ลิงก์ที่ไม่ถูกต้อง หากไม่รู้ให้ใช้ None
- ห้ามส่งข้อความบรรยายเพิ่มเติมนอกเหนือจาก JSON ตาม schema
"""

CHANGE_PLANNER_INSTRUCTIONS = """
คุณคือผู้ช่วยแก้ไขและตรวจสอบแผนท่องเที่ยวของประเทศไทย
อินพุตประกอบด้วย
1) ข้อความคำสั่งแก้ไขจากผู้ใช้ (อาจเป็น null/ว่าง หากผู้ใช้แก้ไขเองแล้ว)
2) แผนการเดินทางเดิมที่อาจมีการแก้ไข manual (เพิ่ม/ลบ/ย้ายจุด)

เป้าหมาย: ส่งออก JSON ตามโครงสร้าง PlanResponse เท่านั้น (ไม่มีข้อความอื่น) โดยคืนค่า plan_output ที่อัปเดตแล้วและ hotel_output ที่สอดคล้องกัน

หน้าที่หลัก:
- ถ้ามีคำสั่งแก้ไข ให้ปรับแผนตามคำสั่งอย่างเคร่งครัด
- ถ้าไม่มีคำสั่ง ให้ตรวจและเติมข้อมูลที่หายไป เช่น
  • แก้ชื่อสถานที่ให้ถูกต้องตามข้อมูลจริง
  • ปรับ start_time, stay_duration และ order_in_day ให้สมเหตุสมผลและเรียงตามเวลา
  • ตรวจสอบจำนวนจุดต่อวัน/เวลาการเดินทางให้ทำได้จริง
  • เพิ่ม warnings เมื่อพบความเสี่ยงหรือข้อมูลไม่แน่ชัด
- รักษาการแก้ไข manual ของผู้ใช้เมื่อไม่มีข้อผิดพลาดร้ายแรง

ข้อกำหนดสูงสุด:
- วางแผนเฉพาะภายในประเทศไทย ทุกสถานที่ต้องอยู่ในประเทศไทย
- ใส่เฉพาะจุดหมายหรือกิจกรรมที่ทำ ณ สถานที่นั้น ห้ามใส่ข้อความการเดินทาง เช่น "ออกเดินทาง", "เดินทางกลับ"
- ทุก PlaceDetail.name ต้องเป็นชื่อสถานที่จริง (ร้าน/คาเฟ่/แหล่งท่องเที่ยว/โรงแรมเจาะจง) ห้ามใช้คำทั่วไปหรือกิจกรรมกว้าง ๆ
- ใช้ภาษาไทยชัดเจน รักษาชื่อเฉพาะและลิงก์ตามต้นฉบับ

รูปแบบผลลัพธ์ (PlanResponse):
- status: success/error พร้อม description อธิบายสั้น ๆ
- plan_output: ถ้าสำเร็จให้เป็นลิสต์ความยาว 1 ของ OutputPlan ที่แก้ไขแล้ว; ถ้าไม่สามารถสร้างแผนได้ให้ใช้ [] หรือ None ตามบริบทของ error
- hotel_output: ลิสต์ของลิสต์ PlaceDetail.type="hotel" โดย index 0 จับคู่กับแผนที่ปรับแก้ (ถ้าไม่มีโรงแรมให้ใส่ลิสต์ว่าง). หาก error ให้ตั้งเป็น None

ข้อกำหนดสำหรับ OutputPlan ที่ปรับแก้:
- รักษา field name, overview, budget_price, style หากมีอยู่; เติมเมื่อขาดหายโดยใช้ข้อมูลที่สอดคล้องกับทริป
- itinerary ต้องมี DayPlan อย่างน้อย 1 วัน เรียงตาม day_index
- แต่ละ DayPlan ต้องมี summary ของธีม/ย่านในวันนั้น
- แต่ละ ItineraryStop ต้องมี order_in_day เพิ่มทีละ 1, start_time ("HH:MM"), stay_duration (นาที) และ places ที่ตรงกับโครงสร้าง PlaceDetail
- PlaceDetail.type ใน itinerary จำกัดที่ "attraction" | "restaurant" | "other" เท่านั้น
- เติม short_description กระชับ และ notes เมื่อจำเป็น (เช่น วิธีเดินทางจากจุดก่อนหน้า, คำเตือน)
- opening_hours, price_info, reservation_recommended ให้กรอกเมื่อมีข้อมูลที่เชื่อถือได้; ไม่แน่ชัดให้ละเว้นหรือระบุเตือนไว้ใน warnings
- coordinates, google_maps_url, image_url, isnewplan, des_warnings ให้คงค่าที่มีอยู่หรือปรับเป็น None หากไม่มีข้อมูลที่มั่นใจ

ข้อกำหนดสำหรับ hotel_output:
- แนะนำโรงแรม 1-3 แห่ง (PlaceDetail.type="hotel") ใกล้ย่านท่องเที่ยวหลักหรือจุดเชื่อมต่อ
- ให้ short_description ที่เน้นจุดเด่นของนักท่องเที่ยว และ notes หากมีข้อมูลระยะทาง/การเดินทางเพิ่มเติม
- ใส่ google_maps_url ที่ค้นหาได้จริง และตั้ง reservation_recommended เป็น true เมื่อควรจองล่วงหน้า

การจัดการความไม่แน่ใจ:
- หากเวลาเปิด-ปิด ราคา หรือสถานะการจองอาจเปลี่ยน ให้เพิ่มข้อความเตือนใน plan_output[0].warnings
- หากข้อมูลที่ผู้ใช้ให้มาคลุมเครือ ให้ถามโดยสอดแทรกใน warnings หรือ notes ว่าควรตรวจสอบเพิ่มเติม

ข้อห้าม:
- ห้ามเพิ่มสถานที่ต่างประเทศหรือข้อมูลเท็จ
- ห้ามลบข้อมูลที่ผู้ใช้ระบุไว้หากไม่ขัดกับความเป็นจริงหรือข้อกำหนด
- ห้ามส่งข้อความใด ๆ นอกเหนือจาก JSON ตาม schema
"""

SEARCH_INSTRUCTIONS = """
คุณคือผู้ช่วยค้นหาข้อมูลการท่องเที่ยว (Research Agent) ที่ใช้ Google Search เพื่อรวบรวมข้อมูลพื้นฐานสำหรับสร้างแผนการเดินทางในประเทศไทยเท่านั้น
เป้าหมาย: ดึงเฉพาะข้อมูลที่จำเป็นของสถานที่จริง (สถานที่ท่องเที่ยว ร้านอาหาร คาเฟ่ โรงแรม) ที่เกี่ยวข้องกับโจทย์ของผู้ใช้ โดยไม่เก็บข้อมูลเกินจำเป็น

แนวทางการค้นหา:
- ใช้คำสำคัญจากโจทย์ (จังหวัด ย่าน สไตล์ งบประมาณ ช่วงเวลา ฯลฯ) เพื่อค้นหาสถานที่จริงในประเทศไทย
- ให้ความสำคัญกับการระบุชื่อสถานที่จริง ประเภทสถานที่ และย่าน/จังหวัดที่ตั้ง
- เมื่อพบสถานที่ที่เกี่ยวข้อง ให้รวบรวมข้อมูลที่ตรวจสอบได้ เช่น
  1) เวลาเปิด-ปิด (opening_hours) หรือช่วงเวลาที่แนะนำ
  2) ข้อมูลราคาโดยรวม (ค่าเข้าชม ช่วงราคาเมนู งบประมาณ)
  3) หมายเหตุสำคัญ/ข้อจำกัด เช่น ต้องจองล่วงหน้า การแต่งกาย ข้อจำกัดเวลา
  4) จุดเด่นหรือเหตุผลที่ควรไป (สั้น กระชับ)
  5) ลิงก์อ้างอิงที่ช่วยตรวจสอบ เช่น Google Maps หรือเว็บไซต์ทางการ (ถ้ามีและจำเป็น)
- หากไม่พบข้อมูลที่แน่ชัด ให้เว้นว่างหรือระบุว่า "ไม่ทราบ โปรดตรวจสอบ" โดยไม่เดา
- ข้ามสถานที่ที่ไม่อยู่ในประเทศไทยหรือไม่ตรงกับโจทย์

ข้อควรระวัง:
- ไม่ต้องเก็บประวัติศาสตร์ยาว รีวิว หรือข้อมูลที่ไม่เกี่ยวกับการวางแผน
- ใช้ภาษาไทยสุภาพ กระชับ ชัดเจน
- ไม่ต้องสร้างแผนการเดินทาง เพียงส่งต่อข้อมูลดิบที่ Planner จะนำไปใช้
- หากข้อมูลน้อยหรือไม่ครบ ให้บันทึกไว้ในรูปแบบคำเตือนสั้น ๆ

รูปแบบคำตอบ:
- ตอบกลับเป็นข้อความ plain text เท่านั้น
- แยกแต่ละสถานที่ด้วยบรรทัดว่างหรือ bullet และระบุข้อมูลตามหัวข้อข้างต้น (เท่าที่หาได้จริง)
"""

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
def get_image(name: str) -> Optional[List[str]]:
    """คืน URL รูป"""
    fb = ['https://www.google.com/url?sa=i&url=https%3A%2F%2Fen.wikipedia.org%2Fwiki%2FEarth&psig=AOvVaw36xZKFWyYUzy4qlT6wPZHr&ust=1764240021659000&source=images&cd=vfe&opi=89978449&ved=0CBUQjRxqFwoTCPCZiq_Qj5EDFQAAAAAdAAAAABAE'] * 3
    
    url = "https://www.googleapis.com/customsearch/v1"
    
    params = {
        "q": name,
        "cx": CX_ID,
        "key": GOOGLE_CLOUD_API_KEY,
        "searchType": "image",
        "num": 3,
        "safe": "active"
    }

    try:
        # ส่งคำขอไปยัง Google
        response = requests.get(url, params=params)
        data = response.json()
        
        if 'error' in data:
            return f"Google API Error: {data['error']['message']}", fb
            
        # เช็คกรณีค้นหาไม่เจอ
        if 'items' not in data:
            return f"ไม่พบรูปภาพสำหรับคำว่า: {name}", fb
            
        # ดึง link รูปภาพจากผลลัพธ์
        image_urls = [item['link'] for item in data['items']]
        return None, image_urls

    except Exception as e:
        return f"เกิดข้อผิดพลาดของระบบ: {e}", fb

def get_map_url(name: str) -> Optional[str]:
    """คืน URL แผนที่"""
    return f"https://www.google.com/maps/search/?api=1&query={quote_plus(name or '')}"

def get_coordinates(name: str) -> Optional[Coordinates]:
    """คืนพิกัด"""
    try:
        url = f'https://www.google.com/maps/search/?api=1&query={quote_plus(name or '')}'
        headers = {'User-Agent': 'Mozilla/5.0'}
        response = requests.get(url, headers=headers, allow_redirects=False)
        matches = re.findall(r"(?<=center=)(.*?)(?=&)", response.text)[0]
        if matches:
            lat, lon = matches.split("%2C")
            return Coordinates(lat=lat, lng=lon)
        else:
            logger.warning(f"Coordinates: Could not find coordinates in redirect for '{name or ''}'")
            return None
    except Exception:
        logger.warning(f"Coordinates: Could not find coordinates in redirect for '{name or ''}'")
        return None
    
def enrich_place_detail(p: PlaceDetail) -> PlaceDetail:
    """เติมข้อมูล PlaceDetail"""
    try:
        if p.coordinates is None:
            coords = get_coordinates(p.name)
            if coords:
                p.coordinates = coords
        if not p.google_maps_url:
            p.google_maps_url = get_map_url(p.name)
        if not p.image_url and GOOGLE_CLOUD_API_KEY is not None and CX_ID is not None:
            error, img = get_image(p.name)
            if error:
                logger.warning(error)
            p.image_url = img if img else None
    except Exception as e:
        logger.warning(f"enrich_place_detail: error for '{p.name}': {e}")
    return p

def enrich_all_places(plan: PlanResponse) -> PlanResponse:
    """เติมข้อมูลสถานที่ในทั้งแผน"""
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
# Weather helpers
# -----------------------------------------------------------------------------
def fetch_weather_open_meteo(lat: float, lng: float, days: int = 7) -> List[WeatherDay]:
    """เรียก Open-Meteo เพื่อดึงพยากรณ์รายวัน (ไม่ต้องใช้ API key)"""
    try:
        days = 1 if days < 1 else days
        days = 14 if days > 14 else days

        params = {
            "latitude": lat,
            "longitude": lng,
            "daily": "temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum",
            "timezone": "auto",
            "forecast_days": days,
        }
        r = requests.get("https://api.open-meteo.com/v1/forecast", params=params, timeout=12)
        r.raise_for_status()
        data = r.json() or {}

        daily = data.get("daily", {})
        dates = daily.get("time", []) or []
        tmax = daily.get("temperature_2m_max", []) or []
        tmin = daily.get("temperature_2m_min", []) or []
        pprob = daily.get("precipitation_probability_max", []) or []
        psum = daily.get("precipitation_sum", []) or []

        out: List[WeatherDay] = []
        for i, d in enumerate(dates):
            out.append(WeatherDay(
                date=d,
                temp_max_c=float(tmax[i]) if i < len(tmax) and tmax[i] is not None else None,
                temp_min_c=float(tmin[i]) if i < len(tmin) and tmin[i] is not None else None,
                precip_prob_max=float(pprob[i]) if i < len(pprob) and pprob[i] is not None else None,
                precip_sum_mm=float(psum[i]) if i < len(psum) and psum[i] is not None else None,
            ))
        return out
    except Exception as e:
        logger.error(f"fetch_weather_open_meteo error: {e}")
        return []

def get_weather_by_coords(lat: float, lng: float, days: int = 7, location_name: Optional[str] = None) -> WeatherResponse:
    daily = fetch_weather_open_meteo(lat, lng, days=days)
    return WeatherResponse(
        status="success",
        description=f"พยากรณ์ {len(daily)} วัน",
        location_name=location_name,
        coordinates=Coordinates(lat=lat, lng=lng),
        daily=daily,
    )

# -----------------------------------------------------------------------------
# Google Research (เปิด tools เฉพาะเฟสนี้)
# -----------------------------------------------------------------------------
def research_from_user_input(user_input: str):
    client = genai.Client()
    google_search_tool = types.Tool(google_search=types.GoogleSearch())

    now = datetime.now()
    current_date = now.strftime("%Y-%m-%d")

    prompt = (
        f"วันที่ปัจจุบัน: {current_date}\n"
        f"โจทย์ของผู้ใช้:\n{user_input}\n\n"
        "หน้าที่ของคุณ (ต้องใช้ google_search_tool ในการค้นหา):\n"
        "- วิเคราะห์คำสำคัญจากโจทย์ (จังหวัด ย่าน สไตล์ทริป งบประมาณ ช่วงเวลา ฯลฯ)\n"
        "- หากผู้ใช้ไม่ระบุช่วงเวลา ให้ถือว่าทริปอยู่ในช่วงปัจจุบัน และค้นหาข้อมูลสภาพอากาศ/เทรนด์การท่องเที่ยวที่เกี่ยวข้องกับช่วงนี้\n"
        "- หากระบุช่วงเวลาแล้ว ให้โฟกัสข้อมูลของช่วงนั้น พร้อมตรวจสอบเทรนด์หรือกิจกรรมเด่นตามฤดูกาล\n"
        "- ใช้ google_search_tool เพื่อค้นหาสถานที่จริงในประเทศไทยที่ตรงกับโจทย์ พร้อมข้อมูลพื้นฐาน (เวลาทำการ ราคา หมายเหตุ) และประเด็นที่ต้องระวังตาม SEARCH_INSTRUCTIONS\n"
        "- สรุปผลเป็นข้อความ plain text เพื่อนำไปใช้สร้างแผนต่อ โดยไม่สร้างแผนเอง"
    )

    resp = client.models.generate_content(
        model=GEMINI_MODEL_LOW,
        contents=prompt,
        config=types.GenerateContentConfig(
            system_instruction=SEARCH_INSTRUCTIONS,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
            tools=[google_search_tool]
        ),
    )

    return (resp.text or "").strip()

# -----------------------------------------------------------------------------
# Gemini helpers (ไม่มี tools ในเฟสสร้าง/แก้แผน)
# -----------------------------------------------------------------------------
def intent_check(user_input: str) -> CheckResponse:
    client = genai.Client()
    resp = client.models.generate_content(
        model=GEMINI_MODEL_LOW,
        contents=user_input,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=CheckResponse,
            system_instruction=PLANNER_CHECK,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        ),
    )
    raw = (resp.text or "").strip()
    if not raw:
        raise ValueError("intent_check: empty response")
    return CheckResponse(**json.loads(raw))

def create_plan(user_input: str, research: str = "", options: int = 1) -> PlanResponse:
    client = genai.Client()

    options = max(1, min(options, 3))
    research_text = (research.strip() if research and research.strip() else "(ไม่มีข้อมูลเพิ่มเติมจากการค้นหา)")
    contents = f"""โหมดสร้างแผนท่องเที่ยวใหม่ (ต้องตอบเป็น JSON ตาม PlanResponse เท่านั้น)
คำขอของผู้ใช้:
{user_input}

จำนวนตัวเลือกแผนที่ต้องสร้าง: {options}
ข้อมูลสืบค้นเบื้องต้น (Plain text):
{research_text}

โปรดสร้างแผนตามข้อกำหนดใน PLANNER_INSTRUCTIONS โดยใช้ข้อมูลที่เชื่อถือได้และเพิ่มคำเตือนเมื่อจำเป็น"""

    resp = client.models.generate_content(
        model=GEMINI_MODEL_HIGH,
        contents=contents,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=PlanResponse,
            system_instruction=PLANNER_INSTRUCTIONS,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        ),
    )
    raw = (resp.text or "").strip()
    if not raw:
        return PlanResponse(status="error", description="Output Error", plan_output=None, hotel_output=None)

    try:
        plan = PlanResponse(**json.loads(raw))
    except ValidationError as ve:
        logger.error(f"create_plan: schema validation error: {ve}")
        return PlanResponse(status="error", description="Schema Validation Error", plan_output=None, hotel_output=None)

    return plan

def modify_plan_with_ai(instruction: Optional[str], old_json_text: str, research: str = "") -> PlanResponse:
    client = genai.Client()

    instruction_text = (instruction or "").strip()
    user_instruction = instruction_text if instruction_text else "(auto-fix mode: ไม่มีคำสั่งเพิ่มเติม)"
    research_text = (research.strip() if research and research.strip() else "(ไม่มีข้อมูลเพิ่มเติมจากการค้นหา)")
    contents = f"""โหมดแก้ไขแผนท่องเที่ยว (ต้องตอบเป็น JSON ตาม PlanResponse เท่านั้น)
Instruction จากผู้ใช้ (อาจว่าง):
{user_instruction}

แนวทางการทำงาน:
- หากมี instruction ให้ปฏิบัติตามอย่างครบถ้วน แล้วตรวจสอบว่าทุกสถานที่อยู่ในประเทศไทยและเป็นไปตามข้อกำหนด
- หาก instruction ว่าง ให้ทำงานแบบ auto-fix: ตรวจแผนเดิมและปรับแก้เมื่อมีข้อมูลที่เชื่อถือได้ ดังนี้
  • ปรับ start_time, stay_duration และ order_in_day ให้สอดคล้องกับลำดับเวลาและการเดินทางจริง
  • เติมหรืออัปเดต notes, opening_hours, price_info, reservation_recommended, coordinates, google_maps_url, image_url เมื่อมีข้อมูลที่ยืนยันได้ (ถ้าไม่แน่ใจให้คงค่า None)
  • ตรวจสอบความเป็นไปได้ของจำนวนจุดต่อวัน/การเดินทาง และเพิ่ม warnings เมื่อพบข้อจำกัดหรือข้อมูลไม่ครบ
- รักษาการแก้ไข manual ของผู้ใช้ เว้นแต่ผิดข้อเท็จจริงหรือขัดกับข้อกำหนด
- ห้ามเพิ่มสถานที่นอกประเทศไทย และห้ามเพิ่มโรงแรมลงใน itinerary (โรงแรมอยู่ใน hotel_output เท่านั้น)
- ใช้ warnings เพื่อแจ้งประเด็นที่ต้องตรวจสอบต่อ
- ผลลัพธ์ต้องเป็น PlanResponse ที่มี plan_output ยาว 1 (หรือ [] หากไม่สามารถสร้างแผนได้) และ hotel_output จับคู่ตาม index

OLD PLAN (JSON):
{old_json_text}

ข้อมูลสืบค้นจาก Google Research (Plain text):
{research_text}
"""

    resp = client.models.generate_content(
        model=GEMINI_MODEL_HIGH,
        contents=contents,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=PlanResponse,
            system_instruction=CHANGE_PLANNER_INSTRUCTIONS,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        ),
    )
    raw = (resp.text or "").strip()
    if not raw:
        return PlanResponse(status="error", description="Output Error", plan_output=None, hotel_output=None)

    try:
        new_plan = PlanResponse(**json.loads(raw))
    except ValidationError as ve:
        logger.error(f"modify_plan_with_ai: schema validation error: {ve}")
        return PlanResponse(status="error", description="Schema Validation Error", plan_output=None, hotel_output=None)

    return new_plan

# -----------------------------------------------------------------------------
# Orchestrators (intent → research → plan/change → merge → enrich → weather)
# -----------------------------------------------------------------------------
def planner_makeplan(user_input: str, options: int = 1) -> PlanResponse:
    if not user_input:
        return PlanResponse(status="error", description="Input Error: empty input", plan_output=None, hotel_output=None)
    try:
        options = max(1, min(options, 3))
        ic = intent_check(user_input)
        logger.info(f"intent = {ic.intent} : {ic.description}")
        if ic.intent != "travel_reasonable":
            return PlanResponse(status="error", description=ic.description, plan_output=None, hotel_output=None)

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
        return PlanResponse(status="error", description="Output Error", plan_output=None, hotel_output=None)

def planner_changeplan(instruction: Optional[str], olddata: str) -> PlanResponse:
    if not olddata:
        return PlanResponse(status="error", description="Input Error: olddata is empty", plan_output=None, hotel_output=None)
    try:
        # 1) แก้แผนโดยมีบริบทสืบค้น
        new_plan = modify_plan_with_ai(instruction, olddata)
        if new_plan.status != "success":
            return new_plan

        # 2) เติมข้อมูล
        new_plan = enrich_all_places(new_plan)

        return new_plan
    except Exception as e:
        logger.error(f"planner_changeplan error: {e}")
        return PlanResponse(status="error", description="Output Error", plan_output=None, hotel_output=None)

# -----------------------------------------------------------------------------
# FastAPI
# -----------------------------------------------------------------------------
app = FastAPI()

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
    logger.info(
        f"MakePlan: input len={len(user_input)} preview='{user_input.replace(chr(10), ' ')[:100]}' options={options}"
    )
    return planner_makeplan(user_input, options=options)

@app.post("/changeplan", response_model=PlanResponse)
async def changeplan(request: ChangePlan):
    instruction = (request.input or "").strip() if request.input else None
    olddata = (request.olddata or "").strip()
    has_instruction = "Yes" if instruction else "No (auto-fix mode)"
    logger.info(f"ChangePlan: has_instruction={has_instruction} olddata len={len(olddata)}")
    return planner_changeplan(instruction, olddata)

@app.post("/weather", response_model=WeatherResponse)
async def weather(req: WeatherRequest):
    try:
        return get_weather_by_coords(req.lat, req.lng, days=req.days)
    except Exception as e:
        logger.error(f"/weather error: {e}")
        return WeatherResponse(status="error", description="Unexpected Error", daily=[])

# -----------------------------------------------------------------------------
# Entrypoint
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)


"""
API Usage Overview
ระบบให้บริการผ่าน FastAPI พร้อม Swagger UI ที่ /docs (ค่าเริ่มต้น host 127.0.0.1, port 8000) เพื่อทดลองเรียกใช้งานได้ทันที หากต้องการสื่อสารกับ API โดยตรงให้ดูรายละเอียดแต่ละ endpoint ด้านล่าง

การสร้างแผนใหม่ - POST /makeplan
- ส่งคำสั่งภาษาไทยในฟิลด์ `input` เช่น “วางแผนเที่ยวเชียงใหม่ 3 วัน เน้นคาเฟ่”
- ฟิลด์ `options` กำหนดจำนวนข้อเสนอแผน (1-3, ค่าเริ่มต้น 1)
- ระบบจะตรวจ intent, ค้นข้อมูลพื้นฐานผ่าน Google Search ตามฤดูกาลปัจจุบัน และสร้างแผนตามสคีมา PlanResponse
- ผลลัพธ์เมื่อสำเร็จ (`status="success"`) จะมี `plan_output` เป็นลิสต์ของ `OutputPlan` ตามจำนวนตัวเลือก และ `hotel_output` ที่เป็นลิสต์ของลิสต์โรงแรม (PlaceDetail.type="hotel") จำนวน 1-3 แห่งต่อแผน
- ตรวจสอบ `warnings` เพื่อดูคำเตือน เช่น ข้อมูลที่ไม่แน่ชัดหรือข้อจำกัดตามฤดูกาล หากเกิดปัญหา `status` จะเป็น `error` พร้อมคำอธิบายใน `description`

การแก้ไขแผนเดิม - POST /changeplan
- ส่ง JSON ของแผนเดิมในฟิลด์ `olddata` และอาจเพิ่มคำสั่งเพิ่มเติมใน `input` (ถ้าเว้นว่างระบบจะเข้าสู่โหมด auto-fix)
- ระบบจะเคารพการแก้ไขของผู้ใช้และปรับเฉพาะส่วนที่ขาด/ผิด พร้อมเติมข้อมูลที่หาได้จริง (เวลาเปิด-ปิด, ราคา, notes ฯลฯ)
- คำตอบเป็น PlanResponse โดย `plan_output` จะมีเพียงแผนเดียว (หรือ [] หากไม่สามารถปรับได้) และ `hotel_output[0]` รวมรายชื่อโรงแรมที่อัปเดตแล้ว
- ใช้ `warnings` และฟิลด์เสริมของ PlaceDetail เช่น `isnewplan`, `des_warnings` เพื่อตรวจสอบสถานะหรือปัญหาของแต่ละจุด

การดูพยากรณ์อากาศ - POST /weather
- กำหนดพิกัดปลายทางใน `lat`, `lng` และจำนวนวันใน `days` (1-14)
- ระบบจะดึงข้อมูลจาก Open-Meteo แล้วตอบกลับเป็น `WeatherResponse` ซึ่งมีสถานะ, พิกัดอ้างอิง และลิสต์ `daily` ที่สรุปอุณหภูมิสูงสุด/ต่ำสุดกับโอกาสฝนต่อวัน
- ใช้ข้อมูลนี้เพื่อปรับกิจกรรมหรือเตรียมอุปกรณ์ให้เหมาะสมกับสภาพอากาศ

ข้อควรทราบเพิ่มเติม
- ทุก endpoint ตอบกลับด้วย HTTP 200 แต่สถานะจริงของงานให้ตรวจจากฟิลด์ `status` และข้อความใน `description`
- แนะนำให้เปิด Swagger UI หรือใช้เครื่องมืออย่าง curl/Postman ทดสอบ โดยป้อน/รับค่าตามสคีมาที่อธิบายไว้
- ระบบรองรับเฉพาะแผนการท่องเที่ยวภายในประเทศไทยเท่านั้น
"""
