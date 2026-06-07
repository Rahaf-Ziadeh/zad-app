import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_home_widgets.dart';

import 'complaint_screen.dart';
import 'identity_verification_screen.dart';
import 'notifications_screen.dart';
import 'user_orders_screen.dart';
import 'user_publish_offer_screen.dart';

class UserHomeScreen extends StatelessWidget {
  final AppUser user;
  final ValueChanged<int> onNavigate;
  final ValueChanged<int> onBrowseTab;
  const UserHomeScreen({
    super.key,
    required this.user,
    required this.onNavigate,
    required this.onBrowseTab,
  });
  Future<void> _openPublishScreen(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection('individuals')
        .doc(uid)
        .get();

    if (!context.mounted) return;

    // أول مرة فقط
    if (!doc.exists ||
        doc.data()?['identityImageUrl'] == null ||
        doc.data()?['identityImageUrl'] == '') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const IdentityVerificationScreen(),
        ),
      );
      return;
    }

    // بعد إرسال الهوية يقدر ينشر مباشرة
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UserPublishOfferScreen(),
      ),
    );
  }

  Stream<int> _activeOrdersStream() => FirebaseFirestore.instance
      .collection('reservations')
      .where('userId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'reserved')
      .snapshots()
      .map((s) => s.docs.length);

  Stream<int> _completedOrdersStream() => FirebaseFirestore.instance
      .collection('reservations')
      .where('userId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'picked_up')
      .snapshots()
      .map((s) => s.docs.length);

  Stream<int> _unreadStream() => FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: user.uid)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: AppColors.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'زاد',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            actions: [
              StreamBuilder<int>(
                stream: _unreadStream(),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  return Stack(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      if (count > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                count > 9 ? '9+' : '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                WelcomeCard(user: user),
                const SizedBox(height: 20),

                // ── إحصائيات ──
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<int>(
                        stream: _activeOrdersStream(),
                        builder: (_, snap) => StatCard(
                          title: 'طلبات نشطة',
                          value: snap.hasData ? '${snap.data}' : '...',
                          icon: Icons.shopping_bag_outlined,
                          color: AppColors.primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UserOrdersScreen(
                                statusFilter: 'reserved',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<int>(
                        stream: _completedOrdersStream(),
                        builder: (_, snap) => StatCard(
                          title: 'تم استلامها',
                          value: snap.hasData ? '${snap.data}' : '...',
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UserOrdersScreen(
                                statusFilter: 'picked_up',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                SectionHeader(title: 'تصفح'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BrowseCard(
                        title: 'العروض',
                        subtitle: 'مجاني أو مخفّض',
                        icon: Icons.local_offer_rounded,
                        color: AppColors.primary,
                        onTap: () => onBrowseTab(0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BrowseCard(
                        title: 'الباقات',
                        subtitle: 'باقات المطاعم',
                        icon: Icons.card_giftcard_rounded,
                        color: const Color(0xFF7C3AED),
                        onTap: () => onBrowseTab(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BrowseCard(
                        title: 'تبرّع',
                        subtitle: 'شارك الخير',
                        icon: Icons.volunteer_activism_rounded,
                        color: const Color(0xFFE11D48),
                        onTap: () => onBrowseTab(2),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                SectionHeader(title: 'إجراءات سريعة'),
                const SizedBox(height: 12),

                ActionTile(
                  icon: Icons.add_box_rounded,
                  title: 'نشر عرض طعام',
                  subtitle: 'شارك طعامك الفائض مجاناً أو بسعر رمزي',
                  color: const Color(0xFF7C3AED),
                  onTap: () => _openPublishScreen(context),
                ),
                ActionTile(
                  icon: Icons.search_rounded,
                  title: 'تصفح عروض الطعام',
                  subtitle: 'اعثر على طعام مجاني أو بسعر رمزي قريباً منك',
                  color: AppColors.primary,
                  badge: const BadgeWidget(
                      label: 'جديد', color: AppColors.success),
                  onTap: () => onBrowseTab(0),
                ),
                ActionTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'طلباتي',
                  subtitle: 'تابع حجوزاتك الحالية والسابقة',
                  color: const Color(0xFF7C3AED),
                  onTap: () => onNavigate(2),
                ),
                ActionTile(
                  icon: Icons.volunteer_activism_rounded,
                  title: 'تبرع بطعام',
                  subtitle: 'شارك طعامك الفائض ودعم المجتمع',
                  color: const Color(0xFFE11D48),
                  onTap: () => onBrowseTab(2),
                ),
                ActionTile(
                  icon: Icons.report_problem_outlined,
                  title: 'تقديم شكوى',
                  subtitle: 'بلّغ عن مشكلة في طلب أو مزوّد طعام',
                  color: AppColors.secondary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ComplaintScreen(),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                SectionHeader(
                  title: 'آخر العروض',
                  actionLabel: 'عرض الكل',
                  onAction: () => onNavigate(1),
                ),
                const SizedBox(height: 12),
                LatestOffersPreview(onViewAll: () => onNavigate(1)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
