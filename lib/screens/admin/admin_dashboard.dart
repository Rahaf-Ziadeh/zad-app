import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';

class AdminDashboard extends StatefulWidget {
  final AppUser user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selectedIndex = 0;

  late final List<Widget> pages = [
    AdminHomeScreen(user: widget.user),
    const AdminUsersScreen(),
    const AdminComplaintsScreen(),
    const AdminReportsScreen(),
    AdminProfileScreen(user: widget.user),
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
          NavigationDestination(icon: Icon(Icons.people), label: "Users"),
          NavigationDestination(icon: Icon(Icons.report), label: "Complaints"),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: "Reports"),
          NavigationDestination(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class AdminHomeScreen extends StatelessWidget {
  final AppUser user;

  const AdminHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              "System Overview",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _AdminStatCard(title: "Users", value: "124", icon: Icons.people)),
                SizedBox(width: 12),
                Expanded(child: _AdminStatCard(title: "Offers", value: "58", icon: Icons.fastfood)),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _AdminStatCard(title: "Orders", value: "76", icon: Icons.receipt_long)),
                SizedBox(width: 12),
                Expanded(child: _AdminStatCard(title: "Complaints", value: "5", icon: Icons.report)),
              ],
            ),
            SizedBox(height: 24),
            Text(
              "Quick Management",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            _AdminActionTile(
              icon: Icons.verified_user,
              title: "Verify New Donors",
              subtitle: "Review identity verification requests",
            ),
            _AdminActionTile(
              icon: Icons.warning,
              title: "Resolve Conflicts",
              subtitle: "Handle reports, complaints, and duplicated reservations",
            ),
            _AdminActionTile(
              icon: Icons.analytics,
              title: "View Reports",
              subtitle: "Monitor platform performance and activity",
            ),
          ],
        ),
      ),
    );
  }
}

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final users = [
      {"name": "Regular User", "role": "Individual", "status": "Active"},
      {"name": "Pizza House", "role": "Restaurant", "status": "Pending"},
      {"name": "Hope Charity", "role": "Charity", "status": "Active"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Users")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];

          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(user["name"]!),
              subtitle: Text("${user["role"]} • ${user["status"]}"),
              trailing: PopupMenuButton(
                itemBuilder: (context) => const [
                  PopupMenuItem(value: "view", child: Text("View Details")),
                  PopupMenuItem(value: "activate", child: Text("Activate")),
                  PopupMenuItem(value: "suspend", child: Text("Suspend")),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminComplaintsScreen extends StatelessWidget {
  const AdminComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final complaints = [
      "User did not pick up the reserved order",
      "Restaurant published wrong pickup time",
      "Duplicate reservation issue",
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Complaints")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: complaints.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.report, color: AppColors.danger),
              title: Text(complaints[index]),
              subtitle: const Text("Status: Under Review"),
              trailing: ElevatedButton(
                onPressed: () {},
                child: const Text("Resolve"),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = [
      "Total food offers this month: 58",
      "Completed pickups: 43",
      "Free donations: 22",
      "Low-price offers: 36",
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Reports")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: reports
            .map(
              (report) => Card(
                child: ListTile(
                  leading: const Icon(Icons.analytics, color: AppColors.primary),
                  title: Text(report),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class AdminProfileScreen extends StatelessWidget {
  final AppUser user;

  const AdminProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return _ProfileLayout(
      title: "Admin Profile",
      name: user.name,
      role: user.role,
      email: user.email,
      phone: user.phone,
      address: user.address,
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _AdminStatCard({
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
          Text(title),
        ],
      ),
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AdminActionTile({
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
              child: Icon(Icons.person, color: Colors.white, size: 55),
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