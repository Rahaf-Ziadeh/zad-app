import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/models/user.dart';
import 'package:zad_app/screens/restaurant/restaurant_donate_to_charity_screen.dart';
import 'package:zad_app/screens/restaurant/restaurant_offer_details_screen.dart';
import 'package:zad_app/screens/restaurant/restaurant_profile_screen.dart';
import 'package:zad_app/screens/restaurant/restaurant_reservations_screen.dart';
import 'package:zad_app/screens/restaurant/restaurant_stats_screen.dart';
import 'package:zad_app/screens/restaurant/restaurant_widgets.dart';
import 'package:zad_app/screens/restaurant/scan_qr_screen.dart';
import 'package:zad_app/theme/app_colors.dart';
import 'package:zad_app/utils/offer_utils.dart';

import '../common/notifications_screen.dart';

// Callback for navigating within the restaurant dashboard shell.
// index: 1 = My Offers (optional offersFilter), 2 = My Reservations (optional reservationsTab)
typedef RestaurantTabNavigate = void Function(
  int index, {
  String? offersFilter,
  int? reservationsTab,
});

class RestaurantHomeScreen extends StatelessWidget {
  final AppUser user;
  final RestaurantTabNavigate onNavigate;

  const RestaurantHomeScreen({
    super.key,
    required this.user,
    required this.onNavigate,
  });

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> _myOffersStream() => FirebaseFirestore.instance
      .collection('offers')
      .where('providerUserId', isEqualTo: _uid)
      .snapshots();

  Stream<QuerySnapshot> _pendingReservationsStream() =>
      FirebaseFirestore.instance
          .collection('reservations')
          .where('providerUserId', isEqualTo: _uid)
          .where('status', isEqualTo: 'reserved')
          .snapshots();

  // Delegates to openRestaurantRelatedNotification so notification-opening logic stays in one place.
  Future<bool> _openRelatedNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) =>
      openRestaurantRelatedNotification(context, user, data);

  Stream<DocumentSnapshot> _userStream() =>
      FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('زاد',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RestaurantStatsScreen(),
              ),
            ),
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'الإحصائيات',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationsScreen(onOpenRelated: _openRelatedNotification),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          WelcomeCard(user: user),
          const SizedBox(height: 20),

          // Verification status banner — only visible during re-review or rejection.
          StreamBuilder<DocumentSnapshot>(
            stream: _userStream(),
            builder: (context, snap) {
              final data = snap.data?.data() as Map<String, dynamic>?;
              final vs = data?['verificationStatus'] as String?;
              if (vs == null || vs == 'approved') return const SizedBox.shrink();
              final rejectionReason =
                  (data?['rejectionReason'] as String? ?? '').trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _VerificationBanner(
                  isRejected: vs == 'rejected',
                  rejectionReason:
                      rejectionReason.isNotEmpty ? rejectionReason : null,
                ),
              );
            },
          ),

          StreamBuilder<QuerySnapshot>(
            stream: _myOffersStream(),
            builder: (context, offersSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: _pendingReservationsStream(),
                builder: (context, resSnap) {
                  final offers =
                      offersSnap.hasData ? offersSnap.data!.docs : [];
                  // "Active" = status 'available' + not expired + remaining quantity > 0.
                  final activeOffers = offers.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final remaining =
                        (d['remainingQuantity'] as num?)?.toInt() ?? 0;
                    return effectiveOfferStatus(d) == 'available' &&
                        remaining > 0;
                  }).length;
                  final pendingRes =
                      resSnap.hasData ? resSnap.data!.docs.length : 0;

                  return Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            debugPrint(
                                '[RestaurantHome] tapped all offers -> RestaurantOffersScreen(initialFilter: null / الكل)');
                            onNavigate(1);
                          },
                          child: StatCard(
                            title: 'كل العروض',
                            value: '${offers.length}',
                            icon: Icons.fastfood_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            debugPrint(
                                "[RestaurantHome] tapped active offers -> RestaurantOffersScreen(initialFilter: 'available' / نشطة)");
                            onNavigate(1, offersFilter: 'available');
                          },
                          child: StatCard(
                            title: 'نشطة',
                            value: '$activeOffers',
                            icon: Icons.check_circle_rounded,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          // Navigate to the "Waiting for pickup" sub-tab inside My Reservations (tab index 1).
                          onTap: () {
                            debugPrint(
                                '[RestaurantHome] tapped waiting reservations -> RestaurantReservationsScreen(initialTabIndex: 1 / بانتظار الاستلام)');
                            onNavigate(2, reservationsTab: 1);
                          },
                          child: StatCard(
                            title: 'بانتظار',
                            value: '$pendingRes',
                            icon: Icons.pending_rounded,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),
          const Text('إجراءات سريعة',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 12),

          ActionTile(
            icon: Icons.add_rounded,
            title: 'إنشاء باقة فائض',
            subtitle: 'أضف باقة طعام بسعر مخفّض للمستخدمين',
            color: AppColors.primary,
            onTap: () => onNavigate(3),
          ),
          ActionTile(
            icon: Icons.qr_code_scanner_rounded,
            title: 'مسح رمز الاستلام',
            subtitle: 'تأكيد استلام طلب بمسح QR من المستخدم',
            color: const Color(0xFF7C3AED),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScanQrScreen())),
          ),
          ActionTile(
            icon: Icons.receipt_long_rounded,
            title: 'متابعة الحجوزات',
            subtitle: 'عرض جميع الطلبات والحجوزات الحالية',
            color: AppColors.secondary,
            onTap: () => onNavigate(2),
          ),
          ActionTile(
            icon: Icons.volunteer_activism_rounded,
            title: 'تبرع لجمعية',
            subtitle: 'تبرّع بفائض الطعام مباشرة لجمعية خيرية',
            color: const Color(0xFFE11D48),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RestaurantDonateToCharityScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _cannotOpenRestaurantNotification(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('لا يمكن فتح محتوى هذا الإشعار'),
      backgroundColor: AppColors.danger,
    ),
  );
}

