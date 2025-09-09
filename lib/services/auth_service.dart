import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance; 

  User? get currentUser => _auth.currentUser;

  // ฟังก์ชันอัปเดตชื่อและรูปโปรไฟล์
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    String? photoURL,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // อัปเดต Firebase Auth
    await user.updateDisplayName(name);
    if (photoURL != null) {
      await user.updatePhotoURL(photoURL);
    }
    await user.reload(); // รีเฟรช user info

    // อัปเดต Firestore
    await _db.collection('users').doc(uid).set({
     'displayName': name,
      if (photoURL != null) 'photoURL': photoURL,
    }, SetOptions(merge: true));
  } 

  Future<UserCredential> registerWithEmail(String email, String password, String name, {String language = 'en_US'}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    // เก็บข้อมูลเพิ่มเติมใน Firestore
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name,
      'email': email,
      'language': language,
      'created_at': FieldValue.serverTimestamp(),
    });
    return cred;
  }

  Future<UserCredential> loginWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

}