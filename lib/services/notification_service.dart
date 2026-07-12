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

  // ── إشعار لمستخدم واحد ──
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'general',
  }) async {
    if (userId.isEmpty) return;

    await _firestore.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
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
      );
    }
  }
}
