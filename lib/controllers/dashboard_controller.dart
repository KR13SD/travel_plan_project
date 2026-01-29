import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_model.dart';

class DashboardController extends GetxController {
  final RxList<TaskModel> allTasks = <TaskModel>[].obs;
  final RxBool isGenerating = true.obs;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // counts
  final RxInt todoCount = 0.obs;
  final RxInt inProgressCount = 0.obs;
  final RxInt doneCount = 0.obs;

  // subs
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ownedSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _memberSub;

  // local caches for merging
  List<TaskModel> _ownedCache = const [];
  List<TaskModel> _memberCache = const [];

  FirebaseAuth get auth => _auth;

  @override
  void onInit() {
    super.onInit();
    tzdata.initializeTimeZones();
    _bindTasks();
    ever(allTasks, (_) => _updateCounts());
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _ownedSub?.cancel();
    _memberSub?.cancel();
    super.onClose();
  }

  void _updateCounts() {
    todoCount.value =
        allTasks.where((t) => t.status.toLowerCase() == 'todo').length;
    inProgressCount.value =
        allTasks.where((t) => t.status.toLowerCase() == 'in_progress').length;
    doneCount.value =
        allTasks.where((t) => t.status.toLowerCase() == 'done').length;
  }

  /// ฟังงานทั้ง "เจ้าของ" (สคีมาเดิม) + "สมาชิก" (สคีมาใหม่ memberUids)
  void _bindTasks() {
    _authSub?.cancel();
    _ownedSub?.cancel();
    _memberSub?.cancel();

    _authSub = _auth.authStateChanges().listen((user) {
      _ownedCache = const [];
      _memberCache = const [];

      _ownedSub?.cancel();
      _memberSub?.cancel();

      if (user == null) {
        allTasks.clear();
        isGenerating.value = false;
        return;
      }

      isGenerating.value = true;

      final ownedQuery =
          _firestore.collection('tasks').where('uid', isEqualTo: user.uid);

      final memberQuery = _firestore
          .collection('tasks')
          .where('memberUids', arrayContains: user.uid);

      _ownedSub = ownedQuery.snapshots().listen((qs) {
        _ownedCache =
            qs.docs.map((d) => TaskModel.fromJson(d.id, d.data())).toList();
        _rebuildMerged();
      }, onError: (e) {
        _handleStreamError(e);
      });

      _memberSub = memberQuery.snapshots().listen((qs) {
        _memberCache =
            qs.docs.map((d) => TaskModel.fromJson(d.id, d.data())).toList();
        _rebuildMerged();
      }, onError: (e) {
        _handleStreamError(e);
      });
    });
  }

  void _handleStreamError(Object e) {
    debugPrint('Task stream error: $e');
    isGenerating.value = false;
    final es = e.toString();
    String msg = 'โหลดข้อมูลไม่สำเร็จ';
    if (es.contains('PERMISSION_DENIED')) {
      msg =
          'ไม่มีสิทธิ์อ่าน tasks — ตรวจ Firestore Rules และให้แน่ใจว่าคอลเลกชันชื่อ `tasks`';
    } else if (es.contains('requires an index')) {
      msg = 'ต้องสร้าง Firestore Index สำหรับ query นี้ใน Firebase Console';
    }
    Get.snackbar('เกิดข้อผิดพลาด', msg, snackPosition: SnackPosition.BOTTOM);
  }

  /// รวม owned + member แล้ว dedupe ด้วย id
  void _rebuildMerged() {
    final map = <String, TaskModel>{};
    for (final t in _ownedCache) map[t.id] = t;
    for (final t in _memberCache) map[t.id] = t;

    allTasks.assignAll(map.values.toList());
    isGenerating.value = false;
  }

  // ===== Convenience getters =====
  List<TaskModel> get tasksToday {
    final bkk = tz.getLocation('Asia/Bangkok');
    final now = tz.TZDateTime.now(bkk);
    final start = tz.TZDateTime(bkk, now.year, now.month, now.day);
    final end =
        start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

    return allTasks.where((task) {
      final s = tz.TZDateTime.from(task.startDate, bkk);
      final e = tz.TZDateTime.from(task.endDate, bkk);
      return task.status.toLowerCase() != 'done' &&
          !(e.isBefore(start) || s.isAfter(end));
    }).toList();
  }

