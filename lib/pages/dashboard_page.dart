import 'package:ai_task_project_manager/controllers/ai_import_controller.dart';
import 'package:ai_task_project_manager/pages/ai_import_page.dart';
import 'package:ai_task_project_manager/pages/task_detail_page.dart';
import 'package:ai_task_project_manager/pages/task_view_page.dart';
import 'package:ai_task_project_manager/widget/ai_generating_overlay.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/dashboard_controller.dart';
import '../../models/task_model.dart';

// ✅ เปลี่ยนสีหลักของหน้านี้ให้เข้ากับธีมใหม่
const Color primaryColor = Color(0xFF06B6D4); // cyan-500

class DashboardPage extends StatefulWidget {
  DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  final DashboardController controller = Get.find<DashboardController>();
  final AiImportController aiCtrl = Get.find<AiImportController>();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String get _todayStr {
    final locale = Get.locale?.toString() ?? 'en_US';
    return DateFormat('dd MMM yyyy', locale).format(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ฟังก์ชันสำหรับกำหนดสีตาม Priority
  Map<String, dynamic> _getPriorityColors(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return {
          'gradient': [Colors.red.shade400, Colors.red.shade600],
          'bg': Colors.red.shade50,
          'fg': Colors.red.shade700,
          'shadow': Colors.red.shade200,
          'icon': Icons.priority_high,
        };
      case 'medium':
        return {
          'gradient': [Colors.orange.shade400, Colors.orange.shade600],
          'bg': Colors.orange.shade50,
          'fg': Colors.orange.shade700,
          'shadow': Colors.orange.shade200,
          'icon': Icons.remove,
        };
      case 'low':
        return {
          'gradient': [Colors.green.shade400, Colors.green.shade600],
          'bg': Colors.green.shade50,
          'fg': Colors.green.shade700,
          'shadow': Colors.green.shade200,
          'icon': Icons.keyboard_arrow_down,
        };
      default:
        return {
          'gradient': [Colors.grey.shade400, Colors.grey.shade600],
          'bg': Colors.grey.shade100,
          'fg': Colors.grey.shade700,
          'shadow': Colors.grey.shade200,
          'icon': Icons.horizontal_rule,
        };
    }
  }

  List<TaskModel> _sortTasksByPriority(List<TaskModel> tasks) {
    final priorityOrder = {"high": 1, "medium": 2, "low": 3};

    tasks.sort((a, b) {
      final aPriority = priorityOrder[a.priority.toLowerCase()] ?? 4;
      final bPriority = priorityOrder[b.priority.toLowerCase()] ?? 4;
      return aPriority.compareTo(bPriority);
    });

    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            // ✅ พื้นหลังธีมใหม่
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
                  _buildModernAppBar(
                    title: 'dashboard'.tr,
                    subtitle: _todayStr,
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
                      child: Obx(() {
                        if (controller.isGenerating.value) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    // ✅ กล่องโหลดใช้กราเดียนต์ธีมใหม่
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF06B6D4),
                                        Color(0xFF0891B2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'loading'.tr,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                        _buildStatsCards(),
                                        const SizedBox(height: 32),
                                        _buildTaskListSection(
                                          context: context,
                                          title: "todaytasks".tr,
                                          tasks: controller.tasksToday,
                                          emptyMessage: "notasksfortoday".tr,
                                          icon: Icons.today,
                                          gradientColors: [
                                            Colors.blue.shade400,
                                            Colors.blue.shade600,
                                          ],
                                        ),
                                        const SizedBox(height: 28),
                                        _buildTaskListSection(
                                          context: context,
                                          title: "taskincoming(3days)".tr,
                                          tasks: controller.tasksUpcoming,
                                          emptyMessage: "noupcomingtasks".tr,
                                          icon: Icons.upcoming,
                                          gradientColors: [
                                            Colors.purple.shade400,
                                            Colors.purple.shade600,
                                          ],
                                        ),
                                        const SizedBox(height: 28),
                                        _buildTaskListSection(
                                          context: context,
                                          title: "taskoverdue".tr,
                                          tasks: controller.tasksOverdue,
                                          emptyMessage: "nooverduetasks".tr,
                                          icon: Icons.schedule,
                                          gradientColors: [
                                            Colors.red.shade400,
                                            Colors.red.shade600,
                                          ],
                                        ),
                                        const SizedBox(height: 100),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AiGeneratingOverlay(),
          ),
        ],
      ),
      floatingActionButton: Obx(() {
        final aiCtrl = Get.find<AiImportController>();

        return Padding(
          padding: EdgeInsets.only(
            bottom: aiCtrl.isGenerating.value || aiCtrl.hasResultReady.value
                ? 80 // ⬆️ ดัน FAB ขึ้น เมื่อมี AI process
                : 0, // ⬇️ ปกติ
          ),
          child: _buildFloatingActionButton(),
        );
      }),
    );
  }

