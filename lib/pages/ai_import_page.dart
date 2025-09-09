import 'package:ai_task_project_manager/controllers/dashboard_controller.dart';
import 'package:ai_task_project_manager/models/task_model.dart';
import 'package:ai_task_project_manager/services/ai_api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class AiImportPage extends StatefulWidget {
  const AiImportPage({super.key});

  @override
  State<AiImportPage> createState() => _AiImportPageState();
}

class _AiImportPageState extends State<AiImportPage>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _mainTaskController = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _previewTasks = [];
  TaskModel? _aiMainTask;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  // 👇 เพิ่มตัวควบคุมสกอร์ล + state โชว์ปุ่มขึ้นบน
  final ScrollController _scrollCtrl = ScrollController();
  bool _showScrollToTop = false;

  final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');

  // 🎨 Primary purple theme
  static const Color kPrimary1 = Color(0xFF8B5CF6); // purple-500
  static const Color kPrimary2 = Color(0xFF7C3AED); // purple-600

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));

    // ✅ ให้ header โผล่ตั้งแต่เริ่มหน้า
    _fadeCtrl.forward();
    _slideCtrl.forward();

    // ✅ ฟังการเลื่อนเพื่อโชว์/ซ่อนปุ่มขึ้นบน
    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.offset > 300;
      if (show != _showScrollToTop && mounted) {
        setState(() => _showScrollToTop = show);
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _controller.dispose();
    _mainTaskController.dispose();
    _scrollCtrl.dispose(); // ✅ ปิด controller
    super.dispose();
  }

  Future<void> _generateTasks() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showSnackbar('pleaseEnterText'.tr, isError: true);
      return;
    }

    setState(() => _loading = true);
    _slideCtrl.reset();

    try {
      final TaskModel task = await AiApiService.fetchTaskFromAi(text);

      // ✅ แปลง startDate / endDate ของ main task เป็น DateTime (รองรับ dd/MM/yyyy)
      DateTime? parseDate(dynamic date) {
        if (date == null) return null;
        if (date is Timestamp) return date.toDate();
        if (date is DateTime) return date;
        if (date is String) {
          try {
            if (date.contains('/')) {
              final parts = date.split('/');
              if (parts.length == 3) {
                final dd = int.parse(parts[0]);
                final mm = int.parse(parts[1]);
                final yyyy = int.parse(parts[2]);
                return DateTime(yyyy, mm, dd);
              }
            }
            return DateTime.parse(date);
          } catch (_) {
            return null;
          }
        }
        return null;
      }

      _aiMainTask = task.copyWith(
        startDate: parseDate(task.startDate) ?? DateTime.now(),
        endDate:
            parseDate(task.endDate) ??
            DateTime.now().add(const Duration(days: 7)),
      );

      // แปลง checklist ให้เป็นรูปแบบที่ใช้ได้
      _previewTasks = [];
      if (task.checklist != null && task.checklist!.isNotEmpty) {
        _previewTasks = task.checklist!
            .map((item) {
              final Map<String, dynamic> taskItem = {};
              if (item is Map<String, dynamic>) {
                taskItem.addAll(item);
              } else if (item is String) {
                taskItem['title'] = item;
                taskItem['description'] = '';
              } else {
                taskItem['title'] = item.toString();
                taskItem['description'] = '';
              }

              final start = parseDate(taskItem['start_date']);
              final end = parseDate(taskItem['end_date']);

              return {
                'title': taskItem['title'] ?? '',
                'description': taskItem['description'] ?? '',
                'done': taskItem['done'] ?? false,
                'expanded': taskItem['expanded'] ?? true,
                'priority': taskItem['priority']?.toString() ?? 'medium',
                'start_date': start,
                'end_date': end,
              };
            })
            .where((item) => item['title'].toString().isNotEmpty)
            .toList();
      }

      if (_previewTasks.isNotEmpty) {
        _mainTaskController.text = _aiMainTask!.title;
        _fadeCtrl.forward();
        _slideCtrl.forward();
      } else {
        _showSnackbar('noSubtasksFound'.tr, isError: true);
      }
    } catch (e) {
      String errorMessage = e.toString();
      try {
        final regex = RegExp(r'"message"\s*:\s*"([^"]+)"');
        final match = regex.firstMatch(errorMessage);
        if (match != null) {
          errorMessage = match.group(1)!;
        }
      } catch (_) {}
      _showSnackbar('${'aiError'.tr}: $errorMessage', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveToProject() async {
    if (_previewTasks.isEmpty) return;

    final mainTaskTitle = _mainTaskController.text.trim();
    if (mainTaskTitle.isEmpty) {
      _showSnackbar('pleaseEnterMainTaskName'.tr, isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final taskController = Get.find<DashboardController>();
      final uid = taskController.auth.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final mainTask = _aiMainTask!.copyWith(
        id: '',
        uid: uid,
        title: mainTaskTitle,
        checklist: _previewTasks,
      );

      await taskController.addTask(mainTask);

      _showSnackbar(
        'savedMainTaskWithNSubtasks'.trParams({
          'count': _previewTasks.length.toString(),
        }),
      );

      if (!mounted) return;
      setState(() {
        _previewTasks = [];
        _controller.clear();
        _mainTaskController.clear();
        _aiMainTask = null;
        _showScrollToTop = false;
      });

      // เลื่อนกลับขึ้นด้านบน
      await _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } catch (e) {
      _showSnackbar('cannotSaveTask'.tr, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _showSnackbar(String message, {bool isError = false}) {
    Get.showSnackbar(
      GetSnackBar(
        message: message,
        duration: const Duration(seconds: 3),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        borderRadius: 12,
        margin: const EdgeInsets.all(20),
        snackPosition: SnackPosition.TOP,
        boxShadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        icon: Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  // Helper format date
  String formatDate(dynamic value) {
    DateTime? d;
    if (value is DateTime) d = value;
    if (value is Timestamp) d = value.toDate();
    if (value is String) {
      d = DateTime.tryParse(value);
      if (d == null && value.contains('/')) {
        // dd/MM/yyyy
        final parts = value.split('/');
        if (parts.length == 3) {
          final dd = int.tryParse(parts[0]) ?? 1;
          final mm = int.tryParse(parts[1]) ?? 1;
          final yyyy = int.tryParse(parts[2]) ?? DateTime.now().year;
          d = DateTime(yyyy, mm, dd);
        }
      }
    }
    d ??= DateTime.now();
    return dateFormatter.format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildBottomSaveBar(),
      body: Stack(
        children: [
          // พื้นหลัง + เนื้อหา
          Container(
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
                  _buildModernHeader(theme),
                  // เนื้อหาโค้งมนสีเทาอ่อนด้านล่างเหมือนหน้าอื่น
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
                      child: Scrollbar(
                        thumbVisibility: true,
                        thickness: 6,
                        radius: const Radius.circular(10),
                        child: CustomScrollView(
                          controller: _scrollCtrl, // ✅ ผูก controller
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  _buildInputSection(theme),
                                  const SizedBox(height: 20),
                                  _buildGenerateButton(),
                                  const SizedBox(height: 28),
                                  if (_previewTasks.isNotEmpty)
                                    FadeTransition(
                                      opacity: _fadeAnim,
                                      child: SlideTransition(
                                        position: _slideAnim,
                                        child: _buildMainTaskInfoSection(theme),
                                      ),
                                    ),
                                  if (_previewTasks.isNotEmpty)
                                    const SizedBox(height: 20),
                                  _buildPreviewSection(theme),
                                  const SizedBox(height: 120), // กันชนใต้สุด
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ปุ่มเลื่อนกลับขึ้นบนสุด (แสดงเมื่อเลื่อนลงพอ)
          if (_showScrollToTop)
            Positioned(
              right: 16,
              bottom: (_previewTasks.isNotEmpty ? 100 : 24),
              child: SafeArea(top: false, child: _buildScrollToTopButton()),
            ),
        ],
      ),
    );
  }

  /// Modern AppBar/Header เหมือนหน้า Dashboard/TaskList/Analytics
  Widget _buildModernHeader(ThemeData theme) {
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
                Icons.auto_awesome_rounded,
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
                    'aiTaskGenerator'.tr,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'aiTaskGeneratorSubtitle'.tr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
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

  Widget _buildInputSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: kPrimary1.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: kPrimary1, size: 20),
                const SizedBox(width: 8),
                Text(
                  'textToConvert'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: kPrimary1,
                  ),
                ),
              ],
            ),
          ),
          // TextField
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Stack(
              children: [
                TextField(
                  controller: _controller,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: 'pasteTextPlaceholder'.tr,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(
                      top: 12,
                      left: 0,
                      right: 40,
                    ),
                  ),
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                    onPressed: () {
                      _controller.clear();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kPrimary1, kPrimary2]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPrimary1.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading
              ? null
              : () {
                  _dismissKeyboard();
                  _generateTasks();
                },
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_loading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                const SizedBox(width: 10),
                Text(
                  _loading ? 'processingWithAI'.tr : 'generateWithAI'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainTaskInfoSection(ThemeData theme) {
    if (_aiMainTask == null) return const SizedBox();

    final mainTask = _aiMainTask!;
    final DateTime startDate = mainTask.startDate;
    final DateTime endDate = mainTask.endDate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: kPrimary1.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimary1, kPrimary2],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary1.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'mainTaskInfo'.tr,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Task Name Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.title_rounded, size: 18, color: kPrimary1),
                    const SizedBox(width: 8),
                    Text(
                      'taskName'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: kPrimary1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _mainTaskController,
                  decoration: InputDecoration(
                    hintText: 'setMainTaskName'.tr,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Dates
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.date_range_rounded,
                      size: 18,
                      color: kPrimary2,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'date'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: kPrimary2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${'start'.tr}: ',
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatDate(startDate),
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${'end'.tr}: ',
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatDate(endDate),
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(ThemeData theme) {
    final hasItem = _previewTasks.isNotEmpty;

    return Container(
      constraints: hasItem ? const BoxConstraints(maxHeight: 600) : null,
      child: _previewTasks.isEmpty
          ? Align(
              alignment: Alignment.topCenter,
              child: _buildEmptyPreview(theme),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section title
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.checklist_rounded,
                            color: kPrimary2,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'subtasks'.tr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // List
                    Expanded(
                      child: ListView.separated(
                        itemCount: _previewTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final task = _previewTasks[index];
                          return _buildSimpleTaskCard(task, index, theme);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSimpleTaskCard(
    Map<String, dynamic> task,
    int index,
    ThemeData theme,
  ) {
    final title = (task['title']?.toString() ?? '').trim();
    final description = (task['description']?.toString() ?? '').trim();

    String displayTitle = title;
    String displayDescription = description;

    // แกะกรณีได้รับรูปแบบ "name: ..., description: ..."
    if (title.contains('name:') && title.contains('description:')) {
      final regex = RegExp(r'name:\s*([^,]*),\s*description:\s*(.*)}?');
      final match = regex.firstMatch(title);
      if (match != null) {
        displayTitle = (match.group(1) ?? title).trim();
        displayDescription = (match.group(2) ?? description).trim();
      }
    }

    if (displayDescription.isEmpty && displayTitle.length > 60) {
      final sentences = displayTitle.split('.');
      if (sentences.length > 1) {
        displayTitle = sentences[0].trim();
        displayDescription = sentences.sublist(1).join('.').trim();
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: kPrimary1.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with task number
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [kPrimary1, kPrimary2]),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kPrimary2,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'subtask'.tr, // singular
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.title_rounded,
                        size: 18,
                        color: kPrimary1,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayTitle.isNotEmpty
                              ? displayTitle
                              : 'noTaskName'.tr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Description
                const SizedBox(height: 12),
                if (displayDescription.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.description_rounded,
                          size: 18,
                          color: kPrimary2,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayDescription,
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (displayDescription.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF2F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCE7F3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'noDetails'.tr,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPreview(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kPrimary1, kPrimary2]),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: kPrimary2.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'subtasksAppearHere'.tr,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'typeAndGenerate'.tr,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  // ✅ ปุ่มแถบบันทึกลอย (ไว้กลางล่าง) — แสดงเมื่อมี preview
  Widget _buildBottomSaveBar() {
    if (_previewTasks.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kPrimary2, kPrimary1]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kPrimary2.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _saveToProject,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_loading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    const Icon(
                      Icons.save_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  const SizedBox(width: 10),
                  Text(
                    _loading ? 'processingWithAI'.tr : 'saveMainTask'.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ ปุ่มเลื่อนกลับขึ้นบนสุด (มุมขวาล่าง)
  Widget _buildScrollToTopButton() {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          _scrollCtrl.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.keyboard_arrow_up_rounded,
            color: kPrimary2,
            size: 28,
          ),
        ),
      ),
    );
  }
}
