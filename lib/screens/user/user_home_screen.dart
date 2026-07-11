import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_home_widgets.dart';

import 'complaint_screen.dart';
import 'donate_tab.dart';
import 'national_id_step_screen.dart';
import 'notifications_screen.dart';
import 'provider_public_profile_screen.dart';
import 'user_extra_screens.dart';
import 'user_publish_offer_screen.dart';

// ─────────────────────────────────────────────
// اختصارات تبرع/نشر: تفتح الشاشة المخصصة مباشرة (CharityDonationScreen أو
// UserPublishOfferScreen) بعد التحقق من توثيق الهوية عبر نفس الدالة
// المشتركة ensureNationalIdSaved، دون أي صفحة دخول وسيطة. charityId/
// charityName اختياريان: يُمرَّران عند وجود جمعية محددة مسبقاً (مثل زر
// "تبرع" بجانب جمعية بعينها)، ويُتركان فارغين عند عدم وجود جمعية محددة
// (كزر "تبرع الآن" العام أو تصنيف "التبرع")، فيختار المستخدم الجمعية من
// داخل CharityDonationScreen نفسها ──
Future<void> _openCharityDonation(
  BuildContext context, {
  String? charityId,
  String? charityName,
}) async {
  final identityReady = await ensureNationalIdSaved(context);
  if (!context.mounted || !identityReady) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CharityDonationScreen(
        initialCharityId: charityId,
        initialCharityName: charityName,
      ),
    ),
  );
}

