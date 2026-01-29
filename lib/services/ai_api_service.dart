import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';

class AiPlanResult {
  final TaskModel task;
  final List<Map<String, dynamic>> planPoints;
  final List<Map<String, dynamic>> hotelPoints;

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

  // ---------- PUBLIC ----------
  static Future<TaskModel> fetchTaskFromAi(String input) async {
    final data = await _callMakePlan(input);
    final planOutput = _readPlanOutput(data);
    return _buildTaskFromPlanOutput(planOutput);
  }

  static Future<AiPlanResult> fetchPlanAndHotels(String input) async {
    final data = await _callMakePlan(input);
    final planOutput = _readPlanOutput(data);

    final task = _buildTaskFromPlanOutput(planOutput);
    final planPoints = _extractPlanPoints(planOutput);
    final hotelPoints = _extractHotelPoints(data);

    return AiPlanResult(
      task: task,
      planPoints: planPoints,
      hotelPoints: hotelPoints,
    );
  }

  /// 👇 อันนี้คืออันที่ TaskDetailPage จะใช้
  static Future<Map<String, dynamic>> adjustPlan(Map<String, dynamic> body) async {
    final taskId = (body['task']?['id'] ?? '').toString();
    final instruction = (body['prompt'] ?? '').toString();
    final checklistNow =
        (body['task']?['checklist'] as List?)?.whereType<Map<String, dynamic>>().toList()
        ?? <Map<String, dynamic>>[];

    final startDateStr = (body['task']?['startDate'] ?? body['task']?['start_date'])?.toString();
    final endDateStr   = (body['task']?['endDate'] ?? body['task']?['end_date'])?.toString();

    final startDate = startDateStr != null ? DateTime.parse(startDateStr) : DateTime.now();
    final endDate   = endDateStr   != null ? DateTime.parse(endDateStr)   : startDate.add(const Duration(days: 1));

    final newChecklist = await changePlan(
      taskId: taskId.isEmpty ? 'local' : taskId,
      instruction: instruction,
      checklistNow: checklistNow,
      startDate: startDate,
      endDate: endDate,
    );

    return {
      'status': 'ok',
      'checklist': newChecklist,
      'title': body['task']?['title'],
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  // ---------- INTERNAL ----------
  static Future<Map<String, dynamic>> _callMakePlan(String input) async {
    final uri = Uri.parse('$baseUrl/makeplan');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'input': input}),
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

  // ✅ helper ดึงรูป: คืนทั้ง images และ cover image
  static Map<String, dynamic> _extractImages(Map<String, dynamic> source) {
    final raw = source['image_url'];
    final List<String> images = (raw is List)
        ? raw.map((e) => e.toString()).where((u) => u.startsWith('http')).toList()
        : <String>[];

    return {
      'images': images,
      'image': images.isNotEmpty ? images.first : null,
    };
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

        double? lat;
        double? lng;
        if (place['coordinates'] is Map) {
          final c = Map<String, dynamic>.from(place['coordinates'] as Map);
          final la = c['lat'];
          final ln = c['lng'];
          lat = la is num ? la.toDouble() : double.tryParse(la?.toString() ?? '');
          lng = ln is num ? ln.toDouble() : double.tryParse(ln?.toString() ?? '');
        }

        final String? startTime = (stop['start_time'] as String?)?.trim();
        final int? durationMin =
            stop['stay_duration'] is num ? (stop['stay_duration'] as num).toInt() : null;
        final Duration dur =
            (durationMin != null && durationMin > 0)
                ? Duration(minutes: durationMin)
                : const Duration(hours: 2);

        DateTime startAt;
        if (startTime != null && startTime.contains(':')) {
          final parts = startTime.split(':');
          final h = int.tryParse(parts[0]) ?? 9;
          final m = int.tryParse(parts[1]) ?? 0;
          startAt = DateTime(cursor.year, cursor.month, cursor.day, h, m);
          if (startAt.isBefore(cursor)) {
            startAt = cursor;
          }
        } else {
          startAt = cursor;
        }
        final endAt = startAt.add(dur);
        cursor = endAt;

        final pType = (place['type'] ?? '').toString().toLowerCase();
        final String priority =
            pType == 'attraction' ? 'High' : (pType == 'restaurant' ? 'Medium' : 'Low');

        // ✅ ดึงรูปจาก place.image_url
        final img = _extractImages(place);

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
          'time': startTime,
          'duration': _formatDurationText(durationMin),

          // ✅ เพิ่มรูป
          'image': img['image'],
          'images': img['images'],
        });
      }
    }

    final startMain =
        checklist.isNotEmpty ? DateTime.parse(checklist.first['start_date']) : now;
    final endMain =
        checklist.isNotEmpty ? DateTime.parse(checklist.last['end_date']) : now.add(const Duration(days: 1));

    final titleWithOverview =
        overview.isNotEmpty ? '$mainTitle — $overview' : mainTitle;

    return TaskModel(
      id: '',
      uid: '',
      title: titleWithOverview,
      priority: 'Medium',
      startDate: startMain,
      endDate: endMain,
      status: 'todo',
      editorUids: const [],
      viewerUids: const [],
      memberUids: const [],
      checklist: checklist,
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

        // ✅ ดึงรูปจาก place.image_url
        final img = _extractImages(place);

        list.add({
          'title': title,
          'lat': lat,
          'lng': lng,
          'type': (place['type'] ?? '').toString(),
          'price': (place['price_info'] ?? '').toString(),
          'notes': (place['notes'] ?? '').toString(),
          'mapsUrl': (place['google_maps_url'] ?? '').toString(),
          'open': (place['opening_hours'] ?? '').toString(),

          // ✅ เพิ่มรูป
          'image': img['image'],
          'images': img['images'],
        });
      }
    }
    return list;
  }

  static List<Map<String, dynamic>> _extractHotelPoints(Map<String, dynamic> data) {
    final result = <Map<String, dynamic>>[];

    final hotelOuterDyn = data['hotel_output'];
    if (hotelOuterDyn is! List || hotelOuterDyn.isEmpty) return result;

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

      // ✅ ดึงรูปจาก hotel.image_url
      final img = _extractImages(m);

      result.add({
        'title': title,
        'lat': lat,
        'lng': lng,
        'type': 'hotel',
        'price': (m['price_info'] ?? '').toString(),
        // คุณใช้ notes ใน UI โรงแรม แต่ใน schema มี notes กับ short_description
        'notes': (m['notes'] ?? m['short_description'] ?? '').toString(),
        'mapsUrl': (m['google_maps_url'] ?? '').toString(),
        'reserve': m['reservation_recommended'] == true,

        // ✅ เพิ่มรูป
        'image': img['image'],
        'images': img['images'],
      });
    }

    return result;
  }

  static String _formatDurationText(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  // ===== changePlan เดิม (ปรับเล็กน้อย) =====
  static Future<List<Map<String, dynamic>>> changePlan({
    required String taskId,
    required String instruction,
    required List<Map<String, dynamic>> checklistNow,
    required DateTime startDate,
    required DateTime endDate,
    String? locale,
    String? city,
  }) async {
    final uri = Uri.parse('$baseUrl/changeplan');

    final toApi = checklistNow.map(_normalizeForApi).toList();

    final body = {
      'task_id': taskId,
      'instruction': instruction,
      'date_range': {
        'start': startDate.toUtc().toIso8601String(),
        'end': (endDate.isBefore(startDate) ? startDate : endDate)
            .toUtc()
            .toIso8601String(),
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

    final rawList = decoded['checklist'];
    if (rawList is! List) {
      throw Exception('changeplan: ฟิลด์ checklist ไม่ใช่ List');
    }

    final result = rawList
        .whereType<Map>()
        .map((e) {
          final m = Map<String, dynamic>.from(e);
          // normalize ตาม UI
          m['type'] = (m['type'] ?? 'plan').toString();
          m['done'] = (m['done'] == true) || (m['completed'] == true);
          m['expanded'] = m['expanded'] ?? true;

          final p = (m['priority'] ?? '').toString().toLowerCase();
          if (p == 'high' || p == 'สูง') {
            m['priority'] = 'High';
          } else if (p == 'low' || p == 'ต่ำ') {
            m['priority'] = 'Low';
          } else {
            m['priority'] = 'Medium';
          }

          double? toDouble(dynamic v) {
            if (v == null) return null;
            if (v is num) return v.toDouble();
            return double.tryParse(v.toString());
          }

          m['lat'] = toDouble(m['lat']);
          m['lng'] = toDouble(m['lng']);

          // ✅ กันหลุด: ทำให้ image/images เป็นรูปแบบคงที่
          if (m['images'] is List) {
            m['images'] = (m['images'] as List).map((e) => e.toString()).toList();
            m['image'] ??= (m['images'] as List).isNotEmpty ? (m['images'] as List).first : null;
          } else {
            m['images'] = const <String>[];
          }

          if (m['type'] == 'hotel' && m['selectedHotel'] == null) {
            m['selectedHotel'] = false;
          }

          return m;
        })
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

    String _normPriority(dynamic p) {
      final s = (p ?? '').toString().toLowerCase();
      if (s == 'high' || s == 'สูง') return 'High';
      if (s == 'low' || s == 'ต่ำ') return 'Low';
      return 'Medium';
    }

    // ✅ ส่ง images/image ไปด้วย (ถ้า backend จะใช้หรือคงไว้)
    final images = (m['images'] is List) ? (m['images'] as List).map((e) => e.toString()).toList() : null;
    final image = m['image']?.toString();

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

      if (image != null && image.isNotEmpty) 'image': image,
      if (images != null && images.isNotEmpty) 'images': images,
    };
  }
}
