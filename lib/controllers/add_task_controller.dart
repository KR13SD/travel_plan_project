import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task_model.dart';

class AddTaskController extends GetxController {
  final TextEditingController titleController = TextEditingController();

  final priority = 'Low'.obs;
  final startDate = DateTime.now().obs;
  final endDate = DateTime.now().add(const Duration(days: 1)).obs;
  final checklist = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;

  final Map<String, Color> priorityColors = {
    'Low': Colors.green,
    'Medium': Colors.orange,
    'High': Colors.red,
  };

  final Map<String, IconData> priorityIcons = {
    'Low': Icons.keyboard_arrow_down,
    'Medium': Icons.remove,
    'High': Icons.keyboard_arrow_up,
  };

  @override
  void onClose() {
    titleController.dispose();
    super.onClose();
  }

  Future<void> pickDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate.value : endDate.value,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context)
                .colorScheme
                .copyWith(primary: priorityColors[priority.value]),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (isStart) {
        startDate.value = picked;
        if (endDate.value.isBefore(startDate.value)) {
          endDate.value = startDate.value.add(const Duration(days: 1));
        }
      } else {
        if (picked.isBefore(startDate.value)) {
          showErrorSnackbar('วันที่สิ้นสุดต้องไม่น้อยกว่าวันที่เริ่ม');
          return;
        }
        endDate.value = picked;
      }
    }
  }

  void addChecklistItem() {
    checklist.add({
      "title": "",
      "description": "",
      "done": false,
      "expanded": true,
      "id": DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> removeChecklistItem(BuildContext context, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            Text('comfirmdelete'.tr),
          ],
        ),
        content: Text('confirmdeletesubtask'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );

    if (confirm == true) {
      checklist.removeAt(index);
    }
  }

  void toggleChecklistExpansion(int index, bool expanded) {
    checklist[index]["expanded"] = expanded;
    checklist.refresh();
  }

  void toggleChecklistDone(int index, bool done) {
    checklist[index]["done"] = done;
    checklist.refresh();
  }

  void showErrorSnackbar(String message) {
    Get.snackbar(
      'เกิดข้อผิดพลาด ⚠️',
      message,
      backgroundColor: Colors.red.withOpacity(0.9),
      colorText: Colors.white,
      icon: const Icon(Icons.error_rounded, color: Colors.white),
      duration: const Duration(seconds: 4),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
    );
  }

  Future<void> saveTask(GlobalKey<FormState> formKey, BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        showErrorSnackbar('ไม่พบผู้ใช้');
        return;
      }

      final task = TaskModel(
        id: '',
        title: titleController.text.trim(),
        priority: priority.value,
        startDate: startDate.value,
        endDate: endDate.value,
        status: 'todo',
        uid: uid,
        checklist: checklist.toList(),
      );

      await FirebaseFirestore.instance.collection('tasks').add(task.toJson());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'สร้าง Task "${titleController.text.trim()}" เรียบร้อยแล้ว'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      Get.back(result: true);
    } catch (e) {
      showErrorSnackbar('เกิดข้อผิดพลาดในการบันทึก: ${e.toString()}');
      print('Error saving task: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