  /// Modern AppBar สไตล์เดียวกับ TaskListPage (มีแอนิเมชัน)
  Widget _buildModernAppBar({required String title, String? subtitle}) {
    return FadeTransition(
      opacity: _fadeAnimation,
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
                Icons.dashboard_rounded,
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

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: "Today",
            count: controller.tasksToday.length,
            icon: Icons.today,
            colors: [Colors.blue.shade400, Colors.blue.shade600],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: "Upcoming",
            count: controller.tasksUpcoming.length,
            icon: Icons.upcoming,
            colors: [Colors.purple.shade400, Colors.purple.shade600],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: "Overdue",
            count: controller.tasksOverdue.length,
            icon: Icons.schedule,
            colors: [Colors.red.shade400, Colors.red.shade600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        // ✅ FAB เปลี่ยนเป็นกราเดียนต์ธีมใหม่
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: 'importAI',
        backgroundColor: Colors.transparent,
        elevation: 0,
        onPressed: () => Get.toNamed('/ai-import'),
        icon: const Icon(Icons.smart_toy_outlined, color: Colors.white),
        label: const Text(
          'AI Import',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTaskListSection({
    required BuildContext context,
    required String title,
    required List<TaskModel> tasks,
    required String emptyMessage,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    final sortedTasks = _sortTasksByPriority(List.from(tasks));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tasks.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        tasks.isEmpty
            ? _buildEmptyState(emptyMessage)
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedTasks.length,
                itemBuilder: (context, index) {
                  final task = sortedTasks[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _taskCard(task),
                  );
                },
              ),
      ],
    );
  }

  Widget _taskCard(TaskModel task) {
    final colors = _getPriorityColors(task.priority);
    final gradientColors = colors['gradient'] as List<Color>;
    final shadowColor = colors['shadow'] as Color;
    final priorityIcon = colors['icon'] as IconData;
    final locale = Get.locale?.languageCode ?? 'en';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Get.to(() => TaskViewPage(task: task), arguments: task.id);
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${DateFormat('d MMM', locale).format(task.startDate)} - '
                                '${DateFormat('d MMM yyyy', locale).format(task.endDate)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildAdvancedPriorityChip(
                      task.priority,
                      priorityIcon,
                      gradientColors,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ในหน้า Dashboard หรือ Home
  Widget _buildAiStatusOverlay() {
    // ดึง Controller มา (ใช้ find เพราะถูกสร้างไปแล้วในหน้า AI Import)
    // ถ้ากลัว Error กรณีเครื่องยังไม่เคยเข้าหน้า AI Import ให้ใช้ Get.put แทน
    final AiImportController aiCtrl = Get.find<AiImportController>();

    return Obx(() {
      // ถ้าไม่ได้กำลังโหลด และ ไม่มีข้อมูลค้างอยู่ ไม่ต้องแสดงอะไร
      if (!aiCtrl.isGenerating.value && aiCtrl.previewTasks.isEmpty) {
        return const SizedBox.shrink();
      }

      return GestureDetector(
        onTap: () => Get.to(() => const AiImportPage()), // กดแล้วกลับไปหน้า AI
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: aiCtrl.isGenerating.value
                ? Colors.blue.shade50
                : Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: aiCtrl.isGenerating.value
                  ? Colors.blue.shade200
                  : Colors.green.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ไอคอนเปลี่ยนตามสถานะ
              aiCtrl.isGenerating.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 12),

              // ข้อความบอกสถานะ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      aiCtrl.isGenerating.value
                          ? "AI กำลังสร้างแผนงาน..."
                          : "AI สร้างแผนงานเสร็จแล้ว!",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: aiCtrl.isGenerating.value
                            ? Colors.blue.shade900
                            : Colors.green.shade900,
                      ),
                    ),
                    Text(
                      aiCtrl.isGenerating.value
                          ? "คุณสามารถทำงานอื่นรอได้"
                          : "แตะเพื่อดูและบันทึกลงโปรเจกต์",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAdvancedPriorityChip(
    String priority,
    IconData icon,
    List<Color> colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            priority.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
