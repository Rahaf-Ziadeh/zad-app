import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zad_app/services/notification_service.dart';

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

      // ── التحقق من تأكيد البريد الإلكتروني ──
      await credential.user!.reload();
      if (!(credential.user!.emailVerified)) {
        await _auth.signOut();
        throw Exception('يرجى التحقق من بريدك الإلكتروني أولاً.');
      }

      final uid = credential.user!.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) throw Exception('بيانات المستخدم غير موجودة');

      final data = userDoc.data()!;
      final role = data['role'] ?? 'individual';
      final status = data['status'] ?? 'active';
      final isApproved = data['isApproved'] ?? false;

      if (status == 'suspended') {
        throw Exception('تم تعليق هذا الحساب من قبل الإدارة');
      }
      if (status == 'rejected') {
        throw Exception('تم رفض هذا الحساب من قبل الإدارة');
      }
      if (status != 'active') throw Exception('هذا الحساب غير نشط حالياً');

      // ── التحقق من موافقة الإدارة على المطاعم والجمعيات ──
      if (role == 'restaurant' || role == 'charity') {
        final vs = data['verificationStatus'] as String?;
        final roleLabel = role == 'restaurant' ? 'المطعم' : 'الجمعية';

        // تحديد حالة القبول الفعلية
        final bool effectivelyApproved;
        if (vs == 'approved') {
          effectivelyApproved = true;
        } else if (vs == 'rejected' || vs == 'pending') {
          effectivelyApproved = false;
        } else {
          // حساب قديم بدون verificationStatus — الرجوع إلى isApproved
          effectivelyApproved = isApproved;
        }

        if (!effectivelyApproved) {
          if (vs == 'rejected') {
            final reason = (data['rejectionReason'] as String? ?? '').trim();
            final display = reason.isNotEmpty ? reason : 'لا يوجد سبب محدد';
            throw Exception(
                'REJECTED:تم رفض طلب تسجيل حساب $roleLabel. السبب: $display');
          }
          throw Exception('PENDING:حساب $roleLabel بانتظار موافقة الإدارة.');
        }
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
      // ── تقليم الحقول التعريفية قبل التحقق من التفرّد وقبل الحفظ ──
      licenseNumber = licenseNumber?.trim();
      registrationNumber = registrationNumber?.trim();
      nationalId = nationalId?.trim();

      // ── التحقق من تفرّد الحقل التعريفي الخاص بالدور قبل إنشاء حساب Firebase Auth ──
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

      final bool needsVerification = role == 'restaurant' || role == 'charity';
      final bool hasLocation = latitude != null && longitude != null;

      final batch = _firestore.batch();

      // ── الصورة الشخصية: تُستخدم شعار المطعم/الجمعية كصورة الحساب في users ──
      final String? photoUrl =
          (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : null;

      // ── المستند العام في users: يُستخدم لتسجيل الدخول والتحقق من القبول ──
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
        // ── حقول التحقق للمطاعم والجمعيات ──
        if (needsVerification) ...{
          'verificationStatus': 'pending',
          'verificationReviewedBy': null,
          'verificationReviewedAt': null,
          'rejectionReason': null,
        },
      });

      // ── المستند التفصيلي الخاص بالدور ──
      final String roleCollection = role == 'restaurant'
          ? 'restaurants'
          : role == 'charity'
              ? 'charities'
              : 'individuals';

      // ── ساعات العمل: { start: "08:00", end: "17:00" } للمطعم والجمعية ──
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
      // ── إرسال بريد التحقق بعد إنشاء الحساب ──
      await credential.user?.sendEmailVerification();

      if (role == 'restaurant' || role == 'charity') {
        await NotificationService().notifyAdmins(
          title: 'حساب جديد بانتظار الموافقة',
          message: 'يوجد حساب $role جديد يحتاج مراجعة من الإدارة.',
          type: 'account',
        );
      }
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
