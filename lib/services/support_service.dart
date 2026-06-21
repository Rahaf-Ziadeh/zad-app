import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';

class SupportService {
  final _db = FirebaseFirestore.instance;
  final _ns = NotificationService();

  // ── Create a new support ticket and its first message ────────────────────

  Future<String> createSupportChat({
    required String userId,
    required String userName,
    required String userRole,
    required String issueCategory,
  }) async {
    final ref = _db.collection('support_chats').doc();
    final chatId = ref.id;

    await ref.set({
      'chatId': chatId,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'issueCategory': issueCategory,
      'firstMessage': issueCategory,
      'status': 'waiting',
      'assignedAdminId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await ref.collection('messages').add({
      'senderId': userId,
      'senderRole': 'user',
      'text': issueCategory,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await _ns.notifyAdmins(
        title: 'طلب دعم جديد',
        message: '$userName: $issueCategory',
        type: 'support',
      );
    } catch (_) {}

    return chatId;
  }

  // ── Send a message and trigger the appropriate notification ───────────────

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderRole,
    required String text,
    String? chatUserId,
  }) async {
    final chatRef = _db.collection('support_chats').doc(chatId);

    await chatRef.collection('messages').add({
      'senderId': senderId,
      'senderRole': senderRole,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await chatRef.update({'updatedAt': FieldValue.serverTimestamp()});

    final preview = text.length > 60 ? '${text.substring(0, 60)}...' : text;

    try {
      if (senderRole == 'admin' && chatUserId != null) {
        await _ns.sendNotification(
          userId: chatUserId,
          title: 'رد من الإدارة',
          message: preview,
          type: 'support',
        );
      } else if (senderRole == 'user') {
        await _ns.notifyAdmins(
          title: 'رسالة دعم جديدة',
          message: preview,
          type: 'support',
        );
      }
    } catch (_) {}
  }

  // ── Admin: assign themselves and mark the chat active ────────────────────

  Future<void> assignAdmin(String chatId, String adminId) async {
    await _db.collection('support_chats').doc(chatId).update({
      'assignedAdminId': adminId,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Admin: close a chat ───────────────────────────────────────────────────

  Future<void> closeChat(String chatId, {String? chatUserId}) async {
    await _db.collection('support_chats').doc(chatId).update({
      'status': 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (chatUserId != null) {
      try {
        await _ns.sendNotification(
          userId: chatUserId,
          title: 'تم إغلاق المحادثة',
          message: 'تم إغلاق محادثة الدعم من قبل الإدارة.',
          type: 'support',
        );
      } catch (_) {}
    }
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<QuerySnapshot> getUserChats(String userId) {
    return _db
        .collection('support_chats')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Stream<QuerySnapshot> getAllChats({String? status}) {
    Query q = _db.collection('support_chats');
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots();
  }

  Stream<QuerySnapshot> getMessages(String chatId) {
    return _db
        .collection('support_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  Stream<DocumentSnapshot> getChatStream(String chatId) {
    return _db.collection('support_chats').doc(chatId).snapshots();
  }
}
