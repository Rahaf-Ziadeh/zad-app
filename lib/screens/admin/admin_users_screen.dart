import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/screens/admin/admin_verification_details_screen.dart';
import 'package:zad_app/screens/admin/admin_widgets.dart';
import 'package:zad_app/services/admin_service.dart';
import 'package:zad_app/services/notification_service.dart';
import 'package:zad_app/theme/app_colors.dart';

enum _UserFilter { all, restaurants, charities }

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

  Future<void> _approveAccount(String userId, Map<String, dynamic> data) async {
    await _adminService.approveAccount(
      userId: userId,
      role: data['role'] ?? 'user',
      adminId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
    );

    await NotificationService().sendNotification(
      userId: userId,
      title: 'تم قبول الحساب ✅',
      message: 'تمت الموافقة على حسابك ويمكنك الآن استخدام التطبيق.',
      type: 'account',
      relatedId: userId,
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

    if (suspend) {
      await NotificationService().sendNotification(
        userId: userId,
        title: 'تم تعليق الحساب',
        message: 'تم تعليق حسابك مؤقتاً من قبل الإدارة.',
        type: 'account',
        relatedId: userId,
      );
    } else {
      await NotificationService().sendNotification(
        userId: userId,
        title: 'تمت إعادة تفعيل الحساب ✅',
        message: 'تمت إعادة تفعيل حسابك ويمكنك استخدام التطبيق مجدداً.',
        type: 'account',
        relatedId: userId,
      );
    }

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
                      child: AdminFilterChip(
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
                  stream: _adminService.getPendingUsersByRole(
                    _filter == _UserFilter.restaurants
                        ? 'restaurant'
                        : _filter == _UserFilter.charities
                            ? 'charity'
                            : 'all',
                  ),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs
                        .where((d) => (d.data() as Map)['role'] != 'admin')
                        .toList();
                    if (docs.isEmpty) {
                      return const EmptyState(
                          message: 'لا توجد حسابات بانتظار الموافقة');
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final role = data['role'] as String? ?? '';
                        final needsVerification =
                            role == 'restaurant' || role == 'charity';
                        return UserCard(
                          name: data['fullName'] ?? data['name'] ?? 'بدون اسم',
                          email: data['email'] ?? '',
                          role: _roleLabel(role),
                          statusLabel: 'بانتظار الموافقة',
                          statusColor: Colors.orange,
                          onTap: needsVerification
                              ? () async {
                                  debugPrint(
                                      '[AdminUsers] تم النقر على المتقدم: ${doc.id}, الدور: $role');
                                  final roleCol = role == 'restaurant'
                                      ? 'restaurants'
                                      : 'charities';
                                  final roleDoc = await FirebaseFirestore
                                      .instance
                                      .collection(roleCol)
                                      .doc(doc.id)
                                      .get();
                                  final roleData =
                                      roleDoc.data() ?? {};
                                  if (!context.mounted) return;
                                  debugPrint(
                                      '[AdminUsers] فتح AdminVerificationDetailsScreen, الدور: $role');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AdminVerificationDetailsScreen(
                                        docId: doc.id,
                                        data: {...data, ...roleData},
                                        role: role,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          actions: [
                            ActionButton(
                              label: 'موافقة',
                              icon: Icons.check_circle_rounded,
                              color: AppColors.success,
                              onTap: () => _approveAccount(doc.id, data),
                            ),
                            const SizedBox(width: 8),
                            ActionButton(
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
                  stream: _adminService.getActiveUsersByRole(
                    _filter == _UserFilter.restaurants
                        ? 'restaurant'
                        : _filter == _UserFilter.charities
                            ? 'charity'
                            : 'all',
                  ),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs
                        .where((d) => (d.data() as Map)['role'] != 'admin')
                        .toList();
                    if (docs.isEmpty) {
                      return const EmptyState(
                          message: 'لا يوجد مستخدمون نشطون');
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return UserCard(
                          name: data['fullName'] ?? data['name'] ?? 'بدون اسم',
                          email: data['email'] ?? '',
                          role: _roleLabel(data['role'] ?? ''),
                          statusLabel: 'نشط',
                          statusColor: AppColors.success,
                          actions: [
                            ActionButton(
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
                  stream: _adminService.getSuspendedUsersByRole(
                    _filter == _UserFilter.restaurants
                        ? 'restaurant'
                        : _filter == _UserFilter.charities
                            ? 'charity'
                            : 'all',
                  ),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs
                        .where((d) => (d.data() as Map)['role'] != 'admin')
                        .toList();
                    if (docs.isEmpty) {
                      return const EmptyState(
                          message: 'لا يوجد مستخدمون معلّقون');
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return UserCard(
                          name: data['fullName'] ?? data['name'] ?? 'بدون اسم',
                          email: data['email'] ?? '',
                          role: _roleLabel(data['role'] ?? ''),
                          statusLabel: 'معلّق',
                          statusColor: AppColors.danger,
                          actions: [
                            ActionButton(
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
