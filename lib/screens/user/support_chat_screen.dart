import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/support_service.dart';
import '../../theme/app_colors.dart';

class SupportChatScreen extends StatefulWidget {
  final String chatId;

  const SupportChatScreen({super.key, required this.chatId});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _svc = SupportService();
  bool _sending = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String chatUserId) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _uid == null) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await _svc.sendMessage(
        chatId: widget.chatId,
        senderId: _uid!,
        senderRole: 'user',
        text: text,
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() => _sending = false);
    _scrollToBottom();
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
        final chatData =
            chatSnap.data?.data() as Map<String, dynamic>? ?? {};
        final status = chatData['status'] as String? ?? 'waiting';
        final issueCategory =
            chatData['issueCategory'] as String? ?? 'طلب دعم';
        final chatUserId = chatData['userId'] as String? ?? '';

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
                  issueCategory,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                _StatusBadge(status: status),
              ],
            ),
          ),
          body: Column(
            children: [
              if (status == 'waiting') _WaitingBanner(),
              if (status == 'closed') _ClosedBanner(),
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
                          'لا توجد رسائل بعد',
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
                        final text =
                            data['text'] as String? ?? '';
                        final senderRole =
                            data['senderRole'] as String? ?? 'user';
                        final isMe = senderRole == 'user';
                        return _MsgBubble(text: text, isMe: isMe);
                      },
                    );
                  },
                ),
              ),
              if (status != 'closed')
                _InputBar(
                  controller: _controller,
                  sending: _sending,
                  onSend: () => _send(chatUserId),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _WaitingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.secondary.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 16,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'جميع المسؤولين مشغولون حالياً. تم تسجيل طلبك وسيتم التواصل معك لاحقاً.',
              style: TextStyle(fontSize: 12, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.border,
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textLight),
          SizedBox(width: 8),
          Text(
            'تم إغلاق هذه المحادثة.',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => ('نشطة', AppColors.success),
      'closed' => ('مغلقة', AppColors.textLight),
      _ => ('في الانتظار', AppColors.secondary),
    };
    return Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _MsgBubble extends StatelessWidget {
  final String text;
  final bool isMe;

  const _MsgBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
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
                hintText: 'اكتب رسالتك...',
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
                color: sending
                    ? AppColors.textLight
                    : AppColors.primary,
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