// Opens the content linked to a restaurant notification by type. Always verifies the linked
// record exists before navigating; unknown types show a message rather than silently doing nothing.
// Shared function (not scoped to RestaurantHomeScreen) so the restaurant chatbot can reuse it.
Future<bool> openRestaurantRelatedNotification(
  BuildContext context,
  AppUser user,
  Map<String, dynamic> data,
) async {
  final type = (data['type'] as String? ?? '').trim();
  final relatedId = (data['relatedId'] as String? ?? '').trim();

  try {
    switch (type) {
      case 'reservation':
      case 'pickup':
        if (relatedId.isEmpty) {
          _cannotOpenRestaurantNotification(context);
          return false;
        }
        final doc = await FirebaseFirestore.instance
            .collection('reservations')
            .doc(relatedId)
            .get();
        if (!context.mounted) return false;
        if (!doc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم العثور على هذا الحجز')),
          );
          return false;
        }
        final resStatus = (doc.data()?['status'] as String?) ?? 'reserved';
        // Navigate to the "Waiting for pickup" tab for active reservations, or the tab matching the actual status.
        final tabIndex = resStatus == 'reserved' || resStatus == 'confirmed'
            ? 1
            : resStatus == 'picked_up'
                ? 2
                : resStatus == 'cancelled'
                    ? 3
                    : 0;
        if (!context.mounted) return false;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                RestaurantReservationsScreen(initialTabIndex: tabIndex),
          ),
        );
        return true;

      case 'offer':
        if (relatedId.isEmpty) {
          _cannotOpenRestaurantNotification(context);
          return false;
        }
        final doc = await FirebaseFirestore.instance
            .collection('offers')
            .doc(relatedId)
            .get();
        if (!context.mounted) return false;
        if (!doc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('هذا العرض لم يعد متوفرًا.')),
          );
          return false;
        }
        if (!context.mounted) return false;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantOfferDetailsScreen(
              offerId: doc.id,
              offerData: doc.data() as Map<String, dynamic>,
            ),
          ),
        );
        return true;

      case 'account':
        // Admin decision about the restaurant's own account — My Account shows current verification status and rejection reason.
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RestaurantProfileScreen(user: user),
          ),
        );
        return true;

      default:
        _cannotOpenRestaurantNotification(context);
        return false;
    }
  } catch (e) {
    if (!context.mounted) return false;
    _cannotOpenRestaurantNotification(context);
    return false;
  }
}

// Verification status banner for the home screen — shown during re-review or rejection.
class _VerificationBanner extends StatelessWidget {
  final bool isRejected;
  final String? rejectionReason;

  const _VerificationBanner({
    required this.isRejected,
    required this.rejectionReason,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRejected ? AppColors.danger : Colors.orange;
    final message = isRejected
        ? 'تم رفض طلب التحقق الخاص بحسابك'
            '${rejectionReason != null ? ' (السبب: $rejectionReason)' : ''}. '
            'يمكنك إكمال حجوزاتك الحالية، لكن لا يمكنك نشر عروض جديدة حتى '
            'تعدّل بيانات الرخصة وتتم الموافقة عليها من جديد.'
        : 'تم تحديث بيانات الرخصة وحسابك قيد إعادة المراجعة. يمكنك إكمال '
            'الحجوزات الحالية، لكن لا يمكنك نشر عروض جديدة حتى تتم الموافقة.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.textDark, fontSize: 12.5, height: 1.7)),
          ),
        ],
      ),
    );
  }
}
