import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';
import 'charity_browse_screen.dart';
import 'charity_donations_screen.dart';
import 'charity_history_screen.dart';
import 'charity_home_screen.dart';
import 'charity_profile_screen.dart';

class CharityDashboard extends StatefulWidget {
  final AppUser user;
  const CharityDashboard({super.key, required this.user});

  @override
  State<CharityDashboard> createState() => _CharityDashboardState();
}

class _CharityDashboardState extends State<CharityDashboard> {
  int _selectedIndex = 0;
  late AppUser _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          CharityHomeScreen(
            user: _currentUser,
            onNavigate: (i) => setState(() => _selectedIndex = i),
          ),
          const CharityDonationsScreen(),
          const CharityBrowseScreen(),
          const CharityHistoryScreen(),
          CharityProfileScreen(
            user: _currentUser,
            onUserUpdated: (updatedUser) {
              setState(() => _currentUser = updatedUser);
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        indicatorColor: AppColors.primaryLight.withOpacity(0.25),
        backgroundColor: AppColors.card,
        elevation: 0,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism_outlined),
            selectedIcon: Icon(Icons.volunteer_activism_rounded),
            label: 'التبرعات',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'تصفح',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'السجل',
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