  List<TaskModel> get tasksUpcoming {
    final bkk = tz.getLocation('Asia/Bangkok');
    final now = tz.TZDateTime.now(bkk);
    final start = tz.TZDateTime(bkk, now.year, now.month, now.day);
    final todayEnd =
        start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    final upcomingEnd = todayEnd.add(const Duration(days: 3));

    return allTasks.where((task) {
      final s = tz.TZDateTime.from(task.startDate, bkk);
      final e = tz.TZDateTime.from(task.endDate, bkk);
      final isToday = !(e.isBefore(start) || s.isAfter(todayEnd));
      return task.status.toLowerCase() != 'done' &&
          !isToday &&
          e.isAfter(todayEnd) &&
          e.isBefore(upcomingEnd.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<TaskModel> get tasksOverdue {
    final now = DateTime.now();
    return allTasks
        .where((t) => t.status.toLowerCase() != 'done' && t.endDate.isBefore(now))
        .toList();
  }

  List<TaskModel> get tasksDone =>
      allTasks.where((t) => t.status.toLowerCase() == 'done').toList();

  // ===== CRUD =====

  /// เพิ่ม task ใหม่ (optimistic: ไม่ push เข้า allTasks ตรง ๆ เพราะต้องรู้ docId จาก Firestore)
  Future<void> addTask(TaskModel task) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        Get.snackbar('Error', 'ยังไม่ล็อกอิน');
        return;
      }

      final editors = task.editorUids;
      final viewers = task.viewerUids;
      final members = <String>{}..add(uid)..addAll(editors)..addAll(viewers);

      final data = {
        ...task.copyWith(uid: uid, memberUids: members.toList()).toJson(),
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        '_joinCode': '',
      };

      // สร้างเอกสารใหม่
      final doc = await _firestore.collection('tasks').add(data);

      // ไม่ใส่ allTasks ทันทีเพื่อเลี่ยงสถานะซ้ำ—ให้ snapshot รับผิดชอบ
      // แต่ถ้าอยากเห็นทันใจมากขึ้น สามารถดัน placeholder เข้าไปก่อนได้ (optional)
      // ตัวอย่าง (คอมเมนต์ไว้):
      // final placeholder = task.copyWith(id: doc.id, uid: uid, memberUids: members.toList());
      // allTasks.add(placeholder); allTasks.refresh();
    } catch (e) {
      debugPrint('Error adding task: $e');
      Get.snackbar('Error', 'ไม่สามารถเพิ่ม Task ได้');
    }
  }

  Future<void> updateTask(TaskModel task) async {
    try {
      await _firestore.collection('tasks').doc(task.id).update({
        ...task.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // optimistic: sync local
      final idx = allTasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        allTasks[idx] = task;
        allTasks.refresh();
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
      Get.snackbar('Error', 'ไม่สามารถบันทึก Task ได้');
    }
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    try {
      final update = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (status.toLowerCase() == 'done') {
        update['completedAt'] = FieldValue.serverTimestamp();
      } else {
        // ถ้าต้องล้าง completedAt เมื่อเปลี่ยนจาก done -> อื่น ๆ ก็ปลดคอมเมนต์บรรทัดล่างนี้
        // update['completedAt'] = FieldValue.delete();
      }

      await _firestore.collection('tasks').doc(taskId).update(update);

      // optimistic: sync local
      final idx = allTasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        final current = allTasks[idx];
        allTasks[idx] = current.copyWith(
          status: status,
          completedAt: status.toLowerCase() == 'done'
              ? DateTime.now()
              : current.completedAt,
        );
        allTasks.refresh();
      }

      Get.snackbar('Success', 'Change task status successfully',
          backgroundColor: const Color.fromARGB(255, 119, 243, 123),
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      debugPrint('Error updating task status: $e');
      Get.snackbar('Error', 'Cannot Change task status');
    }
  }

  /// ลบทันทีใน Firestore + ลบออกจาก allTasks แบบ optimistic เพื่อให้ UI หายทันที
  Future<void> deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();

      // ✅ optimistic: ลบจาก list ก่อน ไม่ต้องรอ snapshot
      final idx = allTasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        allTasks.removeAt(idx);
        allTasks.refresh();
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
      Get.snackbar('Error', 'ไม่สามารถลบ Task ได้');
    }
  }

  Future<void> addSubTask(String taskId, Map<String, dynamic> subTask) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'checklist': FieldValue.arrayUnion([subTask]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ optimistic: อัปเดตในแอปทันที
      final idx = allTasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        final cur = allTasks[idx];
        final newList = List<Map<String, dynamic>>.from(cur.checklist)..add(subTask);
        allTasks[idx] = cur.copyWith(checklist: newList);
        allTasks.refresh();
      }
    } catch (e) {
      debugPrint('Error adding subtask: $e');
      Get.snackbar('Error', 'ไม่สามารถเพิ่ม Task ย่อยได้');
    }
  }

  Future<void> updateSubTask(
      String taskId, List<Map<String, dynamic>> subTasks) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'checklist': subTasks,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ optimistic: sync local
      final idx = allTasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        final cur = allTasks[idx];
        allTasks[idx] = cur.copyWith(checklist: subTasks);
        allTasks.refresh();
      }
    } catch (e) {
      debugPrint('Error updating subtask: $e');
      Get.snackbar('Error', 'ไม่สามารถอัปเดต Task ย่อยได้');
    }
  }

  TaskModel? findTaskById(String id) {
    try {
      return allTasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// ใช้ครั้งเดียวเพื่ออัปเดตเอกสารเก่าให้มี memberUids
  Future<void> backfillMemberUidsForMyTasks() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final qs =
        await _firestore.collection('tasks').where('uid', isEqualTo: uid).get();
    for (final d in qs.docs) {
      final data = d.data();
      final editors = List<String>.from(data['editorUids'] ?? const []);
      final viewers = List<String>.from(data['viewerUids'] ?? const []);
      final members = <String>{}..add(uid)..addAll(editors)..addAll(viewers);
      await d.reference.update({'memberUids': members.toList()});
    }
  }
}
