// lib/pages/task_detail_page.dart
import 'package:ai_task_project_manager/pages/ai_map_page.dart';
import 'package:ai_task_project_manager/pages/map_preview.dart';
import 'package:ai_task_project_manager/widget/invite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../controllers/dashboard_controller.dart';
import '../models/task_model.dart';
import '../services/ai_api_service.dart'; //

class TaskDetailPage extends StatefulWidget {
  final TaskModel task;
  const TaskDetailPage({super.key, required this.task});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage>
    with TickerProviderStateMixin {
  late TextEditingController titleController;
  late DateTime startDate;
  late DateTime endDate;

  late DateTime editedStartDate;
  late DateTime editedEndDate;

  final DashboardController controller = Get.find<DashboardController>();
  final dateFormat = DateFormat('dd MMM yyyy');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // timezone-safe helper
  DateTime _asLocal(DateTime d) => d.isUtc ? d.toLocal() : d;

  // checklist
  List<Map<String, dynamic>> editedChecklist = [];
  List<Map<String, dynamic>> checklist = [];

  // hotel main select
  String? _selectedHotelKey;

  // AI prompt
  final TextEditingController _aiPromptCtrl = TextEditingController();
  bool _aiBusy = false;
  String? _aiBusyReason;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    final latestTask = controller.findTaskById(widget.task.id) ?? widget.task;

    // copy checklist แล้ว normalize
    editedChecklist = (latestTask.checklist ?? []).map<Map<String, dynamic>>((
      raw,
    ) {
      final m = Map<String, dynamic>.from(raw);

      // normalize type
      final type = (m['type'] ?? '').toString();
      if (type.isEmpty) {
        final hasHotelHints =
            m.containsKey('price') ||
            m.containsKey('notes') ||
            m.containsKey('reserve') ||
            (m['type'] == 'hotel');
        m['type'] = hasHotelHints ? 'hotel' : 'plan';
      }

      // default
      m['done'] = (m['done'] == true) || (m['completed'] == true);
      m['expanded'] = m['expanded'] ?? true;

      // date
      m['start_date'] = _toDate(m['start_date']);
      m['end_date'] = _toDate(m['end_date']);

      // string time/duration
      if (m['time'] != null && m['start_date'] != null) {
        final t = m['time'].toString();
        if (t.contains(':')) {
          final parts = t.split(':');
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;

          final base = m['start_date'] as DateTime;

          m['start_date'] = DateTime(
            base.year,
            base.month,
            base.day,
            hour,
            minute,
          );
        }
      }
      if (m['duration'] != null) m['duration'] = m['duration'].toString();

      // lat/lng
      m['lat'] = _toDouble(m['lat']);
      m['lng'] = _toDouble(m['lng']);

      // hotel
      if (m['type'] == 'hotel') {
        m['selectedHotel'] = (m['selectedHotel'] == true);
      }

      return m;
    }).toList();

    // set selected hotel from existing
    final idxSelected = editedChecklist.indexWhere(
      (e) => (e['type'] == 'hotel') && (e['selectedHotel'] == true),
    );
    if (idxSelected != -1) {
      _selectedHotelKey = _hotelKey(idxSelected, editedChecklist[idxSelected]);
    }

    titleController = TextEditingController(text: latestTask.title);
    startDate = _asLocal(latestTask.startDate);
    endDate = _asLocal(latestTask.endDate);
    editedStartDate = startDate;
    editedEndDate = endDate;

    checklist = List<Map<String, dynamic>>.from(editedChecklist);
  }

  @override
  void dispose() {
    _animationController.dispose();
    titleController.dispose();
    _aiPromptCtrl.dispose();
    checklist.clear();
    super.dispose();
  }

