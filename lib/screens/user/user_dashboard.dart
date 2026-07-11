import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';

import 'chatbot_screen.dart';
import 'donate_tab.dart';
import 'offers_tab.dart';
import 'packages_tab.dart';
import 'user_home_screen.dart';
import 'user_orders_screen.dart';
import 'user_profile_screen.dart';

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

  // ── عدّاد يُجبر إعادة إنشاء التنقّل الداخلي لتبويب "تصفح" (تصفير أي شاشة
  // تفاصيل/ملف عام مفتوحة داخله) عند الوصول إليه عبر روابط الشاشة الرئيسية فقط ──
  int _browseNavNonce = 0;

  // ── التنقّل إلى تبويب فرعي داخل شاشة "تصفح"؛ تبويب "التبرع" هو الآن
  // مركز تبرّع محايد (بطاقتا اختيار فقط) لا يحتاج توثيق هوية بحد ذاته —
  // التحقق يتم داخل DonateTab نفسها قبل فتح أي من مسارَي التبرع/النشر ──
  void _goToBrowseTab(int tabIndex) {
    setState(() {
      _browseTabIndex = tabIndex;
      _selectedIndex = 1;
      _browseNavNonce++;
    });
  }

  List<Widget> get _pages => [
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

  // ── مفاتيح كل تبويب: ثابتة للتبويبات التي لا تملك تنقّلاً مُبرمَجاً من
  // الخارج، ومرتبطة بالعدّاد لتبويب "تصفح" كي يُعاد إنشاء Navigator الداخلي
  // فقط عند الوصول إليه عبر روابط الشاشة الرئيسية ──
  List<Key> get _tabKeys => [
        const ValueKey('home'),
        ValueKey('browse_$_browseNavNonce'),
        const ValueKey('orders'),
        const ValueKey('profile'),
      ];

  void _openChatbot() {
    final authUser = FirebaseAuth.instance.currentUser;
    final isAnonymous = authUser?.isAnonymous ?? true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatbotScreen(
          userId: isAnonymous ? null : widget.user.uid,
          userName: widget.user.name,
          onGoToOffers: () => _goToBrowseTab(0),
          onGoToPackages: () => _goToBrowseTab(1),
          onGoToOrders: () => setState(() => _selectedIndex = 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final keys = _tabKeys;
    return Scaffold(
      // ── كل تبويب يحصل على Navigator مستقل خاص به: أي Navigator.push من
      // داخل محتوى التبويب (مثل OfferDetailsScreen أو ProviderPublicProfileScreen)
      // يُكدَّس فوق هذا الـ Navigator الداخلي فقط، فيبقى شريط التنقّل السفلي ظاهراً ──
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(
          pages.length,
          (i) => _UserTabView(key: keys[i], child: pages[i]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openChatbot,
        backgroundColor: AppColors.primary,
        tooltip: 'مساعد زاد',
        child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          setState(() {
            _selectedIndex = i;
          });
        },
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
// Navigator مستقل لكل تبويب — يسمح بعمل Navigator.push داخل التبويب
// (مثل فتح تفاصيل عرض أو الملف العام لمزوّد) دون فقدان شريط التنقّل
// السفلي الخاص بلوحة تحكم المستخدم، ودون كسر زر الرجوع.
// ─────────────────────────────────────────────
class _UserTabView extends StatelessWidget {
  final Widget child;
  const _UserTabView({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => child),
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
