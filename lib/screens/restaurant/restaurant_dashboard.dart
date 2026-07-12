import 'package:flutter/material.dart';
import 'add_offer_screen.dart';
import 'restaurant_home_screen.dart';
import 'restaurant_profile_screen.dart';
import 'restaurant_reservations_screen.dart';
import 'restaurant_offers_screen.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────
// Dashboard الرئيسي
// ─────────────────────────────────────────────
class RestaurantDashboard extends StatefulWidget {
  final AppUser user;

  const RestaurantDashboard({super.key, required this.user});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  int _selectedIndex = 0;

  // ── فلتر تبويب "عروضي" وتبويب "حجوزاتي" الفرعي، يُضبطان عبر بطاقات إحصائيات الرئيسية ──
  String? _offersFilter;
  int _reservationsTabIndex = 0;

  // ── عدّادات تُستخدم لإجبار إعادة إنشاء التنقّل الداخلي للتبويب (تصفير أي شاشة
  // مفتوحة داخله والعودة لأعلى المكدس) عند الوصول عبر بطاقات إحصائيات الرئيسية فقط ──
  int _offersNavNonce = 0;
  int _reservationsNavNonce = 0;

  // ── مفتاح Navigator مستقل ثابت لكل تبويب سفلي؛ يُستخدم لإعادة التبويب
  // إلى شاشته الجذرية (popUntil) عند الضغط على تبويب محدد حالياً بالفعل،
  // دون التأثير على مكدّسات بقية التبويبات — بنفس نمط user_dashboard.dart.
  // مستقل عمداً عن عدّادات إعادة الإنشاء أعلاه: يبقى ثابتاً عبر عمليات
  // إعادة البناء العادية حتى يستمر popUntil في استهداف الـ Navigator الحي ──
  final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _offersNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _reservationsNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _addOfferNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _profileNavigatorKey =
      GlobalKey<NavigatorState>();

  List<GlobalKey<NavigatorState>> get _navigatorKeys => [
        _homeNavigatorKey,
        _offersNavigatorKey,
        _reservationsNavigatorKey,
        _addOfferNavigatorKey,
        _profileNavigatorKey,
      ];

  // ── تنقّل من الشاشة الرئيسية: يبدّل التبويب مع تطبيق الفلتر المطلوب فوراً ──
  void _navigateFromHome(
    int index, {
    String? offersFilter,
    int? reservationsTab,
  }) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _offersFilter = offersFilter;
        _offersNavNonce++;
      }
      if (index == 2) {
        _reservationsTabIndex = reservationsTab ?? 0;
        _reservationsNavNonce++;
      }
    });
  }

  // ── تنقّل عبر شريط التنقّل السفلي مباشرة: يعرض كل العروض/الحجوزات دون فلتر،
  // مع الحفاظ على أي تنقّل داخلي سابق ضمن التبويب نفسه ──
  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      // ── التبويب المحدد بالفعل: إعادة تصفّحه إلى شاشته الجذرية فقط، دون
      // تبديل تبويب ودون التأثير على مكدّسات بقية التبويبات ──
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _selectedIndex = index;
      if (index == 1) _offersFilter = null;
      if (index == 2) _reservationsTabIndex = 0;
    });
  }

  List<Widget> get _pages => [
        RestaurantHomeScreen(
          user: widget.user,
          onNavigate: _navigateFromHome,
        ),
        RestaurantOffersScreen(initialFilter: _offersFilter),
        RestaurantReservationsScreen(initialTabIndex: _reservationsTabIndex),
        const AddOfferScreen(),
        RestaurantProfileScreen(user: widget.user),
      ];

  // ── مفاتيح كل تبويب: ثابتة للتبويبات التي لا تملك فلتراً، ومرتبطة بالعدّاد
  // للتبويبات القابلة للفلترة كي يُعاد إنشاء التنقّل الداخلي عند تغييرها فقط ──
  List<Key> get _tabKeys => [
        const ValueKey('home'),
        ValueKey('offers_$_offersNavNonce'),
        ValueKey('reservations_$_reservationsNavNonce'),
        const ValueKey('add_offer'),
        const ValueKey('profile'),
      ];

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final keys = _tabKeys;
    final navigatorKeys = _navigatorKeys;
    return Scaffold(
      // ── كل تبويب يحصل على Navigator مستقل خاص به: أي Navigator.push من
      // داخل محتوى التبويب (مثل UserPublicProfileScreen) يُكدَّس فوق هذا
      // الـ Navigator الداخلي فقط، فيبقى شريط التنقّل السفلي لهذه الشاشة ظاهراً ──
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(
          pages.length,
          (i) => _RestaurantTabView(
            key: keys[i],
            navigatorKey: navigatorKeys[i],
            child: pages[i],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.25),
        backgroundColor: AppColors.card,
        elevation: 0,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.fastfood_outlined),
            selectedIcon: Icon(Icons.fastfood_rounded),
            label: 'عروضي',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'حجوزاتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'إضافة',
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
// (مثل فتح الملف الشخصي العام للمستخدم من شاشة الحجوزات) دون فقدان
// شريط التنقّل السفلي الخاص بلوحة تحكم المطعم، ودون كسر زر الرجوع.
// ─────────────────────────────────────────────
class _RestaurantTabView extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  const _RestaurantTabView({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => child),
    );
  }
}