  // -------------------- utils --------------------
  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return _asLocal(v);
    if (v is Timestamp) return _asLocal(v.toDate());
    if (v is String) {
      try {
        return _asLocal(DateTime.parse(v));
      } catch (_) {
        if (v.contains('/')) {
          final p = v.split('/');
          if (p.length == 3) {
            final dd = int.tryParse(p[0]) ?? 1;
            final mm = int.tryParse(p[1]) ?? 1;
            final yy = int.tryParse(p[2]) ?? DateTime.now().year;
            return _asLocal(DateTime(yy, mm, dd));
          }
        }
      }
    }
    return null;
  }

  // normalize "1h", "1h30m", "90min" → "1 ชม. 30 นาที"
  String _normalizeDuration(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return raw;

    // EN: "1 hr 30 min", "1 hr", "30 min"
    final regENHM = RegExp(
      r'^(\d+)\s*hr?\s*(\d+)\s*min?$',
      caseSensitive: false,
    );
    final regENH = RegExp(r'^(\d+)\s*hr?$', caseSensitive: false);
    final regENM = RegExp(r'^(\d+)\s*min?$', caseSensitive: false);

    // TH: "1 ชม. 30 นาที", "1 ชม.", "30 นาที"
    final regTHHM = RegExp(r'^(\d+)\s*ชม\.?\s*(\d+)\s*นาที$');
    final regTHH = RegExp(r'^(\d+)\s*ชม\.?$');
    final regTHM = RegExp(r'^(\d+)\s*นาที$');

    // raw: "1h30m", "1h", "30m", "90min"
    final regRawHM = RegExp(
      r'^(\d+)\s*h(?:r|ours?)?\s*(\d+)\s*m(?:in)?$',
      caseSensitive: false,
    );
    final regRawH = RegExp(r'^(\d+)\s*h(?:r|ours?)?$', caseSensitive: false);
    final regRawM = RegExp(r'^(\d+)\s*m(?:in(?:s)?)?$', caseSensitive: false);

    // HM patterns
    for (final reg in [regENHM, regTHHM, regRawHM]) {
      final m = reg.firstMatch(s);
      if (m != null)
        return 'durationHM'.trParams({'h': m.group(1)!, 'm': m.group(2)!});
    }
    // H patterns
    for (final reg in [regENH, regTHH, regRawH]) {
      final m = reg.firstMatch(s);
      if (m != null) return 'durationH'.trParams({'h': m.group(1)!});
    }
    // M patterns
    for (final reg in [regENM, regTHM, regRawM]) {
      final m = reg.firstMatch(s);
      if (m != null) {
        final total = int.parse(m.group(1)!);
        if (total >= 60) {
          final h = total ~/ 60;
          final min = total % 60;
          return min > 0
              ? 'durationHM'.trParams({'h': '$h', 'm': '$min'})
              : 'durationH'.trParams({'h': '$h'});
        }
        return 'durationM'.trParams({'m': m.group(1)!});
      }
    }
    return raw;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('dd/MM/yyyy').format(_asLocal(d));
  }

  String _fmtTime(String? raw) {
    if (raw == null) return '';

    final cleaned = raw.trim();
    if (cleaned.isEmpty) return '';

    // รองรับ 9, 9:00, 09.00, 9.30 ฯลฯ
    final normalized = cleaned.replaceAll('.', ':');

    if (normalized.contains(':')) {
      final parts = normalized.split(':');
      if (parts.length == 2) {
        final hour = parts[0].padLeft(2, '0');
        final minute = parts[1].padLeft(2, '0');
        return '$hour:$minute';
      }
    }

    // ถ้าเป็นแค่ตัวเลข 9 → 09:00
    if (RegExp(r'^\d{1,2}$').hasMatch(normalized)) {
      return normalized.padLeft(2, '0') + ':00';
    }

    return normalized;
  }

  /// ตัดบรรทัดที่เป็น "ลิงก์แผนที่" ออกจากข้อความ
  String _stripMapLinks(String text) {
    if (text.trim().isEmpty) return text;
    final lines = text.split(RegExp(r'\r?\n'));
    final regexUrl = RegExp(
      r'(https?:\/\/)?(www\.)?(google\.[^\/]+\/maps|maps\.app\.goo\.gl|goo\.gl\/maps|shorturl\.at|bit\.ly|tinyurl\.com)\/',
      caseSensitive: false,
    );
    final kept = <String>[];
    for (final raw in lines) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      final lower = s.toLowerCase();
      if (lower.startsWith('แผนที่:') || lower.startsWith('map:')) continue;
      if (regexUrl.hasMatch(s)) continue;
      kept.add(raw);
    }
    return kept.join('\n');
  }

  // -------------------- date picker --------------------
  Future<void> pickDate(BuildContext context, bool isStart) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final t = controller.findTaskById(widget.task.id) ?? widget.task;
    if (!t.canEdit(uid)) return;
    if (_aiBusy) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? editedStartDate : editedEndDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          editedStartDate = picked;
          if (editedEndDate.isBefore(editedStartDate)) {
            editedEndDate = editedStartDate;
          }
        } else {
          editedEndDate = picked;
        }
      });
    }
  }

  // -------------------- CRUD checklist --------------------
  void addChecklistItem({String type = 'plan'}) {
    if (_aiBusy) return;
    setState(() {
      editedChecklist.add({
        'type': type,
        'title': '',
        'description': '',
        'done': false,
        'expanded': true,
        'start_date': null,
        'end_date': null,
        'time': null,
        'duration': null,
        'lat': null,
        'lng': null,
        'price': null,
        'notes': null,
        'mapsUrl': null,
        'reserve': null,
        'selectedHotel': false,
      });
      checklist = List<Map<String, dynamic>>.from(editedChecklist);
    });
  }

  void removeChecklistItem(int index) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final t = controller.findTaskById(widget.task.id) ?? widget.task;
    if (!t.canEdit(uid)) {
      _showErrorSnackbar('noDeletePermission'.tr);
      return;
    }
    if (_aiBusy) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red[600]),
            ),
            const SizedBox(width: 12),
            Text('confirmdelete'.tr),
          ],
        ),
        content: Text('dialogconfirmdelete'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              final key = _hotelKey(index, editedChecklist[index]);
              if (_selectedHotelKey == key) _selectedHotelKey = null;
              setState(() {
                editedChecklist.removeAt(index);
                checklist = List<Map<String, dynamic>>.from(editedChecklist);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('deletetask'.tr),
          ),
        ],
      ),
    );
  }

  String _hotelKey(int index, Map<String, dynamic> h) =>
      'h:$index:${(h['title'] ?? '').toString()}';

  // -------------------- map open --------------------
  Future<void> _openExternalMap(double lat, double lng, {String? label}) async {
    final q = Uri.encodeComponent(label ?? 'Location');
    final googleUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng($q)',
    );
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      return;
    }
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($q)');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      return;
    }
    final appleUrl = Uri.parse('http://maps.apple.com/?ll=$lat,$lng&q=$q');
    await launchUrl(appleUrl, mode: LaunchMode.externalApplication);
  }

  // -------------------- save --------------------
  Future<void> saveTask() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final latest = controller.findTaskById(widget.task.id) ?? widget.task;
    if (!latest.canEdit(uid)) {
      _showErrorSnackbar('noPermission'.tr);
      return;
    }
    if (_aiBusy) return;

    if (titleController.text.trim().isEmpty) {
      _showErrorSnackbar('entertaskname'.tr);
      return;
    }

    // ให้ AI ปรับแผนก่อนเซฟ
    {
      // 🔥 ตรวจว่ามี item ไหนข้อมูลไม่ครบไหม
      final hasIncomplete = editedChecklist.any(_isIncomplete);

      if (hasIncomplete) {
        final ok = await _runAiAdjust(
          overridePrompt: '''
                    มีสถานที่ที่ผู้ใช้เพิ่มแบบ manual และข้อมูลบางส่วนอาจขาด

                    ให้ทำดังนี้:
                    1. เติมข้อมูลที่ขาด เช่น description, lat, lng
                    2. ตรวจสอบเวลาไม่ให้ทับซ้อนกัน
                    3. จัดลำดับสถานที่ให้เหมาะสมตามเส้นทาง
                    4. ปรับเวลาให้ต่อเนื่องโดยเผื่อเวลาเดินทาง
                    5. ถ้าไม่มีเวลา ให้กำหนดเวลาที่เหมาะสมให้

                    ห้ามลบรายการ
                    ห้ามเปลี่ยนโครงสร้าง JSON
                    ต้องคืนข้อมูลครบทุกจุด
                    ''',
          quiet: true,
        );

        if (!ok) {
          _showErrorSnackbar('aiAdjustFailed'.tr);
          return;
        }
      }
    }

    // แตก plan / hotel ออกเป็นสองลิสต์
    final List<Map<String, dynamic>> plans = [];
    final List<Map<String, dynamic>> hotels = [];

    for (var i = 0; i < editedChecklist.length; i++) {
      final raw = editedChecklist[i];
      final m = Map<String, dynamic>.from(raw);

      m['type'] = (m['type'] ?? 'plan').toString();
      m['done'] = (m['done'] == true);
      m['expanded'] = m['expanded'] ?? true;

      m['start_date'] = _toDate(m['start_date']);
      m['end_date'] = _toDate(m['end_date']);

      m['lat'] = _toDouble(m['lat']);
      m['lng'] = _toDouble(m['lng']);

      if (m['time'] != null) m['time'] = m['time'].toString();
      if (m['duration'] != null) m['duration'] = m['duration'].toString();

      if (m['type'] == 'hotel') {
        final key = _hotelKey(i, raw);
        m['selectedHotel'] =
            (_selectedHotelKey != null && key == _selectedHotelKey);
        hotels.add(m);
      } else {
        // ตัดบรรทัดลิงก์ใน description ออกก่อนบันทึก
        if (m['description'] != null) {
          m['description'] = _stripMapLinks(m['description'].toString());
        }
        plans.add(m);
      }
    }

    // ถ้าเลือกโรงแรมหลักไว้ ให้เก็บเฉพาะตัวที่เลือก และตัดลิงก์ออกจาก notes
    List<Map<String, dynamic>> finalHotels = hotels.map((h) {
      if (h['notes'] != null) {
        h['notes'] = _stripMapLinks(h['notes'].toString());
      }
      return h;
    }).toList();

    final selected = finalHotels
        .where((h) => h['selectedHotel'] == true)
        .toList();
    if (selected.isNotEmpty) {
      finalHotels = [selected.first];
    }

    final cleanedChecklist = [...plans, ...finalHotels];

    // สร้าง Task อัปเดต
    final updatedTask = latest.copyWith(
      title: titleController.text.trim(),
      startDate: editedStartDate,
      endDate: editedEndDate,
      checklist: cleanedChecklist,
    );

    // เขียนลง Firestore
    try {
      await controller.updateTask(updatedTask);
      _showSuccessSnackbar('saveSuccess'.tr);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      _showErrorSnackbar('cannotsave'.tr);
    }
  }

  // -------------------- AI adjust --------------------
  Future<void> _applyAiAdjust() async {
    if (_aiBusy) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final latest = controller.findTaskById(widget.task.id) ?? widget.task;
    if (!latest.canEdit(uid)) {
      _showErrorSnackbar('noPermission'.tr);
      return;
    }
    final prompt = _aiPromptCtrl.text.trim();
    if (prompt.isEmpty) {
      _showErrorSnackbar('aiPromptEmpty'.tr);
      return;
    }
    // ใช้ _runAiAdjust ที่มี merge logic ถูกต้องอยู่แล้ว
    await _runAiAdjust(overridePrompt: prompt, quiet: false);
  }

  bool _isIncomplete(Map<String, dynamic> item) {
    final titleEmpty = (item['title'] ?? '').toString().trim().isEmpty;

    final descEmpty = (item['description'] ?? '').toString().trim().isEmpty;

    return titleEmpty || descEmpty;
  }

  Future<void> _autoFillIncompleteItem(int index) async {
    if (_aiBusy) return;

    final item = editedChecklist[index];
    final title = (item['title'] ?? '').toString().trim();
    if (title.isEmpty) return;

    // เช็คว่าข้อมูลยังไม่ครบจริงไหม
    if (!_isIncomplete(item)) return;

    final time = (item['time'] ?? '').toString();

    final prompt =
        '''
เติมข้อมูลสถานที่นี้ให้ครบ:
ชื่อ: $title
เวลา: ${time.isEmpty ? "ไม่ระบุ" : time}

เงื่อนไข:
- ห้ามลบรายการอื่น
- ห้ามเปลี่ยนลำดับ
- เติม description, lat, lng, address, image ถ้ามี
- ถ้าไม่มีเวลา ให้กำหนดเวลาเหมาะสม
''';

    await _runAiAdjust(overridePrompt: prompt, quiet: true);
  }

  // เรียก AI แบบใช้ซ้ำ
  Future<bool> _runAiAdjust({String? overridePrompt, bool quiet = true}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final latest = controller.findTaskById(widget.task.id) ?? widget.task;
    if (!latest.canEdit(uid)) return false;

    final prompt = (overridePrompt ?? _aiPromptCtrl.text).trim();
    if (prompt.isEmpty) return false;

    setState(() {
      _aiBusy = true;
      _aiBusyReason = 'aiProcessing'.tr;
    });

    try {
      final payload = {
        "task": {
          "id": latest.id,
          "title": titleController.text.trim(),
          "startDate": editedStartDate.toIso8601String(),
          "endDate": editedEndDate.toIso8601String(),
          "checklist": editedChecklist.map((item) {
            final m = Map<String, dynamic>.from(item);
            m['start_date'] = _toDate(m['start_date'])?.toIso8601String();
            m['end_date'] = _toDate(m['end_date'])?.toIso8601String();
            m['lat'] = _toDouble(m['lat']);
            m['lng'] = _toDouble(m['lng']);
            if (m['time'] != null) m['time'] = m['time'].toString();
            if (m['duration'] != null) m['duration'] = m['duration'].toString();
            return m;
          }).toList(),
        },
        "prompt": prompt,
      };

      final result = await AiApiService.adjustPlan(payload);
      if ((result['status'] ?? '') != 'ok') {
        throw Exception(result['message'] ?? 'AI error');
      }

      final List<dynamic> newList =
          result['plan_output'] ?? result['checklist'] ?? [];

      final normalized = newList.map<Map<String, dynamic>>((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        m['type'] = (m['type'] ?? 'plan').toString();
        m['done'] = (m['done'] == true);
        m['expanded'] = m['expanded'] ?? true;
        m['lat'] = _toDouble(m['lat']);
        m['lng'] = _toDouble(m['lng']);
        // เก็บ duration เป็น raw format ไว้ใน state ไม่ translate
        // จะ translate เฉพาะตอน render ใน _buildChecklistItem
        if (m['duration'] != null) m['duration'] = m['duration'].toString();
        if (m['type'] == 'hotel') {
          m['selectedHotel'] = (m['selectedHotel'] == true);
        }

        // ✅ parse date ก่อน แล้ว apply time ทันที
        final timeStr = (m['time'] ?? '').toString().trim();
        DateTime? sd = _toDate(m['start_date']);
        DateTime? ed = _toDate(m['end_date']);

        if (timeStr.isNotEmpty && sd != null && timeStr.contains(':')) {
          final parts = timeStr.split(':');
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          sd = DateTime(sd.year, sd.month, sd.day, hour, minute);
        }

        m['time'] = timeStr.isEmpty ? null : timeStr;
        m['start_date'] = sd;
        m['end_date'] = ed;

        return m;
      }).toList();

      debugPrint("AI RESULT: $normalized");

      final merged = <Map<String, dynamic>>[];

      for (final aiItem in normalized) {
        final aiTitle = (aiItem['title'] ?? '').toString().trim();

        debugPrint("---- CHECK AI ITEM: $aiTitle ----");

        final oldItem = editedChecklist.firstWhere(
          (e) => (e['title'] ?? '').toString().trim() == aiTitle,
          orElse: () {
            // fallback: ถ้าเป็น hotel และ match title ไม่ได้ ให้หา hotel ตัวแรกที่ยังไม่ถูก match
            if ((aiItem['type'] ?? '') == 'hotel') {
              return editedChecklist.firstWhere(
                (e) => e['type'] == 'hotel',
                orElse: () => {},
              );
            }
            return {};
          },
        );

        if (oldItem.isNotEmpty) {
          debugPrint("MATCH FOUND for $aiTitle");
          debugPrint("OLD => ${oldItem.toString()}");
          debugPrint("AI  => ${aiItem.toString()}");

          final mergedItem = Map<String, dynamic>.from(oldItem);

          aiItem.forEach((key, value) {
            if (value == null) return;

            // ป้องกัน lat/lng เป็น 0 ทับค่าเดิม
            if ((key == 'lat' || key == 'lng') && value == 0.0) return;

            // ป้องกัน images list ว่างทับของเดิม
            if ((key == 'images' || key == 'image') &&
                value is List &&
                value.isEmpty)
              return;

            // ป้องกัน price / reserve ว่างทับค่าเดิม
            if ((key == 'price' || key == 'reserve') &&
                value.toString().trim().isEmpty)
              return;

            mergedItem[key] = value;
          });

          debugPrint("MERGED RESULT => ${mergedItem.toString()}");
          merged.add(mergedItem);
        } else {
          debugPrint("NO MATCH (NEW ITEM): $aiTitle");
          final newItem = Map<String, dynamic>.from(aiItem);

          // ✅ ดึง time จาก start_date ถ้า AI ไม่ส่ง time มา
          if ((newItem['time'] ?? '').toString().trim().isEmpty) {
            final sd = newItem['start_date'];
            if (sd is DateTime) {
              final h = sd.hour.toString().padLeft(2, '0');
              final m = sd.minute.toString().padLeft(2, '0');
              newItem['time'] = '$h:$m';
            }
          }

          // ✅ คำนวณ duration จาก start_date และ end_date
          // ใช้ _toDate() เพื่อ normalize timezone ก่อนคำนวณทุกครั้ง
          if ((newItem['duration'] ?? '').toString().trim().isEmpty) {
            final sd = _toDate(newItem['start_date']);
            final ed = _toDate(newItem['end_date']);
            if (sd != null && ed != null && ed.isAfter(sd)) {
              final diff = ed.difference(sd);
              // sanity check: ไม่เกิน 12 ชม. ป้องกัน timezone เพี้ยนทำให้ค่าบวม
              if (diff.inMinutes > 0 && diff.inHours < 12) {
                final hours = diff.inHours;
                final minutes = diff.inMinutes % 60;
                if (hours > 0 && minutes > 0) {
                  newItem['duration'] = _normalizeDuration(
                    '${hours}h${minutes}m',
                  );
                } else if (hours > 0) {
                  newItem['duration'] = _normalizeDuration('${hours}h');
                } else {
                  newItem['duration'] = _normalizeDuration('${minutes}m');
                }
              } else {
                debugPrint(
                  'DURATION SKIPPED: diff=${diff.inMinutes} min '
                  '(sd=$sd, ed=$ed) — อาจเป็น timezone issue',
                );
              }
            }
          }

          merged.add(newItem);
        }
      }

      // ✅ apply time → start_date ทุก item หลัง merge เสมอ
      // เพราะ merge อาจดึง start_date เก่ากลับมาทับ
      for (final item in merged) {
        final timeStr = (item['time'] ?? '').toString().trim();
        final sd = _toDate(item['start_date']);
        if (timeStr.isNotEmpty && sd != null && timeStr.contains(':')) {
          final parts = timeStr.split(':');
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          item['start_date'] = DateTime(
            sd.year,
            sd.month,
            sd.day,
            hour,
            minute,
          );
        }
      }

      debugPrint("============== AFTER MERGE ==============");
      for (var e in merged) {
        debugPrint("FINAL ITEM => ${e.toString()}");
      }
      debugPrint("=========================================");

      setState(() {
        editedChecklist = merged;
        checklist = List<Map<String, dynamic>>.from(editedChecklist);
      });

      if (!quiet) _showSuccessSnackbar('aiAdjustSuccess'.tr);
      return true;
    } catch (e) {
      _showErrorSnackbar('aiAdjustFailed'.tr);
      debugPrint('AI adjust error: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _aiBusy = false;
          _aiBusyReason = null;
        });
      }
    }
  }

  // -------------------- move / reorder --------------------
  int? _findPrevSameType(int currentIndex, bool isHotel) {
    final type = isHotel ? 'hotel' : 'plan';
    for (int i = currentIndex - 1; i >= 0; i--) {
      if ((editedChecklist[i]['type'] ?? 'plan') == type) {
        return i;
      }
    }
    return null;
  }

  int? _findNextSameType(int currentIndex, bool isHotel) {
    final type = isHotel ? 'hotel' : 'plan';
    for (int i = currentIndex + 1; i < editedChecklist.length; i++) {
      if ((editedChecklist[i]['type'] ?? 'plan') == type) {
        return i;
      }
    }
    return null;
  }

  void _swapScheduleFields(Map<String, dynamic> a, Map<String, dynamic> b) {
    final tmpStart = a['start_date'];
    final tmpTime = a['time'];

    a['start_date'] = b['start_date'];
    a['time'] = b['time'];

    b['start_date'] = tmpStart;
    b['time'] = tmpTime;

    // คำนวณ end_date ใหม่จาก start + duration ของแต่ละตัว
    _recalcEndDate(a);
    _recalcEndDate(b);
  }

  void _recalcEndDate(Map<String, dynamic> item) {
    final sd = _toDate(item['start_date']);
    final durRaw = (item['duration'] ?? '').toString();
    if (sd == null || durRaw.isEmpty) return;

    // parse minutes จาก raw duration
    int? minutes = _parseDurationToMinutes(durRaw);
    if (minutes != null && minutes > 0) {
      item['end_date'] = sd.add(Duration(minutes: minutes));
    }
  }

  int? _parseDurationToMinutes(String raw) {
    final s = raw.trim().toLowerCase();
    final regHM = RegExp(r'(\d+)\s*h[^0-9]*(\d+)\s*m');
    final regH = RegExp(r'^(\d+)\s*h');
    final regM = RegExp(r'^(\d+)\s*m');

    final mHM = regHM.firstMatch(s);
    if (mHM != null)
      return int.parse(mHM.group(1)!) * 60 + int.parse(mHM.group(2)!);
    final mH = regH.firstMatch(s);
    if (mH != null) return int.parse(mH.group(1)!) * 60;
    final mM = regM.firstMatch(s);
    if (mM != null) return int.parse(mM.group(1)!);
    return null;
  }

  void _moveChecklistItem(
    int index, {
    required bool up,
    required bool isHotel,
  }) {
    if (_aiBusy) return;

    final prevIndex = _findPrevSameType(index, isHotel);
    final nextIndex = _findNextSameType(index, isHotel);

    if (up && prevIndex == null) return;
    if (!up && nextIndex == null) return;

    final targetIndex = up ? prevIndex! : nextIndex!;

    setState(() {
      final current = editedChecklist[index];
      final target = editedChecklist[targetIndex];

      _swapScheduleFields(current, target);

      editedChecklist[index] = target;
      editedChecklist[targetIndex] = current;

      checklist = List<Map<String, dynamic>>.from(editedChecklist);
    });
  }

  // -------------------- snackbar --------------------
  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // -------------------- build --------------------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final currentUid = user?.uid ?? '';
    final latestTask = controller.findTaskById(widget.task.id) ?? widget.task;
    final bool isOwner = latestTask.uid == currentUid;
    final bool canEdit = latestTask.canEdit(currentUid);

    final plans = editedChecklist.where((e) => e['type'] == 'plan').toList();
    final hotels = editedChecklist.where((e) => e['type'] == 'hotel').toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 86,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            titleSpacing: 0,
            title: _buildHeaderBar(),
            actions: [
              if (isOwner)
                IconButton(
                  tooltip: 'invite'.tr,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (_) => InviteSheet(taskId: widget.task.id),
                    );
                  },
                ),
              if (canEdit && !_aiBusy)
                IconButton(
                  onPressed: saveTask,
                  icon: const Icon(Icons.save_rounded),
                  tooltip: 'save'.tr,
                  color: Colors.white,
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_aiBusy) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_clock,
                              color: Color(0xFF1D4ED8),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _aiBusyReason ?? 'aiProcessing'.tr,
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ทริป
                    _buildSectionCard(
                      title: 'tripName'.tr,
                      icon: Icons.flight_takeoff_rounded,
                      child: TextFormField(
                        controller: titleController,
                        readOnly: !canEdit || _aiBusy,
                        decoration: InputDecoration(
                          hintText: 'hintTripName'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: (!canEdit || _aiBusy)
                              ? Colors.grey[100]
                              : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // วันที่
                    _buildSectionCard(
                      title: 'date'.tr,
                      icon: Icons.calendar_today,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDateCard(
                              'start'.tr,
                              editedStartDate,
                              true,
                              canEdit: canEdit && !_aiBusy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateCard(
                              'end'.tr,
                              editedEndDate,
                              false,
                              canEdit: canEdit && !_aiBusy,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // AI adjust
                    _buildAiAdjustCard(canEdit),

                    const SizedBox(height: 16),

                    // แผน / กิจกรรม
                    _buildSectionCard(
                      title: 'tripPlan'.tr,
                      icon: Icons.route_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${'items'.tr}: ${plans.length}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (canEdit && !_aiBusy)
                                TextButton.icon(
                                  onPressed: () =>
                                      addChecklistItem(type: 'plan'),
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: Text('addPlace'.tr),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (plans.isEmpty)
                            _emptyBox('noPlansYet'.tr)
                          else
                            ...plans.asMap().entries.map((entry) {
                              final indexInEdited = editedChecklist.indexOf(
                                entry.value,
                              );
                              return _buildChecklistItem(
                                entry.value,
                                indexInEdited,
                                canEdit: canEdit,
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // โรงแรม
                    _buildSectionCard(
                      title: 'hotel'.tr,
                      icon: Icons.hotel_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'choose1hotel'.tr,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '${'items'.tr}: ${hotels.length}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (canEdit && !_aiBusy)
                                TextButton.icon(
                                  onPressed: () =>
                                      addChecklistItem(type: 'hotel'),
                                  icon: const Icon(Icons.add_business_rounded),
                                  label: Text('addHotel'.tr),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (hotels.isEmpty)
                            _emptyBox('nohotels'.tr)
                          else
                            ...hotels.asMap().entries.map((entry) {
                              final indexInEdited = editedChecklist.indexOf(
                                entry.value,
                              );
                              return _buildChecklistItem(
                                entry.value,
                                indexInEdited,
                                canEdit: canEdit,
                                isHotel: true,
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (canEdit && !_aiBusy)
          ? FloatingActionButton.extended(
              onPressed: saveTask,
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.save_rounded),
              label: Text(
                'save'.tr,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'adjustPlan'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard(
    String label,
    DateTime date,
    bool isStart, {
    required bool canEdit,
  }) {
    final localDate = _asLocal(date);

    return InkWell(
      onTap: canEdit ? () => pickDate(context, isStart) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: canEdit ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isStart ? Icons.play_arrow : Icons.flag,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(localDate),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================  ADD IMAGE GALLERY ==================

  Widget _buildImageGallery(List<String> images) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      _FullscreenImagePage(images: images, initialIndex: index),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAiAdjustCard(bool canEdit) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.tune,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'adjustWithAI'.tr,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aiPromptCtrl,
              enabled: canEdit && !_aiBusy,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'aiPromptHint'.tr,
                filled: true,
                fillColor: (canEdit && !_aiBusy)
                    ? Colors.white
                    : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: (canEdit && !_aiBusy)
                      ? () {
                          setState(() {
                            _aiPromptCtrl.text =
                                'วันแรกขอเน้นย่านพระนครเพิ่มวัดโพธิ์กับวัดอรุณ แล้วลดคาเฟ่ 1 ที่';
                          });
                        }
                      : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text('example'.tr),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: (canEdit && !_aiBusy) ? _applyAiAdjust : null,
                  icon: _aiBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_fix_high_rounded),
                  label: Text('adjustWithAI'.tr),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistItem(
    Map<String, dynamic> item,
    int index, {
    required bool canEdit,
    bool isHotel = false,
  }) {
    print('ITEM DEBUG: ${item.toString()}');
    final expanded = item['expanded'] ?? true;

    final DateTime? start = _toDate(item['start_date']);
    final DateTime? end = _toDate(item['end_date']);
    final String time = _fmtTime(item['time']?.toString());
    final String duration = _normalizeDuration(
      (item['duration'] ?? '').toString(),
    );
    final double? lat = _toDouble(item['lat']);
    final double? lng = _toDouble(item['lng']);
    final String price = (item['price'] ?? '').toString();
    final String notesRaw = (item['notes'] ?? '').toString();
    final String notes = _stripMapLinks(notesRaw);
    final String mapsUrl = (item['mapsUrl'] ?? '').toString();

    final String itemKey = _hotelKey(index, item);
    final bool locked = !canEdit || _aiBusy;

    final prevIndex = _findPrevSameType(index, isHotel);
    final nextIndex = _findNextSameType(index, isHotel);

    // 🔥 ADD IMAGE LIST
    final List<String> images = [
      if (item['image'] != null && item['image'].toString().startsWith('http'))
        item['image'].toString(),
      ...(item['images'] as List? ?? [])
          .map((e) => e.toString())
          .where((u) => u.startsWith('http')),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ObjectKey(item),
          initiallyExpanded: expanded,
          onExpansionChanged: (isExpanded) {
            setState(() => item['expanded'] = isExpanded);
          },
          leading: isHotel
              ? Radio<String>(
                  value: itemKey,
                  groupValue: _selectedHotelKey,
                  onChanged: locked
                      ? null
                      : (val) {
                          setState(() {
                            _selectedHotelKey = val;
                            for (var i = 0; i < editedChecklist.length; i++) {
                              final it = editedChecklist[i];
                              if (it['type'] == 'hotel') {
                                final key = _hotelKey(i, it);
                                it['selectedHotel'] = (key == val);
                              }
                            }
                          });
                        },
                )
              : const Icon(Icons.place_rounded, color: Colors.blueAccent),
          title: TextFormField(
            readOnly: locked,
            initialValue: (item['title'] ?? '').toString(),
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'placeName'.tr,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              item['title'] = val;
            },
          ),
          trailing: !locked
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      onPressed: (prevIndex == null)
                          ? null
                          : () => _moveChecklistItem(
                              index,
                              up: true,
                              isHotel: isHotel,
                            ),
                      tooltip: 'moveUp'.tr,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                      onPressed: (nextIndex == null)
                          ? null
                          : () => _moveChecklistItem(
                              index,
                              up: false,
                              isHotel: isHotel,
                            ),
                      tooltip: 'moveDown'.tr,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => removeChecklistItem(index),
                      tooltip: 'deleteItem'.tr,
                    ),
                  ],
                )
              : null,
          children: [
            // Description
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextFormField(
                readOnly: locked,
                initialValue: _stripMapLinks(
                  (item['description'] ?? '').toString(),
                ),
                style: const TextStyle(color: Colors.black87),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "description".tr,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: locked ? Colors.grey[100] : Colors.white,
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (val) => item['description'] = val,
              ),
            ),

            // date/time/duration/price/notes
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _smallDateButton(
                    label: 'start'.tr,
                    date: start,
                    locked: locked,
                    onTap: () async {
                      if (locked) return;
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: start ?? editedStartDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => item['start_date'] = picked);
                      }
                    },
                  ),
                  _smallDateButton(
                    label: 'end'.tr,
                    date: end,
                    locked: locked,
                    onTap: () async {
                      if (locked) return;
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: end ?? (start ?? editedEndDate),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => item['end_date'] = picked);
                      }
                    },
                  ),
                  _smallTextField(
                    icon: Icons.access_time_rounded,
                    hint: 'timeHint'.tr,
                    initial: time,
                    locked: locked,
                    width: 140,
                    onChanged: (v) => item['time'] = v,
                  ),
                  _smallTextField(
                    icon: Icons.timelapse_rounded,
                    hint: 'durationHint'.tr,
                    initial: duration,
                    locked: locked,
                    width: 140,
                    onChanged: (v) => item['duration'] = v,
                  ),
                  if (isHotel)
                    _smallTextField(
                      icon: Icons.attach_money_rounded,
                      hint: 'price'.tr,
                      initial: price,
                      locked: locked,
                      width: 140,
                      onChanged: (v) => item['price'] = v,
                    ),
                  if (notes.isNotEmpty || isHotel)
                    _smallTextField(
                      icon: Icons.info_outline_rounded,
                      hint: 'notes'.tr,
                      initial: notes,
                      locked: locked,
                      width: 180,
                      onChanged: (v) => item['notes'] = v,
                    ),
                ],
              ),
            ),

            // 🔥 ADD IMAGE GALLERY
            if (images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _buildImageGallery(images),
              ),

            // Map buttons
            if ((lat != null && lng != null) || mapsUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (lat != null && lng != null)
                      ElevatedButton.icon(
                        onPressed: () => _openExternalMap(
                          lat,
                          lng,
                          label: (item['title'] ?? '').toString(),
                        ),
                        icon: const Icon(Icons.map_rounded),
                        label: Text('openInMap'.tr),
                      ),
                    if (lat != null && lng != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AiMapPage(
                                points: [
                                  {
                                    'title': (item['title'] ?? '').toString(),
                                    'lat': lat,
                                    'lng': lng,
                                  },
                                ],
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.fullscreen),
                        label: Text('fullscreen'.tr),
                      ),
                  ],
                ),
              ),
            if (lat != null && lng != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: MapPreview(lat: lat, lng: lng),
              ),
          ],
        ),
      ),
    );
  }

  Widget _smallDateButton({
    required String label,
    required DateTime? date,
    required bool locked,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: locked ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14),
            const SizedBox(width: 6),
            Text(
              date != null ? _fmtDate(date) : label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallTextField({
    required IconData icon,
    required String hint,
    required String initial,
    required bool locked,
    required ValueChanged<String> onChanged,
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        readOnly: locked,
        initialValue: initial,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18),
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: locked ? Colors.grey[100] : Colors.white,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ==================  ADD FULLSCREEN ==================

class _FullscreenImagePage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenImagePage({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImagePage> createState() => _FullscreenImagePageState();
}

class _FullscreenImagePageState extends State<_FullscreenImagePage> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          itemBuilder: (context, index) {
            return InteractiveViewer(
              child: Center(child: Image.network(widget.images[index])),
            );
          },
        ),
      ),
    );
  }
}
