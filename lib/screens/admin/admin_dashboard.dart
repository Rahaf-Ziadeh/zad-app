import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';

enum PendingFilter { all, restaurants, charities }

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
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Welcome, ${user.name}",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            "Monitor users, approvals, complaints, and system activity.",
            style: TextStyle(color: AppColors.textLight),
          ),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return _AdminStatCard(
                title: "Total Users",
                value: count.toString(),
                icon: Icons.people,
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('users')
                .where('isApproved', isEqualTo: false)
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return _AdminStatCard(
                title: "Pending Approval",
                value: count.toString(),
                icon: Icons.verified_user,
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('admins')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return _AdminStatCard(
                title: "Recent Admin Logs",
                value: count.toString(),
                icon: Icons.history,
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "Quick Management",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const _AdminActionTile(
            icon: Icons.verified_user,
            title: "Verify New Accounts",
            subtitle: "Approve restaurants and charities",
          ),
          const _AdminActionTile(
            icon: Icons.warning,
            title: "Resolve Conflicts",
            subtitle: "Handle reports and complaints",
          ),
          const _AdminActionTile(
            icon: Icons.analytics,
            title: "View Reports",
            subtitle: "Monitor platform activity",
          ),
        ],
      ),
    );
  }
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  PendingFilter selectedFilter = PendingFilter.all;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _pendingAccountsStream() {
    Query query = firestore
        .collection('users')
        .where('isApproved', isEqualTo: false)
        .where('status', isEqualTo: 'active');

    if (selectedFilter == PendingFilter.restaurants) {
      query = query.where('role', isEqualTo: 'restaurant');
    } else if (selectedFilter == PendingFilter.charities) {
      query = query.where('role', isEqualTo: 'charity');
    }

    return query.snapshots();
  }

  String _filterTitle() {
    if (selectedFilter == PendingFilter.restaurants) {
      return "Pending Restaurants";
    } else if (selectedFilter == PendingFilter.charities) {
      return "Pending Charities";
    }
    return "Accounts Waiting for Approval";
  }

  Future<void> _logAdminAction({
    required String action,
    required String reason,
    required String targetId,
    required String targetType,
  }) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? "unknown_admin";

    await firestore.collection('admins').add({
      'adminId': adminId,
      'action': action,
      'reason': reason,
      'targetId': targetId,
      'targetType': targetType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _approveAccount(String userId, Map<String, dynamic> data) async {
    await firestore.collection('users').doc(userId).update({
      'isApproved': true,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAdminAction(
      action: 'approve_account',
      reason: 'Account approved by admin',
      targetId: userId,
      targetType: data['role'] ?? 'user',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Account approved")),
    );
  }

  Future<void> _rejectAccount(String userId, Map<String, dynamic> data) async {
    await firestore.collection('users').doc(userId).update({
      'isApproved': false,
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAdminAction(
      action: 'reject_account',
      reason: 'Account rejected by admin',
      targetId: userId,
      targetType: data['role'] ?? 'user',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Account rejected")),
    );
  }

  Future<void> _suspendUser(String userId, Map<String, dynamic> data) async {
    await firestore.collection('users').doc(userId).update({
      'status': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAdminAction(
      action: 'suspend_user',
      reason: 'Suspended by admin',
      targetId: userId,
      targetType: data['role'] ?? 'user',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User suspended")),
    );
  }

  Future<void> _unsuspendUser(String userId, Map<String, dynamic> data) async {
    await firestore.collection('users').doc(userId).update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAdminAction(
      action: 'unsuspend_user',
      reason: 'Unsuspended by admin',
      targetId: userId,
      targetType: data['role'] ?? 'user',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User unsuspended")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Users"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text("All Pending"),
                selected: selectedFilter == PendingFilter.all,
                onSelected: (_) {
                  setState(() => selectedFilter = PendingFilter.all);
                },
              ),
              ChoiceChip(
                label: const Text("Restaurants"),
                selected: selectedFilter == PendingFilter.restaurants,
                onSelected: (_) {
                  setState(() => selectedFilter = PendingFilter.restaurants);
                },
              ),
              ChoiceChip(
                label: const Text("Charities"),
                selected: selectedFilter == PendingFilter.charities,
                onSelected: (_) {
                  setState(() => selectedFilter = PendingFilter.charities);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _filterTitle(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: _pendingAccountsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text("Error: ${snapshot.error}");
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("No pending accounts"),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  if (data['role'] == 'admin') return const SizedBox.shrink();

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(data['fullName'] ?? 'No Name'),
                      subtitle: Text(
                        "${data['email'] ?? ''}\nRole: ${data['role'] ?? ''}",
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: "Approve",
                            icon: const Icon(Icons.check_circle,
                                color: AppColors.primary),
                            onPressed: () => _approveAccount(doc.id, data),
                          ),
                          IconButton(
                            tooltip: "Reject",
                            icon: const Icon(Icons.cancel,
                                color: AppColors.danger),
                            onPressed: () => _rejectAccount(doc.id, data),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "Active Users",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('users')
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("No active users"),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['role'] == 'admin') return const SizedBox.shrink();

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline,
                          color: AppColors.primary),
                      title: Text(data['fullName'] ?? 'No Name'),
                      subtitle: Text(
                        "${data['email'] ?? ''} | ${data['role'] ?? ''}",
                      ),
                      trailing: TextButton(
                        onPressed: () => _suspendUser(doc.id, data),
                        child: const Text("Suspend"),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "Suspended Users",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('users')
                .where('status', isEqualTo: 'suspended')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("No suspended users"),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['role'] == 'admin') return const SizedBox.shrink();

                  return Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.lock_open, color: AppColors.primary),
                      title: Text(data['fullName'] ?? 'No Name'),
                      subtitle: Text(
                        "${data['email'] ?? ''} | ${data['role'] ?? ''}",
                      ),
                      trailing: TextButton(
                        onPressed: () => _unsuspendUser(doc.id, data),
                        child: const Text("Unsuspend"),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
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
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text("Reports")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Recent Admin Logs",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('admins')
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text("Error loading logs");
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final logs = snapshot.data!.docs;

              if (logs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("No admin logs found"),
                  ),
                );
              }

              return Column(
                children: logs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  return Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.history, color: AppColors.primary),
                      title: Text(data['action'] ?? 'No Action'),
                      subtitle: Text(
                        "Reason: ${data['reason'] ?? ''}\nTarget: ${data['targetType'] ?? ''}",
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
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
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
              child: Icon(Icons.admin_panel_settings,
                  color: Colors.white, size: 55),
            ),
            const SizedBox(height: 14),
            Text(name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(role.toUpperCase()),
            const SizedBox(height: 24),
            _ProfileTile(icon: Icons.email, title: "Email", value: email),
            _ProfileTile(icon: Icons.phone, title: "Phone", value: phone),
            _ProfileTile(
                icon: Icons.location_on, title: "Address", value: address),
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
