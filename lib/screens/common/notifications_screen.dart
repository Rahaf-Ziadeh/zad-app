import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import 'notification_details_screen.dart';

/// شاشة إشعارات مشتركة (مطعم/جمعية/أدمن). الضغط على أي إشعار يفتح
/// [NotificationDetailsScreen] أولاً (العنوان الكامل، النص، التاريخ، حالة
/// القراءة)، وزر داخلها يفتح المحتوى المرتبط عبر [onOpenRelated] — الذي
/// يجب أن يتولى بنفسه حالة "المحتوى لم يعد موجوداً" برسالة ودّية بدل ترك
/// الإشعار بلا وجهة (لا يوجد أبداً إشعار بلا معالجة: أي نوع غير معروف يجب
/// أن يعرض onOpenRelated رسالة واضحة بدلاً من فعل لا شيء).
class NotificationsScreen extends StatelessWidget {
  final NotificationOpenHandler onOpenRelated;

  const NotificationsScreen({
    super.key,
    required this.onOpenRelated,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final notificationService = NotificationService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: notificationService.getUserNotifications(uid),
            builder: (context, snapshot) {
              final unread = (snapshot.data?.docs ?? []).where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['isRead'] != true;
              });
              if (unread.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => notificationService.markAllAsRead(uid),
                child: const Text('قراءة الكل'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationService.getUserNotifications(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('حدث خطأ أثناء تحميل الإشعارات'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 14),
                  const Text('لا توجد إشعارات حالياً',
                      style: TextStyle(color: AppColors.textLight, fontSize: 14)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['isRead'] == true;
              final title = (data['title'] as String? ?? 'إشعار');
              final message = (data['message'] as String? ?? '');

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                color: isRead ? AppColors.card : AppColors.primary.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isRead
                        ? AppColors.border
                        : AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Icon(
                    Icons.notifications_rounded,
                    color: isRead ? AppColors.textLight : AppColors.primary,
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  subtitle: Text(message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textLight)),
                  trailing: !isRead
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationDetailsScreen(
                        notificationId: doc.id,
                        data: data,
                        onOpenRelated: onOpenRelated,
                      ),
                    ),
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
