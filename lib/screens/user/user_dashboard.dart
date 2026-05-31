import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'identity_verification_screen.dart';
import 'verification_pending_screen.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import 'notifications_screen.dart';
import 'offers_tab.dart';
import 'packages_tab.dart';
import 'donate_tab.dart';
import 'user_orders_screen.dart';
import 'user_profile_screen.dart';
import 'user_publish_offer_screen.dart';
import 'offer_details_screen.dart';

// ─────────────────────────────────────────────
// Dashboard الرئيسي
// ─────────────────────────────────────────────
class UserDashboard extends StatefulWidget {
  final AppUser user;
  const UserDashboard({super.key, required this.user});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;
  int _browseTabIndex = 0;

  late List<Widget> _pages;

  void _goToBrowseTab(int tabIndex) {
    setState(() {
      _browseTabIndex = tabIndex;
      _selectedIndex = 1;
      _buildPages();
    });
  }

  void _buildPages() {
    _pages = [
      UserHomeScreen(
        user: widget.user,
        onNavigate: (index) => setState(() => _selectedIndex = index),
        onBrowseTab: _goToBrowseTab,
      ),
      UserBrowseTabsScreen(
        key: ValueKey(_browseTabIndex),
        initialIndex: _browseTabIndex,
      ),
      const UserOrdersScreen(),
      UserProfileScreen(user: widget.user),
    ];
  }

