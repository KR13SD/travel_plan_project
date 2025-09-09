import 'package:ai_task_project_manager/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingPage extends StatelessWidget {
  SettingPage({super.key});

  final AuthController _authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "settings".tr,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildSectionTitle("account".tr),
            const SizedBox(height: 8),
            _buildSettingsCard([
              _buildSettingsTile(
                icon: Icons.person_outline_rounded,
                title: "profile_info".tr,
                subtitle: "profile_info_sub".tr,
                onTap: () => Get.toNamed('/profile-detail'),
                iconColor: Colors.blue,
                iconBg: Colors.blue.shade50,
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.lock_outline_rounded,
                title: "change_password".tr,
                subtitle: "change_password_sub".tr,
                onTap: () => Get.toNamed('/change-password'),
                iconColor: Colors.orange,
                iconBg: Colors.orange.shade50,
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.logout_rounded,
                title: "logout".tr,
                subtitle: "confirm_logout".tr,
                onTap: () => _showLogoutDialog(),
                iconColor: Colors.red,
                iconBg: Colors.red.shade50,
              ),
            ]),

            const SizedBox(height: 24),

            // Support Section
            _buildSectionTitle("support".tr),
            const SizedBox(height: 8),
            _buildSettingsCard([
              _buildSettingsTile(
                icon: Icons.support_agent_rounded,
                title: "contact_support".tr,
                subtitle: "contact_support_sub".tr,
                onTap: () => Get.toNamed('/contact-support'),
                iconColor: Colors.green,
                iconBg: Colors.green.shade50,
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.info_outline_rounded,
                title: "about_app".tr,
                subtitle: "about_app_sub".tr,
                onTap: () => Get.toNamed('/about-app'),
                iconColor: Colors.purple,
                iconBg: Colors.purple.shade50,
              ),
            ]),

            const SizedBox(height: 24),

            // Additional Settings Section
            _buildSectionTitle("other_settings".tr),
            const SizedBox(height: 8),
            _buildSettingsCard([
              _buildSettingsTile(
                icon: Icons.language_rounded,
                title: "language".tr,
                subtitle: "language_sub".tr,
                onTap: () => Get.toNamed('/change-language'),
                iconColor: Colors.indigo,
                iconBg: Colors.indigo.shade50,
              ),
            ]),

            const SizedBox(height: 24),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "logout".tr,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
          content: Text(
          "confirmlogout".tr,
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              "cancel".tr,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _authController.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              "logout".tr,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
    required Color iconBg,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: Colors.grey[100],
    );
  }
}
