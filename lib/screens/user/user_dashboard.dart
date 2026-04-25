import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import 'offers_screen.dart';
import 'user_orders_screen.dart';
import 'user_profile_screen.dart';

class UserDashboard extends StatefulWidget {
  final AppUser user;

  const UserDashboard({super.key, required this.user});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int selectedIndex = 0;

  late final List<Widget> pages = [
    UserHomeScreen(user: widget.user),
    const OffersScreen(),
    const UserOrdersScreen(),
    UserProfileScreen(user: widget.user),
  ];

  final titles = [
    "Home",
    "Browse Offers",
    "My Orders",
    "Profile",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        indicatorColor: AppColors.secondary.withOpacity(0.2),
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: "Home"),
          NavigationDestination(icon: Icon(Icons.search), label: "Offers"),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: "Orders"),
          NavigationDestination(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class UserHomeScreen extends StatelessWidget {
  final AppUser user;

  const UserHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ZAD User Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome, ${user.name}",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Find nearby surplus food offers and manage your reservations."),
            const SizedBox(height: 20),

            Row(
              children: const [
                Expanded(child: _StatCard(title: "Current Orders", value: "2", icon: Icons.shopping_bag)),
                SizedBox(width: 12),
                Expanded(child: _StatCard(title: "Previous Orders", value: "8", icon: Icons.history)),
              ],
            ),

            const SizedBox(height: 20),

            const Text("Quick Actions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            const SizedBox(height: 12),

            _ActionTile(
              icon: Icons.search,
              title: "Browse Food Offers",
              subtitle: "Find free or low-price food near you",
            ),
            _ActionTile(
              icon: Icons.qr_code,
              title: "Pickup QR Code",
              subtitle: "Use your QR code to confirm pickup",
            ),
            _ActionTile(
              icon: Icons.report,
              title: "Submit Complaint",
              subtitle: "Report an issue with an order",
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 30),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}