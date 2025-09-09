import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();

  var isLoading = false.obs;
  var isPasswordHidden = true.obs;

  var name = "".obs;
  var photoURL = "".obs;

  // For register fields
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // For login fields
  final loginEmailController = TextEditingController();
  final loginPasswordController = TextEditingController();

  // For update password fields
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final ConfirmNewPasswordController = TextEditingController();

  var isCurrentPasswordHidden = true.obs;
  var isNewPasswordHidden = true.obs;
  var isConfirmPasswordHidden = true.obs;

  var language = 'en_US'.obs;

  User? get currentUser => _authService.currentUser;

  @override
  void onInit() {
    super.onInit();
    _listenToUserProfile();
  }

  @override
  void onClose() {
    // สำหรับ Register
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();

    // สำหรับ Login
    loginEmailController.dispose();
    loginPasswordController.dispose();

    // For updatePassword
    currentPasswordController.dispose();
    newPasswordController.dispose();
    ConfirmNewPasswordController.dispose();

    super.onClose();
  }

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

    isLoading.value = true;
    try {
      final user = currentUser;
      if (user == null) throw Exception("ไม่พบผู้ใช้ในระบบ");

      // ขั้นตอนสำคัญ: ยืนยันตัวตนอีกครั้งด้วยรหัสผ่านปัจจุบัน
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);

      // หากสำเร็จ จึงทำการเปลี่ยนรหัสผ่าน
      await user.updatePassword(newPassword);

      Get.back(); // กลับไปหน้าก่อนหน้า
      Get.snackbar('สำเร็จ', 'เปลี่ยนรหัสผ่านเรียบร้อยแล้ว');
    } on FirebaseAuthException catch (e) {
      String message = 'เกิดข้อผิดพลาด';
      if (e.code == 'wrong-password') {
        message = 'รหัสผ่านปัจจุบันไม่ถูกต้อง';
      } else if (e.code == 'weak-password') {
        message = 'รหัสผ่านใหม่อ่อนแอเกินไป';
      }
      Get.snackbar('เกิดข้อผิดพลาด', message);
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
      // ล้างค่าในช่องกรอกข้อมูลหลังทำรายการเสร็จ
      currentPasswordController.clear();
      newPasswordController.clear();
    }
  }

  // ฟัง realtime changes จาก Firestore
  void _listenToUserProfile() {
    final uid = currentUser?.uid;
    if (uid == null) return;

    FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((
      doc,
    ) {
      if (doc.exists) {
        final data = doc.data()!;
        name.value = data['name'] ?? '';
        photoURL.value = data['photoURL'] ?? '';
        language.value = data['language'] ?? 'en_US';
      }
    });
  }

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

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

    // ตัวแปร reactive จะอัปเดต UI อัตโนมัติ
    name.value = newName;
    if (newPhotoURL != null) photoURL.value = newPhotoURL;
  }

  Future<String> uploadProfileImage(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No logged-in user");

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child('${user.uid}.jpg');

    try {
      // อัปโหลดไฟล์
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;

      // ตรวจสอบว่าสถานะ success
      if (snapshot.state != TaskState.success) {
        throw Exception("Upload failed");
      }

      // ดึง download URL
      print('User UID: ${user.uid}');
      print('Storage path: profile_images/${user.uid}.jpg');
      final url = await storageRef.getDownloadURL();
      return url;
    } on FirebaseException catch (e) {
      throw Exception("Firebase Storage error: ${e.message}");
    }
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty || email.isEmpty || password.length < 6) {
      Get.snackbar(
        'Error',
        'กรุณากรอกข้อมูลให้ครบ ถูกต้อง (รหัสผ่านอย่างน้อย 6 ตัว)',
      );
      return;
    }

    try {
      isLoading.value = true;
      await _authService.registerWithEmail(
        email,
        password,
        name,
        language: 'th_TH',
      );
      _listenToUserProfile();
      Get.offAllNamed('/home');
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Register failed', e.message ?? 'เกิดข้อผิดพลาด');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> login() async {
    final email = loginEmailController.text.trim();
    final password = loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar('Error', 'กรุณากรอก Email และ Password');
      return;
    }

    try {
      isLoading.value = true;
      await _authService.loginWithEmail(email, password);
      _listenToUserProfile();
      Get.offAllNamed('/home');
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Login failed', e.message ?? 'เกิดข้อผิดพลาด');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

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
