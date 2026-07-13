import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'add_offer_screen.dart';
import 'restaurant_home_screen.dart';
import 'restaurant_profile_screen.dart';
import 'restaurant_reservations_screen.dart';
import 'restaurant_offers_screen.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../common/notifications_screen.dart';
import '../user/chatbot_screen.dart';

class RestaurantDashboard extends StatefulWidget {
  final AppUser user;

  const RestaurantDashboard({super.key, required this.user});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  int _selectedIndex = 0;

  // Current filter for My Offers tab and sub-tab index for My Reservations — set from the home stats cards.
  String? _offersFilter;
  int _reservationsTabIndex = 0;

  // Nonces that force-recreate the tab's internal Navigator when navigating from home stats cards.
  int _offersNavNonce = 0;
  int _reservationsNavNonce = 0;

  // Stable per-tab Navigator key for popUntil when re-tapping an already-active tab.
  // Intentionally independent of the nonces — stays constant across normal rebuilds
  // so popUntil keeps targeting the live NavigatorState.
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

  // Navigates from the home screen: switches tab and applies the requested filter immediately.
  //
  // Root cause: changing _RestaurantTabView's ValueKey (via nonces) alone doesn't force the inner
  // Navigator to rebuild its first route. Flutter reparents the existing NavigatorState with its old
  // stack because the GlobalKey (_offersNavigatorKey / _reservationsNavigatorKey) doesn't change,
  // and onGenerateRoute only fires on the first route creation. The route stays stuck at the filter
  // from the first time that tab was shown, regardless of which stats card is tapped later.
  // Fix: explicitly replace the Navigator's content via pushAndRemoveUntil after each tap.
  void _navigateFromHome(
    int index, {
    String? offersFilter,
    int? reservationsTab,
  }) {
    debugPrint(
        '[RestaurantHome] onNavigate($index, offersFilter: $offersFilter, reservationsTab: $reservationsTab)');
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

    if (index == 1) {
      debugPrint(
          '[RestaurantHome] resetting عروضي navigator -> initialFilter: $offersFilter');
      _offersNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => RestaurantOffersScreen(initialFilter: offersFilter),
        ),
        (route) => false,
      );
    } else if (index == 2) {
      final tabIndex = reservationsTab ?? 0;
      debugPrint(
          '[RestaurantHome] resetting حجوزاتي navigator -> initialTabIndex: $tabIndex');
      _reservationsNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              RestaurantReservationsScreen(initialTabIndex: tabIndex),
        ),
        (route) => false,
      );
    }
  }

  // Bottom nav tap: shows all offers/reservations without a filter, preserving any existing in-tab navigation.
  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      // Already on this tab — pop to root without switching tabs or affecting other stacks.
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

  // Same shared ChatbotScreen used in the user dashboard; userRole: 'restaurant' controls all content via ChatbotRoleConfig.
  void _openChatbot() {
    final authUser = FirebaseAuth.instance.currentUser;
    final isAnonymous = authUser?.isAnonymous ?? true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatbotScreen(
          userRole: 'restaurant',
          userId: isAnonymous ? null : widget.user.uid,
          userName: widget.user.name,
          onGoToOffers: () => _navigateFromHome(1),
          onGoToOrders: () => _navigateFromHome(2),
          onGoToAddOffer: () => _navigateFromHome(3),
          onGoToNotifications: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationsScreen(
                onOpenRelated: (ctx, data) =>
                    openRestaurantRelatedNotification(ctx, widget.user, data),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Tab keys: static for unfiltered tabs, nonce-stamped for filterable ones to force Navigator rebuild when filter changes.
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
      // Each tab has its own Navigator — pushes inside a tab stack above it, keeping the bottom bar visible.
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
      floatingActionButton: FloatingActionButton(
        onPressed: _openChatbot,
        backgroundColor: AppColors.primary,
        tooltip: 'مساعد المطعم',
        child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
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

// Per-tab Navigator that allows Navigator.push within a tab without losing the restaurant bottom bar.
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
