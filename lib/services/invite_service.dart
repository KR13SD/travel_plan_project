import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InviteService {
  final FirebaseFirestore _fs;
  final FirebaseAuth _auth;
  InviteService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _fs = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  bool _isOverlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    // ชนถ้าไม่ (A ก่อน B และ A หลัง B)
    return !(aEnd.isBefore(bStart) || aStart.isAfter(bEnd));
  }

  // collections
  CollectionReference<Map<String, dynamic>> _tasksCol() =>
      _fs.collection('tasks');

  CollectionReference<Map<String, dynamic>> _taskInvitesCol(String taskId) =>
      _tasksCol().doc(taskId).collection('invites');

  DocumentReference<Map<String, dynamic>> _codeRef(String code) =>
      _fs.collection('invites').doc(code);

  String generateCode({int length = 6}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(
      length,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
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
    if ((data['uid'] ?? '') != uid) {
      throw Exception('Only the task owner can create invite codes');
    }
  }

  /// สร้างโค้ดเชิญ (เฉพาะเจ้าของแผน)
  Future<String> createInviteCode({
    required String taskId,
    required String role, // 'viewer' | 'editor'
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

    await _taskInvitesCol(taskId).add(payload);
    await _codeRef(code).set(payload);
    return code;
  }

  /// ใช้โค้ดเพื่อเข้าร่วมแผน
  Future<void> joinByCode(
    String code, {
    bool checkOverlapWithOwnedPlans = false,
  }) async {
    final uid = _uidOrThrow();
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) throw Exception('Invalid invite code');

    // อ่านโค้ด
    final codeSnap = await _codeRef(normalized).get();
    if (!codeSnap.exists) {
      throw Exception('โค้ดเชิญไม่ถูกต้อง');
    }

    final data = codeSnap.data()!;
    final String taskId = (data['taskId'] ?? '').toString();
    if (taskId.isEmpty) throw Exception('โค้ดนี้ไม่ผูกกับแผนใดๆ');

    final String role = (data['role'] == 'editor') ? 'editor' : 'viewer';
    final Timestamp? expTs = data['expiresAt'] as Timestamp?;
    final int? maxUses = (data['maxUses'] as num?)?.toInt();
    final int usedCount = (data['usedCount'] as num?)?.toInt() ?? 0;

    // เช็ควันหมดอายุ / โควต้า
    if (expTs != null && expTs.toDate().isBefore(DateTime.now())) {
      throw Exception('โค้ดเชิญหมดอายุแล้ว');
    }
    if (maxUses != null && usedCount >= maxUses) {
      throw Exception('โค้ดนี้ถูกใช้ครบตามจำนวนแล้ว');
    }

    final taskRef = _tasksCol().doc(taskId);
    final taskSnap = await taskRef.get();
    if (!taskSnap.exists) throw Exception('ไม่พบแผนปลายทาง');

    final tData = taskSnap.data() as Map<String, dynamic>? ?? {};
    final owner = (tData['uid'] ?? '').toString();

    // กัน owner ใช้โค้ดเข้าแผนตัวเอง
    if (owner == uid) {
      throw Exception('คุณเป็นเจ้าของแผนนี้อยู่แล้ว');
    }

    // กันสมาชิกซ้ำ
    final editors = List<String>.from(tData['editorUids'] ?? const []);
    final viewers = List<String>.from(tData['viewerUids'] ?? const []);
    final members = <String>{}
      ..add(owner)
      ..addAll(editors)
      ..addAll(viewers);

    if (members.contains(uid)) {
      throw Exception('คุณอยู่ในแผนนี้อยู่แล้ว');
    }


    if (checkOverlapWithOwnedPlans) {
      final Timestamp? sTs = tData['startDate'] as Timestamp?;
      final Timestamp? eTs = tData['endDate'] as Timestamp?;
      if (sTs != null && eTs != null) {
        final targetStart = sTs.toDate();
        final targetEnd = eTs.toDate();

        final owned = await _fs
            .collection('tasks')
            .where('uid', isEqualTo: uid)
            .get();

        for (final d in owned.docs) {
          final x = d.data();
          final os = (x['startDate'] as Timestamp?)?.toDate();
          final oe = (x['endDate'] as Timestamp?)?.toDate();
          if (os != null &&
              oe != null &&
              _isOverlap(os, oe, targetStart, targetEnd)) {
            throw Exception('ช่วงเวลาแผนนี้ชนกับแผนที่คุณเป็นเจ้าของอยู่');
          }
        }
      }
    }

    // เข้าร่วมจริง
    await _fs.runTransaction((trx) async {
      final freshCode = await trx.get(_codeRef(normalized));
      if (!freshCode.exists) {
        throw Exception('โค้ดเชิญไม่ถูกต้อง');
      }

      final freshTask = await trx.get(taskRef);
      if (!freshTask.exists) throw Exception('ไม่พบแผนปลายทาง');

      final ft = freshTask.data() as Map<String, dynamic>? ?? {};
      final fOwner = (ft['uid'] ?? '').toString();
      if (fOwner == uid) {
        throw Exception('คุณเป็นเจ้าของแผนนี้อยู่แล้ว');
      }

      final fEditors = List<String>.from(ft['editorUids'] ?? const []);
      final fViewers = List<String>.from(ft['viewerUids'] ?? const []);
      final fMembers = <String>{}
        ..add(fOwner)
        ..addAll(fEditors)
        ..addAll(fViewers);

      if (fMembers.contains(uid)) {
        throw Exception('คุณอยู่ในแผนนี้อยู่แล้ว');
      }

      // เพิ่มตาม role
      if (role == 'editor') {
        fEditors.add(uid);
      } else {
        fViewers.add(uid);
      }
      fMembers
        ..clear()
        ..add(fOwner)
        ..addAll(fEditors)
        ..addAll(fViewers);

      trx.update(taskRef, {
        'editorUids': fEditors.toSet().toList(),
        'viewerUids': fViewers.toSet().toList(),
        'memberUids': fMembers.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      trx.update(_codeRef(normalized), {'usedCount': FieldValue.increment(1)});
    });
  }

  Future<void> revokeInviteCode({
    required String taskId,
    required String code,
  }) async {
    final uid = _uidOrThrow();
    await _ensureOwner(taskId, uid);

    final normalized = code.trim().toUpperCase();
    await _codeRef(normalized).delete();

    final q = await _taskInvitesCol(
      taskId,
    ).where('code', isEqualTo: normalized).get();
    for (final d in q.docs) {
      await d.reference.delete();
    }
  }

  static String safeRole(String role) =>
      (role == 'editor') ? 'editor' : 'viewer';
}
