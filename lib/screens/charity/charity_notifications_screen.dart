import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import 'charity_donations_screen.dart';
import 'charity_publish_surplus_screen.dart';
import 'charity_reservations_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// شاشة إشعارات الجمعية — قراءة/غير مقروء، تصفح حسب النوع
// ─────────────────────────────────────────────────────────────────────────────
class CharityNotificationsScreen extends StatelessWidget {
  const CharityNotificationsScreen({super.key});

  // No orderBy here — client-side sort avoids composite-index issues on old docs
  Stream<QuerySnapshot> _stream(String uid) => FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .snapshots();

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isRead'] != true) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<void> _handleTap(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    if (data['isRead'] != true) {
      await NotificationService().markAsRead(doc.id);
    }
    if (!context.mounted) return;
    _navigate(context, (data['type'] ?? '').toString(), data);
  }

  void _navigate(
    BuildContext context,
    String type,
    Map<String, dynamic> data,
  ) {
    switch (type) {
      // ── تبرع جديد بانتظار المراجعة ──
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

      // ── تبرع مقبول / تم تحديث حالته ──
      case 'donation_approved':
      case 'donation_status':
      case 'donation_updated':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CharityDonationsScreen(initialTab: 1),
          ),
        );

      // ── تم إعادة توزيع الفائض / نشر عرض ──
      case 'donation_redistributed':
      case 'surplus_published':
      case 'offer_published':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CharityPublishSurplusScreen(),
          ),
        );

      // ── حجز جديد على عرض الجمعية ──
      case 'reservation':
      case 'new_reservation':
      case 'reservation_created':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CharityReservationsScreen(),
          ),
        );

      // ── حالة التحقق من الحساب ──
      case 'account':
      case 'verification_approved':
      case 'verification_rejected':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('انتقل إلى الملف الشخصي لعرض تفاصيل التحقق'),
          ),
        );

      default:
        // لا وجهة محددة — تبقى على الشاشة
        break;
    }
  }

  IconData _iconByType(String type) {
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

  Color _colorByType(String type) {
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

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    final d = timestamp.toDate();
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _stream(uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final hasUnread = snapshot.data!.docs.any((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['isRead'] != true;
              });
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _markAllAsRead(snapshot.data!.docs),
                child: const Text('قراءة الكل'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ أثناء تحميل الإشعارات'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Sort client-side: unread first, then newest first, nulls last
          final notifications = [...snapshot.data!.docs];
          notifications.sort((a, b) {
            final ad = a.data() as Map<String, dynamic>;
            final bd = b.data() as Map<String, dynamic>;
            final aRead = ad['isRead'] == true;
            final bRead = bd['isRead'] == true;
            if (aRead != bRead) return aRead ? 1 : -1;
            final at = ad['createdAt'] as Timestamp?;
            final bt = bd['createdAt'] as Timestamp?;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 64,
                      color: AppColors.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 14),
                  const Text(
                    'لا توجد إشعارات حالياً',
                    style: TextStyle(color: AppColors.textLight, fontSize: 14),
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
              final color = _colorByType(type);

              return GestureDetector(
                onTap: () => _handleTap(context, doc),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead
                        ? AppColors.card
                        : color.withValues(alpha: 0.06),
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
                      // ── أيقونة النوع ──
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_iconByType(type), color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      // ── المحتوى ──
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
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(8),
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
                                  _timeAgo(createdAt),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight),
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
                                    height: 1.4),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // ── نقطة غير مقروء ──
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
