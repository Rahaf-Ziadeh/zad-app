import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/support_service.dart';
import '../../theme/app_colors.dart';
import 'admin_support_chat_screen.dart';

class AdminSupportPanel extends StatelessWidget {
  final AppUser user;

  const AdminSupportPanel({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('إدارة الدعم'),
          backgroundColor: Colors.white,
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            tabs: [
              Tab(text: 'انتظار'),
              Tab(text: 'نشطة'),
              Tab(text: 'مغلقة'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ChatList(status: 'waiting', admin: user),
            _ChatList(status: 'active', admin: user),
            _ChatList(status: 'closed', admin: user),
          ],
        ),
      ),
    );
  }
}

// ─── Per-status list ──────────────────────────────────────────────────────────

class _ChatList extends StatelessWidget {
  final String status;
  final AppUser admin;

  const _ChatList({required this.status, required this.admin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: SupportService().getAllChats(status: status),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'خطأ: ${snap.error}',
              style: const TextStyle(color: AppColors.danger),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        // Sort client-side: most recently updated first
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
                  Icons.inbox_outlined,
                  size: 56,
                  color: AppColors.textLight.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  _emptyLabel(status),
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 15,
                  ),
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
            final data = docs[i].data() as Map<String, dynamic>;
            final chatId = docs[i].id;
            return _AdminChatCard(
              chatId: chatId,
              data: data,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminSupportChatScreen(
                    chatId: chatId,
                    chatData: data,
                    admin: admin,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _emptyLabel(String status) {
    return switch (status) {
      'waiting' => 'لا توجد محادثات في الانتظار',
      'active' => 'لا توجد محادثات نشطة',
      _ => 'لا توجد محادثات مغلقة',
    };
  }
}

// ─── Chat card ────────────────────────────────────────────────────────────────

class _AdminChatCard extends StatelessWidget {
  final String chatId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _AdminChatCard({
    required this.chatId,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final userName = data['userName'] as String? ?? 'مستخدم';
    final issueCategory = data['issueCategory'] as String? ?? 'طلب دعم';
    final lastMessage = data['lastMessage'] as String? ?? '';
    final status = data['status'] as String? ?? 'waiting';
    final hasUnread = data['unreadForAdmin'] == true;

    final (statusLabel, statusColor) = switch (status) {
      'active' => ('نشطة', AppColors.success),
      'closed' => ('مغلقة', AppColors.textLight),
      _ => ('انتظار', AppColors.secondary),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread
              ? AppColors.primary.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
          ),
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    userName.isNotEmpty ? userName[0] : 'م',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                      color: AppColors.textDark,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastMessage.isNotEmpty ? lastMessage : issueCategory,
                    style: TextStyle(
                      color: hasUnread ? AppColors.textDark : AppColors.textLight,
                      fontSize: 12,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
