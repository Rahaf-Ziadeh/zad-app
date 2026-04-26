import 'package:flutter/material.dart';
import 'offers_tab.dart';
import 'packages_tab.dart';
import 'donate_tab.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("User Dashboard"),
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Offers"),
              Tab(text: "Packages"),
              Tab(text: "Donate"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            OffersTab(),
            PackagesTab(),
            DonateTab(),
          ],
        ),
      ),
    );
  }
}