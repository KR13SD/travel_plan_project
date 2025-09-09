import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/auth_controller.dart';
import '../../services/localization_service.dart';

const Color primaryColor = Color(0xFF1E3A8A);
const Color secondaryColor = Color(0xFF3B82F6);

class LoginPage extends StatelessWidget {
  final AuthController c = Get.put(AuthController());
  final LocalizationService ls = Get.find<LocalizationService>();

  LoginPage({super.key});

  // ข้อมูล test user
  final Map<String, String> testUser1 = {
    'email': 'arjin@momomail.coco',
    'password': '111111',
  };
  final Map<String, String> testUser2 = {
    'email': 'aka@mail.com',
    'password': '123456',
  };

  void fillTestUser(Map<String, String> user) {
    c.loginEmailController.text = user['email']!;
    c.loginPasswordController.text = user['password']!;
  }

  // แผนที่ธง
  String _flagOf(Locale locale) {
    const flagMap = {
      'US': '🇺🇸',
      'TH': '🇹🇭',
    };
    return flagMap[locale.countryCode] ?? '🌐';
  }

  // แสดง bottom sheet เลือกภาษา
  void _showLanguageSheet(BuildContext context) {
    final locales = LocalizationService.locales;
    final langs = LocalizationService.langs;
    final current = ls.currentLocale.value;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                height: 4, width: 42,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'chooseLanguage'.tr,
                style: GoogleFonts.kanit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(locales.length, (i) {
                final l = locales[i];
                final name = langs[i];
                final isSelected = l == current;
                return ListTile(
                  leading: Text(_flagOf(l), style: const TextStyle(fontSize: 22)),
                  title: Text(
                    name,
                    style: GoogleFonts.kanit(
                      fontSize: 16,
                      color: isSelected ? primaryColor : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: primaryColor)
                      : const Icon(Icons.circle_outlined, color: Colors.grey),
                  onTap: () {
                    final code = "${l.languageCode}_${l.countryCode}";
                    ls.changeLocale(code);
                    Get.back();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('languageChanged'.tr.replaceAll('{lang}', name)),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: GoogleFonts.kanit(fontSize: 16),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: GoogleFonts.kanit(color: Colors.grey[600], fontSize: 14),
          prefixIcon: Icon(prefixIcon, color: primaryColor, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ls.currentLocale.value;
    final flag = _flagOf(currentLocale);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor,
              primaryColor.withOpacity(0.8),
              secondaryColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'appName'.tr,
                      style: GoogleFonts.kanit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        tooltip: 'chooseLanguage'.tr,
                        onPressed: () => _showLanguageSheet(context),
                        icon: Text(flag, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Obx(
                        () => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            
                            // Title
                            Text(
                              'loginTitle'.tr,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.kanit(
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                                color: primaryColor,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            Text(
                              'กรุณาเข้าสู่ระบบเพื่อเริ่มต้นใช้งาน',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.kanit(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Email Field
                            _buildTextField(
                              controller: c.loginEmailController,
                              labelText: 'email'.tr,
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Password Field
                            _buildTextField(
                              controller: c.loginPasswordController,
                              labelText: 'password'.tr,
                              prefixIcon: Icons.lock_outline,
                              obscureText: c.isPasswordHidden.value,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  c.isPasswordHidden.value
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: primaryColor,
                                  size: 20,
                                ),
                                onPressed: c.togglePasswordVisibility,
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Login Button
                            c.isLoading.value
                                ? Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primaryColor.withOpacity(0.7), secondaryColor.withOpacity(0.7)],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  )
                                : Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primaryColor, secondaryColor],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: c.login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        'login'.tr,
                                        style: GoogleFonts.kanit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                            
                            const SizedBox(height: 24),
                            
                            // Test User Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => fillTestUser(testUser1),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[50],
                                      foregroundColor: Colors.blue[700],
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: Colors.blue[200]!),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text(
                                      'testUser1'.tr,
                                      style: GoogleFonts.kanit(fontSize: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => fillTestUser(testUser2),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[50],
                                      foregroundColor: Colors.green[700],
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: Colors.green[200]!),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text(
                                      'testUser2'.tr,
                                      style: GoogleFonts.kanit(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Register Link
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'noAccount'.tr,
                                    style: GoogleFonts.kanit(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Get.toNamed('/register'),
                                    child: Text(
                                      'register'.tr,
                                      style: GoogleFonts.kanit(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}