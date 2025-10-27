import 'package:ai_task_project_manager/pages/ai_map_page.dart';
import 'package:ai_task_project_manager/pages/map_preview.dart';
import 'package:ai_task_project_manager/widget/invite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  late DateTime editedStartDate;
  late DateTime editedEndDate;

  final DashboardController controller = Get.find<DashboardController>();
  final dateFormat = DateFormat('dd MMM yyyy');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // timezone-safe helper
  DateTime _asLocal(DateTime d) => d.isUtc ? d.toLocal() : d;

  // เก็บต้นฉบับ + สำเนาแก้ไข
  List<Map<String, dynamic>> originalChecklist = [];
  List<Map<String, dynamic>> editedChecklist = [];

  // สำหรับ progress รวม
  List<Map<String, dynamic>> checklist = [];

  // เก็บสถานะเลือกโรงแรมหลัก (radio)
  String? _selectedHotelKey;

  // Priority / Status options
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

    // ต้นฉบับจาก model
    originalChecklist = List<Map<String, dynamic>>.from(latestTask.checklist);

    // สำเนาแก้ไข: preserve field ทั้งหมด + normalize field สำคัญ
    editedChecklist = originalChecklist.map((raw) {
      final m = Map<String, dynamic>.from(raw);

      // normalize type (hotel/plan)
      final type = (m['type'] ?? '').toString();
      if (type.isEmpty) {
        final hasHotelHints =
            m.containsKey('price') ||
            m.containsKey('notes') ||
            m.containsKey('reserve') ||
            (m['type'] == 'hotel');
        m['type'] = hasHotelHints ? 'hotel' : 'plan';
      }

      // normalize basics
      m['done'] = (m['done'] == true) || (m['completed'] == true);
      m['expanded'] = m['expanded'] ?? true;

      // normalize priority
      m['priority'] = _normalizePriority(m['priority']?.toString());

      // parse date fields if present
      m['start_date'] = _toDate(m['start_date']);
      m['end_date'] = _toDate(m['end_date']);

      // time/duration keep as string
      if (m['time'] != null) m['time'] = m['time'].toString();
      if (m['duration'] != null) m['duration'] = m['duration'].toString();

      // lat/lng normalize to double
      m['lat'] = _toDouble(m['lat']);
      m['lng'] = _toDouble(m['lng']);

      // selectedHotel flag (default false)
      if (m['type'] == 'hotel') {
        m['selectedHotel'] = (m['selectedHotel'] == true);
      }

      return m;
    }).toList();

    // ตั้งค่า selectedHotel จากข้อมูลเดิม (ถ้ามี)
    final idxSelected = editedChecklist.indexWhere(
      (e) => (e['type'] == 'hotel') && (e['selectedHotel'] == true),
    );
    if (idxSelected != -1) {
      _selectedHotelKey = _hotelKey(idxSelected, editedChecklist[idxSelected]);
    }

    titleController = TextEditingController(text: latestTask.title);
    priority = _normalizePriority(latestTask.priority);
    startDate = _asLocal(latestTask.startDate);
    endDate = _asLocal(latestTask.endDate);
    editedStartDate = startDate;
    editedEndDate = endDate;
    status = latestTask.status;

    checklist = List<Map<String, dynamic>>.from(editedChecklist);
  }

  String _normalizePriority(String? prio) {
    if (prio == null) return 'Medium';
    if (priorityOptions.containsKey(prio)) return prio;
    switch (prio.toLowerCase()) {
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

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return _asLocal(v);
    if (v is Timestamp) return _asLocal(v.toDate());
    if (v is String) {
      try {
        return _asLocal(DateTime.parse(v));
      } catch (_) {
        if (v.contains('/')) {
          final p = v.split('/');
          if (p.length == 3) {
            final dd = int.tryParse(p[0]) ?? 1;
            final mm = int.tryParse(p[1]) ?? 1;
            final yy = int.tryParse(p[2]) ?? DateTime.now().year;
            return _asLocal(DateTime(yy, mm, dd));
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

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('dd/MM/yyyy').format(_asLocal(d));
  }

  String _fmtTime(String? t) {
    if (t == null || t.trim().isEmpty) return '';
    try {
      if (t.contains(':')) {
        final parts = t.split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final dt = DateTime(2024, 1, 1, h, m);
        return DateFormat('HH:mm').format(dt);
      }
      return t;
    } catch (_) {
      return t;
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

    // กัน viewer
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final t = controller.findTaskById(widget.task.id) ?? widget.task;
    if (!t.canEdit(uid)) return;

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

  void addChecklistItem({String type = 'plan'}) {
    setState(() {
      editedChecklist.add({
        'type': type, // 'plan' or 'hotel'
        'title': '',
        'description': '',
        'done': false,
        'expanded': true,
        'priority': 'Medium',
        // เฉพาะ/ร่วมได้
        'start_date': null,
        'end_date': null,
        'time': null,
        'duration': null,
        'lat': null,
        'lng': null,
        // เฉพาะโรงแรม
        'price': null,
        'notes': null,
        'mapsUrl': null,
        'reserve': null,
        'selectedHotel': false,
      });
      checklist = List<Map<String, dynamic>>.from(editedChecklist);
    });
  }

  void removeChecklistItem(int index) {
    // กัน viewer
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final t = controller.findTaskById(widget.task.id) ?? widget.task;
    if (!t.canEdit(uid)) {
      _showErrorSnackbar('คุณไม่มีสิทธิ์ลบรายการนี้');
      return;
    }

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
              final key = _hotelKey(index, editedChecklist[index]);
              if (_selectedHotelKey == key) _selectedHotelKey = null;
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

  Future<void> _openExternalMap(double lat, double lng, {String? label}) async {
    final q = Uri.encodeComponent(label ?? 'Location');
    final googleUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng($q)',
    );
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      return;
    }
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($q)');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      return;
    }
    final appleUrl = Uri.parse('http://maps.apple.com/?ll=$lat,$lng&q=$q');
    await launchUrl(appleUrl, mode: LaunchMode.externalApplication);
  }

  String _hotelKey(int index, Map<String, dynamic> h) =>
      'h:$index:${(h['title'] ?? '').toString()}';

  Future<void> saveTask() async {
    // กัน viewer ยิงตรง
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final latest = controller.findTaskById(widget.task.id) ?? widget.task;
    if (!latest.canEdit(uid)) {
      _showErrorSnackbar('คุณไม่มีสิทธิ์แก้ไขงานนี้');
      return;
    }

    if (titleController.text.trim().isEmpty) {
      _showErrorSnackbar('entertaskname'.tr);
      return;
    }

    // สร้าง list ใหม่จาก editedChecklist โดย normalize และเคารพ "เลือกโรงแรมเดียว"
    final List<Map<String, dynamic>> plans = [];
    final List<Map<String, dynamic>> hotels = [];

    for (var i = 0; i < editedChecklist.length; i++) {
      final raw = editedChecklist[i];
      final m = Map<String, dynamic>.from(raw);

      // normalize สำคัญ
      m['type'] = (m['type'] ?? 'plan').toString();
      m['done'] = (m['done'] == true);
      m['expanded'] = m['expanded'] ?? true;
      m['priority'] = _normalizePriority(m['priority']?.toString());

      // ให้เป็น DateTime เพื่อให้ TaskModel.toJson() แปลงเป็น Timestamp ได้
      m['start_date'] = _toDate(m['start_date']);
      m['end_date'] = _toDate(m['end_date']);

      // พิกัด double
      m['lat'] = _toDouble(m['lat']);
      m['lng'] = _toDouble(m['lng']);

      // time/duration string
      if (m['time'] != null) m['time'] = m['time'].toString();
      if (m['duration'] != null) m['duration'] = m['duration'].toString();

      // แยกตาม type
      if (m['type'] == 'hotel') {
        // mark selectedHotel (จาก radio)
        final key = _hotelKey(i, raw);
        m['selectedHotel'] =
            (_selectedHotelKey != null && key == _selectedHotelKey);
        hotels.add(m);
      } else {
        plans.add(m);
      }
    }

    // ถ้ามีการเลือกโรงแรมหลัก → เก็บเฉพาะโรงแรมนั้น
    List<Map<String, dynamic>> finalHotels = hotels;
    final selected = hotels.where((h) => h['selectedHotel'] == true).toList();
    if (selected.isNotEmpty) {
      finalHotels = [selected.first];
    }

    final cleanedChecklist = [...plans, ...finalHotels];

    final updatedTask = (controller.findTaskById(widget.task.id) ?? widget.task)
        .copyWith(
          title: titleController.text.trim(),
          priority: priority.isEmpty ? 'Low' : priority,
          startDate: editedStartDate,
          endDate: editedEndDate,
          status: status.isEmpty ? 'todo' : status,
          checklist: cleanedChecklist,
        );

    try {
      await controller.updateTask(updatedTask);
      _showSuccessSnackbar('tasksaved'.tr);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.of(context).pop(true);
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
    final statusInfo = statusOptions[status] ?? statusOptions['todo']!;

    final user = FirebaseAuth.instance.currentUser;
    final currentUid = user?.uid ?? '';

    // ใช้เวอร์ชันล่าสุดของ task จาก controller (กัน stale)
    final latestTask = controller.findTaskById(widget.task.id) ?? widget.task;
    final bool isOwner = latestTask.uid == currentUid;
    final bool canEdit = latestTask.canEdit(currentUid);

    // แยก plans/hotels เพื่อโชว์หัวข้อชัดเจน
    final plans = editedChecklist.where((e) => e['type'] == 'plan').toList();
    final hotels = editedChecklist.where((e) => e['type'] == 'hotel').toList();
    final completedCount = plans.where((e) => e['done'] == true).length;

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
              if (isOwner)
                IconButton(
                  tooltip: 'เชิญเข้าร่วม',
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (_) => InviteSheet(taskId: widget.task.id),
                    );
                  },
                ),
              if (canEdit)
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
                    _buildSectionCard(
                      title: 'taskname'.tr,
                      icon: Icons.title,
                      child: TextFormField(
                        controller: titleController,
                        readOnly: (status == 'done') || !canEdit,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: (status == 'done' || !canEdit)
                              ? Colors.grey
                              : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'insertname'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: (status == 'done' || !canEdit)
                              ? Colors.grey[100]
                              : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSectionCard(
                            title: 'priority'.tr,
                            icon: Icons.priority_high,
                            child: _buildPriorityDropdown(canEdit),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSectionCard(
                            title: 'status'.tr,
                            icon: Icons.flag,
                            child: _buildStatusDropdown(canEdit),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                              canEdit: canEdit,
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
                              canEdit: canEdit,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== Plans Card =====
                    _buildSectionCard(
                      title: 'แผน / กิจกรรม'.tr,
                      icon: Icons.route_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (plans.isNotEmpty) ...[
                            LinearProgressIndicator(
                              value: plans.isNotEmpty
                                  ? completedCount / plans.length
                                  : 0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                completedCount == plans.length
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Text(
                                '${'items'.tr}: ${plans.length}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (status != 'done' && canEdit)
                                TextButton.icon(
                                  onPressed: () =>
                                      addChecklistItem(type: 'plan'),
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: Text('addsubtask'.tr),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (plans.isEmpty)
                            _emptyBox('ไม่มีรายการแผน/กิจกรรม'.tr)
                          else
                            ...plans.asMap().entries.map((entry) {
                              final indexInEdited = editedChecklist.indexOf(
                                entry.value,
                              );
                              return _buildChecklistItem(
                                entry.value,
                                indexInEdited,
                                status == 'done',
                                showHotelRadio: false,
                                canEdit: canEdit,
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== Hotels Card =====
                    _buildSectionCard(
                      title: 'โรงแรม'.tr,
                      icon: Icons.hotel_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _hotelNotice(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '${'items'.tr}: ${hotels.length}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (status != 'done' && canEdit)
                                TextButton.icon(
                                  onPressed: () =>
                                      addChecklistItem(type: 'hotel'),
                                  icon: const Icon(Icons.add_business_rounded),
                                  label: const Text('เพิ่มโรงแรม'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (hotels.isEmpty)
                            _emptyBox('ไม่มีรายการโรงแรม'.tr)
                          else
                            ...hotels.asMap().entries.map((entry) {
                              final indexInEdited = editedChecklist.indexOf(
                                entry.value,
                              );
                              return _buildChecklistItem(
                                entry.value,
                                indexInEdited,
                                status == 'done',
                                showHotelRadio: true,
                                canEdit: canEdit,
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: saveTask,
              backgroundColor: statusInfo['color'],
              foregroundColor: Colors.white,
              icon: const Icon(Icons.save_rounded),
              label: Text(
                'save'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _hotelNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFB45309)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'เลือกโรงแรมหลักได้ 1 แห่ง (ถ้าเลือกไว้ ระบบจะเก็บเฉพาะโรงแรมที่เลือกเมื่อกดบันทึก)',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
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

  Widget _buildPriorityDropdown(bool canEdit) {
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
        fillColor: (isDone || !canEdit) ? Colors.grey[100] : Colors.white,
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
      onChanged: (isDone || !canEdit)
          ? null
          : (val) => setState(() => priority = val!),
    );
  }

  Widget _buildStatusDropdown(bool canEdit) {
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
        fillColor: (isDone || !canEdit) ? Colors.grey[100] : Colors.white,
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
      onChanged: (isDone || !canEdit)
          ? null
          : (value) => setState(() => status = value!),
    );
  }

  Widget _buildDateCard(
    String label,
    DateTime date,
    bool isStart, {
    required bool canEdit,
  }) {
    final isDone = status == 'done';
    final localDate = _asLocal(date);
    final isOverdue = !isDone && localDate.isBefore(DateTime.now()) && !isStart;

    return InkWell(
      onTap: (isDone || !canEdit) ? null : () => pickDate(context, isStart),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isDone || !canEdit) ? Colors.grey[100] : Colors.white,
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
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? Colors.red : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(localDate),
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

  /// แผน/โรงแรมแต่ละแถว
  Widget _buildChecklistItem(
    Map<String, dynamic> item,
    int index,
    bool taskIsDone, {
    required bool showHotelRadio,
    required bool canEdit,
  }) {
    final done = item['done'] == true;
    final expanded = item['expanded'] ?? true;

    final DateTime? start = _toDate(item['start_date']);
    final DateTime? end = _toDate(item['end_date']);
    final String time = _fmtTime(item['time']?.toString());
    final String duration = (item['duration'] ?? '').toString();
    final double? lat = _toDouble(item['lat']);
    final double? lng = _toDouble(item['lng']);
    final String price = (item['price'] ?? '').toString();
    final String notes = (item['notes'] ?? '').toString();
    final String mapsUrl = (item['mapsUrl'] ?? '').toString();
    final bool isHotel = (item['type'] == 'hotel');

    final String itemKey = _hotelKey(index, item);
    final bool locked = taskIsDone || !canEdit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: done && !isHotel ? Colors.green[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done && !isHotel ? Colors.green[200]! : Colors.grey[200]!,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: (isExpanded) {
            setState(() => item['expanded'] = isExpanded);
          },
          leading: isHotel
              ? (showHotelRadio
                    ? Radio<String>(
                        value: itemKey,
                        groupValue: _selectedHotelKey,
                        onChanged: locked
                            ? null
                            : (val) {
                                setState(() {
                                  _selectedHotelKey = val;
                                  // sync flag ให้ item ที่เลือก
                                  for (
                                    var i = 0;
                                    i < editedChecklist.length;
                                    i++
                                  ) {
                                    final it = editedChecklist[i];
                                    if (it['type'] == 'hotel') {
                                      final key = _hotelKey(i, it);
                                      it['selectedHotel'] = (key == val);
                                    }
                                  }
                                });
                              },
                      )
                    : const SizedBox())
              : Checkbox(
                  value: done,
                  onChanged: locked
                      ? null
                      : (val) {
                          setState(() {
                            item['done'] = val ?? false;
                            if (val == true) item['expanded'] = false;
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
            readOnly: locked || (isHotel ? false : done),
            initialValue: (item['title'] ?? '').toString(),
            style: TextStyle(
              color: (isHotel
                  ? Colors.black87
                  : done
                  ? Colors.grey[600]
                  : Colors.black87),
              decoration: (!isHotel && done)
                  ? TextDecoration.lineThrough
                  : null,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              hintText: 'Subtask name',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) => item['title'] = val,
          ),
          trailing: !locked
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => removeChecklistItem(index),
                  tooltip: 'deletesubtask'.tr,
                )
              : null,
          children: [
            // Description
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextFormField(
                readOnly: locked || (!isHotel && done),
                initialValue: (item['description'] ?? '').toString(),
                style: TextStyle(
                  color: (!isHotel && done) ? Colors.grey[600] : Colors.black87,
                ),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "subtaskdetails".tr,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: (!isHotel && done) || locked
                      ? Colors.grey[100]
                      : Colors.white,
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (val) => item['description'] = val,
              ),
            ),

            // Extra info chips: date/time/duration/price/notes
            if (start != null ||
                end != null ||
                time.isNotEmpty ||
                duration.isNotEmpty ||
                price.isNotEmpty ||
                notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (start != null || end != null)
                      _miniInfoChip(
                        icon: Icons.calendar_month_rounded,
                        label: (start != null && end != null && end != start)
                            ? '${_fmtDate(start)} - ${_fmtDate(end)}'
                            : _fmtDate(start ?? end),
                      ),
                    if (time.isNotEmpty)
                      _miniInfoChip(
                        icon: Icons.access_time_rounded,
                        label: time,
                      ),
                    if (duration.isNotEmpty)
                      _miniInfoChip(
                        icon: Icons.timelapse_rounded,
                        label: duration,
                      ),
                    if (price.isNotEmpty)
                      _miniInfoChip(
                        icon: Icons.attach_money_rounded,
                        label: price,
                      ),
                    if (notes.isNotEmpty)
                      _miniInfoChip(
                        icon: Icons.info_outline_rounded,
                        label: notes,
                        maxWidth: 220,
                      ),
                  ],
                ),
              ),

            // Map buttons & preview (view-only ก็ใช้ได้)
            if ((lat != null && lng != null) || mapsUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (lat != null && lng != null)
                      ElevatedButton.icon(
                        onPressed: () => _openExternalMap(
                          lat,
                          lng,
                          label: (item['title'] ?? '').toString(),
                        ),
                        icon: const Icon(Icons.map_rounded),
                        label: Text('Open in Maps'.tr),
                      ),
                    if (mapsUrl.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(mapsUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            _showErrorSnackbar('ไม่สามารถเปิดลิงก์แผนที่ได้');
                          }
                        },
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Google Maps'),
                      ),
                    if (lat != null && lng != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AiMapPage(
                                points: [
                                  {
                                    'title': (item['title'] ?? '').toString(),
                                    'lat': lat,
                                    'lng': lng,
                                  },
                                ],
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.fullscreen),
                        label: Text('Preview'.tr),
                      ),
                  ],
                ),
              ),
            if (lat != null && lng != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: MapPreview(lat: lat, lng: lng),
              ),
          ],
        ),
      ),
    );
  }

  // -------- Shared small widgets --------

  Widget _miniInfoChip({
    required IconData icon,
    required String label,
    double? maxWidth,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF334155)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
        ),
      ],
    );

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  // -------- Header --------
  Widget _buildStatusHeaderBar(Map<String, dynamic> statusInfo) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
          ),
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
