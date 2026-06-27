import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/models/user.dart';
import 'package:zad_app/screens/common/notifications_screen.dart';
import 'package:zad_app/theme/app_colors.dart';
import '../../services/admin_service.dart';
import 'admin_offers_screen.dart';
import 'admin_verification_panel.dart';
import 'admin_widgets.dart';

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
    final adminService = AdminService();
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
                color: AppColors.primary.withValues(alpha: 0.12),
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
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: user.uid)
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final hasUnread =
                  snapshot.hasData && snapshot.data!.docs.isNotEmpty;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationsScreen(
                            onNotificationTap: (context, data) {
                              final type = data['type'];

                              if (type == 'account') {
                                onNavigate(1);
                                Navigator.pop(context);
                              } else if (type == 'complaint') {
                                onNavigate(2);
                                Navigator.pop(context);
                              } else if (type == 'report') {
                                onNavigate(3);
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          // ── بطاقة الترحيب ──
          WelcomeCard(user: user),
          const SizedBox(height: 20),

          // ── إحصائيات ──
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: adminService.getAllUsers(),
                  builder: (_, snap) => StatCard(
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
                  stream: adminService.getPendingUsers(),
                  builder: (_, snap) => StatCard(
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
                  stream: adminService.getOpenComplaints(),
                  builder: (_, snap) => StatCard(
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
                  stream: adminService.getActiveOffers(),
                  builder: (_, snap) => StatCard(
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
                  stream: adminService.getPickedUpReservations(),
                  builder: (_, snap) => StatCard(
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

          ActionTile(
            icon: Icons.verified_user_rounded,
            title: 'مراجعة الحسابات الجديدة',
            subtitle: 'قبول أو رفض حسابات المطاعم والجمعيات',
            color: AppColors.primary,
            onTap: () => onNavigate(1),
          ),
          ActionTile(
            icon: Icons.warning_amber_rounded,
            title: 'متابعة الشكاوى',
            subtitle: 'مراجعة البلاغات وحل النزاعات',
            color: AppColors.danger,
            onTap: () => onNavigate(2),
          ),
          ActionTile(
            icon: Icons.analytics_rounded,
            title: 'عرض التقارير',
            subtitle: 'مراقبة نشاط النظام وسجل الإجراءات',
            color: const Color(0xFF7C3AED),
            onTap: () => onNavigate(3),
          ),
          ActionTile(
            icon: Icons.local_offer_rounded,
            title: 'إدارة العروض',
            subtitle: 'عرض وحذف عروض المطاعم والجمعيات والأفراد',
            color: AppColors.secondary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminOffersScreen(),
              ),
            ),
          ),
          ActionTile(
            icon: Icons.verified_user_rounded,
            title: 'مراجعة التحقق',
            subtitle: 'الموافقة على حسابات المطاعم والجمعيات وهويات المستخدمين',
            color: AppColors.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminVerificationPanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
