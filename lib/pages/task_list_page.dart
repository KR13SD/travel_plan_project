import 'package:ai_task_project_manager/pages/task_view_page.dart';
import 'package:ai_task_project_manager/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../controllers/dashboard_controller.dart';
import '../../models/task_model.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage>
    with TickerProviderStateMixin {
  final DashboardController controller = Get.find<DashboardController>();
  final formattedDate = ''.obs;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // 🎨 Primary theme green
  static const Color kPrimary1 = Color(0xFF10B981); // emerald-500
  static const Color kPrimary2 = Color(0xFF059669); // emerald-600

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initDateFormatting();

    final service = Get.find<LocalizationService>();
    ever(service.currentLocale, (_) => _initDateFormatting());
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
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
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

  Future<void> _initDateFormatting() async {
    final locale = Get.locale?.toString() ?? 'th_TH';
    await initializeDateFormatting(locale, null);
    _updateFormattedDate(DateTime.now());
  }

  void _updateFormattedDate(DateTime date) {
    final locale = Get.locale?.toString() ?? 'th_TH';
    final formatter = DateFormat('dd MMM yyyy', locale);
    formattedDate.value = formatter.format(date);
  }

  final List<Map<String, Object>> statusOptions = [
    {
      'key': 'all',
      'label': 'all'.tr,
      'icon': Icons.dashboard_rounded,
      // ✅ เปลี่ยนเป็นธีมเขียว
      'gradient': [kPrimary1, kPrimary2],
    },
    {
      'key': 'todo',
      'label': 'pending'.tr,
      'icon': Icons.schedule_rounded,
      'gradient': [Color(0xFF74b9ff), Color(0xFF0984e3)],
    },
    {
      'key': 'in_progress',
      'label': 'inprogress'.tr,
      'icon': Icons.trending_up_rounded,
      'gradient': [Color(0xFFfdcb6e), Color(0xFFe17055)],
    },
    {
      'key': 'done',
      'label': 'completed'.tr,
      'icon': Icons.check_circle_rounded,
      'gradient': [Color(0xFF00b894), Color(0xFF00cec9)],
    },
    {
      'key': 'overdue',
      'label': 'overdue'.tr,
      'icon': Icons.warning_rounded,
      'gradient': [Color(0xFFe17055), Color(0xFFd63031)],
    },
  ];

  String selectedStatus = 'all';

  List<TaskModel> filteredTasks(String status) {
    final allTasks = controller.allTasks;

    switch (status) {
      case 'todo':
        return allTasks.where((t) => t.status.toLowerCase() == 'todo').toList();
      case 'in_progress':
        return allTasks
            .where((t) => t.status.toLowerCase() == 'in_progress')
            .toList();
      case 'done':
        return allTasks.where((t) => t.status.toLowerCase() == 'done').toList();
      case 'overdue':
        final now = DateTime.now();
        return allTasks
            .where(
              (t) =>
                  t.status.toLowerCase() != 'done' && t.endDate.isBefore(now),
            )
            .toList();
      case 'all':
      default:
        return allTasks;
    }
  }

  List<TaskModel> _sortTasksByStatus(List<TaskModel> tasks) {
    final now = DateTime.now();
    const priority = {'in_progress': 1, 'todo': 2, 'overdue': 3, 'done': 4};

    return tasks..sort((a, b) {
      String statusA = a.status.toLowerCase();
      String statusB = b.status.toLowerCase();

      if (statusA != 'done' && a.endDate.isBefore(now)) statusA = 'overdue';
      if (statusB != 'done' && b.endDate.isBefore(now)) statusB = 'overdue';

      return (priority[statusA] ?? 99).compareTo(priority[statusB] ?? 99);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // ✅ พื้นหลังหลักเป็น gradient เขียว
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kPrimary1, kPrimary2, kPrimary2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
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
                  child: CustomScrollView(
                    slivers: [_buildFilterChips(), _buildTasksList()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildModernFAB(),
    );
  }

  Widget _buildModernAppBar() {
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
                Icons.task_alt_rounded,
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
                    'tasklist'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'subTitleTaskList'.tr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
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

  Widget _buildFilterChips() {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.all(20),
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: statusOptions.length,
            itemBuilder: (context, index) {
              final option = statusOptions[index];
              final String key = option['key'] as String;
              final String label = option['label'] as String;
              final IconData icon = option['icon'] as IconData;
              final List<Color> gradient = option['gradient'] as List<Color>;
              final isSelected = selectedStatus == key;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() => selectedStatus = key);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(colors: gradient)
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? gradient.first.withOpacity(0.4)
                              : Colors.black.withOpacity(0.1),
                          blurRadius: isSelected ? 12 : 4,
                          offset: Offset(0, isSelected ? 6 : 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: isSelected ? Colors.white : gradient.first,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : gradient.first,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    // ✅ โหลดด้วยกราเดียนต์เขียว
                    gradient: const LinearGradient(
                      colors: [kPrimary1, kPrimary2],
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
          ),
        );
      }

      final tasks = _sortTasksByStatus(filteredTasks(selectedStatus));

      if (tasks.isEmpty) {
        return SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.withOpacity(0.1),
                        Colors.grey.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'notasksinthislist'.tr,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'startcreatetask'.tr,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final task = tasks[index];
          return AnimatedContainer(
            duration: Duration(milliseconds: 300 + (index * 100)),
            margin: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: index == tasks.length - 1 ? 120 : 8,
            ),
            child: _buildGlassmorphismTaskCard(task, index),
          );
        }, childCount: tasks.length),
      );
    });
  }

  Widget _buildGlassmorphismTaskCard(TaskModel task, int index) {
    final isDone = task.status.toLowerCase() == 'done';
    final isOverdue = !isDone && task.endDate.isBefore(DateTime.now());

    List<Color> gradientColors;
    IconData statusIcon;

    switch (task.status.toLowerCase()) {
      case 'todo':
        gradientColors = [const Color(0xFF74b9ff), const Color(0xFF0984e3)];
        statusIcon = Icons.schedule_rounded;
        break;
      case 'in_progress':
        gradientColors = [const Color(0xFFfdcb6e), const Color(0xFFe17055)];
        statusIcon = Icons.trending_up_rounded;
        break;
      case 'done':
        gradientColors = [const Color(0xFF00b894), const Color(0xFF00cec9)];
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        gradientColors = [const Color(0xFF74b9ff), const Color(0xFF0984e3)];
        statusIcon = Icons.help_outline_rounded;
    }

    if (isOverdue) {
      gradientColors = [const Color(0xFFe17055), const Color(0xFFd63031)];
      statusIcon = Icons.warning_rounded;
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.8),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Get.to(() => TaskViewPage(task: task)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardHeader(
                          task,
                          gradientColors,
                          statusIcon,
                          isDone,
                        ),
                        const SizedBox(height: 16),
                        _buildDateSection(task, isOverdue),
                        if (isOverdue) ...[
                          const SizedBox(height: 12),
                          _buildOverdueWarning(),
                        ],
                        const SizedBox(height: 16),
                        _buildActionButtons(task, isDone, gradientColors),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardHeader(
    TaskModel task,
    List<Color> gradientColors,
    IconData statusIcon,
    bool isDone,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(statusIcon, size: 24, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusLabel(task.status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateSection(TaskModel task, bool isOverdue) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDateInfo(
              'startdate'.tr,
              task.startDate,
              Icons.play_circle_filled_rounded,
              const Color(0xFF00b894),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: _buildDateInfo(
              'duedate'.tr,
              task.endDate,
              Icons.flag_rounded,
              // ✅ ถ้าไม่ overdue ใช้เขียวหลัก
              isOverdue ? const Color(0xFFe17055) : kPrimary2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE5E5), Color(0xFFFFCCCC)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFe17055).withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_rounded, color: Color(0xFFe17055), size: 20),
          SizedBox(width: 8),
          Text(
            'out of date',
            style: TextStyle(
              color: Color(0xFFe17055),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    TaskModel task,
    bool isDone,
    List<Color> gradientColors,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!isDone) ...[
          _buildGradientActionButton(
            icon: Icons.play_arrow_rounded,
            gradient: const [Color(0xFFfdcb6e), Color(0xFFe17055)],
            onPressed: () => _confirmUpdateStatus(task),
            tooltip: 'starttask'.tr,
          ),
          const SizedBox(width: 10),
          _buildGradientActionButton(
            icon: Icons.check_rounded,
            gradient: const [Color(0xFF00b894), Color(0xFF00cec9)],
            onPressed: () => _confirmMarkDone(task),
            tooltip: 'endtask'.tr,
          ),
          const SizedBox(width: 10),
        ],
        _buildGradientActionButton(
          icon: Icons.delete_outline_rounded,
          gradient: const [Color(0xFFe17055), Color(0xFFd63031)],
          onPressed: () => _confirmDelete(task),
          tooltip: 'deletetask'.tr,
        ),
      ],
    );
  }

  Widget _buildGradientActionButton({
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateInfo(
    String label,
    DateTime date,
    IconData icon,
    Color color,
  ) {
    final locale = Get.locale?.toString() ?? 'en_US';
    final formatter = DateFormat('dd MMM yyyy', locale);

    return Row(
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                formatter.format(date),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2D3748),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernFAB() {
    return Container(
      decoration: BoxDecoration(
        // ✅ FAB ใช้ธีมเขียว
        gradient: const LinearGradient(colors: [kPrimary1, kPrimary2]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimary1.withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => Get.toNamed('/addtasks'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'addtask'.tr,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'todo':
        return 'pending'.tr;
      case 'in_progress':
        return 'inprogress'.tr;
      case 'done':
        return 'completed'.tr;
      default:
        return status;
    }
  }

  void _confirmMarkDone(TaskModel task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [kPrimary1, kPrimary2]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.task_alt, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              'confirmchangestatus'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text('dialogconfirmstatus'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr, style: TextStyle(color: Colors.grey[600])),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [kPrimary1, kPrimary2]),
              borderRadius: BorderRadius.circular(10)
            ),
            child: TextButton(
              onPressed: () {
                controller.updateTaskStatus(task.id, 'done');
                Navigator.pop(context);
              },
              child: Text('confirm'.tr, style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(TaskModel task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFe17055), Color(0xFFd63031)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              'comfirmdelete'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text('dialogconfirmdelete'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr, style: TextStyle(color: Colors.grey[600])),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFe17055), Color(0xFFd63031)],
              ),
              borderRadius: BorderRadius.circular(10)
            ),
            child: TextButton(
              onPressed: () {
                controller.deleteTask(task.id);
                Navigator.pop(context);
              },
              child: Text(
                'confirm'.tr,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmUpdateStatus(TaskModel task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFfdcb6e), Color(0xFFe17055)],
                ),
                borderRadius: BorderRadius.circular(10)
              ),
              child: const Icon(Icons.work, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              'starttask'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text('confirmchangestatus'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr, style: TextStyle(color: Colors.grey[600])),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFfdcb6e), Color(0xFFe17055)],
              ),
              borderRadius: BorderRadius.circular(10)
            ),
            child: TextButton(
              onPressed: () {
                controller.updateTaskStatus(task.id, 'in_progress');
                Navigator.pop(context);
              },
              child: Text(
                'confirm'.tr,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