Future<void> _openPublishOffer(BuildContext context) async {
  final identityReady = await ensureNationalIdSaved(context);
  if (!context.mounted || !identityReady) return;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const UserPublishOfferScreen()),
  );
}

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


  Stream<int> _activeOrdersStream() => FirebaseFirestore.instance
      .collection('reservations')
      .where('userId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'reserved')
      .snapshots()
      .map((s) => s.docs.length);
  Stream<int> _reviewsCountStream() => FirebaseFirestore.instance
      .collection('reviews')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map((s) => s.docs.length);
  Stream<int> _completedOrdersStream() => FirebaseFirestore.instance
      .collection('reservations')
      .where('userId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'picked_up')
      .snapshots()
      .map((s) => s.docs.length);
  Stream<int> _savedMealsStream() => FirebaseFirestore.instance
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
          children: [
            _TopHeader(unreadStream: _unreadStream()),
            const SizedBox(height: 18),
            Text(
              'مرحباً، ${user.name.isNotEmpty ? user.name : 'بك'} 👋',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'ماذا ترغب أن تفعل اليوم؟',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 20),
            _HeroBanner(onDonate: () => _openCharityDonation(context)),
            const SizedBox(height: 20),
            _SearchBarCard(onTap: () => onBrowseTab(0)),
            const SizedBox(height: 22),
            _CategorySection(
              onBrowseTab: onBrowseTab,
              onOrders: () => onNavigate(2),
              onMyDonations: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserDonationsHistoryScreen(),
                ),
              ),
              onDonateToCharity: () => _openCharityDonation(context),
            ),
            const SizedBox(height: 22),
            const _ImpactTracker(),
            const SizedBox(height: 22),
            const _UrgentCharitiesSection(),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: [
                StreamBuilder<int>(
                  stream: _activeOrdersStream(),
                  builder: (_, snap) => StatCard(
                    title: 'طلبات نشطة',
                    value: snap.hasData ? '${snap.data}' : '...',
                    icon: Icons.shopping_bag_outlined,
                    color: AppColors.primary,
                    onTap: () {},
                  ),
                ),
                StreamBuilder<int>(
                  stream: _completedOrdersStream(),
                  builder: (_, snap) => StatCard(
                    title: 'تم استلامها',
                    value: snap.hasData ? '${snap.data}' : '...',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                    onTap: () {},
                  ),
                ),
                StreamBuilder<int>(
                  stream: _savedMealsStream(),
                  builder: (_, snap) => StatCard(
                    title: 'وجبات منقذة',
                    value: snap.hasData ? '${snap.data}' : '...',
                    icon: Icons.eco_rounded,
                    color: Colors.green,
                    onTap: () {},
                  ),
                ),
                StreamBuilder<int>(
                  stream: _reviewsCountStream(),
                  builder: (_, snap) => StatCard(
                    title: 'تقييماتي',
                    value: snap.hasData ? '${snap.data}' : '...',
                    icon: Icons.star_rounded,
                    color: Colors.amber,
                    onTap: () {},
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
              onTap: () => _openPublishOffer(context),
            ),
            ActionTile(
              icon: Icons.receipt_long_rounded,
              title: 'طلباتي',
              subtitle: 'تابع حجوزاتك الحالية والسابقة',
              color: const Color(0xFF7C3AED),
              onTap: () => onNavigate(2),
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
          ],
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final Stream<int> unreadStream;

  const _TopHeader({required this.unreadStream});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha:0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.eco_rounded,
            color: AppColors.primary,
            size: 20,
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
        const Spacer(),
        StreamBuilder<int>(
          stream: unreadStream,
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
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final VoidCallback onDonate;

  const _HeroBanner({required this.onDonate});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha:0.68),
              Colors.black.withValues(alpha:0.18),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'ساهم بالخير',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'أنقذ الطعام وادعم المجتمع',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'احجز وجبة أو تبرع بطعامك الفائض للجمعيات.',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onDonate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('تبرع الآن'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBarCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBarCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.textLight),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'ابحث عن عرض أو مطعم أو جمعية...',
                style: TextStyle(color: AppColors.textLight, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final ValueChanged<int> onBrowseTab;
  final VoidCallback onOrders;
  final VoidCallback onMyDonations;
  final VoidCallback onDonateToCharity;

  const _CategorySection({
    required this.onBrowseTab,
    required this.onOrders,
    required this.onMyDonations,
    required this.onDonateToCharity,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('العروض', Icons.local_offer_rounded, 0),
      ('الباقات', Icons.card_giftcard_rounded, 1),
      ('التبرع', Icons.volunteer_activism_rounded, 2),
      ('طلباتي', Icons.receipt_long_rounded, -1),
      ('تبرعاتي', Icons.history_rounded, -2),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التصنيفات',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        // ── شبكة من 3 أعمدة: توزّع الفئات الخمس على صفّين بحجم موحّد بدل
        // ازدحامها في صفّ واحد ──
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 16,
          childAspectRatio: 1.05,
          children: items.map((item) {
            return GestureDetector(
              onTap: () {
                if (item.$1 == 'طلباتي') {
                  onOrders();
                } else if (item.$1 == 'تبرعاتي') {
                  onMyDonations();
                } else if (item.$1 == 'التبرع') {
                  // ── لا يرتبط بجمعية محددة، فيفتح CharityDonationScreen
                  // مباشرة ويختار المستخدم الجمعية من داخلها ──
                  onDonateToCharity();
                } else {
                  onBrowseTab(item.$3);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha:0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      item.$2,
                      color: AppColors.primary,
                      size: 27,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ImpactTracker extends StatelessWidget {
  const _ImpactTracker();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha:0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'أثرك المجتمعي',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ساهمت في تقليل هدر الطعام ودعم المجتمع من خلال استخدامك لزاد.',
            style: TextStyle(color: AppColors.textLight, height: 1.5),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: 0.6,
              minHeight: 9,
              backgroundColor: Colors.white,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'هدف الشهر: 20 وجبة',
                style: TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
              Text(
                '60%',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UrgentCharitiesSection extends StatelessWidget {
  const _UrgentCharitiesSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'charity')
          .where('status', isEqualTo: 'active')
          .where('isApproved', isEqualTo: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final charities = snapshot.data!.docs;

        if (charities.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الجمعيات المسجلة',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            ...charities.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? data['fullName'] ?? 'جمعية';
              final email = data['email'] ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('charities')
                    .doc(doc.id)
                    .get(),
                builder: (context, charitySnap) {
                  final charityData =
                      charitySnap.data?.data() as Map<String, dynamic>? ?? {};
                  final address = charityData['address'] ?? '';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      // ── يفتح الملف العام للجمعية؛ زر "تبرع" في trailing
                      // له منطقة لمس خاصة به فلا يتعارض مع هذا الفتح ──
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderPublicProfileScreen(
                            providerUserId: doc.id,
                            providerRole: 'charity',
                          ),
                        ),
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE11D48),
                        child: Icon(
                          Icons.volunteer_activism_rounded,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        address.toString().isNotEmpty ? address : email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        onPressed: () => _openCharityDonation(
                          context,
                          charityId: doc.id,
                          charityName: name.toString(),
                        ),
                        child: const Text('تبرع'),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }
}
