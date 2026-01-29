import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String title;

  /// 'High' | 'Medium' | 'Low'
  final String priority;

  final DateTime startDate;
  final DateTime endDate;

  /// 'todo' | 'in_progress' | 'done'
  final String status;

  /// owner uid
  final String uid;

  /// permissions
  final List<String> editorUids;
  final List<String> viewerUids;
  final List<String> memberUids;

  /// contents (ใช้ checklist เป็นหลัก)
  final List<Map<String, dynamic>> checklist;

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
    this.completedAt,
  })  : editorUids = editorUids ?? const [],
        viewerUids = viewerUids ?? const [],
        memberUids = memberUids ?? const [],
        checklist = checklist ?? const [];

  // ===========================
  // 🔁 FROM JSON (Firestore)
  // ===========================
  factory TaskModel.fromJson(String id, Map<String, dynamic> json) {
    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {}
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
    final end = _toDate(json['endDate']) ?? DateTime.now();
    final doneAt = _toDate(json['completedAt']);

    /// ✅ checklist (deep copy ป้องกัน lat/lng ซ้ำ)
    final List<Map<String, dynamic>> checklist = [];
    for (final item in (json['checklist'] as List? ?? const [])) {
      if (item is Map) {
        final Map<String, dynamic> m = {};

        item.forEach((key, value) {
          if (key == 'lat' || key == 'lng') {
            m[key] = _toDouble(value);
          } else if (value is Timestamp) {
            m[key] = value.toDate();
          } else {
            m[key] = value;
          }
        });

        m['done'] = m['done'] == true;
        m['expanded'] = m['expanded'] ?? true;

        checklist.add(m);
      }
    }

    final editors =
        (json['editorUids'] as List?)?.whereType<String>().toList() ?? const [];
    final viewers =
        (json['viewerUids'] as List?)?.whereType<String>().toList() ?? const [];
    final members =
        (json['memberUids'] as List?)?.whereType<String>().toList() ?? const [];

    return TaskModel(
      id: id,
      title: (json['title'] ?? '').toString(),
      priority: _normPriority((json['priority'] ?? 'Low').toString()),
      startDate: start,
      endDate: end,
      status: (json['status'] ?? 'todo').toString(),
      uid: (json['uid'] ?? '').toString(),
      checklist: checklist,
      completedAt: doneAt,
      editorUids: editors,
      viewerUids: viewers,
      memberUids: members,
    );
  }

  // ===========================
  // 🔼 TO JSON (Firestore)
  // ===========================
  Map<String, dynamic> toJson() {
    Map<String, dynamic> _serializeChecklist(Map<String, dynamic> m) {
      final copy = Map<String, dynamic>.from(m);

      if (copy['start_date'] is DateTime) {
        copy['start_date'] =
            Timestamp.fromDate(copy['start_date'] as DateTime);
      }
      if (copy['end_date'] is DateTime) {
        copy['end_date'] = Timestamp.fromDate(copy['end_date'] as DateTime);
      }

      return copy;
    }

    final fallbackMembers =
        <String>{}..add(uid)..addAll(editorUids)..addAll(viewerUids);

    return {
      'title': title,
      'priority': priority,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'uid': uid,
      'editorUids': editorUids,
      'viewerUids': viewerUids,
      'memberUids':
          memberUids.isEmpty ? fallbackMembers.toList() : memberUids,
      'checklist': checklist.map(_serializeChecklist).toList(),
      if (completedAt != null)
        'completedAt': Timestamp.fromDate(completedAt!),
    };
  }

  // ===========================
  // ✏️ COPY WITH
  // ===========================
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
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      priority: priority ?? this.priority,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      uid: uid ?? this.uid,
      editorUids: editorUids ?? this.editorUids,
      viewerUids: viewerUids ?? this.viewerUids,
      memberUids: memberUids ?? this.memberUids,
      checklist: checklist ?? this.checklist,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // ===========================
  // 🔐 PERMISSION HELPERS
  // ===========================
  bool isOwner(String userId) => userId == uid;
  bool canEdit(String userId) => isOwner(userId) || editorUids.contains(userId);
  bool canView(String userId) => canEdit(userId) || viewerUids.contains(userId);
}
