import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';

class CharityDashboard extends StatefulWidget {
  final AppUser user;

  const CharityDashboard({super.key, required this.user});

  @override
  State<CharityDashboard> createState() => _CharityDashboardState();
}

class _CharityDashboardState extends State<CharityDashboard> {
  int selectedIndex = 0;

  late final List<Widget> pages = [
    CharityHomeScreen(user: widget.user),
    const CharityDonationsScreen(),
    const CharityRequestsScreen(),
    const CharityHistoryScreen(),
    CharityProfileScreen(user: widget.user),
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
          NavigationDestination(icon: Icon(Icons.volunteer_activism), label: "Donations"),
          NavigationDestination(icon: Icon(Icons.assignment), label: "Requests"),
          NavigationDestination(icon: Icon(Icons.history), label: "History"),
          NavigationDestination(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class CharityHomeScreen extends StatelessWidget {
  final AppUser user;

  const CharityHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Charity Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              "Welcome, ${user.name}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("Review donations, schedule pickups, and redistribute surplus food."),
            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(child: _CharityStatCard(title: "Pending Donations", value: "4", icon: Icons.pending)),
                SizedBox(width: 12),
                Expanded(child: _CharityStatCard(title: "Accepted", value: "18", icon: Icons.check_circle)),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(child: _CharityStatCard(title: "Redistributed", value: "14", icon: Icons.share)),
                SizedBox(width: 12),
                Expanded(child: _CharityStatCard(title: "Families Helped", value: "39", icon: Icons.family_restroom)),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const _CharityActionTile(
              icon: Icons.assignment,
              title: "Review Donation Requests",
              subtitle: "Accept or reject submitted donations",
            ),
            const _CharityActionTile(
              icon: Icons.schedule,
              title: "Schedule Pickup",
              subtitle: "Set pickup time for accepted donations",
            ),
            const _CharityActionTile(
              icon: Icons.fastfood,
              title: "Publish Remaining Surplus",
              subtitle: "Redistribute available food to beneficiaries",
            ),
          ],
        ),
      ),
    );
  }
}

class CharityDonationsScreen extends StatelessWidget {
  const CharityDonationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final donations = [
      {"title": "Bread Donation", "donor": "Local Bakery", "status": "Pending"},
      {"title": "Cooked Meals", "donor": "Family Donor", "status": "Accepted"},
      {"title": "Vegetable Boxes", "donor": "Market Store", "status": "Pending"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Donations")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: donations.length,
        itemBuilder: (context, index) {
          final donation = donations[index];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.volunteer_activism, color: AppColors.primary),
              title: Text(donation["title"]!),
              subtitle: Text("Donor: ${donation["donor"]} • ${donation["status"]}"),
              trailing: ElevatedButton(
                onPressed: () {},
                child: const Text("Review"),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CharityRequestsScreen extends StatelessWidget {
  const CharityRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = [
      "Family needs food package",
      "Student group request",
      "Emergency support request",
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Beneficiary Requests")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.assignment, color: AppColors.primary),
              title: Text(requests[index]),
              subtitle: const Text("Status: Waiting Review"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
          );
        },
      ),
    );
  }
}

class CharityHistoryScreen extends StatelessWidget {
  const CharityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = [
      {"title": "Bread Donation", "status": "Received"},
      {"title": "Pizza Packages", "status": "Redistributed"},
      {"title": "Vegetables", "status": "Received"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Donation History")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.history, color: AppColors.primary),
              title: Text(item["title"]!),
              subtitle: Text("Status: ${item["status"]}"),
              trailing: const Icon(Icons.check_circle, color: AppColors.primary),
            ),
          );
        },
      ),
    );
  }
}

class CharityProfileScreen extends StatelessWidget {
  final AppUser user;

  const CharityProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return _ProfileLayout(
      title: "Charity Profile",
      name: user.name,
      role: user.role,
      email: user.email,
      phone: user.phone,
      address: user.address,
    );
  }
}

class _CharityStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _CharityStatCard({
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
          Icon(icon, color: AppColors.primary, size: 32),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _CharityActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CharityActionTile({
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

class _ProfileLayout extends StatelessWidget {
  final String title;
  final String name;
  final String role;
  final String email;
  final String phone;
  final String address;

  const _ProfileLayout({
    required this.title,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.volunteer_activism, color: Colors.white, size: 55),
            ),
            const SizedBox(height: 14),
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(role.toUpperCase()),
            const SizedBox(height: 24),
            _ProfileTile(icon: Icons.email, title: "Email", value: email),
            _ProfileTile(icon: Icons.phone, title: "Phone", value: phone),
            _ProfileTile(icon: Icons.location_on, title: "Address", value: address),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}