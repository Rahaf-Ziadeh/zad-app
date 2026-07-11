import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/models/user.dart';
import 'package:zad_app/screens/common/notifications_screen.dart';
import 'package:zad_app/theme/app_colors.dart';
import '../../services/admin_service.dart';
import 'admin_offers_screen.dart';
import 'admin_stats_detail_screen.dart';
import 'admin_support_panel.dart';
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

  // ── ثوابت اللون لكل بطاقة ──
  static const _colorUsers = AppColors.primary;
  static const _colorRestaurant = Color(0xFF0EA5E9); // أزرق فاتح
  static const _colorCharity = Color(0xFF7C3AED); // بنفسجي
  static const _colorComplaint = AppColors.danger;
  static const _colorOffer = Color(0xFFF59E0B); // أصفر / ذهبي
  static const _colorReservation = AppColors.success;
  static const _colorSupport = Color(0xFFEC4899); // وردي
  static const _colorReview = Color(0xFFEA580C); // برتقالي

  // ── بانيو لشاشة التفاصيل: المستخدمون ──
  AdminStatsDetailScreen _usersDetail(
    Stream<QuerySnapshot> stream,
    String title,
    Color color, {
    String emptyMessage = 'لا يوجد مستخدمون',
  }) {
    return AdminStatsDetailScreen(
      title: title,
      stream: stream,
      titleKey: 'name',
      subtitleKey: 'email',
      accentColor: color,
      emptyMessage: emptyMessage,
      fields: const [
        AdminFieldDef(icon: Icons.badge_outlined, label: 'الدور', key: 'role'),
        AdminFieldDef(
            icon: Icons.circle_outlined, label: 'الحالة', key: 'status'),
        AdminFieldDef(
            icon: Icons.phone_outlined,
            label: 'الهاتف',
            key: 'phone',
            isPhone: true),
      ],
    );
  }

  // ── بانيو لشاشة التفاصيل: الحجوزات ──
  AdminStatsDetailScreen _reservationsDetail(
      AdminService svc, String title, Color color) {
    return AdminStatsDetailScreen(
      title: title,
      stream: svc.getAllReservations(),
      titleKey: 'offerTitle',
      subtitleKey: 'userName',
      accentColor: color,
      emptyMessage: 'لا توجد حجوزات حالياً',
      fields: const [
        AdminFieldDef(
            icon: Icons.info_outline_rounded, label: 'الحالة', key: 'status'),
        AdminFieldDef(
            icon: Icons.access_time_rounded,
            label: 'وقت الاستلام',
            key: 'pickupTime'),
        AdminFieldDef(
            icon: Icons.location_on_outlined,
            label: 'الموقع',
            key: 'pickupLocation'),
        AdminFieldDef(
            icon: Icons.calendar_today_outlined,
            label: 'تاريخ الحجز',
            key: 'createdAt'),
      ],
    );
  }

  // ── بانيو لشاشة التفاصيل: التقييمات ──
  AdminStatsDetailScreen _reviewsDetail(AdminService svc) {
    return AdminStatsDetailScreen(
      title: 'التقييمات',
      stream: svc.getReviews(),
      titleKey: 'offerTitle',
      subtitleKey: 'userName',
      accentColor: _colorReview,
      emptyMessage: 'لا توجد تقييمات بعد',
      fields: const [
        AdminFieldDef(
            icon: Icons.star_outline_rounded,
            label: 'التقييم',
            key: 'rating'),
        AdminFieldDef(
            icon: Icons.comment_outlined, label: 'التعليق', key: 'comment'),
        AdminFieldDef(
            icon: Icons.calendar_today_outlined,
            label: 'التاريخ',
            key: 'createdAt'),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

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

          // ── صف 1: المستخدمون / مطاعم / جمعيات ──
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: adminService.getAllUsers(),
                  builder: (_, snap) => StatCard(
                    title: 'المستخدمون',
                    value:
                        snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.people_rounded,
                    color: _colorUsers,
                    onTap: () => onNavigate(1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: adminService.getUsersByRole('restaurant'),
                  builder: (_, snap) => StatCard(
                    title: 'مطاعم',
                    value:
                        snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.restaurant_rounded,
                    color: _colorRestaurant,
                    onTap: snap.hasData
                        ? () => _push(
                              context,
                              _usersDetail(
                                adminService.getUsersByRole('restaurant'),
                                'المطاعم',
                                _colorRestaurant,
                                emptyMessage: 'لا توجد مطاعم مسجلة بعد',
                              ),
                            )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: adminService.getUsersByRole('charity'),
                  builder: (_, snap) => StatCard(
                    title: 'جمعيات',
                    value:
                        snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.volunteer_activism_rounded,
                    color: _colorCharity,
                    onTap: snap.hasData
                        ? () => _push(
                              context,
                              _usersDetail(
                                adminService.getUsersByRole('charity'),
                                'الجمعيات الخيرية',
                                _colorCharity,
                                emptyMessage:
                                    'لا توجد جمعيات خيرية مسجلة بعد',
                              ),
                            )
                        : null,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── صف 2: الشكاوى / العروض / الحجوزات ──
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: adminService.getOpenComplaints(),
                  builder: (_, snap) => StatCard(
                    title: 'شكاوى',
                    value:
                        snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.report_rounded,
                    color: _colorComplaint,
                    onTap: () => onNavigate(2),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: adminService.getAllOffersStream(),
                  builder: (_, snap) => StatCard(
                    title: 'العروض',
                    value:
                        snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.fastfood_rounded,
                    color: _colorOffer,
                    onTap: () => _push(context, const AdminOffersScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: adminService.getAllReservations(),
                  builder: (_, snap) => StatCard(
                    title: 'الحجوزات',
                    value:
                        snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.receipt_long_rounded,
                    color: _colorReservation,
                    onTap: () => _push(
                      context,
                      _reservationsDetail(
                          adminService, 'جميع الحجوزات', _colorReservation),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── صف 3: محادثات الدعم / التقييمات ──
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: adminService.getSupportChats(),
                  builder: (_, snap) => StatCard(
                    title: 'الدعم',
                    value:
                        snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.support_agent_rounded,
                    color: _colorSupport,
                    onTap: () => _push(
                      context,
                      AdminSupportPanel(user: user),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: adminService.getReviews(),
                  builder: (_, snap) => StatCard(
                    title: 'التقييمات',
                    value:
                        snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.star_rounded,
                    color: _colorReview,
                    onTap: () =>
                        _push(context, _reviewsDetail(adminService)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── إدارة سريعة ──
          const Text('إدارة سريعة',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 12),

          ActionTile(
            icon: Icons.verified_user_rounded,
            title: 'مراجعة التحقق',
            subtitle: 'الموافقة على حسابات المطاعم والجمعيات',
            color: AppColors.primary,
            onTap: () => _push(context, const AdminVerificationPanel()),
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
            onTap: () => _push(context, const AdminOffersScreen()),
          ),
        ],
      ),
    );
  }
}
