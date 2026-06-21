import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/support_service.dart';
import '../../theme/app_colors.dart';
import 'support_chat_screen.dart';

class UserSupportListScreen extends StatelessWidget {
  const UserSupportListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('محادثات الدعم'),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
      ),
      body: uid.isEmpty
          ? const Center(
              child: Text(
                'يجب تسجيل الدخول أولاً',
                style: TextStyle(color: AppColors.textLight),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: SupportService().getUserChats(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ: ${snap.error}',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];
                // Sort client-side by updatedAt descending
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTs = (aData['updatedAt'] as Timestamp?)
                          ?.millisecondsSinceEpoch ??
                      0;
                  final bTs = (bData['updatedAt'] as Timestamp?)
                          ?.millisecondsSinceEpoch ??
                      0;
                  return bTs.compareTo(aTs);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.support_agent_outlined,
                          size: 64,
                          color: AppColors.textLight.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد محادثات دعم بعد',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'استخدم المساعد الذكي للتواصل مع الإدارة',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final data =
                        docs[i].data() as Map<String, dynamic>;
                    final chatId = docs[i].id;
                    return _SupportChatCard(
                      chatId: chatId,
                      data: data,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SupportChatScreen(chatId: chatId),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _SupportChatCard extends StatelessWidget {
  final String chatId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _SupportChatCard({
    required this.chatId,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final issueCategory = data['issueCategory'] as String? ?? 'طلب دعم';
    final firstMessage = data['firstMessage'] as String? ?? '';
    final status = data['status'] as String? ?? 'waiting';

    final (statusLabel, statusColor) = switch (status) {
      'active' => ('نشطة', AppColors.success),
      'closed' => ('مغلقة', AppColors.textLight),
      _ => ('في الانتظار', AppColors.secondary),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issueCategory,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (firstMessage.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      firstMessage,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
