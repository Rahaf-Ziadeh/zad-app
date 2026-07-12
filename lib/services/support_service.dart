import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_service.dart';

class SupportService {
  final _db = FirebaseFirestore.instance;
  final _ns = NotificationService();

  // ── Create a new support ticket and its first message. userEmail is
  // optional (anonymous/legacy callers may not have one) but is always
  // written to the parent doc so admins can see the requester's email
  // without an extra users/{uid} read ──────────────────────────────────────

  Future<String> createSupportChat({
    required String userId,
    required String userName,
    required String userRole,
    required String issueCategory,
    String? userEmail,
  }) async {
    final ref = _db.collection('support_chats').doc();
    final chatId = ref.id;

    await ref.set({
      'chatId': chatId,
      'userId': userId,
      'userName': userName,
      if (userEmail != null && userEmail.isNotEmpty) 'userEmail': userEmail,
      'userRole': userRole,
      'issueCategory': issueCategory,
      'firstMessage': issueCategory,
      'lastMessage': issueCategory,
      'status': 'waiting',
      'assignedAdminId': null,
      'unreadForAdmin': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await ref.collection('messages').add({
      'senderId': userId,
      'senderRole': 'user',
      'text': issueCategory,
      'isReadByAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await _ns.notifyAdmins(
        title: 'طلب دعم جديد',
        message: '$userName: $issueCategory',
        type: 'support',
        relatedId: chatId,
      );
    } catch (_) {}

    return chatId;
  }

  // ── يبحث عن محادثة دعم مفتوحة (غير مغلقة) لنفس المستخدم لتفادي إنشاء
  // أكثر من محادثة مفتوحة واحدة في نفس الوقت؛ فلتر مساواة وحيد (بلا orderBy)
  // لتفادي فهرس مركّب، والفرز/الاختيار يتم على العميل ──
  Future<String?> findOpenChatId(String userId) async {
    final snap =
        await _db.collection('support_chats').where('userId', isEqualTo: userId).get();
    final openDocs = snap.docs.where((d) {
      final status = (d.data()['status'] as String?) ?? 'waiting';
      return status != 'closed';
    }).toList();
    if (openDocs.isEmpty) return null;
    openDocs.sort((a, b) {
      final at = (a.data()['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bt = (b.data()['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at);
    });
    return openDocs.first.id;
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

    final isUserMsg = senderRole == 'user';

    await chatRef.collection('messages').add({
      'senderId': senderId,
      'senderRole': senderRole,
      'text': text,
      'isReadByAdmin': !isUserMsg,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await chatRef.update({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': text.length > 80 ? '${text.substring(0, 80)}…' : text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      if (isUserMsg) 'unreadForAdmin': true,
      if (!isUserMsg) 'unreadForAdmin': false,
    });

    final preview = text.length > 60 ? '${text.substring(0, 60)}...' : text;

    try {
      if (senderRole == 'admin' && chatUserId != null) {
        await _ns.sendNotification(
          userId: chatUserId,
          title: 'رد من الإدارة',
          message: preview,
          type: 'support',
          relatedId: chatId,
        );
      } else if (senderRole == 'user') {
        await _ns.notifyAdmins(
          title: 'رسالة دعم جديدة',
          message: preview,
          type: 'support',
          relatedId: chatId,
        );
      }
    } catch (_) {}
  }

  // ── Admin: assign themselves and mark the chat active ────────────────────

  Future<void> assignAdmin(String chatId, String adminId) async {
    await _db.collection('support_chats').doc(chatId).update({
      'assignedAdminId': adminId,
      'status': 'active',
      'unreadForAdmin': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markReadByAdmin(String chatId) async {
    await _db
        .collection('support_chats')
        .doc(chatId)
        .update({'unreadForAdmin': false});
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
          relatedId: chatId,
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
