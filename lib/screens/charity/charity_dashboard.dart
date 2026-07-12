import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../utils/responsive.dart';
import 'charity_browse_screen.dart';
import 'charity_donations_screen.dart';
import 'charity_history_screen.dart';
import 'charity_home_screen.dart';
import 'charity_profile_screen.dart';
import 'charity_reservations_screen.dart';

class CharityDashboard extends StatefulWidget {
  final AppUser user;

  const CharityDashboard({
    super.key,
    required this.user,
  });

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

  IndexedStack get _body => IndexedStack(
        index: _selectedIndex,
        children: [
          CharityHomeScreen(
            user: _currentUser,
            onNavigate: (i) => setState(() => _selectedIndex = i),
          ),
          const CharityDonationsScreen(),
          const CharityBrowseScreen(),
          const CharityReservationsScreen(),
          const CharityHistoryScreen(),
          CharityProfileScreen(
            user: _currentUser,
            onUserUpdated: (updatedUser) {
              setState(() => _currentUser = updatedUser);
            },
          ),
        ],
      );

  static const List<NavigationRailDestination> _railDestinations = [
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: Text('الرئيسية'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.volunteer_activism_outlined),
      selectedIcon: Icon(Icons.volunteer_activism_rounded),
      label: Text('التبرعات'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search_rounded),
      label: Text('تصفح'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: Text('حجوزاتي'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history_rounded),
      label: Text('السجل'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person_rounded),
      label: Text('حسابي'),
    ),
  ];

  Widget _buildMobileLayout() {
    return Scaffold(
      body: _body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.25),
        backgroundColor: AppColors.card,
        elevation: 0,
        onDestinationSelected: (i) {
          setState(() => _selectedIndex = i);
        },
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
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'حجوزاتي',
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

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) {
              setState(() => _selectedIndex = i);
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.card,
            indicatorColor: AppColors.primaryLight.withValues(alpha: 0.25),
            destinations: _railDestinations,
          ),
          const VerticalDivider(
            thickness: 1,
            width: 1,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                final hPad =
                    AppBreakpoints.contentPadding(constraints.maxWidth);

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: _body,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isDesktop(context)) {
      return _buildDesktopLayout();
    }

    return _buildMobileLayout();
  }
}
