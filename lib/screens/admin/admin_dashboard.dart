import 'package:flutter/material.dart';
import 'package:zad_app/screens/admin/admin_complaints_screen.dart';
import '../../utils/responsive.dart';
import 'package:zad_app/screens/admin/admin_home_screen.dart';
import 'package:zad_app/screens/admin/admin_profile_screen.dart';
import 'package:zad_app/screens/admin/admin_reports_screen.dart';
import 'package:zad_app/screens/admin/admin_support_panel.dart';
import 'package:zad_app/screens/admin/admin_users_screen.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────
// Dashboard الرئيسي
// ─────────────────────────────────────────────
class AdminDashboard extends StatefulWidget {
  final AppUser user;
  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      AdminHomeScreen(
        user: widget.user,
        onNavigate: (i) => setState(() => _selectedIndex = i),
      ),
      const AdminUsersScreen(),
      const AdminComplaintsScreen(),
      const AdminReportsScreen(),
      AdminProfileScreen(user: widget.user),
    ];
  }

  void _openSupportPanel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSupportPanel(user: widget.user),
      ),
    );
  }

  FloatingActionButton get _fab => FloatingActionButton(
        onPressed: _openSupportPanel,
        backgroundColor: AppColors.danger,
        tooltip: 'دعم المستخدمين',
        child: const Icon(Icons.support_agent_rounded, color: Colors.white),
      );

  static const List<NavigationRailDestination> _railDestinations = [
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: Text('الرئيسية'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people_rounded),
      label: Text('المستخدمون'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.report_outlined),
      selectedIcon: Icon(Icons.report_rounded),
      label: Text('الشكاوى'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart_rounded),
      label: Text('التقارير'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person_rounded),
      label: Text('حسابي'),
    ),
  ];

  Widget _buildMobileLayout() {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButton: _fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.25),
        backgroundColor: AppColors.card,
        elevation: 0,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'المستخدمون'),
          NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report_rounded), label: 'الشكاوى'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      floatingActionButton: _fab,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.card,
            indicatorColor: AppColors.primaryLight.withValues(alpha: 0.25),
            destinations: _railDestinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                final hPad = AppBreakpoints.contentPadding(constraints.maxWidth);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: IndexedStack(index: _selectedIndex, children: _pages),
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
    if (AppBreakpoints.isDesktop(context)) return _buildDesktopLayout();
    return _buildMobileLayout();
  }
}
