import 'package:flutter/material.dart';
import 'package:zad_app/screens/admin/admin_complaints_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSupportPanel,
        backgroundColor: AppColors.danger,
        tooltip: 'دعم المستخدمين',
        child: const Icon(Icons.support_agent_rounded, color: Colors.white),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.25),
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
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'المستخدمون',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report_rounded),
            label: 'الشكاوى',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'التقارير',
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
