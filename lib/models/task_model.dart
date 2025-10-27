import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String title;
  /// 'High' | 'Medium' | 'Low'
  final String priority;
  final DateTime startDate;
  final DateTime endDate;
  /// 'todo' | 'in_progress' | 'done' ...
  final String status;

  /// เจ้าของแผน
  final String uid;

  /// ====== สิทธิ์การเข้าถึง ======
  /// คนที่แก้ไขได้ (editor/co-owner)
  final List<String> editorUids;
  /// คนที่ดูได้อย่างเดียว (viewer)
  final List<String> viewerUids;
  /// สมาชิกทั้งหมด (owner + editors + viewers) — ใช้ช่วย query/search
  final List<String> memberUids;

  /// subtasks / แผน
  final List<Map<String, dynamic>> checklist;
  final List<Map<String, dynamic>> planPoints;
  final List<Map<String, dynamic>> hotelPoints;

  final DateTime? completedAt;

  TaskModel({
    required this.id,
    required this.title,
    required this.priority,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.uid,
    List<String>? editorUids,
    List<String>? viewerUids,
    List<String>? memberUids,
    List<Map<String, dynamic>>? checklist,
    List<Map<String, dynamic>>? planPoints,
    List<Map<String, dynamic>>? hotelPoints,
    this.completedAt,
  })  : editorUids = List.unmodifiable(_asStringList(editorUids) ?? const []),
        viewerUids = List.unmodifiable(_asStringList(viewerUids) ?? const []),
        // ถ้า caller ไม่ส่ง memberUids มา ให้รวม owner+editors+viewers อัตโนมัติ
        memberUids = List.unmodifiable(
          _mergeMembers(
            owner: uid,
            editors: _asStringList(editorUids) ?? const [],
            viewers: _asStringList(viewerUids) ?? const [],
            members: _asStringList(memberUids), // อาจเป็น null
          ),
        ),
        checklist = List.unmodifiable(checklist ?? const []),
        planPoints = List.unmodifiable(planPoints ?? const []),
        hotelPoints = List.unmodifiable(hotelPoints ?? const []);

  // ---------- Factory: from JSON/Firestore ----------
  factory TaskModel.fromJson(String id, Map<String, dynamic> json) {
    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          if (v.contains('/')) {
            final p = v.split('/');
            if (p.length == 3) {
              final dd = int.tryParse(p[0]) ?? 1;
              final mm = int.tryParse(p[1]) ?? 1;
              final yy = int.tryParse(p[2]) ?? DateTime.now().year;
              return DateTime(yy, mm, dd);
            }
          }
        }
      }
      return null;
    }

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    String _normPriority(String raw) {
      switch (raw.trim().toLowerCase()) {
        case 'high':
        case 'สูง':
          return 'High';
        case 'medium':
        case 'กลาง':
          return 'Medium';
        case 'low':
        case 'ต่ำ':
          return 'Low';
        default:
          return raw;
      }
    }

    final start = _toDate(json['startDate']) ?? DateTime.now();
    final end   = _toDate(json['endDate'])   ?? DateTime.now();
    final doneAt = _toDate(json['completedAt']);

    // checklist
    final List<Map<String, dynamic>> checklist = [];
    for (final item in (json['checklist'] as List? ?? const [])) {
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        if (m['start_date'] != null) m['start_date'] = _toDate(m['start_date']);
        if (m['end_date']   != null) m['end_date']   = _toDate(m['end_date']);
        if (m.containsKey('lat')) m['lat'] = _toDouble(m['lat']);
        if (m.containsKey('lng')) m['lng'] = _toDouble(m['lng']);
        m['done']     = (m['done'] == true) || (m['completed'] == true);
        m['expanded'] = m['expanded'] ?? true;
        checklist.add(m);
      }
    }

    // planPoints
    final List<Map<String, dynamic>> planPoints = [];
    for (final p in (json['planPoints'] as List? ?? const [])) {
      if (p is Map) {
        final m = Map<String, dynamic>.from(p);
        if (m.containsKey('lat')) m['lat'] = _toDouble(m['lat']);
        if (m.containsKey('lng')) m['lng'] = _toDouble(m['lng']);
        planPoints.add(m);
      }
    }

    // hotelPoints
    final List<Map<String, dynamic>> hotelPoints = [];
    for (final h in (json['hotelPoints'] as List? ?? const [])) {
      if (h is Map) {
        final m = Map<String, dynamic>.from(h);
        if (m.containsKey('lat')) m['lat'] = _toDouble(m['lat']);
        if (m.containsKey('lng')) m['lng'] = _toDouble(m['lng']);
        if (m['reserve'] != null) {
          m['reserve'] = (m['reserve'] == true || m['reserve'].toString() == 'true');
        }
        hotelPoints.add(m);
      }
    }

    // permissions arrays
    final editors = _asStringList(json['editorUids']) ?? const [];
    final viewers = _asStringList(json['viewerUids']) ?? const [];
    final owner   = (json['uid'] ?? '').toString();
    // ถ้ามี memberUids ในเอกสาร ใช้เลย; ถ้าไม่มี ให้รวมอัตโนมัติ
    final membersRaw = _asStringList(json['memberUids']);
    final members = _mergeMembers(
      owner: owner,
      editors: editors,
      viewers: viewers,
      members: membersRaw,
    );

    return TaskModel(
      id: id,
      title: (json['title'] ?? '').toString(),
      priority: _normPriority((json['priority'] ?? 'Low').toString()),
      startDate: start,
      endDate: end,
      status: (json['status'] ?? 'todo').toString(),
      uid: owner,
      checklist: checklist,
      planPoints: planPoints,
      hotelPoints: hotelPoints,
      completedAt: doneAt,
      editorUids: editors,
      viewerUids: viewers,
      memberUids: members,
    );
  }

  // ---------- Serialize: to JSON/Firestore ----------
  Map<String, dynamic> toJson() {
    Map<String, dynamic> _serializeChecklist(Map<String, dynamic> m) {
      final copy = Map<String, dynamic>.from(m);
      if (copy['start_date'] is DateTime) {
        copy['start_date'] = Timestamp.fromDate(copy['start_date'] as DateTime);
      }
      if (copy['end_date'] is DateTime) {
        copy['end_date'] = Timestamp.fromDate(copy['end_date'] as DateTime);
      }
      return copy;
    }

    final computedMembers = _mergeMembers(
      owner: uid,
      editors: editorUids,
      viewers: viewerUids,
      members: memberUids.isEmpty ? null : memberUids,
    );

    return {
      'title': title,
      'priority': priority,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'uid': uid,

      // permissions
      'editorUids': editorUids,
      'viewerUids': viewerUids,
      'memberUids': computedMembers,

      'checklist': checklist.map(_serializeChecklist).toList(),
      if (planPoints.isNotEmpty) 'planPoints': planPoints,
      if (hotelPoints.isNotEmpty) 'hotelPoints': hotelPoints,
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
    };
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? priority,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? uid,
    List<String>? editorUids,
    List<String>? viewerUids,
    List<String>? memberUids,
    List<Map<String, dynamic>>? checklist,
    List<Map<String, dynamic>>? planPoints,
    List<Map<String, dynamic>>? hotelPoints,
    DateTime? completedAt,
  }) {
    final nextOwner = uid ?? this.uid;
    final nextEditors = editorUids ?? this.editorUids;
    final nextViewers = viewerUids ?? this.viewerUids;
    // ถ้า caller ไม่ส่ง memberUids มา ให้ recompute อัตโนมัติ
    final nextMembers = memberUids ??
        _mergeMembers(owner: nextOwner, editors: nextEditors, viewers: nextViewers, members: null);

    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      priority: priority ?? this.priority,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      uid: nextOwner,
      editorUids: nextEditors,
      viewerUids: nextViewers,
      memberUids: nextMembers,
      checklist: checklist ?? this.checklist,
      planPoints: planPoints ?? this.planPoints,
      hotelPoints: hotelPoints ?? this.hotelPoints,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// ===== Helpers: ตรวจสิทธิ์ในแอป =====
  bool isOwner(String userId) => userId.isNotEmpty && userId == uid;
  bool canEdit(String userId) => isOwner(userId) || editorUids.contains(userId);
  bool canView(String userId) => canEdit(userId) || viewerUids.contains(userId);

  // ---------- Private utils ----------
  static List<String>? _asStringList(dynamic v) {
    if (v == null) return null;
    if (v is List) {
      // กรองให้เหลือ String ที่ไม่ว่าง และ unique ตามลำดับเดิม
      final seen = <String>{};
      final out = <String>[];
      for (final e in v) {
        final s = e?.toString() ?? '';
        if (s.isEmpty) continue;
        if (seen.add(s)) out.add(s);
      }
      return out;
    }
    return null;
  }

  static List<String> _mergeMembers({
    required String owner,
    required List<String> editors,
    required List<String> viewers,
    List<String>? members,
  }) {
    // ถ้าเอกสารถูกบันทึกไว้แล้วมี memberUids ที่ดี ให้ใช้ตามนั้น
    if (members != null && members.isNotEmpty) {
      // ทำให้ unique และไม่ว่างอีกรอบเพื่อกันข้อมูลสกปรก
      return _asStringList(members) ?? const [];
    }
    // รวม owner + editors + viewers → unique, no empty
    final set = <String>{};
    if (owner.isNotEmpty) set.add(owner);
    set.addAll(editors.where((e) => e.isNotEmpty));
    set.addAll(viewers.where((e) => e.isNotEmpty));
    return set.toList(growable: false);
  }
}
