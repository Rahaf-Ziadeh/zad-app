import '../../services/notification_service.dart';
class CharityNotificationService {
  final NotificationService _notificationService = NotificationService();

  Future<void> sendDonationStatusNotification({
    required String userId,
    required String status,
    required String foodName,
    String? donationId,
  }) async {
    final notification = _buildNotification(status, foodName);

    await _notificationService.sendNotification(
      userId: userId,
      title: notification.title,
      message: notification.message,
      type: 'donation',
      relatedId: donationId,
    );
  }

  _DonationNotification _buildNotification(String status, String foodName) {
    switch (status) {
      case 'approved':
        return _DonationNotification(
          title: 'تم قبول تبرعك ✅',
          message: 'وافقت الجمعية على تبرعك "$foodName". شكراً لك!',
        );

      case 'rejected':
        return _DonationNotification(
          title: 'تم رفض التبرع',
          message: 'عذراً، تم رفض تبرعك "$foodName".',
        );

      case 'redistributed':
        return _DonationNotification(
          title: 'تم توزيع تبرعك ❤️',
          message: 'تم توزيع تبرعك "$foodName" على المستفيدين. جزاك الله خيراً!',
        );

      default:
        return _DonationNotification(
          title: 'تحديث على تبرعك',
          message: 'تم تحديث حالة تبرعك "$foodName".',
        );
    }
  }
}

class _DonationNotification {
  final String title;
  final String message;

  const _DonationNotification({
    required this.title,
    required this.message,
  });
}