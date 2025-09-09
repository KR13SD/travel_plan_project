import 'package:ai_task_project_manager/pages/task_view_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/auth_controller.dart';
import '../../models/task_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  final AuthController authController = Get.find<AuthController>();

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));

    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final locale = Get.locale?.toString() ?? 'en_US';
    return DateFormat('dd MMM yyyy HH:mm', locale).format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final uid = authController.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("กรุณาเข้าสู่ระบบ")),
      );
    }

    final now = DateTime.now();
    final deadline = now.add(const Duration(days: 2));

    final stream = FirebaseFirestore.instance
        .collection('tasks')
        .where('uid', isEqualTo: uid)
        .where('endDate', isGreaterThanOrEqualTo: now)
        .where('endDate', isLessThanOrEqualTo: deadline)
        .orderBy('endDate')
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        // ✅ พื้นหลังไล่เฉด เหมือน DashboardPage
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF06B6D4), // cyan-500
              Color(0xFF0891B2), // cyan-600
              Color(0xFF0891B2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernHeader(
                title: "notifications".tr,
                subtitle: DateFormat('dd MMM yyyy',
                        Get.locale?.toString() ?? 'en_US')
                    .format(DateTime.now()),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'loading'.tr,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text("⚠️ Error: ${snapshot.error}"),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState("🎉 ไม่มีงานที่ใกล้ครบกำหนดใน 2 วัน");
                      }

                      final docs = snapshot.data!.docs;

                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: SlideTransition(
                              position: _slideAnim,
                              child: FadeTransition(
                                opacity: _fadeAnim,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: docs.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final doc = docs[index];
                                      final data = doc.data()
                                          as Map<String, dynamic>;

                                      final title =
                                          (data['title'] ?? 'ไม่มีชื่อ') as String;
                                      final startDate =
                                          (data['startDate'] as Timestamp)
                                              .toDate();
                                      final endDate =
                                          (data['endDate'] as Timestamp)
                                              .toDate();
                                      final status =
                                          (data['status'] ?? 'todo') as String;
                                      final priority =
                                          (data['priority'] ?? 'Medium')
                                              as String;
                                      final checklist =
                                          (data['checklist'] as List<dynamic>?)
                                                  ?.map((e) =>
                                                      Map<String, dynamic>.from(
                                                          e))
                                                  .toList() ??
                                              [];

                                      final now = DateTime.now();
                                      final isOverdue =
                                          endDate.isBefore(now);
                                      final daysLeft = isOverdue
                                          ? 0
                                          : endDate
                                                  .difference(now)
                                                  .inDays +
                                              1;

                                      final taskModel = TaskModel(
                                        id: doc.id,
                                        title: title,
                                        priority: priority,
                                        startDate: startDate,
                                        endDate: endDate,
                                        status: status,
                                        uid: data['uid'],
                                        checklist: checklist,
                                      );

                                      return _notificationCard(
                                        task: taskModel,
                                        isOverdue: isOverdue,
                                        daysLeft: daysLeft,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 24)),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header เหมือน Dashboard/TaskList/Analytics (แต่ไอคอนกระดิ่ง)
  Widget _buildModernHeader({
    required String title,
    String? subtitle,
  }) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
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
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationCard({
    required TaskModel task,
    required bool isOverdue,
    required int daysLeft,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Get.to(() => TaskViewPage(task: task)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, // พื้นขาวแบบการ์ดทั่วไป
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // แถบสีซ้าย (บอกสถานะใกล้ครบกำหนด)
            Container(
              width: 6,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isOverdue ? Colors.red.shade400 : Colors.orange.shade400,
                    isOverdue ? Colors.red.shade600 : Colors.orange.shade600,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),

            // เนื้อหา
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ชื่อ
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // วันที่ครบกำหนด
                  Row(
                    children: [
                      Icon(
                        Icons.flag_rounded,
                        size: 16,
                        color: isOverdue ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(task.endDate),
                        style: TextStyle(
                          fontSize: 13,
                          color: isOverdue ? Colors.red : Colors.orange[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // badge ด้านขวา
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isOverdue ? Colors.red[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOverdue ? Colors.redAccent : Colors.orange,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.schedule_rounded,
                    size: 14,
                    color: isOverdue ? Colors.redAccent : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOverdue ? "เลยกำหนด" : "ภายใน $daysLeft วัน",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isOverdue ? Colors.redAccent : Colors.orange[800],
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.notifications_off_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
