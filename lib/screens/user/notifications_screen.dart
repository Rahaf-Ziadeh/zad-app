import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';
import 'offer_details_screen.dart';
import 'provider_public_profile_screen.dart';
import 'qr_code_screen.dart';
import 'support_chat_screen.dart';
import 'national_id_step_screen.dart';
import 'user_extra_screens.dart';
import 'user_orders_screen.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Per-notification processing guard — prevents rapid double-taps from launching multiple
  // async handlers and opening the same screen more than once. Set before the first await
  // in _handleTap; always removed (success or failure) after the pushed screen closes.
  final Set<String> _processingIds = {};

  Stream<QuerySnapshot> _notificationsStream() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Failure here must not block navigation — always called from inside _handleTap's
  // try/catch; returns true/false instead of throwing.
  Future<bool> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      debugPrint('[Notifications] markAsRead OK id=$notificationId');
      return true;
    } catch (e) {
      debugPrint('[Notifications] markAsRead FAILED id=$notificationId: $e');
      return false;
    }
  }

  // Opens the screen linked to a notification based on its type. Mark-as-read runs first
  // but its failure never blocks navigation (isolated inside _markAsRead). Routing relies
  // only on structural fields (type/relatedId/relatedRole), never on title/message text.
  // Unhandled cases (unknown type, missing relatedId, fetch error) show an explicit SnackBar
  // rather than silently doing nothing. Uses regular Navigator.push within the current tab
  // so the bottom nav stays visible — no root Navigator involved.
  //
  // Processing guard: set here before the first await (prevents multiple handlers from
  // rapid taps); all Navigator.push calls are awaited until the pushed screen closes
  // before releasing the guard in finally.
  Future<void> _handleTap(
    BuildContext context,
    String notificationId,
    Map<String, dynamic> data,
  ) async {
    if (_processingIds.contains(notificationId)) {
      debugPrint('[Notifications] id=$notificationId tap IGNORED — '
          'already processing');
      return;
    }
    _processingIds.add(notificationId);
    debugPrint('[Notifications] id=$notificationId guard ACQUIRED');

    void showCannotOpen() {
      debugPrint('[Notifications] id=$notificationId cannot open related '
          'content — showing SnackBar fallback');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن فتح محتوى هذا الإشعار'),
          backgroundColor: AppColors.danger,
        ),
      );
    }

    try {
      final type = (data['type'] as String? ?? '').trim();
      final relatedId = (data['relatedId'] as String? ?? '').trim();
      final relatedRole = (data['relatedRole'] as String? ?? '').trim();

      debugPrint('[Notifications] tap id=$notificationId type="$type" '
          'relatedId="$relatedId" relatedRole="$relatedRole"');

      final markedRead = await _markAsRead(notificationId);
      debugPrint('[Notifications] id=$notificationId markedRead=$markedRead '
          '(failure here must NOT block navigation)');
      if (!context.mounted) return;

      switch (type) {
        case 'reservation':
        case 'pickup':
          debugPrint(
              '[Notifications] id=$notificationId branch=reservation/pickup');
          if (relatedId.isEmpty) {
            showCannotOpen();
            return;
          }
          await _openReservation(context, relatedId);
          break;
        case 'offer':
          debugPrint('[Notifications] id=$notificationId branch=offer');
          if (relatedId.isEmpty) {
            showCannotOpen();
            return;
          }
          await _openOffer(context, relatedId);
          break;
        case 'donation':
          debugPrint('[Notifications] id=$notificationId branch=donation');
          if (!context.mounted) return;
          // Awaited so the guard isn't released until the screen closes.
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const UserDonationsHistoryScreen()),
          );
          break;
        case 'provider':
          debugPrint('[Notifications] id=$notificationId branch=provider');
          if (relatedId.isEmpty || relatedRole.isEmpty) {
            showCannotOpen();
            return;
          }
          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProviderPublicProfileScreen(
                providerUserId: relatedId,
                providerRole: relatedRole,
              ),
            ),
          );
          break;
        case 'support':
          debugPrint('[Notifications] id=$notificationId branch=support');
          if (relatedId.isEmpty) {
            showCannotOpen();
            return;
          }
          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SupportChatScreen(chatId: relatedId),
            ),
          );
          break;
        case 'identity_additional_info_required':
          debugPrint('[Notifications] id=$notificationId branch=identity_additional_info');
          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NationalIdStepScreen()),
          );
          break;
        case 'account':
          // Admin decision about the user's own account — opens their profile.
          debugPrint('[Notifications] id=$notificationId branch=account');
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) {
            showCannotOpen();
            return;
          }
          final userDoc =
              await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (!context.mounted) return;
          if (!userDoc.exists) {
            showCannotOpen();
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                user: AppUser.fromMap(uid, userDoc.data()!),
              ),
            ),
          );
          break;
        default:
          // Other types (complaint/report…) have no dedicated screen yet — show a SnackBar instead.
          debugPrint('[Notifications] id=$notificationId branch=unhandled '
              'type="$type"');
          showCannotOpen();
          break;
      }
    } catch (e, stack) {
      debugPrint(
          '[Notifications] id=$notificationId navigation FAILED: $e\n$stack');
      showCannotOpen();
    } finally {
      // Guard always released — whether the handler succeeded, failed, or the pushed screen closed.
      _processingIds.remove(notificationId);
      debugPrint('[Notifications] id=$notificationId guard RELEASED');
    }
  }

  // Active reservation ('reserved') opens the QR screen; otherwise (picked up/cancelled)
  // opens the orders screen on the matching tab since the QR code is no longer useful.
  Future<void> _openReservation(
      BuildContext context, String reservationId) async {
    debugPrint(
        '[Notifications] _openReservation fetching reservations/$reservationId');
    final doc = await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservationId)
        .get();
    if (!context.mounted) return;

    if (!doc.exists) {
      debugPrint('[Notifications] reservations/$reservationId does not exist');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على الحجز')),
      );
      return;
    }

    final data = doc.data()!;
    final status = (data['status'] as String? ?? '').trim();
    debugPrint('[Notifications] reservations/$reservationId status="$status"');

    if (!context.mounted) return;
    if (status == 'reserved') {
      debugPrint('[Notifications] pushing QrCodeScreen for $reservationId');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrCodeScreen(
            reservationId: reservationId,
            offerId: data['offerId'] as String? ?? '',
            userId: data['userId'] as String? ?? '',
            providerName: data['providerName'] as String? ?? '',
            reservationCode: data['reservationCode'] as String? ?? '',
          ),
        ),
      );
    } else {
      debugPrint('[Notifications] pushing UserOrdersScreen(statusFilter: '
          '$status) for $reservationId');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserOrdersScreen(
              statusFilter: status.isEmpty ? null : status),
        ),
      );
    }
  }

  Future<void> _openOffer(BuildContext context, String offerId) async {
    debugPrint('[Notifications] _openOffer fetching offers/$offerId');
    final doc =
        await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
    if (!context.mounted) return;

    if (!doc.exists) {
      debugPrint('[Notifications] offers/$offerId does not exist');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يعد هذا العرض متاحاً')),
      );
      return;
    }

    debugPrint('[Notifications] pushing OfferDetailsScreen for $offerId');
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfferDetailsScreen(
          docId: offerId,
          data: doc.data()!,
        ),
      ),
    );
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (!(data['isRead'] ?? false)) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
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
      case 'identity_additional_info_required':
        return Icons.info_outline_rounded;
      case 'complaint':
        return Icons.report_problem_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorByType(String type) {
    switch (type) {
      case 'reservation':
        return AppColors.primary;
      case 'pickup':
        return const Color(0xFF7C3AED);
      case 'donation':
        return const Color(0xFFE11D48);
      case 'account':
        return AppColors.secondary;
      case 'identity_additional_info_required':
        return Colors.amber;
      case 'complaint':
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _notificationsStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final unread = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return !(data['isRead'] ?? false);
              }).toList();
              if (unread.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _markAllAsRead(snapshot.data!.docs),
                child: const Text('قراءة الكل'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ أثناء تحميل الإشعارات'));
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

              final title = data['title'] ?? 'إشعار';
              final message = data['message'] ?? '';
              final type = data['type'] ?? 'general';
              final isRead = data['isRead'] ?? false;
              final createdAt = data['createdAt'] as Timestamp?;
              final color = _colorByType(type);

              return GestureDetector(
                onTap: () => _handleTap(context, doc.id, data),
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
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_iconByType(type), color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                Text(
                                  _timeAgo(createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textLight),
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
