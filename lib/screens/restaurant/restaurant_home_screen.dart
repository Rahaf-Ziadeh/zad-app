import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/models/user.dart';
import 'package:zad_app/screens/restaurant/restaurant_offers_screen.dart';
import 'package:zad_app/screens/restaurant/restaurant_reservations_screen.dart';
import 'package:zad_app/screens/restaurant/restaurant_stats_screen.dart';
import 'package:zad_app/screens/restaurant/restaurant_widgets.dart';
import 'package:zad_app/screens/restaurant/scan_qr_screen.dart';
import 'package:zad_app/theme/app_colors.dart';

import '../common/notifications_screen.dart';

// ── تنقّل داخل قشرة لوحة تحكم المطعم: يبدّل التبويب مع فلتر اختياري ──
// index: 1 = عروضي (مع offersFilter اختياري)، 2 = حجوزاتي (مع reservationsTab اختياري)
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
                  builder: (_) => NotificationsScreen(
                    onNotificationTap: (context, data) {
                      final type = data['type'];

                      if (type == 'reservation' || type == 'pickup') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const RestaurantReservationsScreen(),
                          ),
                        );
                      } else if (type == 'offer') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RestaurantOffersScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          // ── بطاقة الترحيب ──
          WelcomeCard(user: user),
          const SizedBox(height: 20),

          // ── إحصائيات ──
          StreamBuilder<QuerySnapshot>(
            stream: _myOffersStream(),
            builder: (context, offersSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: _pendingReservationsStream(),
                builder: (context, resSnap) {
                  final offers =
                      offersSnap.hasData ? offersSnap.data!.docs : [];
                  final activeOffers = offers.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return d['status'] == 'available';
                  }).length;
                  final pendingRes =
                      resSnap.hasData ? resSnap.data!.docs.length : 0;

                  return Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onNavigate(1),
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
                          onTap: () => onNavigate(1, offersFilter: 'available'),
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
                          // ── تبويب "بانتظار الاستلام" داخل شاشة حجوزاتي (index 1) ──
                          onTap: () => onNavigate(2, reservationsTab: 1),
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
        ],
      ),
    );
  }
}
