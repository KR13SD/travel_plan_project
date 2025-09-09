import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../controllers/dashboard_controller.dart';
import '../../models/task_model.dart';

class AnalyticsPage extends StatefulWidget {
  AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with TickerProviderStateMixin {
  final DashboardController controller = Get.find<DashboardController>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String selectedPeriod = 'thisWeek';

  // 🎨 Primary theme (Red)
  static const Color kPrimary1 = Color(0xFFEF4444); // red-500
  static const Color kPrimary2 = Color(0xFFDC2626); // red-600

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // คำนวณข้อมูลสำหรับ analytics
  Map<String, dynamic> _calculateAnalytics(List<TaskModel> tasks) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    int todo = 0, inProgress = 0, done = 0, overdue = 0;

    int todayTasks = 0, weekTasks = 0, monthTasks = 0;
    int todayCompleted = 0, weekCompleted = 0, monthCompleted = 0;

    // ✅ ใช้ list สำหรับ “จำนวนเสร็จในแต่ละวัน (ดูที่ completedAt)”
    List<int> dailyCompletions = List.filled(7, 0);

    // ✅ ตัวแปรสำหรับ on-time แบบใหม่
    int completedWithKnownTime = 0; // done && completedAt != null
    int completedOnTime = 0; // done && completedAt <= endDate

    for (var task in tasks) {
      final status = task.status.toLowerCase();
      final isCompleted = status == 'done';

      switch (status) {
        case 'todo':
          todo++;
          break;
        case 'in_progress':
          inProgress++;
          break;
        case 'done':
          done++;
          break;
      }

      // overdue (งานยังไม่เสร็จ แล้วเลยกำหนด)
      if (!isCompleted && task.endDate.isBefore(now)) {
        overdue++;
      }

      // ===== Time-based analytics (การนับ “สร้าง/เริ่ม” งานเดิมของคุณ) =====
      final createdDate = task.startDate;
      if (createdDate.isAfter(now.subtract(const Duration(days: 1))))
        todayTasks++;
      if (createdDate.isAfter(startOfWeek)) weekTasks++;
      if (createdDate.isAfter(startOfMonth)) monthTasks++;

      // ===== ใช้ completedAt สำหรับสถิติการเสร็จ =====
      final cAt = task.completedAt;
      if (isCompleted && cAt != null) {
        if (cAt.isAfter(now.subtract(const Duration(days: 1))))
          todayCompleted++;
        if (cAt.isAfter(startOfWeek)) weekCompleted++;
        if (cAt.isAfter(startOfMonth)) monthCompleted++;

        // กราฟ 7 วันล่าสุด
        for (int i = 0; i < 7; i++) {
          final day = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: 6 - i));
          if (cAt.year == day.year &&
              cAt.month == day.month &&
              cAt.day == day.day) {
            dailyCompletions[i]++;
          }
        }

        // ✅ on-time ใหม่
        completedWithKnownTime++;
        final completedOnOrBeforeDue = !cAt.isAfter(
          task.endDate,
        ); // cAt <= endDate
        if (completedOnOrBeforeDue) completedOnTime++;
      }
    }

    final total = tasks.length;
    final productivity = total == 0 ? 0.0 : (done / total * 100);

    // ✅ สูตรใหม่: พิจารณาเฉพาะงานที่เสร็จและรู้เวลาเสร็จจริง
    final onTimeRate = completedWithKnownTime == 0
        ? 0.0 // หรือจะส่ง null เพื่อให้ UI แสดง "N/A" ก็ได้
        : (completedOnTime / completedWithKnownTime * 100);

    return {
      'statusCounts': {
        'todo': todo,
        'inProgress': inProgress,
        'done': done,
        'overdue': overdue,
        'total': total,
      },
      'timeBased': {
        'todayTasks': todayTasks,
        'todayCompleted': todayCompleted,
        'weekTasks': weekTasks,
        'weekCompleted': weekCompleted,
        'monthTasks': monthTasks,
        'monthCompleted': monthCompleted,
      },
      'performance': {
        'dailyCompletions': dailyCompletions,
        'productivity': productivity,
        'onTimeRate': onTimeRate, // ✅ ใช้สูตรใหม่
        'completedWithKnownTime': completedWithKnownTime, // (ไว้โชว์/ดีบัก)
        'completedOnTime': completedOnTime, // (ไว้โชว์/ดีบัก)
      },
      'insights': {
        'avgTasksPerDay': weekTasks / 7,
        'completionRate': todayTasks > 0
            ? (todayCompleted / todayTasks * 100)
            : 0.0,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // ✅ เปลี่ยนพื้นหลังหลักเป็นธีมแดง
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimary1, kPrimary2, kPrimary2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildAnalyticsContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "analytics".tr,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "trackProgress".tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return Obx(() {
      final tasks = controller.allTasks;
      final analytics = _calculateAnalytics(tasks);

      if (tasks.isEmpty) return _buildEmptyState();

      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKeyMetricsSection(analytics),
              const SizedBox(height: 24),
              _buildPerformanceSection(analytics),
              const SizedBox(height: 24),
              _buildStatusDistributionSection(analytics),
              const SizedBox(height: 24),
              _buildProductivityTrendsSection(analytics),
              const SizedBox(height: 24),
              _buildInsightsSection(analytics),
              const SizedBox(height: 80), // Bottom padding for scroll
            ],
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.insights_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "noDataYet".tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "createTasksToSeeAnalytics".tr,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyMetricsSection(Map<String, dynamic> analytics) {
    final statusCounts = analytics['statusCounts'];
    final timeBased = analytics['timeBased'];
    final performance = analytics['performance'];

    final metrics = [
      {
        'title': 'total'.tr,
        'value': statusCounts['total'].toString(),
        'subtitle': 'allTasks'.tr,
        'icon': Icons.assignment_outlined,
        'color': kPrimary1, // ✅ ใช้สีธีมแดง
        'trend': '+${timeBased['weekTasks']}',
      },
      {
        'title': 'completed'.tr,
        'value': statusCounts['done'].toString(),
        'subtitle': '${(performance['productivity'] as double).toInt()}%',
        'icon': Icons.check_circle_outline,
        'color': const Color(0xFF4CAF50),
        'trend': '+${timeBased['weekCompleted']}',
      },
      {
        'title': 'inProgress'.tr,
        'value': statusCounts['inProgress'].toString(),
        'subtitle': 'active'.tr,
        'icon': Icons.schedule_outlined,
        'color': const Color(0xFFFF9800),
        'trend': 'now'.tr,
      },
      {
        'title': 'overdue'.tr,
        'value': statusCounts['overdue'].toString(),
        'subtitle': 'urgent'.tr,
        'icon': Icons.warning_outlined,
        'color': const Color(0xFFE91E63),
        'trend': statusCounts['overdue'] > 0 ? '!' : '✓',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPrimary1, // ✅ ใช้สีธีมแดง
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.dashboard_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "overview".tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final crossAxisCount = screenWidth > 600 ? 4 : 2;
            final cardWidth =
                (screenWidth - (16 * (crossAxisCount + 1))) / crossAxisCount;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metrics
                  .map((metric) => _buildMetricCard(metric, cardWidth))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric, double width) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 100, maxHeight: 120),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (metric['color'] as Color).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (metric['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(metric['icon'], color: metric['color'], size: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (metric['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    metric['trend'],
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: metric['color'],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<int>(
                    duration: const Duration(milliseconds: 1000),
                    tween: IntTween(begin: 0, end: int.parse(metric['value'])),
                    builder: (context, animValue, child) {
                      return Text(
                        animValue.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: metric['color'],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metric['title'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    metric['subtitle'],
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSection(Map<String, dynamic> analytics) {
    final performance = analytics['performance'];
    final productivity = (performance['productivity'] as double);
    final onTimeRate = (performance['onTimeRate'] as double);
    final hasOnTimeBase = (performance['completedWithKnownTime'] as int) > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "performance".tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              _buildProgressIndicator(
                "productivity".tr,
                productivity,
                const Color(0xFF4CAF50),
                "${productivity.toInt()}%",
              ),
              const SizedBox(height: 16),
              _buildProgressIndicator(
                'onTimeRate'.tr,
                hasOnTimeBase ? onTimeRate : 0,
                const Color(0xFF2196F3),
                hasOnTimeBase ? "${onTimeRate.toInt()}%" : "N/A",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
    String title,
    double value,
    Color color,
    String label,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1500),
          tween: Tween(begin: 0.0, end: value / 100),
          curve: Curves.easeOutCubic,
          builder: (context, animValue, child) {
            return Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: animValue,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusDistributionSection(Map<String, dynamic> analytics) {
    final statusCounts = analytics['statusCounts'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPrimary1, // ✅ ใช้สีธีมแดง
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart_outline,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "taskDistribution".tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 400) {
                // Wide screen: side by side
                return SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: _buildPieChart(statusCounts)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildLegend(statusCounts)),
                    ],
                  ),
                );
              } else {
                // Narrow screen: stacked
                return Column(
                  children: [
                    SizedBox(height: 180, child: _buildPieChart(statusCounts)),
                    const SizedBox(height: 16),
                    _buildLegend(statusCounts),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, dynamic> statusCounts) {
    final total = statusCounts['total'] as int;
    if (total == 0) {
      return const Center(
        child: Text(
          'No data to display',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    final data = [
      {
        'label': 'pending'.tr,
        'value': statusCounts['todo'],
        'color': Colors.grey.shade600,
      },
      {
        'label': 'inProgress'.tr,
        'value': statusCounts['inProgress'],
        'color': const Color(0xFFFF9800),
      },
      {
        'label': 'completed'.tr,
        'value': statusCounts['done'],
        'color': const Color(0xFF4CAF50),
      },
      {
        'label': 'overdue'.tr,
        'value': statusCounts['overdue'],
        'color': const Color(0xFFE91E63),
      },
    ];

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1500),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 30,
            startDegreeOffset: -90,
            sections: data.where((item) => (item['value'] as int) > 0).map((
              item,
            ) {
              final percentage = (item['value'] as int) / total * 100;
              return PieChartSectionData(
                color: item['color'] as Color,
                value: (item['value'] as int).toDouble() * value,
                title: percentage > 5 ? '${percentage.toInt()}%' : '',
                radius: 45,
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildLegend(Map<String, dynamic> statusCounts) {
    final data = [
      {
        'label': 'pending'.tr,
        'value': statusCounts['todo'],
        'color': Colors.grey.shade600,
      },
      {
        'label': 'inProgress'.tr,
        'value': statusCounts['inProgress'],
        'color': const Color(0xFFFF9800),
      },
      {
        'label': 'completed'.tr,
        'value': statusCounts['done'],
        'color': const Color(0xFF4CAF50),
      },
      {
        'label': 'overdue'.tr,
        'value': statusCounts['overdue'],
        'color': const Color(0xFFE91E63),
      },
    ];

    return Column(
      children: data.where((item) => (item['value'] as int) > 0).map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item['color'] as Color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item['label'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${item['value']}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductivityTrendsSection(Map<String, dynamic> analytics) {
    final performance = analytics['performance'];
    final dailyCompletions = performance['dailyCompletions'] as List<int>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPrimary2, // ✅ ใช้สีธีมแดง
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.show_chart,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "weeklyTrend".tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 150, child: _buildLineChart(dailyCompletions)),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<int> dailyData) {
    final maxY = dailyData.isEmpty
        ? 10.0
        : (dailyData.reduce((a, b) => a > b ? a : b).toDouble() + 2);
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 2000),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return LineChart(
          LineChartData(
            maxY: maxY,
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY > 10 ? maxY / 3 : 2,
              getDrawingHorizontalLine: (value) {
                return FlLine(color: Colors.grey.shade300, strokeWidth: 1);
              },
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: maxY > 10 ? maxY / 3 : 2,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 25,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < days.length) {
                      return Text(
                        days[index],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: dailyData.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    entry.value.toDouble() * value,
                  );
                }).toList(),
                isCurved: true,
                // ✅ กราฟเส้นใช้ธีมแดง
                gradient: const LinearGradient(colors: [kPrimary1, kPrimary2]),
                barWidth: 3,
                isStrokeCapRound: true,
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kPrimary1.withOpacity(0.2),
                      kPrimary1.withOpacity(0.0),
                    ],
                  ),
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: kPrimary1, // ✅ จุดใช้สีธีมแดง
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsightsSection(Map<String, dynamic> analytics) {
    final insights = analytics['insights'];
    final statusCounts = analytics['statusCounts'];
    final performance = analytics['performance'];

    // Generate insights based on data
    List<Map<String, dynamic>> insightsList = [];

    // Productivity insight
    final productivity = performance['productivity'] as double;
    if (productivity >= 80) {
      insightsList.add({
        'icon': Icons.trending_up,
        'color': const Color(0xFF4CAF50),
        'title': 'excellentWork'.tr,
        'description': 'keepUpGoodWork'.tr,
        'type': 'positive',
      });
    } else if (productivity >= 60) {
      insightsList.add({
        'icon': Icons.show_chart,
        'color': const Color(0xFFFF9800),
        'title': 'goodProgress'.tr,
        'description': 'roomForImprovement'.tr,
        'type': 'neutral',
      });
    } else if (productivity < 40 && statusCounts['total'] > 0) {
      insightsList.add({
        'icon': Icons.trending_down,
        'color': const Color(0xFFE91E63),
        'title': 'needsFocus'.tr,
        'description': 'tryToCompleteMore'.tr,
        'type': 'warning'.tr,
      });
    }

    // Overdue tasks insight
    final overdue = statusCounts['overdue'] as int;
    if (overdue > 0) {
      insightsList.add({
        'icon': Icons.warning_amber,
        'color': const Color(0xFFE91E63),
        'title': 'overdueTasks'.tr,
        'description': 'tasksNeedAttention'.trParams({
          'count': overdue.toString(),
        }),
        'type': 'warning'.tr,
      });
    }

    // In progress insight
    final inProgress = statusCounts['inProgress'] as int;
    if (inProgress > 5) {
      insightsList.add({
        'icon': Icons.psychology,
        'color': const Color(0xFF2196F3),
        'title': 'focusTip'.tr,
        'description': 'considerFewTasks'.tr,
        'type': 'tip',
      });
    }

    // Weekly completion insight
    final avgTasksPerDay = insights['avgTasksPerDay'] as double;
    if (avgTasksPerDay > 3) {
      insightsList.add({
        'icon': Icons.speed,
        'color': const Color(0xFF9C27B0),
        'title': 'highActivity'.tr,
        'description': 'veryProductive'.tr,
        'type': 'positive',
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "insights".tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (insightsList.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.insights, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    "noInsightsYet".tr,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          ...insightsList.map((insight) => _buildInsightCard(insight)),
      ],
    );
  }

  Widget _buildInsightCard(Map<String, dynamic> insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (insight['color'] as Color).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (insight['color'] as Color).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (insight['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(insight['icon'], color: insight['color'], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight['title'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  insight['description'],
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (insight['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              insight['type'],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: insight['color'],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
