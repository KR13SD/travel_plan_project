import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';

class AiPlanResult {
  final TaskModel task;                        // ใช้ workflow เดิมต่อได้
  final List<Map<String, dynamic>> planPoints;  // จุดจาก itinerary (attraction/restaurant/other)
  final List<Map<String, dynamic>> hotelPoints; // จุดจาก hotel_output (type='hotel')

  AiPlanResult({
    required this.task,
    required this.planPoints,
    required this.hotelPoints,
  });
}

class AiApiService {
  static const String baseUrl = String.fromEnvironment(
    'AI_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// ========== PUBLIC: ใช้แบบเดิม คืน TaskModel ==========
  static Future<TaskModel> fetchTaskFromAi(String input) async {
    final data = await _callMakePlan(input);
    final planOutput = _readPlanOutput(data);
    return _buildTaskFromPlanOutput(planOutput);
  }

  /// ========== PUBLIC: ใช้แยก Plan/Hotel ในครั้งเดียว ==========
  static Future<AiPlanResult> fetchPlanAndHotels(String input) async {
    final data = await _callMakePlan(input);
    final planOutput = _readPlanOutput(data);

    final task = _buildTaskFromPlanOutput(planOutput);
    final planPoints = _extractPlanPoints(planOutput);
    final hotelPoints = _extractHotelPoints(data); // ดึงของ "แผนแรก"

    return AiPlanResult(
      task: task,
      planPoints: planPoints,
      hotelPoints: hotelPoints,
    );
  }

  // ======== INTERNALS ========

  static Future<Map<String, dynamic>> _callMakePlan(String input) async {
    final uri = Uri.parse('$baseUrl/makeplan');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'input': input}), // options ใช้ค่า default = 1
        )
        .timeout(const Duration(seconds: 300));

    if (resp.statusCode != 200) {
      throw Exception('API error: HTTP ${resp.statusCode} - ${resp.body}');
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else {
        throw Exception('รูปแบบ JSON ไม่ถูกต้อง: root ไม่ใช่ Object');
      }
    } catch (_) {
      throw Exception('รูปแบบ JSON ไม่ถูกต้อง: ${resp.body}');
    }

    final status = (data['status'] ?? '').toString();
    final description = (data['description'] ?? '').toString();
    if (status != 'success') {
      throw Exception(description.isEmpty ? 'AI Error' : description);
    }

    return data;
  }

  /// ✅ รองรับ plan_output เป็น List<Map> และหยิบแผนแรก (ต้องเป็น Map<String,dynamic>)
  static Map<String, dynamic> _readPlanOutput(Map<String, dynamic> data) {
    final plansDyn = data['plan_output'];
    if (plansDyn is! List || plansDyn.isEmpty) {
      throw Exception('ผลลัพธ์ว่าง (plan_output == null/empty)');
    }
    final first = plansDyn.first;
    if (first is! Map) {
      throw Exception('plan_output[0] ไม่ใช่ Object');
    }
    return Map<String, dynamic>.from(first as Map);
  }

  static TaskModel _buildTaskFromPlanOutput(Map<String, dynamic> output) {
    final String mainTitle =
        (output['name'] as String?)?.trim().replaceAll('\n', ' ') ?? 'ทริปจาก AI';
    final String overview = (output['overview'] as String?)?.trim() ?? '';
    final now = DateTime.now();

    final List<dynamic> days = (output['itinerary'] as List?) ?? const [];
    final checklist = <Map<String, dynamic>>[];

    DateTime cursor = now;
    for (final d in days) {
      if (d is! Map) continue;
      final day = Map<String, dynamic>.from(d);
      final List<dynamic> stops = (day['stops'] as List?) ?? const [];

      for (final s in stops) {
        if (s is! Map) continue;
        final stop = Map<String, dynamic>.from(s);

        // places = PlaceDetail (object เดียว)
        if (stop['places'] is! Map) continue;
        final place = Map<String, dynamic>.from(stop['places'] as Map);

        final name = (place['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final short = (place['short_description'] ?? '').toString().trim();
        final notes = (place['notes'] ?? '').toString().trim();
        final desc = [
          if (short.isNotEmpty) short,
          if (notes.isNotEmpty) 'หมายเหตุ: $notes',
          if (place['google_maps_url'] != null && place['google_maps_url'].toString().isNotEmpty)
            'แผนที่: ${place['google_maps_url']}',
        ].join('\n').trim();

        // coordinates (รองรับ num/string)
        double? lat;
        double? lng;
        if (place['coordinates'] is Map) {
          final c = Map<String, dynamic>.from(place['coordinates'] as Map);
          final la = c['lat'];
          final ln = c['lng'];
          lat = la is num ? la.toDouble() : double.tryParse(la?.toString() ?? '');
          lng = ln is num ? ln.toDouble() : double.tryParse(ln?.toString() ?? '');
        }

        // time / duration (start_time "HH:MM", stay_duration นาที)
        final String? startTime = (stop['start_time'] as String?)?.trim();
        final int? durationMin =
            stop['stay_duration'] is num ? (stop['stay_duration'] as num).toInt() : null;

        final Duration dur =
            (durationMin != null && durationMin > 0)
                ? Duration(minutes: durationMin)
                : const Duration(hours: 2);

        // สร้างเวลาเริ่ม/จบต่อเนื่องด้วย cursor
        DateTime startAt;
        if (startTime != null && startTime.contains(':')) {
          final parts = startTime.split(':');
          final h = int.tryParse(parts[0]) ?? 9;
          final m = int.tryParse(parts[1]) ?? 0;
          startAt = DateTime(cursor.year, cursor.month, cursor.day, h, m);
          if (startAt.isBefore(cursor)) {
            startAt = cursor; // กันเวลาซ้อน
          }
        } else {
          startAt = cursor;
        }
        final endAt = startAt.add(dur);
        cursor = endAt;

        // priority simple map ตาม type → ใช้ตัวพิมพ์ใหญ่ให้ตรง UI ('High'/'Medium'/'Low')
        final pType = (place['type'] ?? '').toString().toLowerCase();
        final String priority =
            pType == 'attraction' ? 'High' : (pType == 'restaurant' ? 'Medium' : 'Low');

        checklist.add({
          'type': 'plan',
          'title': name,
          'description': desc,
          'done': false,
          'expanded': true,
          'priority': priority,
          'start_date': startAt.toIso8601String(),
          'end_date': endAt.toIso8601String(),
          'lat': lat,
          'lng': lng,
          'time': startTime, // "HH:MM"
          'duration': _formatDurationText(durationMin), // "90m"/"2h30m"
        });
      }
    }

    final startMain =
        checklist.isNotEmpty ? DateTime.parse(checklist.first['start_date']) : now;
    final endMain =
        checklist.isNotEmpty ? DateTime.parse(checklist.last['end_date']) : now.add(const Duration(days: 1));

    final titleWithOverview =
        overview.isNotEmpty ? '$mainTitle — $overview' : mainTitle;

    // ✅ สร้าง TaskModel ให้ครบฟิลด์ที่เป็น required ของโมเดลเวอร์ชันสิทธิ์
    return TaskModel(
      id: '',
      uid: '',                      // จะถูกเติมระหว่าง createTask ใน controller
      title: titleWithOverview,
      priority: 'Medium',
      startDate: startMain,
      endDate: endMain,
      status: 'todo',
      editorUids: const [],
      viewerUids: const [],
      memberUids: const [],         // จะถูกเติมเป็น [owner] ตอน createTask
      checklist: checklist,
      // createdAt/updatedAt ให้ controller ใส่ timestamp ตอนเขียน Firestore
    );
  }

  static List<Map<String, dynamic>> _extractPlanPoints(Map<String, dynamic> output) {
    final List<Map<String, dynamic>> list = [];
    final days = (output['itinerary'] as List?) ?? const [];
    for (final d in days) {
      if (d is! Map) continue;
      final day = Map<String, dynamic>.from(d);
      final stops = (day['stops'] as List?) ?? const [];
      for (final s in stops) {
        if (s is! Map) continue;
        final stop = Map<String, dynamic>.from(s);
        if (stop['places'] is! Map) continue;
        final place = Map<String, dynamic>.from(stop['places'] as Map);

        final title = (place['name'] ?? '').toString().trim();
        if (title.isEmpty) continue;

        double? lat;
        double? lng;
        if (place['coordinates'] is Map) {
          final c = Map<String, dynamic>.from(place['coordinates'] as Map);
          final la = c['lat'];
          final ln = c['lng'];
          lat = la is num ? la.toDouble() : double.tryParse(la?.toString() ?? '');
          lng = ln is num ? ln.toDouble() : double.tryParse(ln?.toString() ?? '');
        }

        list.add({
          'title': title,
          'lat': lat,
          'lng': lng,
          'type': (place['type'] ?? '').toString(),               // attraction/restaurant/other
          'price': (place['price_info'] ?? '').toString(),
          'notes': (place['notes'] ?? '').toString(),
          'mapsUrl': (place['google_maps_url'] ?? '').toString(),
          'open': (place['opening_hours'] ?? '').toString(),
        });
      }
    }
    return list;
  }

  /// ✅ รองรับ hotel_output เป็น List<List<PlaceDetail>>
  /// และดึงเฉพาะ "ชุดโรงแรมของแผนแรก" (index 0) มาแปลงเป็น markers
  static List<Map<String, dynamic>> _extractHotelPoints(Map<String, dynamic> data) {
    final result = <Map<String, dynamic>>[];

    final hotelOuterDyn = data['hotel_output'];
    if (hotelOuterDyn is! List || hotelOuterDyn.isEmpty) return result;

    // hotelOuter[0] = ลิสต์โรงแรมของแผนแรก
    final firstPlanHotelsDyn = hotelOuterDyn.first;
    if (firstPlanHotelsDyn is! List) return result;

    final firstPlanHotels = List<dynamic>.from(firstPlanHotelsDyn);
    for (final h in firstPlanHotels) {
      if (h is! Map) continue;
      final m = Map<String, dynamic>.from(h);

      final title = (m['name'] ?? '').toString().trim();
      if (title.isEmpty) continue;

      double? lat;
      double? lng;
      if (m['coordinates'] is Map) {
        final c = Map<String, dynamic>.from(m['coordinates'] as Map);
        final la = c['lat'];
        final ln = c['lng'];
        lat = la is num ? la.toDouble() : double.tryParse(la?.toString() ?? '');
        lng = ln is num ? ln.toDouble() : double.tryParse(ln?.toString() ?? '');
      }

      result.add({
        'title': title,
        'lat': lat,
        'lng': lng,
        'type': 'hotel',
        'price': (m['price_info'] ?? '').toString(),
        'notes': (m['notes'] ?? '').toString(),
        'mapsUrl': (m['google_maps_url'] ?? '').toString(),
        'reserve': m['reservation_recommended'] == true,
      });
    }

    return result;
  }

  // ---- helpers ----
  static String _formatDurationText(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  /// เรียก /changeplan พร้อม normalize checklist ที่มีอยู่
  static Future<List<Map<String, dynamic>>> changePlan({
    required String taskId,
    required String instruction,                 // “เพิ่มคาเฟ่ใกล้ ICONSIAM อีก 1 ที่”
    required List<Map<String, dynamic>> checklistNow,
    required DateTime startDate,
    required DateTime endDate,
    String? locale,                              // th-TH หรือ en-US
    String? city,                                // ถ้ามีเมือง/พื้นที่
  }) async {
    final uri = Uri.parse('$baseUrl/changeplan');

    // แปลงรายการให้สะอาด & เวลาเป็น UTC ISO
    final toApi = checklistNow.map(_normalizeForApi).toList();

    final body = {
      'task_id': taskId,
      'instruction': instruction,
      'date_range': {
        'start': startDate.toUtc().toIso8601String(),
        'end': endDate.toUtc().toIso8601String(),
      },
      'checklist': toApi,
      if (locale != null) 'locale': locale,
      if (city != null) 'city': city,
    };

    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));

    if (resp.statusCode != 200) {
      throw Exception('changeplan error: HTTP ${resp.statusCode} - ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('changeplan: รูปแบบ JSON ไม่ถูกต้อง');
    }

    // สมมติ API ส่ง checklist ใหม่คืนมาที่ key 'checklist'
    final rawList = decoded['checklist'];
    if (rawList is! List) {
      throw Exception('changeplan: ฟิลด์ checklist ไม่ใช่ List');
    }

    final result = rawList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return result;
  }

  static Map<String, dynamic> _normalizeForApi(Map<String, dynamic> m) {
    DateTime? _asDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    String? _toIsoUtc(DateTime? d) => d == null ? null : d.toUtc().toIso8601String();

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    // ปรับ priority ให้เป็นรูปแบบที่ API/แอปเข้าใจสอดคล้องกัน
    String _normPriority(dynamic p) {
      final s = (p ?? '').toString().toLowerCase();
      if (s == 'high' || s == 'สูง') return 'High';
      if (s == 'low' || s == 'ต่ำ') return 'Low';
      return 'Medium';
    }

    return {
      'type': (m['type'] ?? 'plan').toString(),
      'title': (m['title'] ?? '').toString(),
      'description': (m['description'] ?? '').toString(),
      'done': m['done'] == true || m['completed'] == true,
      'priority': _normPriority(m['priority']),
      'start_date': _toIsoUtc(_asDate(m['start_date'])),
      'end_date': _toIsoUtc(_asDate(m['end_date'])),
      'time': m['time']?.toString(),
      'duration': m['duration']?.toString(),
      'lat': _toDouble(m['lat']),
      'lng': _toDouble(m['lng']),
      'price': m['price']?.toString(),
      'notes': m['notes']?.toString(),
      'mapsUrl': m['mapsUrl']?.toString(),
    };
  }
}