  @override
  void initState() {
    super.initState();
    _buildPages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'تصفح',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'طلباتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// شاشة التصفح — Tabs
// ─────────────────────────────────────────────
class UserBrowseTabsScreen extends StatelessWidget {
  final int initialIndex;

  const UserBrowseTabsScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تصفح الطعام'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'العروض'),
              Tab(text: 'الباقات'),
              Tab(text: 'التبرع'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [OffersTab(), PackagesTab(), DonateTab()],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// الشاشة الرئيسية
// ─────────────────────────────────────────────
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

    final status = doc.data()?['verificationStatus'];

    if (!context.mounted) return;

    if (status == 'approved') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const UserPublishOfferScreen(),
        ),
      );
    } else if (status == 'pending') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const VerificationPendingScreen(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const IdentityVerificationScreen(),
        ),
      );
    }
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
                _WelcomeCard(user: user),
                const SizedBox(height: 20),

                // ── إحصائيات ──
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<int>(
                        stream: _activeOrdersStream(),
                        builder: (_, snap) => _StatCard(
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
                        builder: (_, snap) => _StatCard(
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

                _SectionHeader(title: 'تصفح'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BrowseCard(
                        title: 'العروض',
                        subtitle: 'مجاني أو مخفّض',
                        icon: Icons.local_offer_rounded,
                        color: AppColors.primary,
                        onTap: () => onBrowseTab(0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BrowseCard(
                        title: 'الباقات',
                        subtitle: 'باقات المطاعم',
                        icon: Icons.card_giftcard_rounded,
                        color: const Color(0xFF7C3AED),
                        onTap: () => onBrowseTab(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BrowseCard(
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

                _SectionHeader(title: 'إجراءات سريعة'),
                const SizedBox(height: 12),

                _ActionTile(
                  icon: Icons.add_box_rounded,
                  title: 'نشر عرض طعام',
                  subtitle: 'شارك طعامك الفائض مجاناً أو بسعر رمزي',
                  color: const Color(0xFF7C3AED),
                  onTap: () => _openPublishScreen(context),
                ),
                _ActionTile(
                  icon: Icons.search_rounded,
                  title: 'تصفح عروض الطعام',
                  subtitle: 'اعثر على طعام مجاني أو بسعر رمزي قريباً منك',
                  color: AppColors.primary,
                  badge: const _Badge(label: 'جديد', color: AppColors.success),
                  onTap: () => onBrowseTab(0),
                ),
                _ActionTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'طلباتي',
                  subtitle: 'تابع حجوزاتك الحالية والسابقة',
                  color: const Color(0xFF7C3AED),
                  onTap: () => onNavigate(2),
                ),
                _ActionTile(
                  icon: Icons.volunteer_activism_rounded,
                  title: 'تبرع بطعام',
                  subtitle: 'شارك طعامك الفائض ودعم المجتمع',
                  color: const Color(0xFFE11D48),
                  onTap: () => onBrowseTab(2),
                ),
                _ActionTile(
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

                _SectionHeader(
                  title: 'آخر العروض',
                  actionLabel: 'عرض الكل',
                  onAction: () => onNavigate(1),
                ),
                const SizedBox(height: 12),
                _LatestOffersPreview(onViewAll: () => onNavigate(1)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة الترحيب
// ─────────────────────────────────────────────
class _WelcomeCard extends StatelessWidget {
  final AppUser user;
  const _WelcomeCard({required this.user});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير ☀️';
    if (h < 17) return 'مساء الخير 🌤️';
    return 'مساء النور 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'م',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🌱 ساهم في تقليل الهدر',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة إحصائية
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة تصفح سريع
// ─────────────────────────────────────────────
class _BrowseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BrowseCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.14), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// إجراء سريع
// ─────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final Widget? badge;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                                fontSize: 14)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          badge!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                            height: 1.4)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// آخر العروض
// ─────────────────────────────────────────────
class _LatestOffersPreview extends StatelessWidget {
  final VoidCallback onViewAll;
  const _LatestOffersPreview({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('status', isEqualTo: 'available')
          .limit(3)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('لا توجد عروض متاحة حالياً',
                  style: TextStyle(color: AppColors.textLight)),
            ),
          );
        }

        return Column(
          children: snap.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'عرض طعام';
            final location = data['pickupLocation'] ?? 'غير محدد';
            final isFree = data['isFree'] == true;
            final price = data['discountPrice'] ?? 0;
            final currency = data['currency'] ?? 'ILS';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OfferDetailsScreen(
                        docId: doc.id,
                        data: data,
                      ),
                    ),
                  );
                },
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isFree
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isFree ? 'مجاني' : '$price $currency',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            isFree ? AppColors.success : AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Badge
// ─────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ─────────────────────────────────────────────
// شاشة الشكوى
// ─────────────────────────────────────────────
class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _offerIdController = TextEditingController();
  String? _selectedType;
  bool _isLoading = false;
  bool _submitted = false;

  final _types = [
    'طلب لم يُستلم',
    'معلومات خاطئة',
    'سلوك غير لائق',
    'مشكلة أخرى'
  ];

  @override
  void dispose() {
    _descController.dispose();
    _offerIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance.collection('complaints').add({
        'userId': userId,
        'type': _selectedType ?? 'مشكلة أخرى',
        'description': _descController.text.trim(),
        'relatedOfferId': _offerIdController.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تقديم شكوى')),
      body: _submitted ? _SuccessView() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // ── تنبيه ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.danger.withOpacity(0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.danger, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'سيتم مراجعة شكواك من قبل الإدارة والرد عليك في أقرب وقت.',
                    style: TextStyle(
                        color: AppColors.danger, fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // رقم العرض
                  TextFormField(
                    controller: _offerIdController,
                    decoration: const InputDecoration(
                      labelText: 'رقم العرض (اختياري)',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // نوع الشكوى
                  const Text('نوع الشكوى',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((type) {
                      final selected = _selectedType == type;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.danger.withOpacity(0.10)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.danger
                                  : AppColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(type,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppColors.danger
                                      : AppColors.textLight)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // وصف الشكوى
                  TextFormField(
                    controller: _descController,
                    maxLines: 5,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'يرجى كتابة وصف الشكوى'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'وصف الشكوى *',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 80),
                        child: Icon(Icons.description_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      label:
                          Text(_isLoading ? 'جاري الإرسال...' : 'إرسال الشكوى'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// شاشة النجاح
class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 52),
            ),
            const SizedBox(height: 24),
            const Text('تم إرسال شكواك ✅',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 12),
            const Text(
              'سيتم مراجعة شكواك من قبل الإدارة والرد عليك في أقرب وقت ممكن.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textLight, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('العودة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
