import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// โครงสร้างที่ใช้เก็บโค้ดเชิญ
/// - tasks/{taskId}/invites/{autoId}   (สำหรับดูย้อนหลังในหน้ารายละเอียดแผน)
/// - invites/{CODE}                    (สำหรับ lookup แบบเร็ว ไม่พึ่ง collectionGroup)
///
/// Roles: 'viewer' | 'editor'
class InviteService {
  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;
  InviteService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // -----------------------------
  // Collections
  // -----------------------------
  CollectionReference<Map<String, dynamic>> _tasksCol() =>
      _fs.collection('tasks');

  CollectionReference<Map<String, dynamic>> _taskInvitesCol(String taskId) =>
      _tasksCol().doc(taskId).collection('invites');

  /// top-level สำหรับ lookup ด้วยโค้ดโดยตรง (docId = CODE)
  DocumentReference<Map<String, dynamic>> _codeRef(String code) =>
      _fs.collection('invites').doc(code);

  // -----------------------------
  // Utilities
  // -----------------------------
  String generateCode({int length = 6}) {
    // ใช้ชุดอักษรอ่านง่าย ตัดตัวที่สับสนออก
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  String _uidOrThrow() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Not logged in');
    }
    return uid;
  }

  Future<void> _ensureOwner(String taskId, String uid) async {
    final snap = await _tasksCol().doc(taskId).get();
    if (!snap.exists) throw Exception('Task not found');
    final data = snap.data() as Map<String, dynamic>? ?? {};
    final owner = (data['uid'] ?? '').toString();
    if (owner != uid) {
      throw Exception('Only the task owner can create invite codes');
    }
  }

  // -----------------------------
  // Create invite
  // -----------------------------
  /// สร้างโค้ดเชิญ (เฉพาะเจ้าของแผน)
  ///
  /// - role: 'viewer' | 'editor'
  /// - expiresAt: วันหมดอายุ (ไม่ใส่ = ไม่หมดอายุ)
  /// - maxUses: จำกัดจำนวนครั้งใช้โค้ด (ไม่ใส่ = ไม่จำกัด)
  ///
  /// คืนค่า: CODE
  Future<String> createInviteCode({
    required String taskId,
    required String role,
    DateTime? expiresAt,
    int? maxUses,
  }) async {
    final uid = _uidOrThrow();
    await _ensureOwner(taskId, uid);

    final code = generateCode().toUpperCase();

    final payload = <String, dynamic>{
      'code': code,
      'taskId': taskId,
      'role': (role == 'editor') ? 'editor' : 'viewer',
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      if (maxUses != null) 'maxUses': maxUses,
      'usedCount': 0,
    };

    // เขียน 2 จุด: subcollection (history) + top-level (lookup)
    // 1) เก็บใน tasks/{taskId}/invites
    await _taskInvitesCol(taskId).add(payload);

    // 2) เก็บใน invites/{CODE} → ใช้เป็น source หลักตอน join
    await _codeRef(code).set(payload);

    return code;
  }

  // -----------------------------
  // Join by code
  // -----------------------------
  /// ใช้โค้ดเพื่อเข้าร่วมแผน
  /// - อัปเดต editorUids/viewerUids/memberUids
  /// - เช็ควันหมดอายุ/จำนวนครั้ง
  Future<void> joinByCode(String code) async {
    final uid = _uidOrThrow();
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) throw Exception('Invalid invite code');

    final codeSnap = await _codeRef(normalized).get();
    if (!codeSnap.exists) {
      // ไม่พบทันที → โค้ดไม่ถูกต้อง
      throw Exception('Invalid invite code');
    }

    final data = codeSnap.data()!;
    final String taskId = (data['taskId'] ?? '').toString();
    if (taskId.isEmpty) throw Exception('Invite not linked to any task');

    final String role = (data['role'] == 'editor') ? 'editor' : 'viewer';
    final Timestamp? expTs = data['expiresAt'] as Timestamp?;
    final int? maxUses = (data['maxUses'] as num?)?.toInt();
    final int usedCount = (data['usedCount'] as num?)?.toInt() ?? 0;

    // หมดอายุ?
    if (expTs != null && expTs.toDate().isBefore(DateTime.now())) {
      throw Exception('Invite expired');
    }
    // เต็มจำนวน?
    if (maxUses != null && usedCount >= maxUses) {
      throw Exception('Invite has reached its limit');
    }

    final taskRef = _tasksCol().doc(taskId);

    await _fs.runTransaction((trx) async {
      final tSnap = await trx.get(taskRef);
      if (!tSnap.exists) throw Exception('Task not found');

      final tData = tSnap.data() as Map<String, dynamic>? ?? {};
      final owner = (tData['uid'] ?? '').toString();
      final editors = List<String>.from(tData['editorUids'] ?? const []);
      final viewers = List<String>.from(tData['viewerUids'] ?? const []);

      // ถ้ายังไม่เป็นสมาชิก ให้เพิ่มตาม role
      final alreadyMember =
          (owner == uid) || editors.contains(uid) || viewers.contains(uid);

      if (!alreadyMember) {
        if (role == 'editor') {
          editors.add(uid);
        } else {
          viewers.add(uid);
        }
      }

      final members = <String>{}..add(owner)..addAll(editors)..addAll(viewers);

      // อัปเดต task
      trx.update(taskRef, {
        'editorUids': editors.toSet().toList(),
        'viewerUids': viewers.toSet().toList(),
        'memberUids': members.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // นับการใช้โค้ด (ใน top-level)
      trx.update(codeSnap.reference, {
        'usedCount': FieldValue.increment(1),
      });
    });
  }

  // -----------------------------
  // Maintenance (optional)
  // -----------------------------

  /// ยกเลิก/ลบโค้ดเชิญ (เฉพาะเจ้าของ)
  Future<void> revokeInviteCode({
    required String taskId,
    required String code,
  }) async {
    final uid = _uidOrThrow();
    await _ensureOwner(taskId, uid);

    final normalized = code.trim().toUpperCase();
    // ลบ top-level
    await _codeRef(normalized).delete();

    // ลบใน subcollection ทั้งหมดที่ code ตรงกัน (ถ้ามีหลายอัน)
    final q = await _taskInvitesCol(taskId)
        .where('code', isEqualTo: normalized)
        .get();
    for (final d in q.docs) {
      await d.reference.delete();
    }
  }

  /// แปลง role ให้ปลอดภัย (กันข้อความอื่น ๆ)
  static String safeRole(String role) =>
      (role == 'editor') ? 'editor' : 'viewer';
}
