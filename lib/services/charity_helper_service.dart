import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/theme/app_colors.dart';

class CharityHelperService {
  const CharityHelperService();

  String donationStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'مقبول';

      case 'rejected':
        return 'مرفوض';

      case 'redistributed':
        return 'تم توزيعه';

      default:
        return status;
    }
  }

  List<QueryDocumentSnapshot> sortNotifications(
    List<QueryDocumentSnapshot> documents,
  ) {
    final notifications = List<QueryDocumentSnapshot>.from(documents);

    notifications.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;

      final bData = b.data() as Map<String, dynamic>;

      final aRead = aData['isRead'] == true;

      final bRead = bData['isRead'] == true;

      if (aRead != bRead) {
        return aRead ? 1 : -1;
      }

      final aTime = aData['createdAt'] as Timestamp?;

      final bTime = bData['createdAt'] as Timestamp?;

      if (aTime == null && bTime == null) {
        return 0;
      }

      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return notifications;
  }

  IconData notificationIcon(String type) {
    switch (type) {
      case 'donation':
      case 'new_donation':
      case 'donation_received':
      case 'donation_pending':
      case 'donation_approved':
      case 'donation_status':
      case 'donation_updated':
      case 'donation_redistributed':
        return Icons.volunteer_activism_rounded;

      case 'surplus_published':
      case 'offer_published':
        return Icons.share_rounded;

      case 'reservation':
      case 'new_reservation':
      case 'reservation_created':
        return Icons.receipt_long_rounded;

      case 'account':
      case 'verification_approved':
      case 'verification_rejected':
        return Icons.verified_user_rounded;

      case 'complaint':
      case 'support_message':
      case 'admin_reply':
        return Icons.report_problem_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  Color notificationColor(String type) {
    switch (type) {
      case 'donation':
      case 'new_donation':
      case 'donation_received':
      case 'donation_pending':
        return const Color(0xFFE11D48);

      case 'donation_approved':
      case 'donation_status':
      case 'donation_updated':
        return AppColors.success;

      case 'donation_redistributed':
      case 'surplus_published':
      case 'offer_published':
        return AppColors.primary;

      case 'reservation':
      case 'new_reservation':
      case 'reservation_created':
        return const Color(0xFF0EA5E9);

      case 'account':
      case 'verification_approved':
      case 'verification_rejected':
        return AppColors.secondary;

      case 'complaint':
      case 'support_message':
      case 'admin_reply':
        return AppColors.danger;

      default:
        return AppColors.textLight;
    }
  }

  String notificationTimeAgo(
    Timestamp? timestamp,
  ) {
    if (timestamp == null) {
      return '';
    }

    final difference = DateTime.now().difference(
      timestamp.toDate(),
    );

    if (difference.inMinutes < 1) {
      return 'الآن';
    }

    if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    }

    if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    }

    if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    }

    final date = timestamp.toDate();

    return '${date.day}/${date.month}/${date.year}';
  }

  TimeOfDay? parseTime(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) {
      return null;
    }

    final parts = hhmm.split(':');

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }

  String formatTimeOfDay(
    TimeOfDay time,
  ) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
