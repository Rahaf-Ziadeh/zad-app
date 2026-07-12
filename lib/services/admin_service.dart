import 'package:cloud_firestore/cloud_firestore.dart';

// ── Shared admin account state classification ──────────────────────────────
// Single classification priority used by admin_users_screen for tab filtering,
// badge labels, and action buttons. Keeps orgs and individuals consistent.
//
// Priority: suspended > rejected > pending-verification > active
//
// For restaurant/charity:
//   verificationStatus:'pending'              → pending
//   verificationStatus missing + isApproved:false → pending (legacy compat)
//   verificationStatus:'rejected'             → rejected
//   verificationStatus:'approved' or isApproved:true → active
//
// For individual/user:
//   identityVerificationStatus:'pending'  → pending
//   identityVerificationStatus:'rejected' → rejected
//   missing identityVerificationStatus    → active (no verification required yet)
//
// status:'rejected' set by AdminService.rejectUser → rejected (any role)
// status:'suspended'                               → suspended (highest priority)

enum AdminAccountState { pending, active, rejected, suspended }

AdminAccountState resolveAdminAccountState(Map<String, dynamic> data) {
  final status = data['status'] as String? ?? 'active';
  final role = data['role'] as String? ?? '';

  if (status == 'suspended') return AdminAccountState.suspended;
  if (status == 'rejected') return AdminAccountState.rejected;

  if (role == 'restaurant' || role == 'charity') {
    final vs = data['verificationStatus'] as String?;
    final isApproved = data['isApproved'] as bool? ?? false;
    if (vs == 'pending') return AdminAccountState.pending;
    // Legacy accounts without verificationStatus: fall back to isApproved
    if (vs == null && !isApproved) return AdminAccountState.pending;
    if (vs == 'rejected') return AdminAccountState.rejected;
  } else {
    final ivs = data['identityVerificationStatus'] as String?;
    if (ivs == 'pending_additional_info') return AdminAccountState.pending;
    if (ivs == 'pending') return AdminAccountState.pending;
    if (ivs == 'rejected') return AdminAccountState.rejected;
  }

  return AdminAccountState.active;
}

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getAllUsers() {
    return _firestore.collection('users').snapshots();
  }

  Stream<QuerySnapshot> getPendingUsers() {
    return _firestore
        .collection('users')
        .where('isApproved', isEqualTo: false)
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  Stream<QuerySnapshot> getOpenComplaints() {
    return _firestore
        .collection('complaints')
        .where('status', isEqualTo: 'open')
        .snapshots();
  }

  Stream<QuerySnapshot> getActiveOffers() {
    return _firestore
        .collection('offers')
        .where('status', isEqualTo: 'available')
        .snapshots();
  }

  Stream<QuerySnapshot> getPickedUpReservations() {
    return _firestore
        .collection('reservations')
        .where('status', isEqualTo: 'picked_up')
        .snapshots();
  }

  Stream<QuerySnapshot> getActiveUsersByRole(String filter) {
    Query query = _firestore
        .collection('users')
        .where('status', isEqualTo: 'active')
        .where('isApproved', isEqualTo: true);

    if (filter == 'restaurant') {
      query = query.where('role', isEqualTo: 'restaurant');
    } else if (filter == 'charity') {
      query = query.where('role', isEqualTo: 'charity');
    }

    return query.snapshots();
  }

  Stream<QuerySnapshot> getSuspendedUsersByRole(String filter) {
    Query query =
        _firestore.collection('users').where('status', isEqualTo: 'suspended');

    if (filter == 'restaurant') {
      query = query.where('role', isEqualTo: 'restaurant');
    } else if (filter == 'charity') {
      query = query.where('role', isEqualTo: 'charity');
    }

    return query.snapshots();
  }

  Stream<QuerySnapshot> getPendingUsersByRole(String filter) {
    Query query = _firestore
        .collection('users')
        .where('isApproved', isEqualTo: false)
        .where('status', isEqualTo: 'active');

    if (filter == 'restaurant') {
      query = query.where('role', isEqualTo: 'restaurant');
    } else if (filter == 'charity') {
      query = query.where('role', isEqualTo: 'charity');
    }

    return query.snapshots();
  }

  // Individual users whose identity verification is pending
  Stream<QuerySnapshot> getPendingIdentityVerificationUsers() {
    return _firestore
        .collection('users')
        .where('identityVerificationStatus', isEqualTo: 'pending')
        .snapshots();
  }

  // Broad role-filtered stream used by admin_users_screen for client-side
  // classification via resolveAdminAccountState(). Returns all users of the
  // given role so the UI can assign each doc to the correct tab in real time.
  // filter: 'restaurant' | 'charity' | 'individual' | 'all'
  Stream<QuerySnapshot> getUsersStream(String filter) {
    switch (filter) {
      case 'restaurant':
        return _firestore
            .collection('users')
            .where('role', isEqualTo: 'restaurant')
            .snapshots();
      case 'charity':
        return _firestore
            .collection('users')
            .where('role', isEqualTo: 'charity')
            .snapshots();
      case 'individual':
        return _firestore
            .collection('users')
            .where('role', whereIn: ['individual', 'user'])
            .snapshots();
      default: // 'all'
        return _firestore.collection('users').snapshots();
    }
  }

  Future<void> logAdminAction({
    required String adminId,
    required String action,
    required String reason,
    required String targetId,
    required String targetType,
  }) async {
    await _firestore.collection('admins').add({
      'adminId': adminId,
      'action': action,
      'reason': reason,
      'targetId': targetId,
      'targetType': targetType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── مجموعة التفاصيل الخاصة بدور المطعم/الجمعية إن وُجد ──
  String? _roleCollectionFor(String? role) {
    if (role == 'restaurant') return 'restaurants';
    if (role == 'charity') return 'charities';
    return null;
  }

  Future<void> approveUser(String userId, {String? role}) async {
    final batch = _firestore.batch();
    final roleCollection = _roleCollectionFor(role);
    batch.update(_firestore.collection('users').doc(userId), {
      'isApproved': true,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
      if (roleCollection != null) 'verificationStatus': 'approved',
      if (roleCollection != null) 'rejectionReason': null,
      // ── علامة دائمة لا تُعاد أبداً إلى false: تُستخدم لاحقاً للتمييز بين
      // "طلب مرفوض للمرة الأولى" (يُحظر الدخول بالكامل) و"مطعم/جمعية كان
      // معتمَداً سابقاً ثم رُفض تحديث لاحق كتعديل الرخصة" (يُسمح بدخول محدود
      // لإكمال الحجوزات القائمة) — راجع AuthService.login وmain.dart ──
      if (roleCollection != null) 'wasEverApproved': true,
    });
    if (roleCollection != null) {
      batch.set(
        _firestore.collection(roleCollection).doc(userId),
        {
          'isVerified': true,
          'verificationStatus': 'approved',
          'rejectionReason': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> rejectUser(String userId, {String? role, String? reason}) async {
    final batch = _firestore.batch();
    final roleCollection = _roleCollectionFor(role);
    final rejectionReason = reason ?? 'تم رفض الحساب من قبل الإدارة';
    batch.update(_firestore.collection('users').doc(userId), {
      'isApproved': false,
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
      if (roleCollection != null) 'verificationStatus': 'rejected',
      if (roleCollection != null) 'rejectionReason': rejectionReason,
    });
    if (roleCollection != null) {
      batch.set(
        _firestore.collection(roleCollection).doc(userId),
        {
          'isVerified': false,
          'verificationStatus': 'rejected',
          'rejectionReason': rejectionReason,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    // ── إخفاء/تعليق العروض العامة النشطة لهذا المزوّد فور الرفض (Part 9
    // item 79) — نفس المنطق المستخدم في شاشتَي مراجعة التحقق، حتى يبقى
    // السلوك متطابقاً بصرف النظر عن أي شاشة إدارية نُفِّذ الرفض منها.
    // غير حرج: فشله لا يُبطل قرار الرفض نفسه ──
    if (roleCollection != null) {
      try {
        final activeOffers = await _firestore
            .collection('offers')
            .where('providerUserId', isEqualTo: userId)
            .where('status', isEqualTo: 'available')
            .get();
        if (activeOffers.docs.isNotEmpty) {
          final offersBatch = _firestore.batch();
          for (final doc in activeOffers.docs) {
            offersBatch.update(doc.reference, {
              'status': 'closed',
              'closedDueToRejection': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          await offersBatch.commit();
        }
      } catch (_) {}
    }
  }

  Future<void> suspendUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'status': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unsuspendUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveAccount({
    required String userId,
    required String role,
    required String adminId,
  }) async {
    await approveUser(userId, role: role);

    await logAdminAction(
      adminId: adminId,
      action: 'approve_account',
      reason: 'تمت الموافقة على الحساب',
      targetId: userId,
      targetType: role,
    );
  }

  Future<void> rejectAccount({
    required String userId,
    required String role,
    required String adminId,
  }) async {
    await rejectUser(userId, role: role);

    await logAdminAction(
      adminId: adminId,
      action: 'reject_account',
      reason: 'تم رفض الحساب',
      targetId: userId,
      targetType: role,
    );
  }

  Future<void> toggleSuspendUser({
    required String userId,
    required String role,
    required String adminId,
    required bool suspend,
  }) async {
    if (suspend) {
      await suspendUser(userId);
    } else {
      await unsuspendUser(userId);
    }

    await logAdminAction(
      adminId: adminId,
      action: suspend ? 'suspend_user' : 'unsuspend_user',
      reason: suspend ? 'تم تعليق الحساب' : 'تمت إعادة تفعيل الحساب',
      targetId: userId,
      targetType: role,
    );
  }

  // ── عروض: جلب الكل مرتبة بالأحدث ──
  Stream<QuerySnapshot> getAllOffersStream() {
    return _firestore
        .collection('offers')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── عروض: حذف مع فحص الحجوزات وتسجيل الإجراء ──
  Future<void> deleteOffer({
    required String offerId,
    required String offerTitle,
    required String providerUserId,
    required String adminId,
  }) async {
    final activeReservations = await _firestore
        .collection('reservations')
        .where('offerId', isEqualTo: offerId)
        .where('status', whereIn: ['reserved', 'picked_up'])
        .get();

    if (activeReservations.docs.isNotEmpty) {
      throw Exception('لا يمكن حذف هذا العرض لأنه مرتبط بحجوزات موجودة.');
    }

    await _firestore.collection('offers').doc(offerId).delete();

    await _firestore.collection('admin_activity_logs').add({
      'actionType': 'delete_offer',
      'adminId': adminId,
      'offerId': offerId,
      'offerTitle': offerTitle,
      'providerUserId': providerUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'details': 'تم حذف العرض "$offerTitle" من قبل المسؤول',
    });
  }

  // ── جميع المستخدمين حسب الدور (بدون فلتر موافقة) ──
  Stream<QuerySnapshot> getUsersByRole(String role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots();
  }

  // ── جميع الحجوزات (مرتبة client-side لتجنب الفهرس المركب) ──
  Stream<QuerySnapshot> getAllReservations() {
    return _firestore.collection('reservations').snapshots();
  }

  // ── جميع جلسات الدعم ──
  Stream<QuerySnapshot> getSupportChats() {
    return _firestore.collection('support_chats').snapshots();
  }

  // ── جميع التقييمات ──
  Stream<QuerySnapshot> getReviews() {
    return _firestore.collection('reviews').snapshots();
  }

  Stream<QuerySnapshot> getRedistributedDonations() {
    return _firestore
        .collection('donations')
        .where('status', isEqualTo: 'redistributed')
        .snapshots();
  }

  Stream<QuerySnapshot> getPickedUpMeals() {
    return _firestore
        .collection('reservations')
        .where('status', isEqualTo: 'picked_up')
        .snapshots();
  }

  Stream<QuerySnapshot> getAdminLogs() {
    return _firestore
        .collection('admins')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  Stream<QuerySnapshot> getLoginLogs() {
    return _firestore
        .collection('login_logs')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot> getResolvedComplaints() {
    return _firestore
        .collection('complaints')
        .where('status', isEqualTo: 'resolved')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> resolveComplaint(String complaintId) async {
    await _firestore.collection('complaints').doc(complaintId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resolveComplaintWithNote({
    required String complaintId,
    required String adminId,
    String? note,
  }) async {
    await _firestore.collection('complaints').doc(complaintId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': adminId,
      if (note != null && note.trim().isNotEmpty) 'resolutionNote': note.trim(),
    });
  }

  Future<void> reopenComplaint(String complaintId) async {
    await _firestore.collection('complaints').doc(complaintId).update({
      'status': 'open',
      'reopenedAt': FieldValue.serverTimestamp(),
    });
  }
}
