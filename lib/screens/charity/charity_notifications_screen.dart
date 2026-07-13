import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/charity_data_service.dart';
import '../../services/charity_helper_service.dart';
import '../../theme/app_colors.dart';
import 'charity_donations_screen.dart';
import 'charity_publish_surplus_screen.dart';
import 'charity_reservations_screen.dart';

class CharityNotificationsScreen extends StatelessWidget {
  CharityNotificationsScreen({super.key});

  final CharityDataService _dataService = CharityDataService();
  final CharityHelperService _helperService = const CharityHelperService();

  Future<void> _handleTap(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>;

    if (data['isRead'] != true) {
      await _dataService.markNotificationAsRead(doc.id);
    }

    if (!context.mounted) return;

    _navigate(
      context,
      (data['type'] ?? '').toString(),
      data,
    );
  }

  void _navigate(
    BuildContext context,
    String type,
    Map<String, dynamic> data,
  ) {
    switch (type) {
      case 'donation':
      case 'new_donation':
      case 'donation_received':
      case 'donation_pending':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CharityDonationsScreen(initialTab: 0),
          ),
        );

      case 'donation_approved':
      case 'donation_status':
      case 'donation_updated':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CharityDonationsScreen(initialTab: 1),
          ),
        );

      case 'donation_redistributed':
      case 'surplus_published':
      case 'offer_published':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CharityPublishSurplusScreen(),
          ),
        );

      case 'reservation':
      case 'new_reservation':
      case 'reservation_created':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CharityReservationsScreen(),
          ),
        );

      case 'account':
      case 'verification_approved':
      case 'verification_rejected':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'انتقل إلى الملف الشخصي لعرض تفاصيل التحقق',
            ),
          ),
        );

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _dataService.watchNotifications(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final hasUnread = snapshot.data!.docs.any((document) {
                final data = document.data() as Map<String, dynamic>;

                return data['isRead'] != true;
              });

              if (!hasUnread) {
                return const SizedBox.shrink();
              }

              return TextButton(
                onPressed: () => _dataService.markAllNotificationsAsRead(
                  snapshot.data!.docs,
                ),
                child: const Text('قراءة الكل'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dataService.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'حدث خطأ أثناء تحميل الإشعارات',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final notifications = _helperService.sortNotifications(
            snapshot.data!.docs,
          );

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'لا توجد إشعارات حالياً',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                    ),
                  ),
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

              final title = (data['title'] ?? 'إشعار').toString();

              final message = (data['message'] ?? '').toString();

              final type = (data['type'] ?? 'general').toString();

              final isRead = data['isRead'] == true;

              final createdAt = data['createdAt'] as Timestamp?;

              final color = _helperService.notificationColor(type);

              return GestureDetector(
                onTap: () => _handleTap(context, doc),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        isRead ? AppColors.card : color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isRead
                          ? AppColors.border
                          : color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: 0.12,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _helperService.notificationIcon(type),
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.w500
                                          : FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                if (!isRead) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(
                                        8,
                                      ),
                                    ),
                                    child: const Text(
                                      'جديد',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 4),
                                Text(
                                  _helperService.notificationTimeAgo(
                                    createdAt,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
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
