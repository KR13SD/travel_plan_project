import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart'; // 👈 สำหรับ FilteringTextInputFormatter
import '../../controllers/auth_controller.dart';

const Color primaryColor = Color(0xFF1E3A8A);
const Color secondaryColor = Color(0xFF3B82F6);

class RegisterPage extends StatelessWidget {
  final AuthController c = Get.find<AuthController>();

  RegisterPage({super.key});

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        style: GoogleFonts.kanit(fontSize: 16),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: GoogleFonts.kanit(color: Colors.grey[600], fontSize: 14),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(prefixIcon, color: primaryColor, size: 20),
          ),
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

  // Multi-select Chips
  Widget _buildTravelStyleChips() {
    return Obx(() {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: c.travelStyles.map((style) {
          final selected = c.selectedTravelStyles.contains(style);
          return FilterChip(
            selected: selected,
            label: Text(
              style.tr, // ถ้ามี key แปล, ไม่มีก็จะแสดงเดิม
              style: GoogleFonts.kanit(
                color: selected ? Colors.white : primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            checkmarkColor: Colors.white,
            selectedColor: secondaryColor,
            backgroundColor: primaryColor.withOpacity(0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (_) => c.toggleTravelStyle(style),
          );
        }).toList(),
      );
    });
  }

  // แจ้งเตือนสั้น ๆ ถ้ายังไม่เลือกสไตล์
  void _validateAndRegister() {
    final ageOk = c.ageController.text.trim().isEmpty ||
        int.tryParse(c.ageController.text.trim()) != null;
    if (!ageOk) {
      Get.snackbar('Invalid age'.tr, 'กรุณากรอกอายุเป็นตัวเลข'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (c.selectedTravelStyles.isEmpty) {
      Get.snackbar('Select at least 1 style'.tr, 'เลือกสไตล์การท่องเที่ยวอย่างน้อย 1 แบบ'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    c.register();
  }

  @override
  Widget build(BuildContext context) {
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
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'createAccountHeader'.tr,
                      style: GoogleFonts.kanit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
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
                            Text(
                              'registerTitle'.tr,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.kanit(
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.kanit(fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 40),

                            // Full Name
                            _buildTextField(
                              controller: c.nameController,
                              labelText: 'fullName'.tr,
                              prefixIcon: Icons.person_outline,
                            ),
                            const SizedBox(height: 20),

                            // Email
                            _buildTextField(
                              controller: c.emailController,
                              labelText: 'email'.tr,
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 20),

                            // Password
                            _buildTextField(
                              controller: c.passwordController,
                              labelText: 'password'.tr,
                              prefixIcon: Icons.lock_outline,
                              obscureText: c.isPasswordHidden.value,
                              suffixIcon: Container(
                                margin: const EdgeInsets.all(12),
                                child: IconButton(
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
                            ),
                            const SizedBox(height: 20),

                            // 👇 Age (optional แต่เป็นตัวเลข)
                            _buildTextField(
                              controller: c.ageController,
                              labelText: 'age'.tr, // เพิ่ม key ใน i18n: age: อายุ
                              prefixIcon: Icons.cake_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                            const SizedBox(height: 24),

                            // Travel Style (multi-select)
                            Text(
                              'travelStyleTitle'.tr, // เพิ่ม key เช่น: "สไตล์การท่องเที่ยว (เลือกได้หลายแบบ)"
                              style: GoogleFonts.kanit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTravelStyleChips(),
                            const SizedBox(height: 8),
                            Text(
                              'travelStyleHint'.tr, // เช่น "เลือกอย่างน้อย 1 แบบเพื่อช่วยให้แผนตรงใจคุณ"
                              style: GoogleFonts.kanit(fontSize: 13, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 32),

                            // Register Button
                            c.isGenerating.value
                                ? Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primaryColor.withOpacity(0.7), secondaryColor.withOpacity(0.7)],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
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
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _validateAndRegister, // 👈 ใช้ตรวจอายุ/สไตล์ก่อน
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Text(
                                        'registerButton'.tr,
                                        style: GoogleFonts.kanit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                            const SizedBox(height: 32),

                            // Back to Login
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
                                    'alreadyHaveAccount'.tr,
                                    style: GoogleFonts.kanit(color: Colors.grey[600], fontSize: 16),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text(
                                      'backToLogin'.tr,
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
