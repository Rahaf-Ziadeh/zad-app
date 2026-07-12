import 'package:cloud_firestore/cloud_firestore.dart';

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
}
