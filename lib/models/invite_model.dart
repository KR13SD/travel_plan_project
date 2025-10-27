import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String id;              // doc id (top-level ใช้ CODE ก็ได้, subcollection ใช้ autoId)
  final String code;            // โค้ดเชิญ
  final String taskId;          // อ้างถึง task
  final String role;            // 'viewer' | 'editor'
  final String createdBy;       // uid ผู้สร้าง
  final DateTime? createdAt;    // อาจเป็น null ชั่วคราวถ้า serverTimestamp เพิ่งถูกเขียน
  final DateTime? expiresAt;    // null = ไม่หมดอายุ
  final int? maxUses;           // null = ไม่จำกัด
  final int usedCount;

  const InviteModel({
    required this.id,
    required this.code,
    required this.taskId,
    required this.role,
    required this.createdBy,
    required this.createdAt,
    this.expiresAt,
    this.maxUses,
    this.usedCount = 0,
  });

  /// Normalizers
  static String _normRole(String? v) {
    final s = (v ?? 'viewer').toLowerCase().trim();
    return s == 'editor' ? 'editor' : 'viewer';
    // ถ้าอยากรองรับ 'owner' ค่อยเพิ่มทีหลัง
  }

  static String _normCode(String? v) {
    return (v ?? '').trim().toUpperCase();
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory InviteModel.fromJson(String id, Map<String, dynamic> json) {
    return InviteModel(
      id: id,
      code: _normCode(json['code']),
      taskId: (json['taskId'] ?? '').toString(),
      role: _normRole(json['role']),
      createdBy: (json['createdBy'] ?? '').toString(),
      createdAt: _toDate(json['createdAt']),
      expiresAt: _toDate(json['expiresAt']),
      maxUses: (json['maxUses'] as num?)?.toInt(),
      usedCount: (json['usedCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory InviteModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InviteModel.fromJson(doc.id, data);
  }

  Map<String, dynamic> toJson({bool writeServerTimestampIfNull = false}) {
    return {
      'code': _normCode(code),
      'taskId': taskId,
      'role': _normRole(role),
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : (writeServerTimestampIfNull ? FieldValue.serverTimestamp() : null),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (maxUses != null) 'maxUses': maxUses,
      'usedCount': usedCount,
    }..removeWhere((k, v) => v == null);
  }

  /// Convenience getters
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isAtLimit {
    if (maxUses == null) return false;
    return usedCount >= (maxUses ?? 0);
  }

  int? get remainingUses {
    if (maxUses == null) return null;
    final left = maxUses! - usedCount;
    return left < 0 ? 0 : left;
  }

  bool get canJoin => !isExpired && !isAtLimit;

  InviteModel copyWith({
    String? id,
    String? code,
    String? taskId,
    String? role,
    String? createdBy,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? maxUses,
    int? usedCount,
  }) {
    return InviteModel(
      id: id ?? this.id,
      code: code != null ? _normCode(code) : this.code,
      taskId: taskId ?? this.taskId,
      role: role != null ? _normRole(role) : this.role,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      maxUses: maxUses ?? this.maxUses,
      usedCount: usedCount ?? this.usedCount,
    );
  }
}
