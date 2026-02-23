import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class LocalizationService extends Translations {
  // 🔥 Default locale
  static final locale = const Locale('en', 'US');

  static final _box = GetStorage();
  static const String _storageKey = 'language_code';

  // 🔥 Fallback locale ถ้าไม่เจอภาษา
  static final fallbackLocale = const Locale('en', 'US');

  final currentLocale = const Locale('en', 'US').obs;

  // 🔥 ภาษาที่รองรับ
  static final langs = ['ไทย', 'English'];

  static final locales = [const Locale('th', 'TH'), const Locale('en', 'US')];

  @override
  Map<String, Map<String, String>> get keys => {
    'th_TH': {
      // ===== Core / Auth =====
      'hello,': 'สวัสดี',
      'login': 'เข้าสู่ระบบ',
      'logout': 'ออกจากระบบ',
      'cancel': 'ยกเลิก',
      'confirm': 'ยืนยัน',
      'register': 'สมัครสมาชิก',
      'email': 'อีเมล',
      'password': 'รหัสผ่าน',

      // ===== App Naming =====
      'ai-task-manager': 'AI Trip Planner',
      'appName': 'AI Trip Planner',
      'appSubtitle': 'ฉลาด ใช้ง่าย วางแผนไว',

      "adjustWithAI": "ปรับแผนด้วย AI",
      "aiPromptHint": "พิมพ์คำสั่ง เช่น เพิ่มสถานที่ หรือเลื่อนเวลา",
      "example": "ตัวอย่าง",
      "placeName": "ชื่อสถานที่",
      "moveUp": "เลื่อนขึ้น",
      "moveDown": "เลื่อนลง",
      "deleteItem": "ลบรายการ",
      "description": "รายละเอียด",
      "timeHint": "เวลา (14:30)",
      "durationHint": "ระยะเวลา",
      "price": "ราคา",
      "note": "โน้ต",
      "openInMap": "เปิดในแผนที่",
      "fullscreen": "แสดงเต็มจอ",
      "items": "รายการ",

      // ===== Dashboard / Overview (ปรับจากงาน -> ทริป) =====
      'dashboard': 'แดชบอร์ดทริป',
      'analytics': 'สถิติทริป',
      'overview': 'ภาพรวมทั้งหมด',
      'tsakstatusoverview': 'สัดส่วนสถานะในแผน',
      'taskstatusoverview': 'ภาพรวมสถานะในแผน',
      'tasksbystatus': 'จำนวนกิจกรรมตามสถานะ',
      'tasksNeedAttention': 'มี @count รายการที่ต้องจัดการด่วน',
      'loading': 'กำลังโหลดข้อมูล...',

      // ===== Tabs / Filters =====
      'all': 'ทั้งหมด',
      'today': 'วันนี้',
      'thisWeek': 'สัปดาห์นี้',
      'thisMonth': 'เดือนนี้',
      'allTime': 'ทั้งหมด',

      // ===== “Task list” -> “Trip plan items” =====
      'tasklist': 'รายการแผนเที่ยว',
      'todaytasks': 'แผนวันนี้',
      'taskincoming(3days)': 'รายการที่กำลังจะถึง (3 วัน)',
      'taskoverdue': 'รายการเลยเวลา',
      'notasksfortoday': 'วันนี้ยังไม่มีแผน 🤙🏽',
      'noupcomingtasks': 'ยังไม่มีรายการที่กำลังจะถึง',
      'nooverduetasks': 'ยังไม่มีรายการเลยเวลา',
      'notasksinthislist': 'ยังไม่มีรายการในหมวดนี้',
      'startcreatetask': 'เริ่มสร้างแผนเที่ยวกันเถอะ!',
      'addtask': 'เพิ่มรายการในแผน',
      'addnewtask': 'เพิ่มรายการใหม่',
      'createyourtask': 'สร้างแผนของคุณ',
      'taskview': 'ดูรายละเอียดแผน',
      'taskdetails': 'แก้ไขรายละเอียดแผน',
      'taskname': 'ชื่อรายการ',
      'date': 'ช่วงเวลา',
      'noAccount': 'ไม่มีบัญชีผู้ใช้?',

      // ===== Status (ใช้กับ “รายการ/กิจกรรม”) =====
      'status': 'สถานะ',
      'pending': 'ยังไม่เริ่ม',
      'inprogress': 'กำลังทำ',
      'completed': 'เสร็จสิ้น',
      'overdue': 'เลยเวลา',
      'out of date': 'เลยเวลาแล้ว',
      'starttask': 'เริ่มกิจกรรม',
      'endtask': 'เสร็จสิ้น',

      // ===== Priority =====
      'priority': 'ความสำคัญ',
      'low': 'ต่ำ',
      'medium': 'ปานกลาง',
      'high': 'สูง',
      'urgent': 'เร่งด่วน',

      // ===== CRUD actions =====
      'save': 'บันทึก',
      'savetask': 'บันทึกแผน',
      'saving...': 'กำลังบันทึก...',
      'tasksaved': 'บันทึกเรียบร้อยแล้ว',
      'cannotsave': 'ไม่สามารถบันทึกได้',
      'cannotSaveTask': 'ไม่สามารถบันทึกได้',
      'deletetask': 'ลบรายการ',
      'delete': 'ลบ',
      'comfirmdelete': 'ยืนยันการลบ',
      'dialogconfirmdelete': 'คุณแน่ใจว่าต้องการลบรายการนี้หรือไม่?',
      'confirmchangestatus': 'ยืนยันการเปลี่ยนสถานะ',
      'dialogconfirmstatus':
          'ต้องการเปลี่ยนสถานะรายการเป็น “เสร็จสิ้น” หรือไม่?',
      'confirmdeletesubtask': 'คุณต้องการลบรายการย่อยนี้หรือไม่?',
      'confirm_logout': 'ออกจากระบบ',
      'confirmlogout': 'คุณต้องการออกจากระบบหรือไม่?',
      'logout_title': 'ออกจากระบบ',
      'logout_message': 'คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?',

      // ===== Inputs / Validation =====
      'hintnametask': 'กรอกชื่อรายการในแผน',
      'inserttaskname': 'กรุณากรอกชื่อรายการ',
      'entertaskname': 'กรุณากรอกชื่อรายการ',
      'insertname': 'ใส่ชื่อรายการ...',
      'noTaskName': 'ไม่มีชื่อรายการ',
      'noDetails': 'ไม่มีรายละเอียด',
      'openMap': 'เปิดแผนที่',

      // ===== Subtasks -> Stops/Activities =====
      'subtasks': 'รายการย่อย',
      'subtask': 'รายการย่อย',
      'subtaskname': 'ชื่อรายการย่อย',
      'subtaskdetails': 'รายละเอียดรายการย่อย (ไม่จำเป็น)',
      'nosubtasks': 'ยังไม่มีรายการย่อย',
      'guidelinessubtasks': 'แตะปุ่ม "เพิ่ม" เพื่อเพิ่มรายการย่อย',
      'addsubtask': 'เพิ่มรายการย่อย',
      'deletesubtask': 'ลบรายการย่อย',
      'subtasksAppearHere': 'รายการย่อยจะแสดงที่นี่',
      'typeAndGenerate': 'ใส่ข้อความแล้วกดสร้างแผน',
      'subtask_progress': 'เสร็จแล้ว @completed จาก @total รายการ',
      'list_item': '@count รายการ',
      'add': 'เพิ่ม',

      // ===== AI Import / Generator =====
      'ai-import': 'สร้างแผนด้วย AI',
      'aiTaskGenerator': 'AI Trip Planner',
      'aiTaskGeneratorSubtitle': 'แปลงข้อความเป็นแผนเที่ยวอัตโนมัติ',
      'textToConvert': 'ข้อความที่ต้องการแปลง',
      'pasteTextPlaceholder':
          'วางแพลนเที่ยว, รายการสถานที่, หรือโน้ตที่อยากให้ AI จัดตารางให้...',
      'processingWithAI': 'กำลังประมวลผลด้วย AI...',
      'generateWithAI': 'สร้างแผนด้วย AI',
      'mainTaskInfo': 'ข้อมูลแผนหลัก',
      'taskName': 'ชื่อทริป/ชื่อแผน',
      'setMainTaskName': 'กำหนดชื่อทริปหรือชื่อแผนหลัก',
      'start': 'เริ่ม',
      'end': 'สิ้นสุด',
      'saveMainTask': 'บันทึกแผนหลัก',
      'pleaseEnterText': 'กรุณาใส่ข้อความ',
      'noSubtasksFound': 'ไม่พบรายการย่อยที่แปลงได้',
      'aiError': 'เกิดข้อผิดพลาดจาก AI',
      'pleaseEnterMainTaskName': 'กรุณาใส่ชื่อทริป/ชื่อแผนหลัก',
      'savedMainTaskWithNSubtasks':
          'บันทึกแผนหลักพร้อม {{count}} รายการย่อยเรียบร้อยแล้ว ✓',

      // ===== Greetings / Home =====
      'welcometext':
          'ยินดีต้อนรับสู่ AI Trip Planner! วางแผนเที่ยวได้ไวขึ้น จัดตารางได้ลงตัว ด้วยพลังของ AI',
      'ready-to-be-productive': 'พร้อมออกเดินทางกันหรือยัง',
      'good-morning': 'สวัสดีตอนเช้า',
      'good-afternoon': 'สวัสดีตอนบ่าย',
      'good-evening': 'สวัสดีตอนเย็น',
      'hiUser': 'สวัสดี, @name 👋',

      // ===== Insights (ปรับเป็นทริป) =====
      'performance': 'คุณภาพทริป',
      'productivity': 'ความคืบหน้าแผน',
      'onTimeRate': 'อัตราทำตามเวลา',
      'taskDistribution': 'การกระจายรายการ',
      'weeklyTrend': 'แนวโน้มรายสัปดาห์',
      'insights': 'คำแนะนำ',
      'noInsightsYet': 'ยังไม่มีคำแนะนำ',
      'excellentWork': 'เยี่ยมมาก!',
      'keepUpGoodWork': 'ทำต่อไป! แผนของคุณกำลังไปได้สวย',
      'goodProgress': 'คืบหน้าดี',
      'roomForImprovement': 'ดีแล้ว แต่ยังปรับให้ลงตัวได้อีก',
      'needsFocus': 'ควรโฟกัส',
      'tryToCompleteMore': 'ลองจัดลำดับรายการให้ชัดขึ้นเพื่อทำตามแผนได้มากขึ้น',
      'overdueTasks': 'รายการเลยเวลา',
      'focusTip': 'ทิปการจัดแผน',
      'considerFewTasks': 'ลองลดจำนวนสถานที่/กิจกรรมในช่วงเวลาเดียวกัน',

      'adjustPlan': 'ปรับแผนการท่องเที่ยว',

      // ===== Settings =====
      'settings': 'การตั้งค่า',
      'account': 'บัญชีผู้ใช้',
      'support': 'การสนับสนุน',
      'other_settings': 'การตั้งค่าอื่นๆ',
      'profile_info': 'ข้อมูลส่วนตัว',
      'profile_info_sub': 'จัดการข้อมูลโปรไฟล์ของคุณ',
      'profiledetails': 'จัดการโปรไฟล์',
      'displayname': 'ชื่อผู้ใช้',
      'chooseAvatar': 'เปลี่ยนรูปโปรไฟล์',
      'age': 'อายุ',
      'language': 'ภาษา',
      'languageheader': 'เลือกภาษา',
      'language_sub': 'เลือกภาษาที่ต้องการใช้',
      'chooseLanguage': 'เลือกภาษา',
      'languageChanged': 'เปลี่ยนภาษาเป็น {lang} แล้ว',
      'currentLanguage': 'ภาษาปัจจุบัน',
      'active': 'ใช้งานอยู่',
      'selectLanguage': 'เลือกภาษาที่คุณต้องการ',
      'languageDescription': 'เลือกภาษาสำหรับหน้าจอของแอปพลิเคชัน',
      'apply': 'ตกลง',

      // ===== About =====
      'about_app': 'เกี่ยวกับแอป',
      'about_app_sub': 'ข้อมูลเวอร์ชันและนโยบาย',
      'version': 'เวอร์ชัน : 1.0.0',
      'about_app_desc':
          'แอปนี้ช่วยคุณวางแผนเที่ยว จัดตารางกิจกรรม ติดตามความคืบหน้า และดูสรุปทริปด้วยข้อมูลเชิงลึกจาก AI',

      // ===== Change password =====
      'change_password': 'เปลี่ยนรหัสผ่าน',
      'change_password_sub': 'อัปเดตรหัสผ่านเพื่อความปลอดภัย',
      'secure_account': 'ปกป้องบัญชีของคุณ',
      'secure_account_desc': 'อัปเดตรหัสผ่านเพื่อความปลอดภัยของบัญชี',
      'current_password': 'รหัสผ่านปัจจุบัน',
      'current_password_hint': 'กรอกรหัสผ่านปัจจุบันของคุณ',
      'current_password_error': 'กรุณากรอกรหัสผ่านปัจจุบัน',
      'new_password': 'รหัสผ่านใหม่',
      'new_password_hint': 'กรอกรหัสผ่านใหม่ของคุณ',
      'new_password_error': 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
      'confirm_new_password': 'ยืนยันรหัสผ่านใหม่',
      'confirm_new_password_hint': 'กรอกรหัสผ่านใหม่อีกครั้ง',
      'confirm_password_error': 'รหัสผ่านไม่ตรงกัน',
      'password_tips': 'เคล็ดลับการตั้งรหัสผ่าน',
      'tip_length': 'ใช้ความยาวอย่างน้อย 8 ตัวอักษร',
      'tip_symbols': 'ใส่ตัวเลขและสัญลักษณ์',
      'tip_case': 'ผสมตัวพิมพ์เล็กและพิมพ์ใหญ่',
      'update_password': 'อัปเดตรหัสผ่าน',

      // ===== Notifications / Support =====
      'notifications': 'การแจ้งเตือน',
      'notifications_sub': 'จัดการการแจ้งเตือนแอป',
      'contact_support': 'ติดต่อฝ่ายสนับสนุน',
      'contact_support_sub': 'ได้รับความช่วยเหลือและแก้ไขปัญหา',
      'form_info_text': 'ความคิดเห็นของคุณช่วยให้เราปรับปรุงแอปให้ดียิ่งขึ้น',

      // ===== Travel style (ของทริปจริงๆ) =====
      'travelStyleTitle': 'สไตล์การท่องเที่ยว (เลือกได้หลายแบบ)',
      'travelStyleHint': 'เลือกอย่างน้อย 1 แบบเพื่อให้แผนเที่ยวตรงใจคุณ',

      'permission': 'สิทธิ์การเข้าถึง',
      'noPermission': 'คุณไม่มีสิทธิ์แก้ไขรายการนี้',

      'owner': 'เจ้าของ',
      'editor': 'ผู้แก้ไข',
      'viewer': 'ผู้ดู',

      'location': 'สถานที่',
      'invite': 'เชิญผู้ร่วมทริป',
      'edit': 'แก้ไข',

      'tripPlan': 'แผนการเดินทาง',
      'hotels': 'ที่พัก',

      'noPlans': 'ยังไม่มีแผนการเดินทาง',
      'noHotels': 'ยังไม่มีที่พัก',

      'nature': 'ธรรมชาติ',
      'culture': 'วัฒนธรรม',
      'foodie': 'สายกิน',
      'adventure': 'ผจญภัย',
      'relax': 'พักผ่อน',
      'shopping': 'ช้อปปิ้ง',
      'nightlife': 'กลางคืน',
      'photography': 'ถ่ายภาพ',
      'roadtrip': 'ทริปขับรถ',
      'family-friendly': 'เหมาะกับครอบครัว',
      'budget': 'ประหยัด',
      'luxury': 'หรูหรา',

      'noPermissionDelete': 'คุณไม่มีสิทธิ์ลบรายการนี้',
      'noPermissionEditTrip': 'คุณไม่มีสิทธิ์แก้ไขทริปนี้',
      'enterTaskName': 'กรุณากรอกชื่อทริป',
      'cannotSave': 'ไม่สามารถบันทึกได้',

      'confirmdelete': 'ยืนยันการลบ',
      'saveSuccess': 'บันทึกแผนเที่ยวแล้ว',
      'aiAdjustSuccess': 'AI ปรับแผนให้แล้ว',
      'aiAdjustFailed': 'ปรับแผนไม่สำเร็จ',
      'aiProcessing': 'กำลังให้ AI ปรับแผน...',
      'aiStopSave': 'หยุดบันทึก: ให้ AI ปรับไม่สำเร็จ',
      'aiPromptRequired': 'พิมพ์สิ่งที่อยากให้ AI ปรับก่อน',

      'editTravelPlan': 'ปรับแต่งแผนเที่ยว',

      'tripName': 'ชื่อทริป',
      'travelDate': 'วันที่เดินทาง',
      'plansActivities': 'แผน / กิจกรรม',

      'tripNameExample': 'เช่น เที่ยวกรุงเทพ 2 วัน 1 คืน',

      'saveButton': 'บันทึก',
      'addPlace': 'เพิ่มสถานที่',
      'addHotel': 'เพิ่มโรงแรม',
      'aiAdjust': 'ปรับด้วย AI',

      'shouldBookInAdvance': 'แนะนำให้จองล่วงหน้า',

      'selectOneHotel': 'เลือกโรงแรมหลักได้ 1 แห่ง',

      // ===== Months =====
      'jan': 'ม.ค.',
      'feb': 'ก.พ.',
      'mar': 'มี.ค.',
      'apr': 'เม.ย.',
      'may': 'พ.ค.',
      'jun': 'มิ.ย.',
      'jul': 'ก.ค.',
      'aug': 'ส.ค.',
      'sep': 'ก.ย.',
      'oct': 'ต.ค.',
      'nov': 'พ.ย.',
      'dec': 'ธ.ค.',

      // Header
      'joinPlan': 'เข้าร่วมแผน',
      'joinPlanSubtitle': 'กรอกโค้ดเชิญเพื่อเข้าร่วมแผนการเดินทาง',

      // Welcome
      'welcome': 'ยินดีต้อนรับ!',
      'welcomeJoinMessage':
          'คุณสามารถเข้าร่วมแผนการเดินทางของเพื่อนได้ด้วยโค้ดเชิญ',

      // Input
      'inviteCode': 'โค้ดเชิญ',
      'codeLength': 'โค้ดต้องมี 6 ตัวอักษร',
      'paste': 'วาง',
      'backToLogin': 'เข้าสู่ระบบ',

      'aiPromptEmpty': 'กรุณากรอกคำสั่งที่ต้องการให้ AI ปรับแผน',

      // Button
      'joinPlanButton': 'เข้าร่วมแผน',
      'joiningPlan': 'กำลังเข้าร่วม...',

      'survey': 'แบบสำรวจความพึงพอใจ',
      'survey_sub': 'ช่วยเราปรับปรุงแอปของเรา',

      // Info section
      'infoTitle': 'ข้อมูลเพิ่มเติม',
      'validCodeTitle': 'โค้ดต้องถูกต้อง',
      'validCodeDesc': 'ตรวจสอบให้แน่ใจว่าโค้ดเชิญถูกต้องและยังไม่หมดอายุ',

      'codeExpiryTitle': 'โค้ดมีวันหมดอายุ',
      'codeExpiryDesc': 'โค้ดบางรายการอาจหมดอายุหรือถูกใช้ครบจำนวนแล้ว',

      'joinImmediateTitle': 'เข้าร่วมทันที',
      'joinImmediateDesc': 'เมื่อโค้ดถูกต้อง คุณจะเข้าร่วมแผนได้ทันที',

      'success_title': 'ส่งข้อความสำเร็จ!',
      'success_message': 'ขอบคุณที่ติดต่อเรา ทีมงานจะตอบกลับคุณโดยเร็วที่สุด',
      'send_new_message': 'ส่งข้อความใหม่',

      'form_header_title': 'ต้องการความช่วยเหลือ?',
      'form_header_subtitle':
          'กรอกแบบฟอร์มด้านล่าง แล้วทีมงานจะติดต่อกลับโดยเร็ว',

      'name': 'ชื่อ-นามสกุล',
      'name_hint': 'กรอกชื่อ-นามสกุลของคุณ',
      'please_enter_name': 'กรุณากรอกชื่อ',

      'email_hint': 'กรอกอีเมลของคุณ',
      'please_enter_email': 'กรุณากรอกอีเมล',
      'please_enter_valid_email': 'กรุณากรอกอีเมลให้ถูกต้อง',

      'message': 'ข้อความ',
      'message_hint': 'อธิบายปัญหาหรือคำถามของคุณที่นี่...',
      'please_enter_message': 'กรุณากรอกข้อความ',
      'message_too_short': 'ข้อความต้องมีอย่างน้อย 10 ตัวอักษร',

      'send_message': 'ส่งข้อความ',
      'sending': 'กำลังส่ง...',
      'send_error': 'ไม่สามารถส่งข้อความได้ กรุณาลองใหม่อีกครั้ง',

      'durationH': '@h ชม.',
      'durationM': '@m นาที',
      'durationHM': '@h ชม. @m นาที',

      // Errors / Snackbar
      'pleaseEnterInviteCode': 'กรุณากรอกโค้ดเชิญ',
      'joinPlanSuccess': 'เข้าร่วมแผนสำเร็จ 🎉',

      'alreadyOwner': 'คุณเป็นเจ้าของแผนนี้อยู่แล้ว',
      'alreadyInPlan': 'คุณอยู่ในแผนนี้แล้ว',
      'inviteExpired': 'โค้ดเชิญหมดอายุแล้ว',
      'inviteMaxUsed': 'โค้ดถูกใช้ครบตามจำนวนแล้ว',
      'planNotFound': 'ไม่พบแผนที่เกี่ยวข้อง',
      'invalidInviteCode': 'โค้ดเชิญไม่ถูกต้อง',
      'planTimeConflict': 'ช่วงเวลาชนกับแผนที่มีอยู่',
      'joinFailed': 'เข้าร่วมแผนไม่สำเร็จ',

      // ===== Task List Page =====
      'subTitleTaskList': 'จัดการแผนการเดินทางทั้งหมดของคุณ',
      'startdate': 'วันเริ่มต้น',
      'duedate': 'วันสิ้นสุด',

      'allPlans': 'แผนทั้งหมด',
      'joinWithCode': 'เข้าร่วมด้วยโค้ดเชิญ',

      'leavePlan': 'ออกจากแผน (ซ่อนเฉพาะของฉัน)',
      'leavePlanConfirmTitle': 'ออกจากแผนนี้?',
      'leavePlanConfirmDesc': 'คุณจะไม่เห็นแผนนี้ในรายการของคุณอีกต่อไป',
      'confirmLeave': 'ยืนยัน',
      'view-overview': 'ภาพรวมแผน',
      'manage-tasks': 'จัดการแผน',
      'ai-assistant': 'Ai Assistant',
      'loginTitle': 'ยินดีต้อนรับ!',
      'descLogin': 'กรุณาเข้าสู่ระบบเพื่อเริ่มต้นใช้งาน',
      'registerTitle': 'เข้าร่วมกับเราและเริ่มวางแผนเที่ยวกับ AI!',
      'fullName': 'ชื่อผู้ใช้',
      'registerButton': 'สร้างบัญชี',
      'alreadyHaveAccount': 'มีบัญชีผู้ใช้แล้ว?',
      'createAccountHeader': 'สร้างบัญชีผู้ใช้',

      "enterName": "กรอกชื่อของคุณ",
      "pleaseinsertname": "กรุณากรอกชื่อ",
      "updateprofile": "อัปเดตโปรไฟล์สำเร็จ",
    },

    'en_US': {
      // ===== Core / Auth =====
      'hello,': 'Hello,',
      'login': 'Log in',
      'logout': 'Log out',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'register': 'Sign up',
      'email': 'Email',
      'password': 'Password',
      'descLogin': 'Please log in to start using the app',
      'loginTitle': 'Welcome !',

      'shouldBookInAdvance': 'Should book in advance.',

      // ===== App Naming =====
      'ai-task-manager': 'AI Trip Planner',
      'appName': 'AI Trip Planner',
      'appSubtitle': 'Smart. Simple. Fast planning.',

      "profiledetails": "Profile Details",
      "displayname": "Display Name",
      "enterName": "Enter your name",
      "chooseAvatar": "Choose Avatar",
      "save": "Save",
      "pleaseinsertname": "Please insert your name",
      "updateprofile": "Profile updated successfully",

      'noPermissionDelete': 'You do not have permission to delete this item',
      'noPermissionEditTrip': 'You do not have permission to edit this trip',
      'enterTaskName': 'Please enter trip name',
      'cannotSave': 'Cannot save',

      'confirmdelete': 'Confirm Delete',
      'dialogconfirmdelete': 'Do you want to delete this item?',
      'deletetask': 'Delete',

      'saveSuccess': 'Travel plan saved',
      'aiAdjustSuccess': 'AI adjusted the plan',
      'aiAdjustFailed': 'Failed to adjust plan',
      'aiProcessing': 'AI is adjusting the plan...',
      'aiStopSave': 'Stop saving: AI adjustment failed',
      'aiPromptRequired': 'Please enter AI instruction first',
      'openMap': 'Open Map',
      'editTravelPlan': 'Edit Travel Plan',

      'tripName': 'Trip Name',
      'travelDate': 'Travel Date',
      'plansActivities': 'Plans / Activities',
      'hotels': 'Hotels',

      'tripNameExample': 'e.g. Bangkok trip 2 days 1 night',
      'aiPromptHint':
          'Type command like “Add ICONSIAM in afternoon and move Yaowarat to evening”',
      'placeName': 'Place Name',
      'description': 'Description',
      'timeHint': 'Time (14:30)',
      'durationHint': 'Duration (1 hr)',
      'price': 'Price',
      'note': 'Note',

      'saveButton': 'Save',
      'addPlace': 'Add Place',
      'addHotel': 'Add Hotel',
      'example': 'Example',
      'aiAdjust': 'Adjust with AI',
      'openInMap': 'Open in Map',
      'fullscreen': 'Fullscreen',
      'moveUp': 'Move Up',
      'moveDown': 'Move Down',
      'deleteItem': 'Delete',

      'noPlans': 'No plans yet',
      'noHotels': 'No hotels yet',

      'start': 'Start',
      'end': 'End',

      'selectOneHotel': 'You can select 1 main hotel',
      'items': 'Items',

      // ===== Dashboard / Analytics =====
      'dashboard': 'Trip Dashboard',
      'analytics': 'Trip Analytics',
      'overview': 'Overall Overview',
      'tsakstatusoverview': 'Status breakdown (%)',
      'taskstatusoverview': 'Plan Status Overview',
      'tasksbystatus': 'Items by Status',
      'tasksNeedAttention': '@count items need attention',
      'loading': 'Loading...',
      'view-overview': 'View overview',
      'manage-tasks': 'Manage plans',
      'ai-assistant': 'AI Assistant',

      // ===== Tabs / Filters =====
      'all': 'All',
      'today': 'Today',
      'thisWeek': 'This week',
      'thisMonth': 'This month',
      'allTime': 'All time',
      'noAccount': 'No account?',

      // ===== Plan list =====
      'tasklist': 'Trip Plan',
      'todaytasks': 'Today\'s Plan',
      'taskincoming(3days)': 'Upcoming (3 days)',
      'taskoverdue': 'Late items',
      'notasksfortoday': 'No plan for today 🤙🏽',
      'noupcomingtasks': 'No upcoming items',
      'nooverduetasks': 'No late items',
      'notasksinthislist': 'No items here yet',
      'startcreatetask': 'Let’s start planning your trip!',
      'addtask': 'Add plan item',
      'addnewtask': 'Add new item',
      'createyourtask': 'Create your plan',
      'taskview': 'View plan details',
      'taskdetails': 'Edit plan details',
      'taskname': 'Item title',
      'date': 'Time',
      'createAccountHeader': 'Create an account',
      'registerTitle': 'Join us and start planning your trips with AI!',
      'fullName': 'Username',
      'registerButton': 'Create account',
      'alreadyHaveAccount': 'Already have an account?',
      'backToLogin': 'Back to login',

      'contact_support': 'Contact Support',

      'success_title': 'Message Sent Successfully!',
      'success_message':
          'Thank you for contacting us. Our support team will get back to you as soon as possible.',
      'send_new_message': 'Send New Message',

      'form_header_title': 'Need Help?',
      'form_header_subtitle':
          'Fill out the form below and our team will assist you shortly.',

      'name': 'Full Name',
      'name_hint': 'Enter your full name',
      'please_enter_name': 'Please enter your name',

      'email_hint': 'Enter your email address',
      'please_enter_email': 'Please enter your email',
      'please_enter_valid_email': 'Please enter a valid email address',

      'message': 'Message',
      'message_hint': 'Describe your issue or question here...',
      'please_enter_message': 'Please enter your message',
      'message_too_short': 'Message must be at least 10 characters',

      'send_message': 'Send Message',
      'sending': 'Sending...',
      'send_error': 'Failed to send message. Please try again.',

      'form_info_text':
          'Our support team typically responds within 24 hours. Please check your email for updates.',

      // ===== Status =====
      'status': 'Status',
      'pending': 'Not started',
      'inprogress': 'In progress',
      'completed': 'Done',
      'overdue': 'Late',
      'out of date': 'Late',
      'starttask': 'Start',
      'endtask': 'Done',

      // ===== Priority =====
      'priority': 'Priority',
      'low': 'Low',
      'medium': 'Medium',
      'high': 'High',
      'urgent': 'Urgent',

      // ===== CRUD =====
      'savetask': 'Save plan',
      'saving...': 'Saving...',
      'tasksaved': 'Saved successfully',
      'cannotsave': 'Unable to save',
      'cannotSaveTask': 'Unable to save',
      'delete': 'Delete',
      'comfirmdelete': 'Confirm delete',
      'confirmchangestatus': 'Confirm status',
      'dialogconfirmstatus': 'Mark this item as Done?',
      'confirmdeletesubtask': 'Delete this sub-item?',
      'confirmlogout': 'Are you sure you want to log out?',
      'logout_title': 'Log out',
      'logout_message': 'Are you sure you want to log out?',
      'confirm_logout': 'Log out',

      // ===== Inputs / Validation =====
      'hintnametask': 'Enter an item title',
      'inserttaskname': 'Please enter an item title',
      'entertaskname': 'Please enter an item title',
      'insertname': 'Type a title...',
      'noTaskName': 'No title',
      'noDetails': 'No details',

      // ===== Subtasks =====
      'subtasks': 'Sub-items',
      'subtask': 'Sub-item',
      'subtaskname': 'Sub-item title',
      'subtaskdetails': 'Details (optional)',
      'nosubtasks': 'No sub-items yet',
      'guidelinessubtasks': 'Tap "Add" to create a sub-item',
      'addsubtask': 'Add sub-item',
      'deletesubtask': 'Delete sub-item',
      'subtasksAppearHere': 'Sub-items will appear here',
      'subtask_progress': 'Completed @completed of @total items',
      'list_item': '@count items',
      'add': 'Add',

      // ===== AI Generator =====
      'ai-import': 'Create plan with AI',
      'aiTaskGenerator': 'AI Trip Planner',
      'aiTaskGeneratorSubtitle': 'Turn text into a trip plan automatically',
      'textToConvert': 'Text to convert',
      'pasteTextPlaceholder':
          'Paste your notes, places list, or any text — AI will schedule it into a plan...',
      'processingWithAI': 'Processing with AI...',
      'generateWithAI': 'Generate plan',
      'mainTaskInfo': 'Main plan info',
      'taskName': 'Trip / Plan name',
      'setMainTaskName': 'Set a trip / main plan name',
      'saveMainTask': 'Save main plan',
      'pleaseEnterText': 'Please enter some text',
      'noSubtasksFound': 'No sub-items could be generated',
      'aiError': 'AI error',
      'pleaseEnterMainTaskName': 'Please enter a trip / main plan name',
      'savedMainTaskWithNSubtasks': 'Saved with {{count}} sub-items ✓',

      // ===== Welcome / Insights =====
      'welcometext':
          'Welcome to AI Trip Planner! Plan faster, organize better, and travel smarter with AI.',
      'ready-to-be-productive': 'Ready to travel',
      'good-morning': 'Good morning',
      'good-afternoon': 'Good afternoon',
      'good-evening': 'Good evening',
      'hiUser': 'Hi, @name 👋',
      'performance': 'Trip quality',
      'productivity': 'Plan progress',
      'onTimeRate': 'On-time rate',
      'taskDistribution': 'Item distribution',
      'weeklyTrend': 'Weekly trend',
      'insights': 'Insights',
      'noInsightsYet': 'No insights yet',
      'excellentWork': 'Excellent!',
      'keepUpGoodWork': 'Keep it up — your plan looks great.',
      'goodProgress': 'Good progress',
      'roomForImprovement': 'Good, but you can refine it more.',
      'needsFocus': 'Needs focus',
      'tryToCompleteMore':
          'Try simplifying or reordering items for a smoother plan.',
      'overdueTasks': 'Late items',
      'focusTip': 'Planning tip',
      'considerFewTasks': 'Consider fewer stops in the same time window.',

      'permission': 'Permission',
      'noPermission': 'You do not have permission to edit this item',

      'owner': 'Owner',
      'editor': 'Editor',
      'viewer': 'Viewer',

      'location': 'Location',
      'invite': 'Invite',
      'edit': 'Edit',

      'tripPlan': 'Trip Plan',

      'nature': 'Nature',
      'culture': 'Culture',
      'foodie': 'Foodie',
      'adventure': 'Adventure',
      'relax': 'Relax',
      'shopping': 'Shopping',
      'nightlife': 'Nightlife',
      'photography': 'Photography',
      'roadtrip': 'Roadtrip',
      'family-friendly': 'Family-Friendly',
      'budget': 'Budget',
      'luxury': 'Luxury',

      // ===== Settings / About =====
      'settings': 'Settings',
      'account': 'Account',
      'support': 'Support',
      'other_settings': 'Other settings',
      'profile_info': 'Profile information',
      'profile_info_sub': 'Manage your profile details',
      'age': 'Age',
      'language': 'Language',
      'languageheader': 'Select language',
      'language_sub': 'Choose your preferred language',
      'chooseLanguage': 'Choose language',
      'languageChanged': 'Language changed to {lang}',
      'currentLanguage': 'Current language',
      'active': 'Active',
      'selectLanguage': 'Select your preferred language',
      'languageDescription': 'Choose a language for the app interface',
      'apply': 'Apply',
      'about_app': 'About',
      'about_app_sub': 'Version info & policies',
      'version': 'Version : 1.0.0',
      'about_app_desc':
          'This app helps you plan trips, schedule activities, track progress, and get AI-powered insights.',

      // ===== Security =====
      'change_password': 'Change password',
      'change_password_sub': 'Update your password for security',
      'secure_account': 'Secure your account',
      'secure_account_desc': 'Update your password to keep your account safe',
      'current_password': 'Current password',
      'current_password_hint': 'Enter your current password',
      'current_password_error': 'Please enter your current password',
      'new_password': 'New password',
      'new_password_hint': 'Enter your new password',
      'new_password_error': 'Password must be at least 6 characters long',
      'confirm_new_password': 'Confirm new password',
      'confirm_new_password_hint': 'Re-enter your new password',
      'confirm_password_error': 'Passwords do not match',
      'password_tips': 'Password tips',
      'tip_length': 'Use at least 8 characters',
      'tip_symbols': 'Include numbers and symbols',
      'tip_case': 'Mix uppercase and lowercase',
      'update_password': 'Update password',

      "adjustWithAI": "Adjust with AI",
      "adjustPlan": "Adjust plan",

      // ===== Notifications / Support =====
      'notifications': 'Notifications',
      'notifications_sub': 'Manage app notifications',
      'contact_support_sub': 'Get help and resolve issues',

      // ===== Travel style =====
      'travelStyleTitle': 'Travel styles (multi-select)',
      'travelStyleHint': 'Pick at least 1 style to personalize your trip plan',

      // ===== Months =====
      'jan': 'Jan',
      'feb': 'Feb',
      'mar': 'Mar',
      'apr': 'Apr',
      'may': 'May',
      'jun': 'Jun',
      'jul': 'Jul',
      'aug': 'Aug',
      'sep': 'Sep',
      'oct': 'Oct',
      'nov': 'Nov',
      'dec': 'Dec',

      // Header
      'joinPlan': 'Join Plan',
      'joinPlanSubtitle': 'Enter an invite code to join a travel plan',

      // Welcome
      'welcome': 'Welcome!',
      'welcomeJoinMessage':
          'You can join your friend’s travel plan using an invite code.',

      'durationH': '@h hr',
      'durationM': '@m min',
      'durationHM': '@h hr @m min',

      // Input
      'inviteCode': 'Invite Code',
      'codeLength': 'Code must contain 6 characters',
      'paste': 'Paste',
      'aiPromptEmpty': 'Please enter an instruction for AI to adjust your plan',

      // Button
      'joinPlanButton': 'Join Plan',
      'joiningPlan': 'Joining...',

      // Info section
      'infoTitle': 'Information',
      'validCodeTitle': 'Valid Code Required',
      'validCodeDesc': 'Make sure the invite code is correct and not expired.',

      'codeExpiryTitle': 'Code Expiration',
      'codeExpiryDesc': 'Some codes may expire or reach maximum usage limit.',

      'joinImmediateTitle': 'Instant Access',
      'joinImmediateDesc':
          'Once the code is valid, you will join the plan immediately.',

      // Errors / Snackbar
      'pleaseEnterInviteCode': 'Please enter an invite code',
      'joinPlanSuccess': 'Successfully joined the plan 🎉',

      'alreadyOwner': 'You are already the owner of this plan',
      'alreadyInPlan': 'You are already in this plan',
      'inviteExpired': 'Invite code has expired',
      'inviteMaxUsed': 'Invite code has reached maximum usage',
      'planNotFound': 'Plan not found',
      'invalidInviteCode': 'Invalid invite code',
      'planTimeConflict': 'This plan conflicts with your existing plans',
      'joinFailed': 'Failed to join plan',

      // ===== Task List Page =====
      'subTitleTaskList': 'Manage all your trip plans here',
      'startdate': 'Start date',
      'duedate': 'End date',

      'allPlans': 'All plans',
      'joinWithCode': 'Join with code',

      'leavePlan': 'Leave plan (hide from my list)',
      'leavePlanConfirmTitle': 'Leave this plan?',
      'leavePlanConfirmDesc': 'This plan will no longer appear in your list',
      'confirmLeave': 'Confirm',
      'survey': 'Satisfaction Survey',
      'survey_sub': 'Help us improve our app',
    },
  };

  // โหลดค่า locale จาก storage
  Locale? getSavedLocale() {
    final String? langCode = _box.read(_storageKey);
    if (langCode != null) {
      return _getLocaleFromString(langCode);
    }
    return null;
  }

  // เปลี่ยนภาษา + บันทึกค่า
  void changeLocale(String languageCode) {
    final locale = _getLocaleFromString(languageCode);
    currentLocale.value = locale;
    Get.updateLocale(locale);
    _box.write(_storageKey, languageCode); // << บันทึก
  }

  // Helper แปลง string → Locale
  Locale _getLocaleFromString(String lang) {
    switch (lang) {
      case 'th_TH':
        return const Locale('th', 'TH');
      case 'en_US':
        return const Locale('en', 'US');
      default:
        return fallbackLocale;
    }
  }
}
