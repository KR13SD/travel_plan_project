// lib/pages/task_view_page.dart
import 'dart:io';

import 'package:ai_task_project_manager/pages/task_detail_page.dart';
import 'package:ai_task_project_manager/pages/map_preview.dart';
import 'package:ai_task_project_manager/widget/invite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../controllers/dashboard_controller.dart';
import '../models/task_model.dart';
import 'package:url_launcher/url_launcher.dart';

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

  late TaskModel currentTask;

  // timezone-safe helper
  DateTime _asLocal(DateTime d) => d.isUtc ? d.toLocal() : d;

  // ===== Helpers แก้พิกัด (ดึง Logic จาก AiImportPage) =====
  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _openGoogleMap(double lat, double lng, {String? label}) async {
    final q = Uri.encodeComponent(label ?? 'location'.tr);
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

  Future<void> _navigateToEditPage({required bool canEdit}) async {
    if (!canEdit) {
      Get.snackbar(
        'permission'.tr,
        'noPermission'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final result = await Get.to(TaskDetailPage(task: currentTask));
    if (result == true) {
      _refreshTaskData();
    }
  }

  String _formatTime(dynamic time) {
    if (time == null) return '';

    try {
      if (time is DateTime) {
        return DateFormat('HH:mm').format(time);
      }

      final t = time.toString();

      final dt = DateTime.tryParse(t);
      if (dt != null) {
        return DateFormat('HH:mm').format(dt);
      }

      if (t.contains(':')) {
        final parts = t.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        return DateFormat('HH:mm').format(DateTime(2024, 1, 1, hour, minute));
      }

      return '';
    } catch (_) {
      return '';
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

  String _stripMapLinks(String text) {
    if (text.trim().isEmpty) return text;
    final lines = text.split(RegExp(r'\r?\n'));
    final regexUrl = RegExp(
      r'(https?:\/\/)?(www\.)?(google\.[^\/]+\/maps|maps\.app\.goo\.gl|goo\.gl\/maps|shorturl\.at|bit\.ly|tinyurl\.com)\/',
      caseSensitive: false,
    );

    final kept = <String>[];
    for (final raw in lines) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      final lower = s.toLowerCase();
      if (lower.startsWith('แผนที่:') || lower.startsWith('map:')) continue;
      if (regexUrl.hasMatch(s)) continue;
      kept.add(raw);
    }
    return kept.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final statusInfo =
        statusOptions[currentTask.status] ?? statusOptions['todo']!;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isOwner = currentTask.uid == uid;
    final bool isEditor = currentTask.editorUids.contains(uid);
    final bool isViewer = currentTask.viewerUids.contains(uid);
    final bool canEdit = isOwner || isEditor;
    final bool canInvite = isOwner;

    final List<Map<String, dynamic>> raw = List<Map<String, dynamic>>.from(
      currentTask.checklist,
    );
    final hotels = raw
        .where((m) => (m['type']?.toString() ?? '') == 'hotel')
        .toList();
    final plans = raw
        .where((m) => (m['type']?.toString() ?? '') != 'hotel')
        .toList();

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
            title: _buildStatusHeaderBar(
              statusInfo,
              roleBadge: isOwner
                  ? 'owner'.tr
                  : (isEditor ? 'editor'.tr : (isViewer ? 'viewer'.tr : '')),
            ),
            actions: [
              if (canInvite)
                IconButton(
                  tooltip: 'invite'.tr,
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
                      builder: (_) => InviteSheet(taskId: currentTask.id),
                    );
                  },
                ),
              if (canEdit)
                IconButton(
                  onPressed: () => _navigateToEditPage(canEdit: canEdit),
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
                      _buildTaskTitleCard(currentTask, statusInfo, isOverdue),
                      const SizedBox(height: 16),
                      _buildDateInfoCard(currentTask, isOverdue),
                      const SizedBox(height: 20),

                      // ===== Plans Section =====
                      _buildSectionHeader(
                        icon: Icons.route_rounded,
                        color: Colors.blue,
                        title: 'tripPlan'.tr,
                        trailingCount: plans.length,
                      ),
                      const SizedBox(height: 12),
                      if (plans.isEmpty)
                        _buildEmptyBox('noPlans'.tr)
                      else
                        ...plans.asMap().entries.map(
                          (e) => _buildPlanItemView(e.value, e.key),
                        ),

                      const SizedBox(height: 20),

                      // ===== Hotels Section =====
                      _buildSectionHeader(
                        icon: Icons.hotel_rounded,
                        color: Colors.purple,
                        title: 'hotels'.tr,
                        trailingCount: hotels.length,
                      ),
                      const SizedBox(height: 12),
                      if (hotels.isEmpty)
                        _buildEmptyBox('noHotels'.tr)
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
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToEditPage(canEdit: canEdit),
              backgroundColor: statusInfo['color'],
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_rounded),
              label: Text(
                'edit'.tr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  // ===== UI blocks =====
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

  Widget _buildDateInfoCard(TaskModel task, bool isOverdue) {
    final start = _asLocal(task.startDate);
    final end = _asLocal(task.endDate);

    return Card(
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
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
    debugPrint("ITEM $index FULL DATA -> $item");
    final done = item['done'] == true || item['completed'] == true;
    final title = (item['title'] ?? '').toString();
    final description = _stripMapLinks((item['description'] ?? '').toString());
    final startDate = item['start_date'];

    final hasTimeField =
        item['time'] != null ||
        item['start_time'] != null ||
        item['startTime'] != null;

    final rawTime =
        item['time'] ?? item['start_time'] ?? item['startTime'] ?? '';
    debugPrint("ITEM $index -> ${item['start_date']}");

    final time = _formatTime(rawTime);
    final duration = (item['duration'] ?? '').toString();
    final List<String> images = [
      if (item['image'] != null && item['image'].toString().startsWith('http'))
        item['image'].toString(),
      ...(item['images'] as List? ?? [])
          .map((e) => e.toString())
          .where((u) => u.startsWith('http')),
    ];

    // ใช้ Logic แก้พิกัดจาก AiImportPage
    final double? lat = _parseCoordinate(item['lat']);
    final double? lng = _parseCoordinate(item['lng']);

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
              const Spacer(),
              if (done) _buildDoneBadge(),
            ],
          ),

          if (images.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildImageGallery(images),
          ],

          const SizedBox(height: 10),

          Text(
            title.isEmpty ? 'untitledsubtask'.tr : title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
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

              if (hasTimeField || duration.isNotEmpty)
                _infoChip(
                  icon: Icons.schedule_rounded,
                  label: time.isNotEmpty && duration.isNotEmpty
                      ? '$time ($duration)'
                      : (time.isNotEmpty ? time : duration),
                  color: const Color(0xFFF59E0B),
                ),
            ],
          ),

          // ฝังแผนที่ Interactive แบบ AiImportPage
          if (lat != null && lng != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () => _openGoogleMap(lat, lng, label: title),
                child: Stack(
                  children: [
                    MapPreview(
                      key: ValueKey('plan_map_${currentTask.id}_${index}_$lat'),
                      lat: lat,
                      lng: lng,
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'openMap'.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHotelItemView(Map<String, dynamic> h, int index) {
    final title = (h['title'] ?? '').toString();
    final notes = _stripMapLinks((h['notes'] ?? '').toString());
    final price = (h['price'] ?? '').toString();
    final reserve = h['reserve'] == true;
    final List<String> images = [
      if (h['image'] != null && h['image'].toString().startsWith('http'))
        h['image'].toString(),
      ...(h['images'] as List? ?? [])
          .map((e) => e.toString())
          .where((u) => u.startsWith('http')),
    ];

    // ใช้ Logic แก้พิกัดจาก AiImportPage
    final double? lat = _parseCoordinate(h['lat']);
    final double? lng = _parseCoordinate(h['lng']);

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
                  title.isEmpty ? 'hotel'.tr : title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (reserve) _buildReserveBadge(),
            ],
          ),

          if (images.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildImageGallery(images),
          ],

          const SizedBox(height: 8),

          if (price.isNotEmpty)
            _infoChip(
              icon: Icons.attach_money_rounded,
              label: price,
              color: const Color(0xFF059669),
            ),

          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              notes,
              style: const TextStyle(color: Color(0xFF374151), height: 1.5),
            ),
          ],

          // ฝังแผนที่ Interactive สำหรับโรงแรม
          if (lat != null && lng != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () => _openGoogleMap(lat, lng, label: title),
                child: Stack(
                  children: [
                    MapPreview(
                      key: ValueKey(
                        'hotel_map_${currentTask.id}_${index}_$lat',
                      ),
                      lat: lat,
                      lng: lng,
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.map_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'openMap'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== Tiny UI Badges =====
  Widget _buildDoneBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.green),
          SizedBox(width: 6),
          Text(
            'done'.tr,
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReserveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 14,
            color: Color(0xFFF59E0B),
          ),
          SizedBox(width: 4),
          Text(
            'shouldBookInAdvance'.tr,
            style: TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
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

  Widget _buildStatusHeaderBar(
    Map<String, dynamic> statusInfo, {
    String roleBadge = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'tripPlan'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    if (roleBadge.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          roleBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  '${'status'.tr}: ${statusOptions[currentTask.status]?['label'] ?? '—'}',
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

  Widget _buildImageGallery(List<String> images) {
    if (images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                loadingBuilder: (c, w, p) => p == null
                    ? w
                    : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.broken_image_rounded,
                    size: 36,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
