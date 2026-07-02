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
      UserProfileScreen(
        user: widget.user,
        onGoToDonate: () => _goToBrowseTab(2),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _buildPages();
  }

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
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
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
