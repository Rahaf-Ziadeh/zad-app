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

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminHomeScreen(
        user: widget.user,
        onNavigate: (index) => setState(() => selectedIndex = index),
      ),
      const AdminUsersScreen(),
      const AdminComplaintsScreen(),
      const AdminReportsScreen(),
      AdminProfileScreen(user: widget.user),
    ];

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        indicatorColor: AppColors.primaryLight.withOpacity(0.25),
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: "الرئيسية",
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: "المستخدمون",
          ),
          NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report_rounded),
            label: "الشكاوى",
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: "التقارير",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: "حسابي",
          ),
        ],
      ),
    );
  }
}

class AdminHomeScreen extends StatelessWidget {
  final AppUser user;
  final ValueChanged<int> onNavigate;

  const AdminHomeScreen({
    super.key,
    required this.user,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة التحكم"),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF10B981),
                  Color(0xFF059669),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "مرحباً بعودتك",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "راقب الحسابات، الموافقات، الشكاوى، ونشاط النظام من مكان واحد.",
                        style: TextStyle(
                          color: Colors.white,
                          height: 1.5,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return _AdminStatCard(
                title: "إجمالي المستخدمين",
                value: count.toString(),
                icon: Icons.people_rounded,
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
                title: "حسابات بانتظار الموافقة",
                value: count.toString(),
                icon: Icons.verified_user_rounded,
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
                title: "آخر إجراءات الأدمن",
                value: count.toString(),
                icon: Icons.history_rounded,
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "إدارة سريعة",
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          _AdminActionTile(
            icon: Icons.verified_user_rounded,
            title: "مراجعة الحسابات الجديدة",
            subtitle: "قبول أو رفض حسابات المطاعم والجمعيات",
            onTap: () => onNavigate(1),
          ),
          _AdminActionTile(
            icon: Icons.warning_amber_rounded,
            title: "متابعة الشكاوى",
            subtitle: "مراجعة البلاغات وحل النزاعات",
            onTap: () => onNavigate(2),
          ),
          _AdminActionTile(
            icon: Icons.analytics_rounded,
            title: "عرض التقارير",
            subtitle: "مراقبة نشاط النظام وسجل الإجراءات",
            onTap: () => onNavigate(3),
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
      return "مطاعم بانتظار الموافقة";
    } else if (selectedFilter == PendingFilter.charities) {
      return "جمعيات بانتظار الموافقة";
    }
    return "حسابات بانتظار الموافقة";
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'restaurant':
        return 'مطعم';
      case 'charity':
        return 'جمعية';
      case 'individual':
        return 'مستخدم';
      case 'admin':
        return 'مدير';
      default:
        return role;
    }
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
      reason: 'تمت الموافقة على الحساب',
      targetId: userId,
      targetType: data['role'] ?? 'user',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تمت الموافقة على الحساب")),
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
      reason: 'تم رفض الحساب',
      targetId: userId,
      targetType: data['role'] ?? 'user',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم رفض الحساب")),
    );
  }

  Future<void> _suspendUser(String userId, Map<String, dynamic> data) async {
    await firestore.collection('users').doc(userId).update({
      'status': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAdminAction(
      action: 'suspend_user',
      reason: 'تم تعليق الحساب',
      targetId: userId,
      targetType: data['role'] ?? 'user',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم تعليق المستخدم")),
    );
  }

  Future<void> _unsuspendUser(String userId, Map<String, dynamic> data) async {
    await firestore.collection('users').doc(userId).update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAdminAction(
      action: 'unsuspend_user',
      reason: 'تمت إعادة تفعيل الحساب',
      targetId: userId,
      targetType: data['role'] ?? 'user',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تمت إعادة تفعيل المستخدم")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة المستخدمين"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text("الكل"),
                selected: selectedFilter == PendingFilter.all,
                onSelected: (_) {
                  setState(() => selectedFilter = PendingFilter.all);
                },
              ),
              ChoiceChip(
                label: const Text("المطاعم"),
                selected: selectedFilter == PendingFilter.restaurants,
                onSelected: (_) {
                  setState(() => selectedFilter = PendingFilter.restaurants);
                },
              ),
              ChoiceChip(
                label: const Text("الجمعيات"),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: _pendingAccountsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text("حدث خطأ أثناء تحميل الحسابات");
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const _EmptyCard(
                    text: "لا توجد حسابات بانتظار الموافقة");
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  if (data['role'] == 'admin') return const SizedBox.shrink();

                  return _UserManagementCard(
                    name: data['fullName'] ?? 'بدون اسم',
                    email: data['email'] ?? '',
                    role: _roleLabel(data['role'] ?? ''),
                    status: "بانتظار الموافقة",
                    icon: Icons.pending_actions_rounded,
                    actions: [
                      IconButton(
                        tooltip: "موافقة",
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        ),
                        onPressed: () => _approveAccount(doc.id, data),
                      ),
                      IconButton(
                        tooltip: "رفض",
                        icon: const Icon(
                          Icons.cancel_rounded,
                          color: AppColors.danger,
                        ),
                        onPressed: () => _rejectAccount(doc.id, data),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "المستخدمون النشطون",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
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
                return const _EmptyCard(text: "لا يوجد مستخدمون نشطون");
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  if (data['role'] == 'admin') return const SizedBox.shrink();

                  return _UserManagementCard(
                    name: data['fullName'] ?? 'بدون اسم',
                    email: data['email'] ?? '',
                    role: _roleLabel(data['role'] ?? ''),
                    status: "نشط",
                    icon: Icons.person_outline_rounded,
                    actions: [
                      TextButton(
                        onPressed: () => _suspendUser(doc.id, data),
                        child: const Text("تعليق"),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "المستخدمون المعلّقون",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
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
                return const _EmptyCard(text: "لا يوجد مستخدمون معلّقون");
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  if (data['role'] == 'admin') return const SizedBox.shrink();

                  return _UserManagementCard(
                    name: data['fullName'] ?? 'بدون اسم',
                    email: data['email'] ?? '',
                    role: _roleLabel(data['role'] ?? ''),
                    status: "معلّق",
                    icon: Icons.lock_open_rounded,
                    actions: [
                      TextButton(
                        onPressed: () => _unsuspendUser(doc.id, data),
                        child: const Text("إعادة تفعيل"),
                      ),
                    ],
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
      "مستخدم لم يستلم الطلب في الموعد",
      "مطعم نشر وقت استلام غير صحيح",
      "مشكلة حجز مكرر لنفس العرض",
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("الشكاوى والبلاغات")),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: complaints.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.danger.withOpacity(0.12),
                child: const Icon(
                  Icons.report_rounded,
                  color: AppColors.danger,
                ),
              ),
              title: Text(
                complaints[index],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("الحالة: قيد المراجعة"),
              trailing: ElevatedButton(
                onPressed: () {},
                child: const Text("حل"),
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

  String _actionLabel(String action) {
    switch (action) {
      case 'approve_account':
        return 'الموافقة على حساب';
      case 'reject_account':
        return 'رفض حساب';
      case 'suspend_user':
        return 'تعليق مستخدم';
      case 'unsuspend_user':
        return 'إعادة تفعيل مستخدم';
      default:
        return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text("التقارير والسجلات")),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            "آخر إجراءات الإدارة",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
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
                return const Text("حدث خطأ أثناء تحميل السجلات");
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final logs = snapshot.data!.docs;

              if (logs.isEmpty) {
                return const _EmptyCard(text: "لا توجد سجلات حالياً");
              }

              return Column(
                children: logs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: const Icon(
                          Icons.history_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        _actionLabel(data['action'] ?? ''),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "السبب: ${data['reason'] ?? ''}\nالنوع: ${data['targetType'] ?? ''}",
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
      title: "حساب المدير",
      name: user.name,
      role: "مدير النظام",
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textLight),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }
}

class _UserManagementCard extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String status;
  final IconData icon;
  final List<Widget> actions;

  const _UserManagementCard({
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.icon,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("$email\nالدور: $role • الحالة: $status"),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 6,
          children: actions,
        ),
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
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 10),
          const CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primary,
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            role,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          _ProfileTile(
              icon: Icons.email_outlined, title: "البريد", value: email),
          _ProfileTile(
              icon: Icons.phone_outlined, title: "الهاتف", value: phone),
          _ProfileTile(
            icon: Icons.location_on_outlined,
            title: "العنوان",
            value: address,
          ),
        ],
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
        subtitle: Text(value.isEmpty ? "غير محدد" : value),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textLight),
        ),
      ),
    );
  }
}
