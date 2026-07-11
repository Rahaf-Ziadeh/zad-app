import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  final void Function(BuildContext context, Map<String, dynamic> data)?
      onNotificationTap;

  const NotificationsScreen({
    super.key,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final notificationService = NotificationService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
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
            return const Center(child: Text('لا توجد إشعارات حالياً'));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;

              final isRead = data['isRead'] == true;

              return ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: isRead ? Colors.grey : Colors.green,
                ),
                title: Text(
                  data['title'] ?? '',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(data['message'] ?? ''),
                onTap: () async {
                  await notificationService.markAsRead(doc.id);

                  if (!context.mounted) return;

                  if (onNotificationTap != null) {
                    onNotificationTap!(context, data);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
