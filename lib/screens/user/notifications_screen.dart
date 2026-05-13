import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Stream<QuerySnapshot> _notificationsStream() {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  IconData _iconByType(String type) {
    switch (type) {
      case 'reservation':
        return Icons.shopping_bag_rounded;
      case 'pickup':
        return Icons.qr_code_rounded;
      case 'donation':
        return Icons.volunteer_activism_rounded;
      case 'account':
        return Icons.verified_user_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الإشعارات"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("حدث خطأ أثناء تحميل الإشعارات"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                "لا توجد إشعارات حالياً",
                style: TextStyle(color: AppColors.textLight),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'إشعار';
              final message = data['message'] ?? '';
              final type = data['type'] ?? 'general';
              final isRead = data['isRead'] ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isRead ? AppColors.card : AppColors.primary.withOpacity(0.08),
                child: ListTile(
                  onTap: () => _markAsRead(doc.id),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: Icon(
                      _iconByType(type),
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(message),
                  trailing: isRead
                      ? const Icon(Icons.done_rounded, color: AppColors.textLight)
                      : const Icon(Icons.circle, size: 12, color: AppColors.primary),
                ),
              );
            },
          );
        },
      ),
    );
  }
}