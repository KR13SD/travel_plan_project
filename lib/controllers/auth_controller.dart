import 'dart:io';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  // UI states
  var isGenerating = false.obs;
  var isPasswordHidden = true.obs;

  // Profile basics
  var name = "".obs;
  var photoURL = "".obs;
  var language = 'en_US'.obs;

  // ====== Register fields ======
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // New: Age & Travel styles (multi-select)
  final ageController = TextEditingController();
  final RxSet<String> selectedTravelStyles = <String>{}.obs;

  // Options for travel styles
  final List<String> travelStyles = [
    'nature'.tr,
    'culture'.tr,
    'foodie'.tr,
    'adventure'.tr,
    'relax'.tr,
    'shopping'.tr,
    'nightlife'.tr,
    'photography'.tr,
    'roadtrip'.tr,
    'family-friendly'.tr,
    'budget'.tr,
    'luxury'.tr,
  ];

  // ====== Login fields ======
  final loginEmailController = TextEditingController();
  final loginPasswordController = TextEditingController();

  // ====== Update password fields ======
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final ConfirmNewPasswordController = TextEditingController();

  var isCurrentPasswordHidden = true.obs;
  var isNewPasswordHidden = true.obs;
  var isConfirmPasswordHidden = true.obs;

  User? get currentUser => _authService.currentUser;

  @override
  void onInit() {
    super.onInit();
    _listenToUserProfile();
  }

  @override
  void onClose() {
    // Register
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    ageController.dispose();

    // Login
    loginEmailController.dispose();
    loginPasswordController.dispose();

    // Update password
    currentPasswordController.dispose();
    newPasswordController.dispose();
    ConfirmNewPasswordController.dispose();

    super.onClose();
  }

  // ====== Travel styles helpers ======
  void toggleTravelStyle(String style) {
    if (selectedTravelStyles.contains(style)) {
      selectedTravelStyles.remove(style);
    } else {
      selectedTravelStyles.add(style);
    }
  }

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  // ====== Password update ======
  Future<void> updatePassword() async {
    final currentPassword = currentPasswordController.text;
    final newPassword = newPasswordController.text;
    final confirmPassword = ConfirmNewPasswordController.text;

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      Get.snackbar('Error', 'กรุณากรอกรหัสผ่านปัจจุบันและรหัสผ่านใหม่');
      return;
    }
    if (newPassword.length < 6) {
      Get.snackbar('Error', 'รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร');
      return;
    }
    if (newPassword != confirmPassword) {
      Get.snackbar('Error', 'รหัสผ่านใหม่และการยืนยันไม่ตรงกัน');
      return;
    }

    isGenerating.value = true;
    try {
      final user = currentUser;
      if (user == null) throw Exception("ไม่พบผู้ใช้ในระบบ");

      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);

      Get.back();
      Get.snackbar('สำเร็จ', 'เปลี่ยนรหัสผ่านเรียบร้อยแล้ว');
    } on FirebaseAuthException catch (e) {
      String message = 'เกิดข้อผิดพลาด';
      if (e.code == 'wrong-password')
        message = 'รหัสผ่านปัจจุบันไม่ถูกต้อง';
      else if (e.code == 'weak-password')
        message = 'รหัสผ่านใหม่อ่อนแอเกินไป';
      Get.snackbar('เกิดข้อผิดพลาด', message);
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isGenerating.value = false;
      currentPasswordController.clear();
      newPasswordController.clear();
    }
  }

  // ====== Firestore profile listener ======
  void _listenToUserProfile() {
    final uid = currentUser?.uid;
    if (uid == null) return;

    FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((
      doc,
    ) {
      if (!doc.exists) return;
      final data = doc.data()!;
      name.value = data['name'] ?? '';
      photoURL.value = data['photoURL'] ?? '';
      language.value = data['language'] ?? 'en_US';

      // optional read-back (ถ้าจะ sync สู่ UI ส่วนอื่นภายหลัง)
      final intAge = data['age'];
      if (intAge is int) {
        // ไม่ใส่ลง ageController เพื่อไม่รบกวนฟอร์มระหว่างพิมพ์
      }
      final styles = data['travelStyles'];
      if (styles is List) {
        selectedTravelStyles
          ..clear()
          ..addAll(styles.whereType<String>());
      }
    });
  }

  // ====== Profile update (basic) ======
  Future<void> updateProfile({
    required String newName,
    String? newPhotoURL,
  }) async {
    final user = currentUser;
    if (user == null) return;

    await _authService.updateUserProfile(
      uid: user.uid,
      name: newName,
      photoURL: newPhotoURL,
    );

    name.value = newName;
    if (newPhotoURL != null) photoURL.value = newPhotoURL;
  }

  // ====== Upload profile image ======
  Future<String> uploadProfileImage(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No logged-in user");

    final bytes = await imageFile.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  // ====== Register with extra fields (age + travelStyles) ======
  Future<void> register() async {
    final fullName = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final ageText = ageController.text.trim();

    if (fullName.isEmpty || email.isEmpty || password.length < 6) {
      Get.snackbar(
        'Error',
        'กรุณากรอกข้อมูลให้ครบ ถูกต้อง (รหัสผ่านอย่างน้อย 6 ตัว)',
      );
      return;
    }
    // age optional แต่ต้องเป็นตัวเลขถ้ากรอก
    if (ageText.isNotEmpty && int.tryParse(ageText) == null) {
      Get.snackbar('Invalid age', 'กรุณากรอกอายุเป็นตัวเลข');
      return;
    }
    if (selectedTravelStyles.isEmpty) {
      Get.snackbar(
        'Select at least 1 style',
        'เลือกสไตล์การท่องเที่ยวอย่างน้อย 1 แบบ',
      );
      return;
    }

    try {
      isGenerating.value = true;

      // สมัคร + สร้างเอกสารหลัก (ตามที่ AuthService จัดการ)
      await _authService.registerWithEmail(
        email,
        password,
        fullName,
        language: 'th_TH',
      );

      // เติมฟิลด์เฉพาะ (merge เพื่อไม่ทับของเดิมที่ AuthService อาจสร้างไว้)
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final int? ageVal = ageText.isEmpty ? null : int.tryParse(ageText);
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': fullName,
          'email': email,
          'age': ageVal,
          'travelStyles': selectedTravelStyles.toList(),
          'language': 'th_TH',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _listenToUserProfile();
      Get.offAllNamed('/home');
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Register failed', e.message ?? 'เกิดข้อผิดพลาด');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isGenerating.value = false;
    }
  }

  // ====== Login ======
  Future<void> login() async {
    final email = loginEmailController.text.trim();
    final password = loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar('Error', 'กรุณากรอก Email และ Password');
      return;
    }

    try {
      isGenerating.value = true;
      await _authService.loginWithEmail(email, password);
      _listenToUserProfile();
      Get.offNamed('/home');
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Login failed', e.message ?? 'เกิดข้อผิดพลาด');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isGenerating.value = false;
    }
  }

  // ====== Sign out ======
  Future<void> signOut() async {
    await _authService.signOut();
    Get.offAllNamed('/login');
    Get.snackbar(
      "ออกจากระบบสำเร็จ",
      "คุณได้ออกจากระบบเรียบร้อยแล้ว",
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
    );
  }
}
