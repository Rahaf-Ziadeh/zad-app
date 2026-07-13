import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:zad_app/services/notification_service.dart';

import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fire-and-forget login log — never blocks the login flow.
  void _writeLoginLog({
    required String email,
    required String? userId,
    required String? role,
    required bool success,
    required String? reason,
  }) {
    final platform = _getPlatform();
    _firestore.collection('login_logs').add({
      'userId': userId,
      'email': email,
      'role': role,
      'success': success,
      'failureReason': success ? null : reason,
      'timestamp': FieldValue.serverTimestamp(),
      'platform': platform,
      'deviceType': _getDeviceType(platform),
    }).then<void>((_) {}, onError: (_) {});
  }

  String _getPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'unknown';
  }

  String _getDeviceType(String platform) {
    switch (platform) {
      case 'android':
      case 'ios':
        return 'mobile';
      case 'windows':
      case 'macos':
      case 'linux':
        return 'desktop';
      case 'web':
        return 'web';
      default:
        return 'unknown';
    }
  }

  Future<AppUser> login(String email, String password) async {
    // Tracks whether we already logged this attempt inside the try block,
    // so the FirebaseAuthException handler does not double-log.
    String? capturedUid;
    String? capturedRole;

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      capturedUid = uid;

      // Fetch the user doc first so we know the role before checking verification.
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        _writeLoginLog(
            email: email, userId: uid, role: null,
            success: false, reason: 'user_not_found');
        throw Exception('بيانات المستخدم غير موجودة');
      }

      final data = userDoc.data()!;
      final role = data['role'] ?? 'individual';
      capturedRole = role;

      // Email verification check — skipped for admin accounts.
      if (role != 'admin') {
        await credential.user!.reload();
        if (!(credential.user!.emailVerified)) {
          await _auth.signOut();
          _writeLoginLog(
              email: email, userId: uid, role: role,
              success: false, reason: 'email_not_verified');
          throw Exception('يرجى التحقق من بريدك الإلكتروني أولاً.');
        }
      }

      final status = data['status'] ?? 'active';
      final isApproved = data['isApproved'] ?? false;
      final isProviderRole = role == 'restaurant' || role == 'charity';
      final wasEverApproved = data['wasEverApproved'] == true;
      final verificationStatus = data['verificationStatus'] as String?;

      if (status == 'suspended') {
        _writeLoginLog(
            email: email, userId: uid, role: role,
            success: false, reason: 'suspended');
        throw Exception('تم تعليق هذا الحساب من قبل الإدارة');
      }

      final restrictedRejectedAccess = verificationStatus == 'rejected' &&
          isProviderRole &&
          wasEverApproved;

      if (status == 'rejected' && !restrictedRejectedAccess) {
        _writeLoginLog(
            email: email, userId: uid, role: role,
            success: false, reason: 'rejected');
        throw Exception('تم رفض هذا الحساب من قبل الإدارة');
      }
      if (status != 'active' && !restrictedRejectedAccess) {
        _writeLoginLog(
            email: email, userId: uid, role: role,
            success: false, reason: 'inactive');
        throw Exception('هذا الحساب غير نشط حالياً');
      }

      if (isProviderRole) {
        final vs = verificationStatus;
        final roleLabel = role == 'restaurant' ? 'المطعم' : 'الجمعية';

        final bool effectivelyApproved;
        if (vs == 'approved') {
          effectivelyApproved = true;
        } else if (vs == 'pending') {
          effectivelyApproved = isApproved;
        } else if (vs == 'rejected') {
          effectivelyApproved = restrictedRejectedAccess;
        } else {
          effectivelyApproved = isApproved;
        }

        if (!effectivelyApproved) {
          if (vs == 'rejected') {
            final reason =
                (data['rejectionReason'] as String? ?? '').trim();
            final display =
                reason.isNotEmpty ? reason : 'لا يوجد سبب محدد';
            _writeLoginLog(
                email: email, userId: uid, role: role,
                success: false, reason: 'rejected_provider');
            throw Exception(
                'REJECTED:تم رفض طلب تسجيل حساب $roleLabel. السبب: $display');
          }
          _writeLoginLog(
              email: email, userId: uid, role: role,
              success: false, reason: 'pending_approval');
          throw Exception(
              'PENDING:حساب $roleLabel بانتظار موافقة الإدارة.');
        }
      }

      _writeLoginLog(
          email: email, userId: uid, role: role,
          success: true, reason: null);
      return AppUser.fromMap(uid, data);
    } on FirebaseAuthException catch (e) {
      _writeLoginLog(
          email: email, userId: capturedUid, role: capturedRole,
          success: false, reason: e.code);
      throw Exception(_authErrorMessage(e.code));
    } catch (e) {
      // Specific failure cases above already logged — just rethrow.
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
    String? nationalId,
    double? latitude,
    double? longitude,
    String? locationSource,
    // Restaurant
    String? ownerName,
    Map<String, String>? workingHours,
    String? licenseNumber,
    String? description,
    String? logoUrl,
    String? businessLicenseUrl,
    // Charity
    String? responsiblePerson,
    String? registrationNumber,
    String? charityDocumentUrl,
  }) async {
    try {
      licenseNumber = licenseNumber?.trim();
      registrationNumber = registrationNumber?.trim();
      nationalId = nationalId?.trim();

      if (role == 'restaurant') {
        final existing = await _firestore
            .collection('restaurants')
            .where('licenseNumber', isEqualTo: licenseNumber)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          throw Exception('رقم رخصة المطعم مستخدم مسبقًا');
        }
      } else if (role == 'charity') {
        final existing = await _firestore
            .collection('charities')
            .where('registrationNumber', isEqualTo: registrationNumber)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          throw Exception('رقم تسجيل الجمعية مستخدم مسبقًا');
        }
      } else if (role == 'individual' &&
          nationalId != null &&
          nationalId.isNotEmpty) {
        final existing = await _firestore
            .collection('individuals')
            .where('nationalId', isEqualTo: nationalId)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          throw Exception('رقم الهوية مستخدم مسبقًا');
        }
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      final bool needsVerification =
          role == 'restaurant' || role == 'charity';
      final bool hasLocation = latitude != null && longitude != null;

      final batch = _firestore.batch();

      final String? photoUrl =
          (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : null;

      final userRef = _firestore.collection('users').doc(uid);
      batch.set(userRef, {
        'uid': uid,
        'name': fullName,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'status': 'active',
        'isApproved': !needsVerification,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (needsVerification) ...{
          'verificationStatus': 'pending',
          'verificationReviewedBy': null,
          'verificationReviewedAt': null,
          'rejectionReason': null,
        },
      });

      final String roleCollection = role == 'restaurant'
          ? 'restaurants'
          : role == 'charity'
              ? 'charities'
              : 'individuals';

      final Map<String, String> resolvedWorkingHours =
          workingHours ?? {'start': '', 'end': ''};

      final Map<String, dynamic> roleData;
      if (role == 'restaurant') {
        roleData = {
          'userId': uid,
          'restaurantName': fullName,
          'name': fullName,
          'ownerName': ownerName ?? '',
          'email': email,
          'phone': phone,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'workingHours': resolvedWorkingHours,
          'licenseNumber': licenseNumber ?? '',
          'description': description ?? '',
          'logoUrl': logoUrl ?? '',
          'businessLicenseUrl': businessLicenseUrl ?? '',
          'isVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
      } else if (role == 'charity') {
        roleData = {
          'userId': uid,
          'charityName': fullName,
          'name': fullName,
          'responsiblePerson': responsiblePerson ?? '',
          'email': email,
          'phone': phone,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'workingHours': resolvedWorkingHours,
          'registrationNumber': registrationNumber ?? '',
          'description': description ?? '',
          'logoUrl': logoUrl ?? '',
          'charityDocumentUrl': charityDocumentUrl ?? '',
          'isVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
      } else {
        roleData = {
          'userId': uid,
          'name': fullName,
          'address': address,
          'nationalId': nationalId ?? '',
          'latitude': latitude,
          'longitude': longitude,
          'hasLocation': hasLocation,
          'locationSource':
              latitude != null ? (locationSource ?? 'gps') : 'manual',
          'points': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }

      batch.set(_firestore.collection(roleCollection).doc(uid), roleData);
      await batch.commit();
      await credential.user?.sendEmailVerification();

      if (role == 'restaurant' || role == 'charity') {
        await NotificationService().notifyAdmins(
          title: 'حساب جديد بانتظار الموافقة',
          message: 'يوجد حساب $role جديد يحتاج مراجعة من الإدارة.',
          type: 'account',
          relatedId: uid,
          relatedRole: role,
        );
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e.code));
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Creates a new admin account without signing out the current admin session.
  // Uses a temporary secondary Firebase app that's deleted after use.
  // No verification email sent — admins are created by trusted existing admins.
  Future<void> createAdmin({
    required String fullName,
    required String email,
    required String password,
    required String createdByUid,
  }) async {
    // Unique name prevents conflicts if called concurrently
    final appName = 'adminCreation_${DateTime.now().millisecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: Firebase.app().options,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential =
          await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': fullName,
        'name': fullName,
        'email': email,
        'role': 'admin',
        'status': 'active',
        'isApproved': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': createdByUid,
      });

      await secondaryAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e.code));
    } finally {
      // Always delete secondary app to free resources
      await secondaryApp.delete();
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
