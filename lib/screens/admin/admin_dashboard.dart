import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';

enum _UserFilter { all, restaurants, charities }

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

// ─────────────────────────────────────────────
// الشاشة الرئيسية
// ─────────────────────────────────────────────
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('زاد',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          // ── بطاقة الترحيب ──
          _WelcomeCard(user: user),
          const SizedBox(height: 20),

          // ── إحصائيات ──
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestore.collection('users').snapshots(),
                  builder: (_, snap) => _StatCard(
                    title: 'المستخدمون',
                    value: snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.people_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestore
                      .collection('users')
                      .where('isApproved', isEqualTo: false)
                      .where('status', isEqualTo: 'active')
                      .snapshots(),
                  builder: (_, snap) => _StatCard(
                    title: 'بانتظار',
                    value: snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.pending_rounded,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestore
                      .collection('complaints')
                      .where('status', isEqualTo: 'open')
                      .snapshots(),
                  builder: (_, snap) => _StatCard(
                    title: 'شكاوى',
                    value: snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.report_rounded,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── عروض نشطة + حجوزات ──
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestore
                      .collection('offers')
                      .where('status', isEqualTo: 'available')
                      .snapshots(),
                  builder: (_, snap) => _StatCard(
                    title: 'عروض نشطة',
                    value: snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.fastfood_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestore
                      .collection('reservations')
                      .where('status', isEqualTo: 'picked_up')
                      .snapshots(),
                  builder: (_, snap) => _StatCard(
                    title: 'تم توزيعه',
                    value: snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text('إدارة سريعة',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 12),

          _ActionTile(
            icon: Icons.verified_user_rounded,
            title: 'مراجعة الحسابات الجديدة',
            subtitle: 'قبول أو رفض حسابات المطاعم والجمعيات',
            color: AppColors.primary,
            onTap: () => onNavigate(1),
          ),
          _ActionTile(
            icon: Icons.warning_amber_rounded,
            title: 'متابعة الشكاوى',
            subtitle: 'مراجعة البلاغات وحل النزاعات',
            color: AppColors.danger,
            onTap: () => onNavigate(2),
          ),
          _ActionTile(
            icon: Icons.analytics_rounded,
            title: 'عرض التقارير',
            subtitle: 'مراقبة نشاط النظام وسجل الإجراءات',
            color: const Color(0xFF7C3AED),
            onTap: () => onNavigate(3),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// شاشة المستخدمين
// ─────────────────────────────────────────────
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  _UserFilter _filter = _UserFilter.all;
  late final TabController _tabController;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _pendingStream() {
    Query q = _firestore
        .collection('users')
        .where('isApproved', isEqualTo: false)
        .where('status', isEqualTo: 'active');
    if (_filter == _UserFilter.restaurants) {
      q = q.where('role', isEqualTo: 'restaurant');
    } else if (_filter == _UserFilter.charities) {
      q = q.where('role', isEqualTo: 'charity');
    }
    return q.snapshots();
  }

  Future<void> _logAction({
    required String action,
    required String reason,
    required String targetId,
    required String targetType,
  }) async {
    final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    await _firestore.collection('admins').add({
      'adminId': adminId,
      'action': action,
      'reason': reason,
      'targetId': targetId,
      'targetType': targetType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _approveAccount(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update({
      'isApproved': true,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await NotificationService().sendNotification(
      userId: userId,
      title: 'تم قبول الحساب ✅',
      message: 'تمت الموافقة على حسابك ويمكنك الآن استخدام التطبيق.',
      type: 'account',
    );
    await _logAction(
      action: 'approve_account',
      reason: 'تمت الموافقة على الحساب',
      targetId: userId,
      targetType: data['role'] ?? 'user',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تمت الموافقة على الحساب ✅'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _rejectAccount(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update({
      'isApproved': false,
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await NotificationService().sendNotification(
      userId: userId,
      title: 'تم رفض الحساب',
      message: 'عذراً، تم رفض طلب إنشاء حسابك.',
      type: 'account',
    );
    await _logAction(
      action: 'reject_account',
      reason: 'تم رفض الحساب',
      targetId: userId,
      targetType: data['role'] ?? 'user',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم رفض الحساب')),
    );
  }

  Future<void> _toggleSuspend(
      String userId, Map<String, dynamic> data, bool suspend) async {
    final newStatus = suspend ? 'suspended' : 'active';
    await _firestore.collection('users').doc(userId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (suspend) {
      await NotificationService().sendNotification(
        userId: userId,
        title: 'تم تعليق الحساب',
        message: 'تم تعليق حسابك مؤقتاً من قبل الإدارة.',
        type: 'account',
      );
    }
    await _logAction(
      action: suspend ? 'suspend_user' : 'unsuspend_user',
      reason: suspend ? 'تم تعليق الحساب' : 'تمت إعادة تفعيل الحساب',
      targetId: userId,
      targetType: data['role'] ?? 'user',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(suspend ? 'تم تعليق المستخدم' : 'تمت إعادة تفعيل المستخدم'),
        backgroundColor: suspend ? AppColors.danger : AppColors.success,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'بانتظار الموافقة'),
            Tab(text: 'نشطون'),
            Tab(text: 'معلّقون'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── فلتر ──
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded,
                    size: 18, color: AppColors.textLight),
                const SizedBox(width: 8),
                ...[
                  ('الكل', _UserFilter.all),
                  ('مطاعم', _UserFilter.restaurants),
                  ('جمعيات', _UserFilter.charities),
                ].map((e) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChip(
                        label: e.$1,
                        selected: _filter == e.$2,
                        onTap: () => setState(() => _filter = e.$2),
                      ),
                    )),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── بانتظار الموافقة ──
                StreamBuilder<QuerySnapshot>(
                  stream: _pendingStream(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs
                        .where((d) => (d.data() as Map)['role'] != 'admin')
                        .toList();
                    if (docs.isEmpty) {
                      return const _EmptyState(
                          message: 'لا توجد حسابات بانتظار الموافقة');
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return _UserCard(
                          name: data['fullName'] ?? data['name'] ?? 'بدون اسم',
                          email: data['email'] ?? '',
                          role: _roleLabel(data['role'] ?? ''),
                          statusLabel: 'بانتظار الموافقة',
                          statusColor: Colors.orange,
                          actions: [
                            _ActionButton(
                              label: 'موافقة',
                              icon: Icons.check_circle_rounded,
                              color: AppColors.success,
                              onTap: () => _approveAccount(doc.id, data),
                            ),
                            const SizedBox(width: 8),
                            _ActionButton(
                              label: 'رفض',
                              icon: Icons.cancel_rounded,
                              color: AppColors.danger,
                              onTap: () => _rejectAccount(doc.id, data),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                // ── نشطون ──
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .where('status', isEqualTo: 'active')
                      .where('isApproved', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs
                        .where((d) => (d.data() as Map)['role'] != 'admin')
                        .toList();
                    if (docs.isEmpty) {
                      return const _EmptyState(
                          message: 'لا يوجد مستخدمون نشطون');
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return _UserCard(
                          name: data['fullName'] ?? data['name'] ?? 'بدون اسم',
                          email: data['email'] ?? '',
                          role: _roleLabel(data['role'] ?? ''),
                          statusLabel: 'نشط',
                          statusColor: AppColors.success,
                          actions: [
                            _ActionButton(
                              label: 'تعليق',
                              icon: Icons.pause_circle_rounded,
                              color: AppColors.danger,
                              onTap: () => _toggleSuspend(doc.id, data, true),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                // ── معلّقون ──
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .where('status', isEqualTo: 'suspended')
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs
                        .where((d) => (d.data() as Map)['role'] != 'admin')
                        .toList();
                    if (docs.isEmpty) {
                      return const _EmptyState(
                          message: 'لا يوجد مستخدمون معلّقون');
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return _UserCard(
                          name: data['fullName'] ?? data['name'] ?? 'بدون اسم',
                          email: data['email'] ?? '',
                          role: _roleLabel(data['role'] ?? ''),
                          statusLabel: 'معلّق',
                          statusColor: AppColors.danger,
                          actions: [
                            _ActionButton(
                              label: 'إعادة تفعيل',
                              icon: Icons.play_circle_rounded,
                              color: AppColors.success,
                              onTap: () => _toggleSuspend(doc.id, data, false),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// شاشة الشكاوى — حقيقية من Firestore
// ─────────────────────────────────────────────
class AdminComplaintsScreen extends StatelessWidget {
  const AdminComplaintsScreen({super.key});

  Future<void> _resolveComplaint(
      BuildContext context, String complaintId) async {
    await FirebaseFirestore.instance
        .collection('complaints')
        .doc(complaintId)
        .update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حل الشكوى ✅'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.danger;
      case 'resolved':
        return AppColors.success;
      default:
        return AppColors.textLight;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'مفتوحة';
      case 'resolved':
        return 'تم الحل';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('الشكاوى والبلاغات'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'مفتوحة'),
              Tab(text: 'تم الحل'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ComplaintsList(
              stream: FirebaseFirestore.instance
                  .collection('complaints')
                  .where('status', isEqualTo: 'open')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              onResolve: _resolveComplaint,
              statusColor: _statusColor,
              statusLabel: _statusLabel,
              showResolveButton: true,
            ),
            _ComplaintsList(
              stream: FirebaseFirestore.instance
                  .collection('complaints')
                  .where('status', isEqualTo: 'resolved')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              onResolve: null,
              statusColor: _statusColor,
              statusLabel: _statusLabel,
              showResolveButton: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintsList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final Future<void> Function(BuildContext, String)? onResolve;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final bool showResolveButton;

  const _ComplaintsList({
    required this.stream,
    required this.onResolve,
    required this.statusColor,
    required this.statusLabel,
    required this.showResolveButton,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _EmptyState(
            message: showResolveButton
                ? 'لا توجد شكاوى مفتوحة 🎉'
                : 'لا توجد شكاوى محلولة',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'open';
            final description = data['description'] ?? 'لا يوجد وصف';
            final relatedOffer = data['relatedOfferId'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: statusColor(status).withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.report_rounded,
                              color: AppColors.danger, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('شكوى مستخدم',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              if (relatedOffer.isNotEmpty)
                                Text('رقم العرض: $relatedOffer',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textLight)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor(status).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel(status),
                            style: TextStyle(
                                color: statusColor(status),
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                          height: 1.5),
                    ),
                    if (showResolveButton && onResolve != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => onResolve!(context, doc.id),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('تمييز كمحلول'),
                          style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// شاشة التقارير
// ─────────────────────────────────────────────
class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  String _actionLabel(String action) {
    switch (action) {
      case 'approve_account':
        return 'موافقة على حساب';
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

  IconData _actionIcon(String action) {
    switch (action) {
      case 'approve_account':
        return Icons.check_circle_rounded;
      case 'reject_account':
        return Icons.cancel_rounded;
      case 'suspend_user':
        return Icons.pause_circle_rounded;
      case 'unsuspend_user':
        return Icons.play_circle_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'approve_account':
      case 'unsuspend_user':
        return AppColors.success;
      case 'reject_account':
      case 'suspend_user':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('التقارير والسجلات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // ── إحصائيات سريعة ──
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestore
                      .collection('donations')
                      .where('status', isEqualTo: 'redistributed')
                      .snapshots(),
                  builder: (_, snap) => _MiniStatCard(
                    title: 'تبرعات موزّعة',
                    value: snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.volunteer_activism_rounded,
                    color: const Color(0xFFE11D48),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestore
                      .collection('reservations')
                      .where('status', isEqualTo: 'picked_up')
                      .snapshots(),
                  builder: (_, snap) => _MiniStatCard(
                    title: 'وجبات وُزّعت',
                    value: snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.fastfood_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text('آخر إجراءات الإدارة',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('admins')
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final logs = snap.data!.docs;
              if (logs.isEmpty) {
                return const _EmptyState(message: 'لا توجد سجلات حالياً');
              }
              return Column(
                children: logs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final action = data['action'] ?? '';
                  final color = _actionColor(action);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(_actionIcon(action), color: color, size: 20),
                      ),
                      title: Text(
                        _actionLabel(action),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        data['reason'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        data['targetType'] ?? '',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textLight),
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

// ─────────────────────────────────────────────
// شاشة البروفايل
// ─────────────────────────────────────────────
class AdminProfileScreen extends StatelessWidget {
  final AppUser user;
  const AdminProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حساب المدير'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'أ',
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('مدير النظام',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoTile(
                      icon: Icons.email_outlined,
                      label: 'البريد الإلكتروني',
                      value: user.email),
                  const Divider(),
                  _InfoTile(
                      icon: Icons.phone_outlined,
                      label: 'الهاتف',
                      value: user.phone.isEmpty ? '—' : user.phone),
                  const Divider(),
                  _InfoTile(
                      icon: Icons.location_on_outlined,
                      label: 'العنوان',
                      value: user.address.isEmpty ? '—' : user.address),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            label: const Text('تسجيل الخروج',
                style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widgets مشتركة
// ─────────────────────────────────────────────
class _WelcomeCard extends StatelessWidget {
  final AppUser user;
  const _WelcomeCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'أ',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مرحباً بعودتك 👋',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 3),
                Text(user.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text('راقب الحسابات والشكاوى ونشاط النظام',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 3),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                            height: 1.4)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String statusLabel;
  final Color statusColor;
  final List<Widget> actions;

  const _UserCard({
    required this.name,
    required this.email,
    required this.role,
    required this.statusLabel,
    required this.statusColor,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '؟',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(email,
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('الدور: $role',
                style:
                    const TextStyle(color: AppColors.textLight, fontSize: 12)),
            const SizedBox(height: 10),
            Row(children: actions),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textLight,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded,
                size: 56, color: AppColors.primary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textLight, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.textDark)),
            ],
          ),
        ],
      ),
    );
  }
}
