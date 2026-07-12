import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/support_service.dart';
import '../../theme/app_colors.dart';

class AdminSupportChatScreen extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> chatData;
  final AppUser admin;

  const AdminSupportChatScreen({
    super.key,
    required this.chatId,
    required this.chatData,
    required this.admin,
  });

  @override
  State<AdminSupportChatScreen> createState() =>
      _AdminSupportChatScreenState();
}

class _AdminSupportChatScreenState extends State<AdminSupportChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _svc = SupportService();
  bool _sending = false;

  String get _chatUserId =>
      widget.chatData['userId'] as String? ?? '';

  String get _chatUserName =>
      widget.chatData['userName'] as String? ?? 'مستخدم';

  @override
  void initState() {
    super.initState();
    final status = widget.chatData['status'] as String? ?? 'waiting';
    if (status == 'waiting') {
      // assignAdmin sets status→active and unreadForAdmin→false
      _svc.assignAdmin(widget.chatId, widget.admin.uid);
    } else {
      // For active chats, just clear the unread flag
      _svc.markReadByAdmin(widget.chatId);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await _svc.sendMessage(
        chatId: widget.chatId,
        senderId: widget.admin.uid,
        senderRole: 'admin',
        text: text,
        chatUserId: _chatUserId,
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _confirmClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق المحادثة'),
        content: Text(
          'هل تريد إغلاق محادثة "$_chatUserName"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await _svc.closeChat(widget.chatId, chatUserId: _chatUserId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _svc.getChatStream(widget.chatId),
      builder: (context, chatSnap) {
        final liveData =
            chatSnap.data?.data() as Map<String, dynamic>? ??
                widget.chatData;
        final status = liveData['status'] as String? ?? 'waiting';
        final issueCategory =
            liveData['issueCategory'] as String? ?? 'طلب دعم';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _chatUserName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  issueCategory,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
            actions: [
              if (status != 'closed')
                TextButton.icon(
                  onPressed: _confirmClose,
                  icon: const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppColors.danger,
                  ),
                  label: const Text(
                    'إغلاق',
                    style: TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              _StatusBar(status: status),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _svc.getMessages(widget.chatId),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final docs = snap.data!.docs;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients &&
                          _scrollController.position.maxScrollExtent > 0) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'لا توجد رسائل',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data =
                            docs[i].data() as Map<String, dynamic>;
                        final text = data['text'] as String? ?? '';
                        final senderRole =
                            data['senderRole'] as String? ?? 'user';
                        // From admin's perspective, 'admin' messages are "mine"
                        final isMe = senderRole == 'admin';
                        return _MsgBubble(
                          text: text,
                          isMe: isMe,
                          senderRole: senderRole,
                        );
                      },
                    );
                  },
                ),
              ),
              if (status != 'closed')
                _InputBar(
                  controller: _controller,
                  sending: _sending,
                  onSend: _send,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final String status;
  const _StatusBar({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'active' => ('محادثة نشطة', AppColors.success, Icons.circle),
      'closed' => ('محادثة مغلقة', AppColors.textLight, Icons.lock_outline_rounded),
      _ => ('في الانتظار', AppColors.secondary, Icons.hourglass_top_rounded),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MsgBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String senderRole;

  const _MsgBubble({
    required this.text,
    required this.isMe,
    required this.senderRole,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
            child: Text(
              isMe ? 'أنت (إدارة)' : 'المستخدم',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textLight,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textDark,
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'اكتب ردك هنا...',
                hintTextDirection: TextDirection.rtl,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: sending ? AppColors.textLight : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
