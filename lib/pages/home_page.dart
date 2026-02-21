import 'dart:convert';

import 'package:ai_task_project_manager/controllers/ai_import_controller.dart';
import 'package:ai_task_project_manager/widget/ai_generating_overlay.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/auth_controller.dart';
import '../../controllers/dashboard_controller.dart';

// Theme Colors
const Color primaryColor = Color(0xFF6366F1);
const Color secondaryColor = Color(0xFF8B5CF6);
const Color accentColor = Color(0xFFEC4899);
const Color backgroundColor = Color(0xFFF5F5F5);

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final AuthController authController = Get.find<AuthController>();
  final DashboardController dashboardController =
      Get.find<DashboardController>();
  final AiImportController aiImportController = Get.find<AiImportController>();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
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

  @override
  Widget build(BuildContext context) {
    final uid = authController.currentUser?.uid;
    if (uid == null) {
      Future.microtask(() => Get.offAllNamed('/login'));
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                  child: Text(
                    "ไม่พบข้อมูลผู้ใช้",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final name = userData['name'] ?? 'ผู้ใช้งาน';
              final email = userData['email'] ?? 'ไม่มีข้อมูล';

              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: CustomScrollView(
                    slivers: [
                      _buildSliverAppBar(name),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: 32),
                            _buildWelcomeCard(name, email),
                            const SizedBox(height: 80),
                            _buildMenuGrid(),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 🔹 Modern AppBar
  Widget _buildSliverAppBar(String name) {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: primaryColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'ai-task-manager'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // _buildNotificationIcon(),
        _buildIconButton(Icons.settings_outlined, '/settings'),
        _buildLogoutButton(),
      ],
    );
  }

  Widget _buildNotificationIcon() {
    final uid = authController.currentUser?.uid;
    if (uid == null) return const SizedBox();

    final now = DateTime.now();
    final deadline = now.add(const Duration(days: 2));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('uid', isEqualTo: uid)
          .where('endDate', isGreaterThanOrEqualTo: now)
          .where('endDate', isLessThanOrEqualTo: deadline)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              onPressed: () => Get.toNamed('/notifications'),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildIconButton(IconData icon, String route) {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      onPressed: () => Get.toNamed(route),
    );
  }

  Widget _buildLogoutButton() {
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
      ),
      onPressed: () => _confirmSignOut(),
    );
  }

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('data:image')) {
      return MemoryImage(base64Decode(url.split(',')[1]));
    }
    return NetworkImage(url);
  }

  // 🔹 Welcome Card
  Widget _buildWelcomeCard(String name, String email) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Hero(
            tag: 'profile-avatar',
            child: Obx(
              () => CircleAvatar(
                radius: 40,
                backgroundImage: authController.photoURL.value.isNotEmpty
                    ? _getImageProvider(authController.photoURL.value) // 
                    : const AssetImage("assets/default_avatar.png")
                          as ImageProvider,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  "hiUser".trParams({'name': name}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  minFontSize: 12,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Greeting Text
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'good-morning'.tr;
    if (hour < 17) return 'good-afternoon'.tr;
    return 'good-evening'.tr;
  }

  // 🔹 Menu Grid - FIXED VERSION
  Widget _buildMenuGrid() {
    final List<Map<String, dynamic>> menus = [
      // {
      //   'icon': Icons.dashboard_rounded,
      //   'title': 'dashboard'.tr,
      //   'route': '/dashboard',
      //   'color': const Color(0xFF06B6D4),
      //   'description': 'view-overview'.tr,
      //   'gradient': [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
      // },
      {
        'icon': Icons.assignment_outlined,
        'title': 'tasklist'.tr,
        'route': '/tasks',
        'color': const Color(0xFF10B981),
        'description': 'manage-tasks'.tr,
        'gradient': [const Color(0xFF10B981), const Color(0xFF059669)],
      },
      {
        'icon': Icons.auto_awesome,
        'title': 'ai-import'.tr,
        'route': '/ai-import',
        'color': const Color(0xFF8B5CF6),
        'description': 'ai-assistant'.tr,
        'gradient': [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
      },
    ];

    return Column(
      children: [
        /// 🔹 Row แรก (2 ช่อง)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: menus.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisSpacing: 60,
            childAspectRatio: 3.5,
          ),
          itemBuilder: (context, index) {
            return _buildMenuItem(menus[index], index);
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    Map<String, dynamic> menu,
    int index, {
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Get.toNamed(menu['route']);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250 + index * 50),
        curve: Curves.easeOutCubic,
        width: fullWidth ? double.infinity : null,
        height: fullWidth ? 140 : null,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: menu['gradient'],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: menu['color'].withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: fullWidth
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(menu['icon'], size: 40, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: fullWidth
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  AutoSizeText(
                    menu['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    minFontSize: 12,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  AutoSizeText(
                    menu['description'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    minFontSize: 10,
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

  // 🔹 Confirm SignOut Dialog
  void _confirmSignOut() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "logout".tr,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "confirmlogout".tr,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        "cancel".tr,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        authController.signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "logout".tr,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
