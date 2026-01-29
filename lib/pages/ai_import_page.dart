// ai_import_page.dart
import 'package:ai_task_project_manager/controllers/ai_import_controller.dart';
import 'package:ai_task_project_manager/controllers/dashboard_controller.dart';
import 'package:ai_task_project_manager/widget/ai_generating_overlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ai_task_project_manager/pages/ai_map_page.dart';
import 'package:ai_task_project_manager/pages/map_preview.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AiImportPage extends StatefulWidget {
  const AiImportPage({super.key});

  @override
  State<AiImportPage> createState() => _AiImportPageState();
}

class _AiImportPageState extends State<AiImportPage>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _mainTaskController = TextEditingController();
  final AiImportController aiCtrl = Get.put(
    AiImportController(),
    permanent: true,
  );

  // เลือกโรงแรมได้แค่ 1 รายการ
  int? _selectedHotelIndex;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  // สกอร์ล + ปุ่ม scroll-to-top
  final ScrollController _scrollCtrl = ScrollController();
  bool _showScrollToTop = false;

  // เก็บ index รูปที่เลือกต่อการ์ด 
  final Map<String, int> _selectedImageIndex = {}; // "plan-0" / "hotel-2"

  final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');
  final DateFormat timeFormatter = DateFormat('HH:mm');

  // 🎨 Primary purple theme
  static const Color kPrimary1 = Color(0xFF8B5CF6); // purple-500
  static const Color kPrimary2 = Color(0xFF7C3AED); // purple-600

  @override
  void initState() {
    super.initState();
    aiCtrl.isOnAiImportPage.value = true;
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

    _fadeCtrl.forward();
    _slideCtrl.forward();

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
    _scrollCtrl.dispose();
    aiCtrl.isOnAiImportPage.value = false;
    super.dispose();
  }

  // ===== Helpers แก้ค่าจากการแตะ Chip =====
  Future<void> _pickSubtaskDate(int index) async {
    final current =
        aiCtrl.previewTasks[index]['start_date'] as DateTime? ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => aiCtrl.previewTasks[index]['start_date'] = picked);
    }
  }

  Future<void> _editStringField({
    required int index,
    required String key,
    required String title,
    String? hint,
  }) async {
    final controller = TextEditingController(
      text: (aiCtrl.previewTasks[index][key] ?? '').toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => aiCtrl.previewTasks[index][key] = controller.text.trim());
    }
  }

  // ===== AI Generate =====
  void _generateTasks() {
    aiCtrl.generateFromText(_controller.text.trim());
  }

  // ===== Map helpers =====
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

  // ===== Save =====
  Future<void> _saveToProject() async {
    if (aiCtrl.previewTasks.isEmpty) return;

    final mainTaskTitle = _mainTaskController.text.trim();
    if (mainTaskTitle.isEmpty) {
      _showSnackbar('pleaseEnterMainTaskName'.tr, isError: true);
      return;
    }

    setState(() => aiCtrl.isGenerating.value = true);
    try {
      final taskController = Get.find<DashboardController>();
      final uid = taskController.auth.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      // รวม checklist + โรงแรมที่เลือก (ถ้ามี)
      final finalChecklist = List<Map<String, dynamic>>.from(
        aiCtrl.previewTasks,
      );
      if (_selectedHotelIndex != null) {
        final h = aiCtrl.hotelPoints[_selectedHotelIndex!];
        final double? lat = (h['lat'] is num)
            ? (h['lat'] as num).toDouble()
            : (h['lat'] is String ? double.tryParse(h['lat']) : null);
        final double? lng = (h['lng'] is num)
            ? (h['lng'] as num).toDouble()
            : (h['lng'] is String ? double.tryParse(h['lng']) : null);

        // รูปโรงแรม (ถ้ามี)
        final String? image = h['image']?.toString();
        final List<String> images = (h['images'] as List? ?? const [])
            .map((e) => e.toString())
            .where((u) => u.startsWith('http'))
            .toList();

        finalChecklist.add({
          'type': 'hotel',
          'title': (h['title'] ?? '').toString(),
          'description': (h['notes'] ?? '').toString(),
          'price': (h['price'] ?? '').toString(),
          'reserve': h['reserve'] == true,
          'mapsUrl': (h['mapsUrl'] ?? '').toString(),
          'lat': lat,
          'lng': lng,
          'done': false,
          'expanded': true,
          'start_date': null,
          'end_date': null,
          'priority': 'medium',
          'image': (image != null && image.startsWith('http')) ? image : null,
          'images': images,
        });
      }

      final mainTask = aiCtrl.aiMainTask!.copyWith(
        id: '',
        uid: uid,
        title: mainTaskTitle,
        status: (aiCtrl.aiMainTask!.status.isEmpty
            ? 'todo'
            : aiCtrl.aiMainTask!.status),
        priority: (aiCtrl.aiMainTask!.priority.isEmpty
            ? 'Low'
            : aiCtrl.aiMainTask!.priority),
        checklist: finalChecklist, // Timestamp conversion handled in toJson()
      );

      await taskController.addTask(mainTask);

      if (!mounted) return;
      Get.back(); // กลับไป TaskList

      _showSnackbar(
        'savedMainTaskWithNSubtasks'.trParams({
          'count': aiCtrl.previewTasks.length.toString(),
        }),
      );

      if (!mounted) return;
      setState(() {
        aiCtrl.previewTasks.clear();
        _controller.clear();
        _mainTaskController.clear();
        aiCtrl.aiMainTask = null;
        aiCtrl.planPoints.clear();
        aiCtrl.hotelPoints.clear();
        _selectedHotelIndex = null;
        _showScrollToTop = false;
        _selectedImageIndex.clear();
      });

      await _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } catch (e) {
      _showSnackbar('cannotSaveTask'.tr, isError: true);
    } finally {
      if (mounted) setState(() => aiCtrl.isGenerating.value = false);
    }
  }

  // ===== UI helpers =====
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

  String formatDate(dynamic value) {
    DateTime? d;
    if (value is DateTime) d = value;
    if (value is Timestamp) d = value.toDate();
    if (value is String) {
      d = DateTime.tryParse(value);
      if (d == null && value.contains('/')) {
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

  String formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          final time = DateTime(2024, 1, 1, hour, minute);
          return timeFormatter.format(time);
        }
      }
      return timeStr;
    } catch (_) {
      return timeStr;
    }
  }

  String formatDuration(String? durationStr) {
    if (durationStr == null || durationStr.isEmpty) return '';
    return durationStr;
  }

  Color getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444); // red-500
      case 'medium':
        return const Color(0xFFF59E0B); // amber-500
      case 'low':
        return const Color(0xFF10B981); // emerald-500
      default:
        return const Color(0xFF6B7280); // gray-500
    }
  }

  IconData getPriorityIcon(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Icons.priority_high_rounded;
      case 'medium':
        return Icons.remove_rounded;
      case 'low':
        return Icons.keyboard_arrow_down_rounded;
      default:
        return Icons.remove_rounded;
    }
  }

  // ===== Better Image UI (Hero + Thumbnails) =====
  Widget _glassIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildHeroImage({
    required List<String> images,
    required String cacheKey,
    required String title,
    String? subtitle,
    String? tagText, // PLAN / HOTEL
    Color? tagColor,
    String? mapsUrl,
    VoidCallback? onOpenMap,
  }) {
    final hasImages = images.isNotEmpty;
    final selected = _selectedImageIndex[cacheKey] ?? 0;
    final activeIndex = (selected < images.length) ? selected : 0;
    final activeUrl = hasImages ? images[activeIndex] : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: activeUrl == null
                  ? Container(
                      color: const Color(0xFFF1F5F9),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.image_outlined,
                            size: 34,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No image',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: activeUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFFF1F5F9),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFFF1F5F9),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_rounded,
                          size: 34,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.00),
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.65),
                    ],
                  ),
                ),
              ),
            ),

            if (tagText != null && tagText.trim().isNotEmpty)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (tagColor ?? kPrimary2).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tagText.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),

            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  _glassIconButton(
                    icon: Icons.fullscreen_rounded,
                    tooltip: 'View image',
                    onTap: activeUrl == null
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                insetPadding: const EdgeInsets.all(14),
                                backgroundColor: Colors.black,
                                child: Stack(
                                  children: [
                                    InteractiveViewer(
                                      child: CachedNetworkImage(
                                        imageUrl: activeUrl,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: IconButton(
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                  ),
                  const SizedBox(width: 8),
                  if ((mapsUrl != null && mapsUrl.isNotEmpty) ||
                      onOpenMap != null)
                    _glassIconButton(
                      icon: Icons.map_rounded,
                      tooltip: 'Open map',
                      onTap:
                          onOpenMap ??
                          () async {
                            final uri = Uri.parse(mapsUrl!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              _showSnackbar(
                                'ไม่สามารถเปิดลิงก์แผนที่ได้',
                                isError: true,
                              );
                            }
                          },
                    ),
                ],
              ),
            ),

            Positioned(
              left: 12,
              right: 12,
              bottom: hasImages && images.length > 1 ? 54 : 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? '-' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (hasImages && images.length > 1)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length.clamp(0, 10),
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final isSelected = i == activeIndex;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedImageIndex[cacheKey] = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.35),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: CachedNetworkImage(
                              imageUrl: images[i],
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.white.withOpacity(0.10),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.white.withOpacity(0.10),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===== Main build =====
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(
      () => Scaffold(
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
                            controller: _scrollCtrl,
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  0,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    _buildInputSection(theme),
                                    const SizedBox(height: 20),
                                    _buildGenerateButton(),

                                    // ปุ่มดูแผนที่รวม
                                    if (aiCtrl.planPoints.isNotEmpty ||
                                        aiCtrl.hotelPoints.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.map_rounded),
                                          label: Text(
                                            'ดูแผนที่รวม (แผน + โรงแรม)'.tr,
                                          ),
                                          onPressed: () {
                                            final points =
                                                [
                                                      ...aiCtrl.planPoints,
                                                      ...aiCtrl.hotelPoints,
                                                    ]
                                                    .where(
                                                      (e) =>
                                                          e['lat'] != null &&
                                                          e['lng'] != null,
                                                    )
                                                    .toList();

                                            if (points.isEmpty) {
                                              _showSnackbar(
                                                'ยังไม่มีพิกัดจาก AI',
                                                isError: true,
                                              );
                                              return;
                                            }

                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => AiMapPage(
                                                  points: points
                                                      .map(
                                                        (p) => {
                                                          'title': p['title'],
                                                          'lat': p['lat'],
                                                          'lng': p['lng'],
                                                          'type': p['type'],
                                                        },
                                                      )
                                                      .toList(),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                    const SizedBox(height: 28),

                                    if (aiCtrl.previewTasks.isNotEmpty)
                                      FadeTransition(
                                        opacity: _fadeAnim,
                                        child: SlideTransition(
                                          position: _slideAnim,
                                          child: _buildMainTaskInfoSection(
                                            theme,
                                          ),
                                        ),
                                      ),
                                    if (aiCtrl.previewTasks.isNotEmpty)
                                      const SizedBox(height: 20),

                                    _buildPreviewSection(theme),
                                    const SizedBox(height: 16),
                                    _buildHotelsSection(theme),
                                    const SizedBox(height: 120),
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

            // ปุ่มเลื่อนกลับขึ้นบนสุด
            if (_showScrollToTop)
              Positioned(
                right: 16,
                bottom: (aiCtrl.previewTasks.isNotEmpty ? 100 : 24),
                child: SafeArea(top: false, child: _buildScrollToTopButton()),
              ),
            if (aiCtrl.isGenerating.value && !aiCtrl.isOnAiImportPage.value)
              const AiGeneratingOverlay(),
          ],
        ),
      ),
    );
  }

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
    return Obx(() {
      final isGenerating = aiCtrl.isGenerating.value;

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
            onTap: isGenerating
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
                  if (isGenerating)
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
                    isGenerating ? 'processingWithAI'.tr : 'generateWithAI'.tr,
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
    });
  }

  Widget _buildMainTaskInfoSection(ThemeData theme) {
    if (aiCtrl.aiMainTask == null) return const SizedBox();

    final mainTask = aiCtrl.aiMainTask!;
    final DateTime startDate = mainTask.startDate;
    final DateTime endDate = mainTask.endDate;
    _mainTaskController.text = mainTask.title;

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
                  onChanged: (_) {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

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
    final hasItem = aiCtrl.previewTasks.isNotEmpty;

    return Container(
      constraints: hasItem ? const BoxConstraints(maxHeight: 800) : null,
      child: aiCtrl.previewTasks.isEmpty
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
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimary1.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${aiCtrl.previewTasks.length} ${'items'.tr}',
                              style: const TextStyle(
                                color: kPrimary1,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: aiCtrl.previewTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final task = aiCtrl.previewTasks[index];
                          return _buildEnhancedTaskCard(task, index, theme);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  DateTime? safeDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  double? safeDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String safePriority(dynamic v) {
    final p = (v ?? 'medium').toString().toLowerCase();
    return ['high', 'medium', 'low'].contains(p) ? p : 'medium';
  }

  Widget _buildEnhancedTaskCard(
    Map<String, dynamic> task,
    int index,
    ThemeData theme,
  ) {
    final rawTitle = (task['title']?.toString() ?? '').trim();
    final rawDesc = (task['description']?.toString() ?? '').trim();
    final time = formatTime(task['time']?.toString());
    final duration = formatDuration(task['duration']?.toString());
    final DateTime? startDate = safeDate(task['start_date']);
    final double? lat = safeDouble(task['lat']);
    final double? lng = safeDouble(task['lng']);
    final String priority = safePriority(task['priority']);

    final String? image = task['image']?.toString();
    final List<String> images = (task['images'] as List? ?? const [])
        .map((e) => e.toString())
        .where((u) => u.startsWith('http'))
        .toList();

    final List<String> imagesAll = <String>[
      if (image != null && image.startsWith('http')) image,
      ...images,
    ].toSet().toList();

    // ปรับเคส "name: , description:" ที่อาจติดมา
    String displayTitle = rawTitle;
    String displayDescription = rawDesc;
    if (rawTitle.contains('name:') && rawTitle.contains('description:')) {
      final regex = RegExp(r'name:\s*([^,]*),\s*description:\s*(.*)}?');
      final match = regex.firstMatch(rawTitle);
      if (match != null) {
        displayTitle = (match.group(1) ?? rawTitle).trim();
        displayDescription = (match.group(2) ?? rawDesc).trim();
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
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kPrimary1.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPrimary1, kPrimary2],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: getPriorityColor(priority).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: getPriorityColor(priority).withOpacity(0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: priority,
                      items: const [
                        DropdownMenuItem(value: 'high', child: Text('HIGH')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('MEDIUM'),
                        ),
                        DropdownMenuItem(value: 'low', child: Text('LOW')),
                      ],
                      onChanged: (val) => setState(
                        () => aiCtrl.previewTasks[index]['priority'] =
                            val ?? 'medium',
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                IconButton(
                  tooltip: 'deletesubtask'.tr,
                  onPressed: () =>
                      setState(() => aiCtrl.previewTasks.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ),

          // Better Image UI
          if (imagesAll.isNotEmpty)
            _buildHeroImage(
              images: imagesAll,
              cacheKey: 'plan-$index',
              title: displayTitle,
              subtitle: displayDescription,
              tagText: 'PLAN',
              tagColor: kPrimary2,
              mapsUrl: task['mapsUrl']?.toString(),
              onOpenMap: (lat != null && lng != null)
                  ? () => _openExternalMap(lat, lng, label: displayTitle)
                  : null,
            ),

          // Main Content (Editable)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: displayTitle.isNotEmpty
                      ? displayTitle
                      : 'noTaskName'.tr,
                  decoration: const InputDecoration(
                    hintText: 'Task title',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    fontSize: 16,
                    height: 1.4,
                  ),
                  onChanged: (v) =>
                      aiCtrl.previewTasks[index]['title'] = v.trim(),
                ),

                TextFormField(
                  initialValue: displayDescription,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'รายละเอียด',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    height: 1.6,
                    fontSize: 14,
                  ),
                  onChanged: (v) =>
                      aiCtrl.previewTasks[index]['description'] = v.trim(),
                ),

                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (startDate != null)
                      _buildInfoChip(
                        icon: Icons.calendar_today_rounded,
                        label: formatDate(startDate),
                        color: const Color(0xFF3B82F6),
                        onTap: () => _pickSubtaskDate(index),
                      ),

                    _buildInfoChip(
                      icon: Icons.schedule_rounded,
                      label: (time.isEmpty && duration.isEmpty)
                          ? '—'
                          : (duration.isNotEmpty
                                ? (time.isEmpty
                                      ? duration
                                      : '$time ($duration)')
                                : time),
                      color: const Color(0xFFF59E0B),
                      onTap: () async {
                        await _editStringField(
                          index: index,
                          key: 'time',
                          title: 'เวลานัดหมาย',
                          hint: 'เช่น 09:30',
                        );
                      },
                    ),

                    if (lat != null && lng != null)
                      _buildInfoChip(
                        icon: Icons.place_rounded,
                        label: 'Location',
                        color: const Color(0xFFEF4444),
                        onTap: () =>
                            _openExternalMap(lat, lng, label: displayTitle),
                      ),
                  ],
                ),

                if (lat != null && lng != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MapPreview(lat: lat, lng: lng),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openExternalMap(lat, lng, label: displayTitle),
                          icon: const Icon(Icons.map_rounded, size: 16),
                          label: Text(
                            'Open'.tr,
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AiMapPage(
                                  points: [
                                    {
                                      'title': displayTitle,
                                      'lat': lat,
                                      'lng': lng,
                                    },
                                  ],
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.fullscreen, size: 16),
                          label: Text(
                            'Preview'.tr,
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Chip widget
  Widget _buildInfoChip({
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

  // ปุ่ม SAVE 
  Widget _buildBottomSaveBar() {
    if (aiCtrl.previewTasks.isEmpty) return const SizedBox.shrink();

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
            onTap: aiCtrl.isGenerating.value ? null : _saveToProject,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (aiCtrl.isGenerating.value)
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
                    aiCtrl.isGenerating.value
                        ? 'processingWithAI'.tr
                        : 'saveMainTask'.tr,
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

  Widget _buildHotelsSection(ThemeData theme) {
    if (aiCtrl.hotelPoints.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                  Icons.hotel_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'โรงแรมที่แนะนำ'.tr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kPrimary1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${aiCtrl.hotelPoints.length} ${'items'.tr}',
                  style: const TextStyle(
                    color: kPrimary1,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ListView.separated(
            itemCount: aiCtrl.hotelPoints.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final h = aiCtrl.hotelPoints[index];
              final String title = (h['title'] ?? '').toString();
              final String notes = (h['notes'] ?? '').toString();
              final String price = (h['price'] ?? '').toString();
              final bool reserve = h['reserve'] == true;
              final String mapsUrl = (h['mapsUrl'] ?? '').toString();

              final double? lat = (h['lat'] is num)
                  ? (h['lat'] as num).toDouble()
                  : (h['lat'] is String ? double.tryParse(h['lat']) : null);
              final double? lng = (h['lng'] is num)
                  ? (h['lng'] as num).toDouble()
                  : (h['lng'] is String ? double.tryParse(h['lng']) : null);

              final selected = _selectedHotelIndex == index;

              final String? image = h['image']?.toString();
              final List<String> images = (h['images'] as List? ?? const [])
                  .map((e) => e.toString())
                  .where((u) => u.startsWith('http'))
                  .toList();

              final List<String> imagesAll = <String>[
                if (image != null && image.startsWith('http')) image,
                ...images,
              ].toSet().toList();

              return Container(
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFEEF2FF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? kPrimary2 : const Color(0xFFE2E8F0),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imagesAll.isNotEmpty)
                      _buildHeroImage(
                        images: imagesAll,
                        cacheKey: 'hotel-$index',
                        title: title,
                        subtitle: notes,
                        tagText: 'HOTEL',
                        tagColor: const Color(0xFF0EA5E9),
                        mapsUrl: mapsUrl,
                        onOpenMap: (lat != null && lng != null)
                            ? () => _openExternalMap(lat, lng, label: title)
                            : (mapsUrl.isNotEmpty ? null : null),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Radio<int>(
                                value: index,
                                groupValue: _selectedHotelIndex,
                                onChanged: (v) =>
                                    setState(() => _selectedHotelIndex = v),
                                activeColor: kPrimary2,
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.bed_rounded,
                                color: kPrimary2,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title.isEmpty ? 'Hotel' : title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: selected
                                        ? kPrimary2
                                        : const Color(0xFF111827),
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
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B),
                                    ),
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

                          if ((lat != null && lng != null) ||
                              mapsUrl.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (lat != null && lng != null)
                                  ElevatedButton.icon(
                                    onPressed: () => _openExternalMap(
                                      lat,
                                      lng,
                                      label: title,
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
                                        _showSnackbar(
                                          'ไม่สามารถเปิดลิงก์แผนที่ได้',
                                          isError: true,
                                        );
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
                                                'title': title,
                                                'lat': lat,
                                                'lng': lng,
                                                'type': 'hotel',
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
                          ],

                          if (lat != null && lng != null) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: MapPreview(lat: lat, lng: lng),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          if (aiCtrl.hotelPoints
              .where((e) => e['lat'] != null && e['lng'] != null)
              .isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const Text('ดูเฉพาะโรงแรมบนแผนที่'),
                onPressed: () {
                  final points = aiCtrl.hotelPoints
                      .where((e) => e['lat'] != null && e['lng'] != null)
                      .map(
                        (p) => {
                          'title': p['title'],
                          'lat': p['lat'],
                          'lng': p['lng'],
                          'type': 'hotel',
                        },
                      )
                      .toList();

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AiMapPage(points: points),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ปุ่มเลื่อนกลับขึ้นบนสุด
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
