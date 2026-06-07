import 'package:flutter/material.dart';

import '../../models/user.dart';

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
