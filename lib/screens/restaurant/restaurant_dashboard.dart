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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      RestaurantHomeScreen(
        user: widget.user,
        onNavigate: (i) => setState(() => _selectedIndex = i),
      ),
      const RestaurantOffersScreen(),
      const RestaurantReservationsScreen(),
      const AddOfferScreen(),
      RestaurantProfileScreen(user: widget.user),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
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
