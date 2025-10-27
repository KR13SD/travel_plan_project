import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import '../models/task_model.dart';

class DashboardController extends GetxController {
  final RxList<TaskModel> allTasks = <TaskModel>[].obs;
  final RxBool isLoading = true.obs;

  FirebaseAuth get auth => _auth;

  RxInt todoCount = 0.obs;
  RxInt inProgressCount = 0.obs;
  RxInt doneCount = 0.obs;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void onInit() {
    super.onInit();
    tzdata.initializeTimeZones();
    _bindTasks();
    ever(allTasks, (_) => updateCounts());
  }

  // ✅ นับจำนวน task ตาม status (ไม่แคสเซนซิทีฟ)
  void updateCounts() {
    todoCount.value = allTasks
        .where((t) => t.status.toLowerCase() == 'todo')
        .length;
    inProgressCount.value = allTasks
        .where((t) => t.status.toLowerCase() == 'in_progress')
        .length;
    doneCount.value = allTasks
        .where((t) => t.status.toLowerCase() == 'done')
        .length;
  }

  // ✅ ดึง tasks ตาม uid ของ user
  void _bindTasks() {
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        allTasks.clear();
        isLoading.value = false;
        return;
      }

      final uid = user.uid;
      isLoading.value = true;

      // เดิม: where('uid', isEqualTo: uid)
      // ใหม่: แผนที่เราเป็นเจ้าของ หรือเป็นสมาชิก → ใช้ memberUids
      allTasks.bindStream(
        _firestore
            .collection('tasks')
            .where('memberUids', arrayContains: uid)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map((doc) => TaskModel.fromJson(doc.id, doc.data()))
                  .toList(),
            ),
      );

      allTasks.listen((_) => isLoading.value = false);
    });
  }

  // ✅ Tasks วันนี้
  List<TaskModel> get tasksToday {
    final bangkok = tz.getLocation('Asia/Bangkok');
    final now = tz.TZDateTime.now(bangkok);
    final todayStart = tz.TZDateTime(bangkok, now.year, now.month, now.day);
    final todayEnd = todayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));

    return allTasks.where((task) {
      final taskStart = tz.TZDateTime.from(task.startDate, bangkok);
      final taskEnd = tz.TZDateTime.from(task.endDate, bangkok);
      return task.status.toLowerCase() != 'done' &&
          !(taskEnd.isBefore(todayStart) || taskStart.isAfter(todayEnd));
    }).toList();
  }

  // ✅ Tasks ใกล้ถึงกำหนด (3 วันถัดไป)
  List<TaskModel> get tasksUpcoming {
    final bangkok = tz.getLocation('Asia/Bangkok');
    final now = tz.TZDateTime.now(bangkok);

    final todayStart = tz.TZDateTime(bangkok, now.year, now.month, now.day);
    final todayEnd = todayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(seconds: 1));
    final upcomingEnd = todayEnd.add(const Duration(days: 3));

    return allTasks.where((task) {
      final taskStart = tz.TZDateTime.from(task.startDate, bangkok);
      final taskEnd = tz.TZDateTime.from(task.endDate, bangkok);

      final isToday =
          !(taskEnd.isBefore(todayStart) || taskStart.isAfter(todayEnd));

      return task.status.toLowerCase() != 'done' &&
          !isToday &&
          taskEnd.isAfter(todayEnd) &&
          taskEnd.isBefore(upcomingEnd.add(const Duration(seconds: 1)));
    }).toList();
  }

  // ✅ Tasks เกินกำหนด
  List<TaskModel> get tasksOverdue {
    final now = DateTime.now();
    return allTasks
        .where(
          (task) =>
              task.status.toLowerCase() != 'done' && task.endDate.isBefore(now),
        )
        .toList();
  }

  // ✅ Tasks ที่เสร็จแล้ว
  List<TaskModel> get tasksDone {
    return allTasks
        .where((task) => task.status.toLowerCase() == 'done')
        .toList();
  }

  // ✅ อัปเดต task ทั้งก้อน
  Future<void> updateTask(TaskModel task) async {
    try {
      await _firestore.collection('tasks').doc(task.id).update(task.toJson());

      // อัปเดตใน local list เพื่อให้ UI ตอบสนองทันที
      final index = allTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        allTasks[index] = task;
        allTasks.refresh();
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
      Get.snackbar('Error', 'ไม่สามารถบันทึก Task ได้');
    }
  }

  // ✅ หา task ตาม id
  TaskModel? findTaskById(String id) {
    try {
      return allTasks.firstWhere((task) => task.id == id);
    } catch (_) {
      return null;
    }
  }

  // ✅ อัปเดตสถานะ task (และอัปเดต local list)
  Future<void> updateTaskStatus(String taskId, String status) async {
    try {
      final update = <String, dynamic>{'status': status};

      if (status.toLowerCase() == 'done') {
        update['completedAt'] = FieldValue.serverTimestamp();
      } else {
        // ถ้าต้องการล้าง completedAt เมื่อเปลี่ยนกลับจาก done:
        // update['completedAt'] = FieldValue.delete();
      }

      await _firestore.collection('tasks').doc(taskId).update(update);

      // อัปเดต local list
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

      Get.snackbar(
        'Success',
        'Change task status successfully',
        backgroundColor: const Color.fromARGB(255, 119, 243, 123),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Error updating task status: $e');
      Get.snackbar('Error', 'Cannot Change task status');
    }
  }

  // ✅ ลบ task
  Future<void> deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
    } catch (e) {
      debugPrint('Error deleting task: $e');
      Get.snackbar('Error', 'ไม่สามารถลบ Task ได้');
    }
  }

  // ✅ เพิ่ม task ใหม่
  Future<void> addTask(TaskModel task) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // รวม uid + createdAt ให้พร้อม (เผื่ออยาก orderBy)
      final data = {
        ...task.toJson(),
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('tasks').add(data);
    } catch (e) {
      debugPrint('Error adding task: $e');
      Get.snackbar('Error', 'ไม่สามารถเพิ่ม Task ได้');
    }
  }

  // ✅ เพิ่ม checklist item (เดิมใช้ subTasks → แก้ให้ตรง model)
  Future<void> addSubTask(String taskId, Map<String, dynamic> subTask) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'checklist': FieldValue.arrayUnion([subTask]),
      });
    } catch (e) {
      debugPrint('Error adding subtask: $e');
      Get.snackbar('Error', 'ไม่สามารถเพิ่ม Task ย่อยได้');
    }
  }

  // ✅ อัปเดต checklist ทั้งชุด (เดิมใช้ subTasks → แก้ให้ตรง model)
  Future<void> updateSubTask(
    String taskId,
    List<Map<String, dynamic>> subTasks,
  ) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'checklist': subTasks,
      });
    } catch (e) {
      debugPrint('Error updating subtask: $e');
      Get.snackbar('Error', 'ไม่สามารถอัปเดต Task ย่อยได้');
    }
  }
}
