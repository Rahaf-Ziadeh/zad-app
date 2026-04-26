import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum PendingFilter {
  all,
  restaurants,
  charities,
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  PendingFilter selectedFilter = PendingFilter.all;

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _pendingRestaurantsStream() {
    return firestore
        .collection('users')
        .where('role', isEqualTo: 'restaurant')
        .where('isApproved', isEqualTo: false)
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  Stream<QuerySnapshot> _pendingCharitiesStream() {
    return firestore
        .collection('users')
        .where('role', isEqualTo: 'charity')
        .where('isApproved', isEqualTo: false)
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

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
    } else {
      return "Accounts Waiting for Approval";
    }
  }

  Future<void> _approveAccount({
    required String userId,
    required Map<String, dynamic> data,
    required BuildContext context,
  }) async {
    final adminId = FirebaseAuth.instance.currentUser!.uid;

    await firestore.collection('users').doc(userId).update({
      'isApproved': true,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await firestore.collection('admins').add({
      'adminId': adminId,
      'action': 'approve_account',
      'reason': 'Account approved by admin',
      'targetId': userId,
      'targetType': data['role'] ?? 'user',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Account approved")),
    );
  }

  Future<void> _rejectAccount({
    required String userId,
    required Map<String, dynamic> data,
    required BuildContext context,
  }) async {
    final adminId = FirebaseAuth.instance.currentUser!.uid;

    await firestore.collection('users').doc(userId).update({
      'isApproved': false,
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await firestore.collection('admins').add({
      'adminId': adminId,
      'action': 'reject_account',
      'reason': 'Account rejected by admin',
      'targetId': userId,
      'targetType': data['role'] ?? 'user',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Account rejected")),
    );
  }

  Future<void> _suspendUser({
    required String userId,
    required Map<String, dynamic> data,
    required BuildContext context,
  }) async {
    final adminId = FirebaseAuth.instance.currentUser!.uid;

    await firestore.collection('users').doc(userId).update({
      'status': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await firestore.collection('admins').add({
      'adminId': adminId,
      'action': 'suspend_user',
      'reason': 'Suspended by admin',
      'targetId': userId,
      'targetType': data['role'] ?? 'user',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User suspended")),
    );
  }

  Future<void> _unsuspendUser({
    required String userId,
    required Map<String, dynamic> data,
    required BuildContext context,
  }) async {
    final adminId = FirebaseAuth.instance.currentUser!.uid;

    await firestore.collection('users').doc(userId).update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await firestore.collection('admins').add({
      'adminId': adminId,
      'action': 'unsuspend_user',
      'reason': 'Unsuspended by admin',
      'targetId': userId,
      'targetType': data['role'] ?? 'user',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User unsuspended")),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome Admin",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            StreamBuilder<QuerySnapshot>(
              stream: _pendingRestaurantsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                return _buildStatCard(
                  title: "Pending Restaurants",
                  value: snapshot.data!.docs.length.toString(),
                  icon: Icons.restaurant,
                  isSelected: selectedFilter == PendingFilter.restaurants,
                  onTap: () {
                    setState(() {
                      selectedFilter = PendingFilter.restaurants;
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot>(
              stream: _pendingCharitiesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                return _buildStatCard(
                  title: "Pending Charities",
                  value: snapshot.data!.docs.length.toString(),
                  icon: Icons.volunteer_activism,
                  isSelected: selectedFilter == PendingFilter.charities,
                  onTap: () {
                    setState(() {
                      selectedFilter = PendingFilter.charities;
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 12),

            _buildAllPendingButton(),

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
                  return const CircularProgressIndicator();
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Text("No pending accounts");
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (data['role'] == 'admin') {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(data['fullName'] ?? 'No Name'),
                        subtitle: Text(
                          "${data['email'] ?? ''} | ${data['role'] ?? ''}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                _approveAccount(
                                  userId: doc.id,
                                  data: data,
                                  context: context,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Approve"),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                _rejectAccount(
                                  userId: doc.id,
                                  data: data,
                                  context: context,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Reject"),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

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
                  return const CircularProgressIndicator();
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Text("No active users");
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (data['role'] == 'admin') {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(data['fullName'] ?? 'No Name'),
                        subtitle: Text(
                          "${data['email'] ?? ''} | ${data['role'] ?? ''}",
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            _suspendUser(
                              userId: doc.id,
                              data: data,
                              context: context,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Suspend"),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

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
                  return const CircularProgressIndicator();
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Text("No suspended users");
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (data['role'] == 'admin') {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.lock_open),
                        title: Text(data['fullName'] ?? 'No Name'),
                        subtitle: Text(
                          "${data['email'] ?? ''} | ${data['role'] ?? ''}",
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            _unsuspendUser(
                              userId: doc.id,
                              data: data,
                              context: context,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Unsuspend"),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            const Text(
              "Recent Admin Logs",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('admins')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text("Error loading logs");
                }

                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final logs = snapshot.data!.docs;

                if (logs.isEmpty) {
                  return const Text("No admin logs found");
                }

                return Column(
                  children: logs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(data['action'] ?? 'No Action'),
                        subtitle: Text(
                          "Reason: ${data['reason'] ?? ''}\nTarget: ${data['targetType'] ?? ''} - ${data['targetId'] ?? ''}",
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: isSelected ? 6 : 3,
      color: isSelected ? const Color(0xFFE6F7EF) : Colors.white,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, size: 32, color: const Color(0xFF059669)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text("Tap to filter"),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAllPendingButton() {
    final bool isSelected = selectedFilter == PendingFilter.all;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            selectedFilter = PendingFilter.all;
          });
        },
        icon: const Icon(Icons.list_alt),
        label: const Text("Show All Pending Accounts"),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF059669),
          backgroundColor: isSelected ? const Color(0xFFE6F7EF) : Colors.white,
          side: const BorderSide(color: Color(0xFF059669)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}