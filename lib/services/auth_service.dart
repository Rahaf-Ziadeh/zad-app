import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUser> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) throw Exception('بيانات المستخدم غير موجودة');

      final data = userDoc.data()!;
      final role = data['role'] ?? 'individual';
      final status = data['status'] ?? 'active';
      final isApproved = data['isApproved'] ?? false;

      if (status == 'suspended')
        throw Exception('تم تعليق هذا الحساب من قبل الإدارة');
      if (status == 'rejected')
        throw Exception('تم رفض هذا الحساب من قبل الإدارة');
      if (status != 'active') throw Exception('هذا الحساب غير نشط حالياً');
      if ((role == 'restaurant' || role == 'charity') && !isApproved) {
        throw Exception('حسابك بانتظار موافقة الإدارة');
      }

      return AppUser.fromMap(uid, data);
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e.code));
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String role,
    required String address,
    String? nationalId, // ← جديد
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': fullName,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'address': address,
        'nationalId': nationalId ?? '', // ← يُحفظ في Firestore
        'status': 'active',
        'isApproved': role == 'individual' || role == 'admin',
        'photoUrl': null,
        'points': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e.code));
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async => await _auth.signOut();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب';
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني';
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مستخدم مسبقاً';
      case 'weak-password':
        return 'كلمة المرور ضعيفة، استخدم 6 أحرف على الأقل';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت';
      case 'too-many-requests':
        return 'محاولات كثيرة، انتظر قليلاً وأعد المحاولة';
      default:
        return 'حدث خطأ، يرجى المحاولة مرة أخرى';
    }
  }
}
