import 'package:ai_task_project_manager/pages/auth/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  // ✅ นับจำนวน task ตาม status
  void updateCounts() {
    todoCount.value = allTasks.where((t) => t.status == 'todo').length;
    inProgressCount.value = allTasks
        .where((t) => t.status == 'in_progress')
        .length;
    doneCount.value = allTasks.where((t) => t.status == 'done').length;
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

      allTasks.bindStream(
        _firestore
            .collection('tasks')
            .where('uid', isEqualTo: uid)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map((doc) => TaskModel.fromJson(doc.id, doc.data()))
                  .toList(),
            ),
      );

      // เมื่อ stream พร้อม → ปิด loading
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
      return task.status != 'done' &&
          !(taskEnd.isBefore(todayStart) || taskStart.isAfter(todayEnd));
    }).toList();
  }

  // ✅ Tasks ใกล้ถึงกำหนด
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

      return task.status != 'done' &&
          !isToday &&
          taskEnd.isAfter(todayEnd) &&
          taskEnd.isBefore(upcomingEnd.add(const Duration(seconds: 1)));
    }).toList();
  }

  // ✅ Tasks เกินกำหนด
  List<TaskModel> get tasksOverdue {
    final now = DateTime.now();
    return allTasks
        .where((task) => task.status != 'done' && task.endDate.isBefore(now))
        .toList();
  }

  // ✅ Tasks ที่เสร็จแล้ว
  List<TaskModel> get tasksDone {
    return allTasks.where((task) => task.status == 'done').toList();
  }

  // ✅ อัปเดต task
  Future<void> updateTask(TaskModel task) async {
    try {
      await _firestore.collection('tasks').doc(task.id).update(task.toJson());

      // 👇 เพิ่มตรงนี้เพื่ออัปเดต local list ด้วย (กัน task หาย)
      final index = allTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        allTasks[index] = task;
        allTasks.refresh();
      }
    } catch (e) {
      print('Error updating task: $e');
      Get.snackbar('Error', 'ไม่สามารถบันทึก Task ได้');
    }
  }

  // ✅ หา task ตาม id
  TaskModel? findTaskById(String id) {
    try {
      return allTasks.firstWhere((task) => task.id == id);
    } catch (e) {
      return null;
    }
  }

  // ✅ อัปเดตสถานะ task
  Future<void> updateTaskStatus(String taskId, String status) async {
    try {
      final update = <String, dynamic>{'status': status};

      if (status == 'done'){
        update['completedAt'] = FieldValue.serverTimestamp();
      }
      else {
        // update['completedAt'] = FieldValue.delete();
      }

      await _firestore.collection('tasks').doc(taskId).update(update);
      Get.snackbar('Success', 'Change task status successfully',
      backgroundColor: const Color.fromARGB(255, 119, 243, 123),
      snackPosition: SnackPosition.BOTTOM 
      );
    }
    catch (e) {
      print('Error updating task status: $e');
      Get.snackbar('Error', 'Cannot Change task status');
    }
  }

  // ✅ ลบ task
  Future<void> deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
    } catch (e) {
      print('Error deleting task: $e');
      Get.snackbar('Error', 'ไม่สามารถลบ Task ได้');
    }
  }

  // ✅ เพิ่ม task ใหม่
  Future<void> addTask(TaskModel task) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _firestore.collection('tasks').add({...task.toJson(), 'uid': uid});
    } catch (e) {
      print('Error adding task: $e');
      Get.snackbar('Error', 'ไม่สามารถเพิ่ม Task ได้');
    }
  }

  // ✅ เพิ่ม task ย่อย
  Future<void> addSubTask(String taskId, Map<String, dynamic> subTask) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'subTasks': FieldValue.arrayUnion([subTask]),
      });
    } catch (e) {
      print('Error adding subtask: $e');
      Get.snackbar('Error', 'ไม่สามารถเพิ่ม Task ย่อยได้');
    }
  }

  // ✅ อัปเดต subTask
  Future<void> updateSubTask(
    String taskId,
    List<Map<String, dynamic>> subTasks,
  ) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'subTasks': subTasks,
      });
    } catch (e) {
      print('Error updating subtask: $e');
      Get.snackbar('Error', 'ไม่สามารถอัปเดต Task ย่อยได้');
    }
  }
}
