import '../../widgets/app_widgets.dart';
import 'package:flutter/material.dart';
import '../../models/user.dart';

class UserHomeScreen extends StatelessWidget {
  final AppUser user;

  const UserHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ZAD")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppHeader(
            title: "Welcome, ${user.name}",
            subtitle:
                "Discover nearby surplus food, reserve offers, and manage your pickups.",
          ),
          const SizedBox(height: 22),
          const Row(
            children: [
              Expanded(
                child: StatCard(
                  title: "Current Orders",
                  value: "2",
                  icon: Icons.shopping_bag,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: StatCard(
                  title: "Previous Orders",
                  value: "8",
                  icon: Icons.history,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const ActionCard(
            icon: Icons.search,
            title: "Browse Offers",
            subtitle: "Find free and low-price food near you",
          ),
          const ActionCard(
            icon: Icons.qr_code,
            title: "Pickup QR Code",
            subtitle: "Show your code when collecting food",
          ),
          const ActionCard(
            icon: Icons.report,
            title: "Report an Issue",
            subtitle: "Submit complaint or feedback",
          ),
        ],
      ),
    );
  }
}
