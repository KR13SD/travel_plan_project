import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/add_task_controller.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage>
    with TickerProviderStateMixin {
  final AddTaskController controller = Get.put(AddTaskController());
  final _formKey = GlobalKey<FormState>();
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;

  // ใช้ธีมสีเขียวเหมือน TaskListPage
  static const Color kPrimary1 = Color(0xFF10B981); // emerald-500
  static const Color kPrimary2 = Color(0xFF059669); // emerald-600

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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
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

  String _formatDate(DateTime date) {
    final months = [
      '',
      'jan'.tr, 'feb'.tr, 'mar'.tr, 'apr'.tr, 'may'.tr, 'jun'.tr,
      'jul'.tr, 'aug'.tr, 'sep'.tr, 'oct'.tr, 'nov'.tr, 'dec'.tr,
    ];
    return '${date.day} ${months[date.month]} ${date.year + 543}';
  }

  Widget _buildGlassmorphismCard({
    required Widget child,
    double delay = 0.0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (delay * 200).toInt()),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
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
                    color: kPrimary1.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: child!,
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Color> gradient,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
                  child: Form(
                    key: _formKey,
                    child: Obx(() => ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            // Task Title Section
                            _buildGlassmorphismCard(
                              delay: 0.0,
                              child: Column(
                                children: [
                                  _buildSectionHeader(
                                    icon: Icons.edit_document,
                                    title: 'taskdetails'.tr,
                                    gradient: [
                                      controller.priorityColors[controller.priority.value] ?? kPrimary1,
                                      (controller.priorityColors[controller.priority.value] ?? kPrimary1).withOpacity(0.8),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: TextFormField(
                                        controller: controller.titleController,
                                        decoration: InputDecoration(
                                          labelText: 'taskname'.tr,
                                          hintText: 'hintnametask'.tr,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide.none,
                                          ),
                                          prefixIcon: Container(
                                            margin: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  (controller.priorityColors[controller.priority.value] ?? kPrimary1).withOpacity(0.2),
                                                  (controller.priorityColors[controller.priority.value] ?? kPrimary1).withOpacity(0.1),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.edit,
                                              color: controller.priorityColors[controller.priority.value] ?? kPrimary1,
                                              size: 20,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.transparent,
                                          labelStyle: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'inserttaskname'.tr;
                                          }
                                          return null;
                                        },
                                        textInputAction: TextInputAction.next,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Priority and Dates Section
                            _buildGlassmorphismCard(
                              delay: 0.1,
                              child: Column(
                                children: [
                                  _buildSectionHeader(
                                    icon: Icons.tune,
                                    title: 'settings'.tr,
                                    gradient: const [Color(0xFF74b9ff), Color(0xFF0984e3)],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                    child: Column(
                                      children: [
                                        // Priority Selector
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Row(
                                            children: ['low'.tr, 'medium'.tr, 'high'.tr].map((p) {
                                              final isSelected = controller.priority.value == p;
                                              final priorityColor = controller.priorityColors[p] ?? kPrimary1;
                                              
                                              return Expanded(
                                                child: GestureDetector(
                                                  onTap: () => controller.priority.value = p,
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.easeInOut,
                                                    margin: const EdgeInsets.all(2),
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    decoration: BoxDecoration(
                                                      gradient: isSelected
                                                          ? LinearGradient(
                                                              colors: [
                                                                priorityColor,
                                                                priorityColor.withOpacity(0.8),
                                                              ],
                                                            )
                                                          : null,
                                                      borderRadius: BorderRadius.circular(12),
                                                      boxShadow: isSelected
                                                          ? [
                                                              BoxShadow(
                                                                color: priorityColor.withOpacity(0.3),
                                                                blurRadius: 8,
                                                                offset: const Offset(0, 4),
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          controller.priorityIcons[p],
                                                          color: isSelected ? Colors.white : priorityColor,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          p.toLowerCase().tr,
                                                          style: TextStyle(
                                                            color: isSelected ? Colors.white : priorityColor,
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),

                                        const SizedBox(height: 24),

                                        // Date Pickers
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => controller.pickDate(context, true),
                                                  child: _buildDateInfo(
                                                    'startdate'.tr,
                                                    controller.startDate.value,
                                                    Icons.play_circle_filled_rounded,
                                                    const Color(0xFF00b894),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 1,
                                                height: 40,
                                                color: Colors.grey.withOpacity(0.2),
                                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                              ),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => controller.pickDate(context, false),
                                                  child: _buildDateInfo(
                                                    'duedate'.tr,
                                                    controller.endDate.value,
                                                    Icons.flag_rounded,
                                                    kPrimary2,
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
                            ),

                            // Checklist Section
                            _buildGlassmorphismCard(
                              delay: 0.2,
                              child: Column(
                                children: [
                                  _buildSectionHeader(
                                    icon: Icons.checklist_rtl,
                                    title: 'subtasks'.tr,
                                    subtitle: 'list_item'.trParams({
                                      'count': controller.checklist.length.toString(),
                                    }),
                                    gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                                    action: _buildGradientActionButton(
                                      icon: Icons.add,
                                      gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                                      onPressed: controller.addChecklistItem,
                                      label: 'add'.tr,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                    child: controller.checklist.isEmpty
                                        ? _buildEmptyChecklistState()
                                        : _buildChecklistItems(),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildModernBottomBar(),
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
                Icons.add_task_rounded,
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
                    'addnewtask'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'createyourtask'.tr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Obx(() => controller.isLoading.value
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : const SizedBox()),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInfo(String label, DateTime date, IconData icon, Color color) {
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
                _formatDate(date),
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

  Widget _buildGradientActionButton({
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onPressed,
    String? label,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: label != null ? 16 : 12,
              vertical: 12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                if (label != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChecklistState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.withOpacity(0.05),
            Colors.grey.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.checklist_rtl,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'nosubtasks'.tr,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'guidelinessubtasks'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItems() {
    return Column(
      children: controller.checklist.asMap().entries.map((entry) {
        int index = entry.key;
        var item = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item["done"] == true
                  ? Colors.green.shade300
                  : Colors.grey.shade200,
              width: 1.5,
            ),
            gradient: LinearGradient(
              colors: item["done"] == true
                  ? [
                      Colors.green.shade50,
                      Colors.green.shade100.withOpacity(0.5),
                    ]
                  : [
                      Colors.white,
                      Colors.grey.shade50.withOpacity(0.5),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ExpansionTile(
            key: ValueKey(item["id"]),
            initiallyExpanded: item["expanded"] ?? true,
            onExpansionChanged: (expanded) {
              controller.toggleChecklistExpansion(index, expanded);
            },
            leading: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(
                  color: item["done"] == true ? Colors.green : Colors.grey.shade300,
                  width: 2,
                ),
                color: item["done"] == true ? Colors.green : Colors.transparent,
              ),
              child: Checkbox(
                value: item["done"],
                onChanged: (val) {
                  controller.toggleChecklistDone(index, val!);
                },
                activeColor: Colors.transparent,
                checkColor: Colors.white,
                side: BorderSide.none,

              ),
            ),
            title: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                readOnly: item["done"] ?? false,
                decoration: InputDecoration(
                  hintText: "subtaskname".tr,
                  border: InputBorder.none,
                  isDense: true,
                ),
                controller: TextEditingController(text: item["title"])
                  ..selection = TextSelection.collapsed(
                    offset: item["title"]?.length ?? 0,
                  ),
                style: TextStyle(
                  color: (item["done"] ?? false) ? Colors.grey.shade600 : Colors.black87,
                  decoration: (item["done"] ?? false)
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                onChanged: (val) => item["title"] = val,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    onPressed: () => controller.removeChecklistItem(context, index),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: (item["expanded"] ?? true) ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    readOnly: item["done"] ?? false,
                    decoration: InputDecoration(
                      hintText: "subtaskdetails".tr,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                    controller: TextEditingController(
                      text: item["description"],
                    ),
                    style: TextStyle(
                      color: (item["done"] ?? false)
                          ? Colors.grey.shade600
                          : Colors.black87,
                      fontSize: 14,
                    ),
                    onChanged: (val) => item["description"] = val,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModernBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Obx(() => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      controller.priorityColors[controller.priority.value] ?? kPrimary1,
                      (controller.priorityColors[controller.priority.value] ?? kPrimary1)
                          .withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (controller.priorityColors[controller.priority.value] ?? kPrimary1)
                          .withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.saveTask(_formKey, context),
                  icon: controller.isLoading.value
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 24),
                  label: Text(
                    controller.isLoading.value ? 'saving'.tr : 'savetask'.tr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
        ),
      ),
    );
  }
}