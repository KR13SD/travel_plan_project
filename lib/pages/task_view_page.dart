import 'package:ai_task_project_manager/pages/task_detail_page.dart';
import 'package:ai_task_project_manager/widget/invite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/dashboard_controller.dart';
import '../models/task_model.dart';

class TaskViewPage extends StatefulWidget {
  final TaskModel task;
  const TaskViewPage({super.key, required this.task});

  @override
  State<TaskViewPage> createState() => _TaskViewPageState();
}

class _TaskViewPageState extends State<TaskViewPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final DashboardController controller = Get.find<DashboardController>();
  final dateFormat = DateFormat('dd MMM yyyy');

  // current task (จะอัปเดตหลังกลับจากหน้าแก้ไข)
  late TaskModel currentTask;

  // timezone-safe helper
  DateTime _asLocal(DateTime d) => d.isUtc ? d.toLocal() : d;

  // Priority options ให้ตรงกับระบบ
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
    currentTask = widget.task;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );
    _animationController.forward();
  }

  void _refreshTaskData() {
    final latestTask = controller.findTaskById(widget.task.id);
    if (latestTask != null) {
      setState(() {
        currentTask = latestTask;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _normalizePriority(String? priority) {
    if (priority == null) return 'Medium';
    if (priorityOptions.containsKey(priority)) return priority;
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

  Future<void> _navigateToEditPage() async {
    final result = await Get.to(TaskDetailPage(task: currentTask));
    if (result == true) {
      _refreshTaskData();
    }
  }

  // ===== helpers for map & format =====
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

  String _formatTime(dynamic time) {
    if (time == null) return '';
    try {
      final t = time.toString();
      if (t.contains(':')) {
        final parts = t.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final dt = DateTime(2024, 1, 1, hour, minute);
        return DateFormat('HH:mm').format(dt);
      }
      return t;
    } catch (_) {
      return time.toString();
    }
  }

  String _formatDateFlexible(dynamic v) {
    DateTime? d;
    if (v is DateTime) d = v;
    if (v is String) {
      d = DateTime.tryParse(v);
      if (d == null && v.contains('/')) {
        final p = v.split('/');
        if (p.length == 3) {
          final dd = int.tryParse(p[0]) ?? 1;
          final mm = int.tryParse(p[1]) ?? 1;
          final yy = int.tryParse(p[2]) ?? DateTime.now().year;
          d = DateTime(yy, mm, dd);
        }
      }
    }
    return dateFormat.format(_asLocal(d ?? DateTime.now()));
  }

  Color _priorityColor(String? p) {
    switch ((p ?? 'medium').toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = _normalizePriority(currentTask.priority);
    final statusInfo =
        statusOptions[currentTask.status] ?? statusOptions['todo']!;
    final priorityInfo =
        priorityOptions[priority] ?? priorityOptions['Medium']!;

    final user = FirebaseAuth.instance.currentUser;
    final bool isOwner = (user?.uid ?? '') == (currentTask.uid ?? '');

    // แยก checklist: hotels vs plans
    final List<Map<String, dynamic>> raw = List<Map<String, dynamic>>.from(
      currentTask.checklist,
    );
    final hotels = raw
        .where((m) => (m['type']?.toString() ?? '') == 'hotel')
        .toList();
    final plans = raw
        .where((m) => (m['type']?.toString() ?? '') != 'hotel')
        .toList();

    final completedCount = plans
        .where((item) => item['done'] == true || item['completed'] == true)
        .length;

    final isOverdue =
        currentTask.status != 'done' &&
        _asLocal(currentTask.endDate).isBefore(DateTime.now());

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
                      builder: (_) => InviteSheet(
                        taskId: currentTask.id,
                        // สามารถเพิ่ม isOwner: true ถ้าปรับ InviteSheet รองรับ
                      ),
                    );
                  },
                ),
              IconButton(
                onPressed: _navigateToEditPage,
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'edit'.tr,
                color: Colors.white,
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title / Overdue
                      _buildTaskTitleCard(currentTask, statusInfo, isOverdue),

                      const SizedBox(height: 20),

                      // Status & Priority
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              title: 'status'.tr,
                              icon: statusInfo['icon'],
                              color: statusInfo['color'],
                              content: statusInfo['label'],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoCard(
                              title: 'priority'.tr,
                              icon: priorityInfo['icon'],
                              color: priorityInfo['color'],
                              content: priorityInfo['label'],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Date range
                      _buildDateInfoCard(currentTask, isOverdue),

                      // Progress (เฉพาะ plans)
                      if (plans.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildProgressCard(plans, completedCount),
                      ],

                      const SizedBox(height: 20),

                      // ====== Plans Section ======
                      _buildSectionHeader(
                        icon: Icons.route_rounded,
                        color: Colors.blue,
                        title: 'แผน / กิจกรรม'.tr,
                        trailingCount: plans.length,
                      ),
                      const SizedBox(height: 12),
                      if (plans.isEmpty)
                        _buildEmptyBox('ไม่มีรายการแผน/กิจกรรม'.tr)
                      else
                        ...plans.asMap().entries.map(
                          (e) => _buildPlanItemView(e.value, e.key),
                        ),

                      const SizedBox(height: 20),

                      // ====== Hotels Section ======
                      _buildSectionHeader(
                        icon: Icons.hotel_rounded,
                        color: Colors.purple,
                        title: 'โรงแรม'.tr,
                        trailingCount: hotels.length,
                      ),
                      const SizedBox(height: 12),
                      if (hotels.isEmpty)
                        _buildEmptyBox('ไม่มีรายการโรงแรม'.tr)
                      else
                        ...hotels.asMap().entries.map(
                          (e) => _buildHotelItemView(e.value, e.key),
                        ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToEditPage,
        backgroundColor: statusInfo['color'],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: Text(
          'edit'.tr,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ===== UI Building Blocks =====
  Widget _buildTaskTitleCard(
    TaskModel task,
    Map<String, dynamic> statusInfo,
    bool isOverdue,
  ) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey[50]!],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusInfo['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    statusInfo['icon'],
                    size: 24,
                    color: statusInfo['color'],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      decoration: task.status == 'done'
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
            if (isOverdue) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red[700],
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'overdue'.tr,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    return Card(
      elevation: 3,
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInfoCard(TaskModel task, bool isOverdue) {
    final start = _asLocal(task.startDate);
    final end = _asLocal(task.endDate);
    final duration = end.difference(start).inDays;

    return Card(
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                    Icons.calendar_today,
                    size: 20,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'date'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateDisplay(
                    'startdate'.tr,
                    start,
                    Icons.play_arrow,
                    Colors.green,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward, color: Colors.grey[400]),
                ),
                Expanded(
                  child: _buildDateDisplay(
                    'duedate'.tr,
                    end,
                    Icons.flag,
                    isOverdue ? Colors.red : Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'duration'.trParams({'days': duration.toString()}),
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateDisplay(
    String label,
    DateTime date,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          dateFormat.format(_asLocal(date)),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(List<dynamic> plans, int completedCount) {
    final progress = plans.isEmpty ? 0.0 : completedCount / plans.length;

    return Card(
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    size: 20,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'progress'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: progress == 1.0 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : Colors.orange,
              ),
              minHeight: 8,
            ),
            const SizedBox(height: 12),
            Text(
              'subtask_progress'.trParams({
                'completed': completedCount.toString(),
                'total': plans.length.toString(),
              }),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    required int trailingCount,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$trailingCount ${'items'.tr}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyBox(String text) {
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

  // ===== Item views =====
  Widget _buildPlanItemView(Map<String, dynamic> item, int index) {
    final done = item['done'] ?? item['completed'] ?? false;
    final title = (item['title'] ?? '').toString();
    final description = (item['description'] ?? '').toString();
    final priority = (item['priority'] ?? 'medium').toString();
    final startDate = item['start_date'];
    final time = _formatTime(item['time']);
    final duration = (item['duration'] ?? '').toString();
    final double? lat = (item['lat'] is num)
        ? (item['lat'] as num).toDouble()
        : null;
    final double? lng = (item['lng'] is num)
        ? (item['lng'] as num).toDouble()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: done ? Colors.green[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? Colors.green[200]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // row 1: index + priority + done marker
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _priorityColor(priority).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priority.toString().toUpperCase(),
                  style: TextStyle(
                    color: _priorityColor(priority),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? Colors.green : Colors.transparent,
                  border: Border.all(
                    color: done ? Colors.green : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // title
          Text(
            title.isEmpty ? 'untitledsubtask'.tr : title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: done ? Colors.grey[600] : const Color(0xFF111827),
              decoration: done ? TextDecoration.lineThrough : null,
            ),
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                color: done ? Colors.grey[500] : const Color(0xFF374151),
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 10),

          // info chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (startDate != null)
                _infoChip(
                  icon: Icons.calendar_today_rounded,
                  label: _formatDateFlexible(startDate),
                  color: const Color(0xFF3B82F6),
                ),
              if (time.isNotEmpty || duration.isNotEmpty)
                _infoChip(
                  icon: Icons.schedule_rounded,
                  label: time.isNotEmpty && duration.isNotEmpty
                      ? '$time ($duration)'
                      : time.isNotEmpty
                          ? time
                          : duration,
                  color: const Color(0xFFF59E0B),
                ),
              if (lat != null && lng != null)
                _infoChip(
                  icon: Icons.place_rounded,
                  label: 'Location',
                  color: const Color(0xFFEF4444),
                  onTap: () => _openExternalMap(lat, lng, label: title),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHotelItemView(Map<String, dynamic> h, int index) {
    final title = (h['title'] ?? '').toString();
    final notes = (h['notes'] ?? '').toString();
    final price = (h['price'] ?? '').toString();
    final reserve = h['reserve'] == true;
    final mapsUrl = (h['mapsUrl'] ?? '').toString();
    final double? lat = (h['lat'] is num) ? (h['lat'] as num).toDouble() : null;
    final double? lng = (h['lng'] is num) ? (h['lng'] as num).toDouble() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header row
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.bed_rounded, color: Colors.purple, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.isEmpty ? 'Hotel' : title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (reserve)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.event_available_rounded,
                        size: 14,
                        color: Color(0xFFF59E0B),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'ควรจองล่วงหน้า',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          if (price.isNotEmpty)
            Row(
              children: [
                const Icon(
                  Icons.attach_money_rounded,
                  size: 16,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    price,
                    style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          if (price.isNotEmpty) const SizedBox(height: 6),

          if (notes.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF4B5563),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    notes,
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),

          if ((lat != null && lng != null) || mapsUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (lat != null && lng != null)
                  ElevatedButton.icon(
                    onPressed: () => _openExternalMap(lat, lng, label: title),
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
                        Get.showSnackbar(
                          GetSnackBar(
                            message: 'ไม่สามารถเปิดลิงก์แผนที่ได้',
                            duration: const Duration(seconds: 3),
                            backgroundColor: Colors.red.shade600,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Google Maps'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
              Icons.visibility_rounded,
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
                  'taskview'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                Text(
                  '${'status'.tr}: ${statusOptions[currentTask.status]?['label'] ?? '—'}',
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
