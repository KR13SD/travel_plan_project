import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/dashboard_controller.dart';
import '../models/task_model.dart';

class TaskDetailPage extends StatefulWidget {
  final TaskModel task;
  const TaskDetailPage({super.key, required this.task});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage>
    with TickerProviderStateMixin {
  late TextEditingController titleController;
  late String priority;
  late DateTime startDate;
  late DateTime endDate;
  late String status;
  late String editedPriority;
  late String editedStatus;
  late DateTime editedStartDate;
  late DateTime editedEndDate;
  final DashboardController controller = Get.find<DashboardController>();
  final dateFormat = DateFormat('dd MMM yyyy');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> originalChecklist = [];
  List<Map<String, dynamic>> editedChecklist = [];

  List<Map<String, dynamic>> checklist = [];

  // แก้ไข Priority options ให้ตรงกับ AI Import
  final Map<String, Map<String, dynamic>> priorityOptions = {
    'Low': {
      'label': 'low'.tr,
      'color': Colors.green,
      'icon': Icons.low_priority,
    },
    'Medium': {
      'label': 'medium'.tr,
      'color': Colors.orange,
      'icon': Icons.remove,
    },
    'High': {
      'label': 'high'.tr,
      'color': Colors.red,
      'icon': Icons.priority_high,
    },
  };

  final Map<String, Map<String, dynamic>> statusOptions = {
    'todo': {
      'label': 'pending'.tr,
      'color': Colors.grey,
      'icon': Icons.pending_actions,
    },
    'in_progress': {
      'label': 'inprogress'.tr,
      'color': Colors.orange,
      'icon': Icons.work,
    },
    'done': {
      'label': 'completed'.tr,
      'color': Colors.green,
      'icon': Icons.task_alt,
    },
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    final latestTask = controller.findTaskById(widget.task.id) ?? widget.task;

    // แก้ไข checklist initialization
    originalChecklist = latestTask.checklist != null
        ? List<Map<String, dynamic>>.from(latestTask.checklist!)
        : [];

    // สร้างสำเนาสำหรับ UI และตรวจสอบ field ที่จำเป็น
    editedChecklist = originalChecklist.map((item) {
      return {
        'title': item['title'] ?? '',
        'description': item['description'] ?? '',
        'done':
            item['done'] ??
            item['completed'] ??
            false, // รองรับทั้ง done และ completed
        'expanded': item['expanded'] ?? true,
        'priority': item['priority'] ?? 'Medium',
        'due_date': item['due_date'],
      };
    }).toList();

    titleController = TextEditingController(text: latestTask.title);

    // ตรวจสอบและแปลง priority เป็นรูปแบบที่ถูกต้อง
    priority = _normalizePriority(latestTask.priority);
    startDate = latestTask.startDate;
    endDate = latestTask.endDate;
    editedStartDate = startDate;
    editedEndDate = endDate;
    status = latestTask.status;

    // โหลด checklist จาก TaskModel
    checklist = List<Map<String, dynamic>>.from(editedChecklist);
  }

  // เพิ่มฟังก์ชัน normalize priority
  String _normalizePriority(String? priority) {
    if (priority == null) return 'Medium';

    // ถ้าเป็นรูปแบบใหม่แล้ว ให้ return เลย
    if (priorityOptions.containsKey(priority)) {
      return priority;
    }

    // แปลงจากรูปแบบเก่า
    switch (priority.toLowerCase()) {
      case 'high':
      case 'สูง':
        return 'High';
      case 'low':
      case 'ต่ำ':
        return 'Low';
      case 'medium':
      case 'กลาง':
      default:
        return 'Medium';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    titleController.dispose();
    checklist.clear();
    super.dispose();
  }

  Future<void> pickDate(BuildContext context, bool isStart) async {
    if (status == 'done') return;

    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? editedStartDate : editedEndDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          editedStartDate = picked;
          if (editedEndDate.isBefore(editedStartDate)) {
            editedEndDate = editedStartDate;
          }
        } else {
          editedEndDate = picked;
        }
      });
    }
  }

  void addChecklistItem() {
    setState(() {
      editedChecklist.add({
        "title": "",
        "description": "",
        "done": false,
        "expanded": true,
        "priority": "Medium",
        "due_date": null,
      });
      // อัปเดต checklist ด้วย
      checklist = List<Map<String, dynamic>>.from(editedChecklist);
    });
  }

  void removeChecklistItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red[600]),
            ),
            const SizedBox(width: 12),
            Text('confirmdelete'.tr),
          ],
        ),
        content: Text('dialogconfirmdelete'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                editedChecklist.removeAt(index);
                checklist = List<Map<String, dynamic>>.from(editedChecklist);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('deletetask'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> saveTask() async {
    if (titleController.text.trim().isEmpty) {
      _showErrorSnackbar('entertaskname'.tr);
      return;
    }

    // แปลง checklist กลับเป็นรูปแบบที่ TaskModel คาดหวัง
    final cleanedChecklist = editedChecklist
        .map(
          (item) => {
            'title': item['title'] ?? '',
            'description': item['description'] ?? '',
            'done': item['done'] ?? false,
            'expanded': item['expanded'] ?? true,
            'priority': item['priority'] ?? 'Medium',
            'due_date': item['due_date'],
          },
        )
        .toList();

    final updatedTask = widget.task.copyWith(
      title: titleController.text.trim(),
      priority: priority,
      startDate: editedStartDate,
      endDate: editedEndDate,
      status: status,
      checklist: cleanedChecklist,
    );

    try {
      await controller.updateTask(updatedTask);
      _showSuccessSnackbar('tasksaved'.tr);

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } catch (e) {
      _showErrorSnackbar('cannotsave'.tr);
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDone = status == 'done';
    final statusInfo = statusOptions[status] ?? statusOptions['todo']!;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: statusInfo['color'],
            foregroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 86,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            titleSpacing: 0,
            title: _buildStatusHeaderBar(statusInfo),
            actions: [
              IconButton(
                onPressed: saveTask,
                icon: const Icon(Icons.save_rounded),
                tooltip: 'save'.tr,
                color: Colors.white,
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ชื่องาน
                    _buildSectionCard(
                      title: 'taskname'.tr,
                      icon: Icons.title,
                      child: TextFormField(
                        controller: titleController,
                        readOnly: isDone,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDone ? Colors.grey : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'insertname'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDone ? Colors.grey[100] : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Priority และ Status
                    Row(
                      children: [
                        Expanded(
                          child: _buildSectionCard(
                            title: 'priority'.tr,
                            icon: Icons.priority_high,
                            child: _buildPriorityDropdown(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSectionCard(
                            title: 'status'.tr,
                            icon: Icons.flag,
                            child: _buildStatusDropdown(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // วันที่
                    _buildSectionCard(
                      title: 'date'.tr,
                      icon: Icons.calendar_today,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDateCard(
                              'startdate'.tr,
                              editedStartDate,
                              true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateCard(
                              'duedate'.tr,
                              editedEndDate,
                              false,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Checklist Section
                    _buildChecklistSection(),

                    const SizedBox(height: 100), // พื้นที่สำหรับ FAB
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saveTask,
        backgroundColor: statusInfo['color'],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.save_rounded),
        label: Text('save'.tr, style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    final isDone = status == 'done';

    return DropdownButtonFormField<String>(
      value: priorityOptions.containsKey(priority) ? priority : 'Medium',
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDone ? Colors.grey[100] : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      items: priorityOptions.entries.map((entry) {
        final info = entry.value;
        return DropdownMenuItem(
          value: entry.key,
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: info['color'],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(info['icon'], size: 14, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(info['label'], overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: isDone ? null : (val) => setState(() => priority = val!),
    );
  }

  Widget _buildStatusDropdown() {
    final isDone = status == 'done';

    return DropdownButtonFormField<String>(
      value: statusOptions.containsKey(status) ? status : 'todo',
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDone ? Colors.grey[100] : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      items: statusOptions.entries.map((entry) {
        final info = entry.value;
        return DropdownMenuItem(
          value: entry.key,
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: info['color'],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(info['icon'], size: 14, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(info['label'], overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: status == "done"
          ? null
          : (value) => setState(() => status = value!),
    );
  }

  Widget _buildDateCard(String label, DateTime date, bool isStart) {
    final isDone = status == 'done';
    final isOverdue = !isDone && date.isBefore(DateTime.now()) && !isStart;

    return InkWell(
      onTap: isDone ? null : () => pickDate(context, isStart),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDone ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? Colors.red[300]! : Colors.grey[300]!,
            width: isOverdue ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isStart ? Icons.play_arrow : Icons.flag,
                  size: 16,
                  color: isOverdue ? Colors.red : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverdue ? Colors.red : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isOverdue ? Colors.red : Colors.black87,
              ),
            ),
            if (isOverdue) ...[
              const SizedBox(height: 4),
              Text(
                'overdue'.tr,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistSection() {
    final isDone = status == 'done';
    final completedCount = checklist
        .where((item) => item['done'] == true)
        .length;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.checklist,
                    size: 20,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'subtasks'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (checklist.isNotEmpty)
                        Text(
                          'subtask_progress'.trParams({
                            'completed': completedCount.toString(),
                            'total': checklist.length.toString(),
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isDone)
                  IconButton(
                    onPressed: addChecklistItem,
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    tooltip: 'addsubtask'.tr,
                  ),
              ],
            ),

            if (checklist.isNotEmpty) ...[
              const SizedBox(height: 16),
              // Progress Bar
              LinearProgressIndicator(
                value: checklist.isNotEmpty
                    ? completedCount / checklist.length
                    : 0,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  completedCount == checklist.length
                      ? Colors.green
                      : Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Checklist Items
            ...editedChecklist.asMap().entries.map((entry) {
              int index = entry.key;
              var item = entry.value;
              return _buildChecklistItem(item, index, isDone);
            }).toList(),

            if (checklist.isEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.checklist_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'nosubtasks'.tr,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      if (!isDone) ...[
                        const SizedBox(height: 4),
                        Text(
                          'addsubtask'.tr,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(
    Map<String, dynamic> item,
    int index,
    bool taskIsDone,
  ) {
    final done = item["done"] ?? false;
    final expanded = item["expanded"] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: done ? Colors.green[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? Colors.green[200]! : Colors.grey[200]!,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: (isExpanded) {
            setState(() => item["expanded"] = isExpanded);
          },
          leading: Checkbox(
            value: done,
            onChanged: taskIsDone
                ? null
                : (val) {
                    setState(() {
                      item["done"] = val ?? false;
                      if (val == true) item["expanded"] = false;
                      // อัปเดต checklist ด้วย
                      checklist = List<Map<String, dynamic>>.from(
                        editedChecklist,
                      );
                    });
                  },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            activeColor: Colors.green,
          ),
          title: TextFormField(
            readOnly: done || taskIsDone,
            initialValue: item["title"] ?? "",
            style: TextStyle(
              color: done ? Colors.grey[600] : Colors.black87,
              decoration: done
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: "subtaskname".tr,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) => item["title"] = val,
          ),
          trailing: !taskIsDone
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => removeChecklistItem(index),
                  tooltip: 'deletesubtask'.tr,
                )
              : null,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextFormField(
                readOnly: done || taskIsDone,
                initialValue: item["description"] ?? "",
                style: TextStyle(
                  color: done ? Colors.grey[600] : Colors.black87,
                ),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "subtaskdetails".tr,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: done || taskIsDone
                      ? Colors.grey[100]
                      : Colors.white,
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (val) => item["description"] = val,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeaderBar(Map<String, dynamic> statusInfo) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ปุ่ม Back
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
          ),

          // กล่องไอคอนโปร่ง (เหมือนหน้าอื่น)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          // ชื่อใหญ่ + ซับไตเติล เหมือนหน้าอื่น
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'taskdetails'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                Text(
                  // ใช้ label ของสถานะเพื่อสื่อสี/สถานะตรงกัน
                  '${'status'.tr}: ${statusOptions[status]?['label'] ?? '—'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
