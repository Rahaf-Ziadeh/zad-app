import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── إشعار لمستخدم واحد. relatedId/relatedRole اختياريان: يحملان معرّف
  // السجل المرتبط (رقم حجز، معرّف عرض، معرّف مزوّد...) ودوره إن وُجد، حتى
  // تتمكن شاشة الإشعارات من فتح الصفحة المرتبطة مباشرة عند الضغط ──
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'general',
    String? relatedId,
    String? relatedRole,
  }) async {
    if (userId.isEmpty) return;

    await _firestore.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      if (relatedId != null && relatedId.isNotEmpty) 'relatedId': relatedId,
      if (relatedRole != null && relatedRole.isNotEmpty)
        'relatedRole': relatedRole,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── إشعار لمجموعة مستخدمين (batch) ──
  Future<void> sendBulkNotification({
    required List<String> userIds,
    required String title,
    required String message,
    String type = 'general',
    String? relatedId,
    String? relatedRole,
  }) async {
    if (userIds.isEmpty) return;

    final batch = _firestore.batch();
    for (final uid in userIds) {
      if (uid.isEmpty) continue;
      final ref = _firestore.collection('notifications').doc();
      batch.set(ref, {
        'userId': uid,
        'title': title,
        'message': message,
        'type': type,
        if (relatedId != null && relatedId.isNotEmpty) 'relatedId': relatedId,
        if (relatedRole != null && relatedRole.isNotEmpty)
          'relatedRole': relatedRole,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ── تمييز إشعار كمقروء ──
  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
  }

  // ── تمييز كل إشعارات مستخدم كمقروءة ──
  Future<void> markAllAsRead(String userId) async {
    final query = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> notifyAdmins({
    required String title,
    required String message,
    String type = 'account',
    String? relatedId,
    String? relatedRole,
  }) async {
    final admins = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    for (final admin in admins.docs) {
      await sendNotification(
        userId: admin.id,
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
        relatedRole: relatedRole,
      );
    }
  }

  // ── إشعار أدمن بطلب توثيق هوية — batch بمعرّف حتمي لمنع التكرار ──
  Future<void> notifyAdminsAboutIdentityVerification({
    required String userUid,
    required String userName,
  }) async {
    debugPrint('[IdentityNotification] userUid=$userUid, userName=$userName');

    final admins = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    debugPrint('[IdentityNotification] adminsFound=${admins.docs.length}');
    if (admins.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final admin in admins.docs) {
      final adminUid = admin.id;
      // Deterministic doc ID prevents duplicate notification on re-upload
      final ref = _firestore
          .collection('notifications')
          .doc('identity_${userUid}_$adminUid');
      batch.set(ref, {
        'userId': adminUid,
        'targetUserId': adminUid,
        'targetRole': 'admin',
        'title': 'طلب توثيق هوية جديد',
        'message': '$userName قام بإرفاق الوثائق المطلوبة.',
        'type': 'identity_verification_request',
        'relatedId': userUid,
        'submittedUserId': userUid,
        'submittedUserName': userName,
        'isRead': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[IdentityNotification] notificationWrittenFor=$adminUid');
    }
    await batch.commit();
  }

  // ── إشعار أدمن بشكوى جديدة — batch بمعرّف حتمي لمنع التكرار ──
  Future<void> notifyAdminsAboutComplaint({
    required String complaintId,
    required String complainantId,
    required String complainantName,
    required String complainantEmail,
    required String complaintType,
  }) async {
    debugPrint('[ComplaintNotification] complaintId=$complaintId');
    debugPrint('[ComplaintNotification] complainantId=$complainantId');

    final admins = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    debugPrint('[ComplaintNotification] adminsFound=${admins.docs.length}');
    debugPrint(
        '[ComplaintNotification] adminIds=${admins.docs.map((d) => d.id).toList()}');

    if (admins.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final admin in admins.docs) {
      final adminUid = admin.id;
      // Deterministic doc ID prevents duplicate on retry
      final ref = _firestore
          .collection('notifications')
          .doc('complaint_${complaintId}_$adminUid');
      batch.set(ref, {
        'userId': adminUid,
        'targetUserId': adminUid,
        'targetRole': 'admin',
        'title': 'شكوى جديدة',
        'message': 'تم تقديم شكوى جديدة من $complainantName',
        'type': 'new_complaint',
        'relatedId': complaintId,
        'complainantId': complainantId,
        'complainantName': complainantName,
        if (complainantEmail.isNotEmpty) 'complainantEmail': complainantEmail,
        'isRead': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[ComplaintNotification] notificationWrittenFor=$adminUid');
    }
    await batch.commit();
  }
}
