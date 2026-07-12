import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/screens/admin/admin_create_admin_screen.dart';
import 'package:zad_app/screens/admin/admin_identity_details_screen.dart';
import 'package:zad_app/screens/admin/admin_verification_details_screen.dart';
import 'package:zad_app/screens/admin/admin_widgets.dart';
import 'package:zad_app/services/admin_service.dart';
import 'package:zad_app/services/notification_service.dart';
import 'package:zad_app/theme/app_colors.dart';

enum _UserFilter { all, individuals, restaurants, charities }

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  _UserFilter _filter = _UserFilter.all;
  late final TabController _tabController;
  final _adminService = AdminService();

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

  // ── Account-level approval (restaurants & charities) ──────────────────────

  Future<void> _approveAccount(String userId, Map<String, dynamic> data) async {
    await _adminService.approveAccount(
      userId: userId,
      role: data['role'] ?? 'user',
      adminId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
    );
    await NotificationService().sendNotification(
      userId: userId,
      title: 'تم قبول الحساب',
      message: 'تمت الموافقة على حسابك ويمكنك الآن استخدام التطبيق.',
      type: 'account',
      relatedId: userId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تمت الموافقة على الحساب'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _rejectAccount(String userId, Map<String, dynamic> data) async {
    await _adminService.rejectAccount(
      userId: userId,
      role: data['role'] ?? 'user',
      adminId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
    );
    await NotificationService().sendNotification(
      userId: userId,
      title: 'تم رفض الحساب',
      message: 'عذراً، تم رفض طلب إنشاء حسابك.',
      type: 'account',
      relatedId: userId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم رفض الحساب'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  Future<void> _toggleSuspend(
      String userId, Map<String, dynamic> data, bool suspend) async {
    await _adminService.toggleSuspendUser(
      userId: userId,
      role: data['role'] ?? 'user',
      adminId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      suspend: suspend,
    );
    await NotificationService().sendNotification(
      userId: userId,
      title: suspend ? 'تم تعليق الحساب' : 'تمت إعادة تفعيل الحساب',
      message: suspend
          ? 'تم تعليق حسابك مؤقتاً من قبل الإدارة.'
          : 'تمت إعادة تفعيل حسابك ويمكنك استخدام التطبيق مجدداً.',
      type: 'account',
      relatedId: userId,
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

  // ── Identity-level approval (individual users) ─────────────────────────────

  Future<void> _approveIdentity(String userId) async {
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(userId),
        {
          'identityVerificationStatus': 'approved',
          'identityVerified': true,
          'identityVerificationReviewedBy': adminId,
          'identityVerificationReviewedAt': FieldValue.serverTimestamp(),
          'identityRejectionReason': null,
        },
      );
      batch.set(
        FirebaseFirestore.instance.collection('individuals').doc(userId),
        {
          'verificationStatus': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      await NotificationService().sendNotification(
        userId: userId,
        title: 'تم توثيق هويتك',
        message: 'تمت الموافقة على توثيق هويتك ويمكنك الآن نشر تبرعاتك.',
        type: 'account',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم توثيق الهوية'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _rejectIdentity(String userId) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب رفض التوثيق'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب سبب الرفض...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              final r = ctrl.text.trim();
              if (r.isEmpty) return;
              Navigator.pop(ctx, r);
            },
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null || !mounted) return;
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(userId),
        {
          'identityVerificationStatus': 'rejected',
          'identityVerified': false,
          'identityVerificationReviewedBy': adminId,
          'identityVerificationReviewedAt': FieldValue.serverTimestamp(),
          'identityRejectionReason': reason,
        },
      );
      batch.set(
        FirebaseFirestore.instance.collection('individuals').doc(userId),
        {
          'verificationStatus': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      await NotificationService().sendNotification(
        userId: userId,
        title: 'طلب التوثيق مرفوض',
        message: 'تم رفض طلب توثيق هويتك. السبب: $reason',
        type: 'account',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الرفض')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _openUserDetails(
      String docId, Map<String, dynamic> data) async {
    final role = (data['role'] as String? ?? '').trim();
    if (role == 'restaurant' || role == 'charity') {
      final roleCol = role == 'restaurant' ? 'restaurants' : 'charities';
      final roleDoc = await FirebaseFirestore.instance
          .collection(roleCol)
          .doc(docId)
          .get();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminVerificationDetailsScreen(
            docId: docId,
            data: {...data, ...roleDoc.data() ?? {}},
            role: role,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminIdentityDetailsScreen(
            docId: docId,
            data: data,
          ),
        ),
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _roleLabel(String role) {
    switch (role) {
      case 'restaurant':
        return 'مطعم';
      case 'charity':
        return 'جمعية';
      case 'individual':
      case 'user':
        return 'مستخدم';
      case 'admin':
        return 'مدير';
      default:
        return role;
    }
  }

  // Maps the UI filter chip to the getUsersStream() filter argument.
  // '_UserFilter.individuals' uses 'individual' so getUsersStream does a
  // whereIn(['individual','user']) query.
  String _filterArg() => switch (_filter) {
    _UserFilter.restaurants => 'restaurant',
    _UserFilter.charities => 'charity',
    _UserFilter.individuals => 'individual',
    _UserFilter.all => 'all',
  };

  (String label, Color color) _stateDisplay(AdminAccountState state) =>
      switch (state) {
        AdminAccountState.pending => ('بانتظار الموافقة', Colors.orange),
        AdminAccountState.active => ('نشط', AppColors.success),
        AdminAccountState.rejected => ('مرفوض', AppColors.danger),
        AdminAccountState.suspended => ('معلّق', AppColors.danger),
      };

  String _emptyMessage(AdminAccountState state) => switch (state) {
    AdminAccountState.pending => 'لا توجد حسابات بانتظار الموافقة',
    AdminAccountState.active => 'لا يوجد مستخدمون نشطون',
    AdminAccountState.suspended => 'لا يوجد مستخدمون معلّقون',
    AdminAccountState.rejected => 'لا توجد بيانات',
  };

  List<Widget> _buildActions(
      String docId, Map<String, dynamic> data, AdminAccountState state) {
    final role = data['role'] as String? ?? '';
    switch (state) {
      case AdminAccountState.pending:
        if (role == 'restaurant' || role == 'charity') {
          return [
            ActionButton(
              label: 'موافقة',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              onTap: () => _approveAccount(docId, data),
            ),
            const SizedBox(width: 8),
            ActionButton(
              label: 'رفض',
              icon: Icons.cancel_rounded,
              color: AppColors.danger,
              onTap: () => _rejectAccount(docId, data),
            ),
          ];
        }
        // individual / user: identity verification actions
        return [
          ActionButton(
            label: 'قبول الهوية',
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
            onTap: () => _approveIdentity(docId),
          ),
          const SizedBox(width: 8),
          ActionButton(
            label: 'رفض الهوية',
            icon: Icons.cancel_rounded,
            color: AppColors.danger,
            onTap: () => _rejectIdentity(docId),
          ),
        ];
      case AdminAccountState.active:
        return [
          ActionButton(
            label: 'تعليق',
            icon: Icons.pause_circle_rounded,
            color: AppColors.danger,
            onTap: () => _toggleSuspend(docId, data, true),
          ),
        ];
      case AdminAccountState.suspended:
        return [
          ActionButton(
            label: 'إعادة تفعيل',
            icon: Icons.play_circle_rounded,
            color: AppColors.success,
            onTap: () => _toggleSuspend(docId, data, false),
          ),
        ];
      default:
        return [];
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
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_rounded),
            tooltip: 'إضافة مسؤول جديد',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminCreateAdminScreen(),
              ),
            ),
          ),
        ],
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.filter_list_rounded,
                      size: 18, color: AppColors.textLight),
                  const SizedBox(width: 8),
                  ...[
                    ('الكل', _UserFilter.all),
                    ('مستخدمون', _UserFilter.individuals),
                    ('مطاعم', _UserFilter.restaurants),
                    ('جمعيات', _UserFilter.charities),
                  ].map((e) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: AdminFilterChip(
                          label: e.$1,
                          selected: _filter == e.$2,
                          onTap: () => setState(() => _filter = e.$2),
                        ),
                      )),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            // Single StreamBuilder feeds all three tabs from the same real-time
            // stream. resolveAdminAccountState() assigns each doc to the correct
            // tab. When admin approves/rejects, Firestore emits an update and
            // the card moves between tabs automatically — no logout required.
            child: StreamBuilder<QuerySnapshot>(
              stream: _adminService.getUsersStream(_filterArg()),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Exclude admins; classify remaining docs
                final pairs = snap.data!.docs
                    .map((d) => (d, d.data() as Map<String, dynamic>))
                    .where((p) => p.$2['role'] != 'admin')
                    .toList();

                final pendingDocs = pairs
                    .where((p) =>
                        resolveAdminAccountState(p.$2) ==
                        AdminAccountState.pending)
                    .toList();
                final activeDocs = pairs
                    .where((p) =>
                        resolveAdminAccountState(p.$2) ==
                        AdminAccountState.active)
                    .toList();
                final suspendedDocs = pairs
                    .where((p) =>
                        resolveAdminAccountState(p.$2) ==
                        AdminAccountState.suspended)
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTabList(pendingDocs, AdminAccountState.pending),
                    _buildTabList(activeDocs, AdminAccountState.active),
                    _buildTabList(suspendedDocs, AdminAccountState.suspended),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabList(
      List<(QueryDocumentSnapshot, Map<String, dynamic>)> docs,
      AdminAccountState state) {
    if (docs.isEmpty) {
      return EmptyState(message: _emptyMessage(state));
    }
    final (:label, :color) = _stateDisplay(state).let(
      (p) => (label: p.$1, color: p.$2),
    );
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final (doc, data) = docs[i];
        return UserCard(
          name: data['fullName'] ?? data['name'] ?? 'بدون اسم',
          email: data['email'] ?? '',
          role: _roleLabel(data['role'] ?? ''),
          statusLabel: label,
          statusColor: color,
          onTap: () => _openUserDetails(doc.id, data),
          actions: _buildActions(doc.id, data, state),
        );
      },
    );
  }
}

extension _RecordLet<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}
