import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';

import 'chatbot_screen.dart';
import 'donate_tab.dart';
import 'notifications_screen.dart';
import 'offers_tab.dart';
import 'packages_tab.dart';
import 'user_home_screen.dart';
import 'user_orders_screen.dart';
import 'user_profile_screen.dart';

class UserDashboard extends StatefulWidget {
  final AppUser user;
  const UserDashboard({super.key, required this.user});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;
  int _browseTabIndex = 0;

  // Nonce to force-recreate the Browse tab's internal Navigator when navigating from home screen links.
  int _browseNavNonce = 0;

  // Stable per-tab Navigator key for popUntil when re-tapping an already-active tab.
  final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _browseNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _ordersNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _profileNavigatorKey =
      GlobalKey<NavigatorState>();

  List<GlobalKey<NavigatorState>> get _navigatorKeys => [
        _homeNavigatorKey,
        _browseNavigatorKey,
        _ordersNavigatorKey,
        _profileNavigatorKey,
      ];

  // Navigate to a sub-tab inside the Browse screen. Identity verification happens inside DonateTab, not here.
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

  // Tab keys: static for unfiltered tabs, nonce-stamped for Browse to force Navigator rebuild when navigating from home.
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
          userRole: 'individual',
          userId: isAnonymous ? null : widget.user.uid,
          userName: widget.user.name,
          onGoToOffers: () => _goToBrowseTab(0),
          onGoToPackages: () => _goToBrowseTab(1),
          onGoToOrders: () => setState(() => _selectedIndex = 2),
          onGoToDonate: () => _goToBrowseTab(2),
          onGoToNotifications: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
      ),
    );
  }

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
          (i) => _UserTabView(
            key: keys[i],
            navigatorKey: navigatorKeys[i],
            child: pages[i],
          ),
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
          if (i == _selectedIndex) {
            // Already on this tab — pop to root without switching tabs or affecting other stacks.
            _navigatorKeys[i].currentState?.popUntil((route) => route.isFirst);
            return;
          }
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

// Per-tab Navigator that allows Navigator.push within a tab without losing the user dashboard bottom bar.
class _UserTabView extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  const _UserTabView({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => child),
    );
  }
}

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
