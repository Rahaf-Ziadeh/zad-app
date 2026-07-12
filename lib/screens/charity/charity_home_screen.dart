import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/charity_data_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/charity_widgets.dart';
import 'charity_donations_screen.dart';
import 'charity_notifications_screen.dart';
import 'charity_publish_surplus_screen.dart';

class CharityHomeScreen extends StatelessWidget {
  final AppUser user;
  final ValueChanged<int> onNavigate;

  CharityHomeScreen({
    super.key,
    required this.user,
    required this.onNavigate,
  });

  final CharityDataService _dataService = CharityDataService();

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(
                Icons.eco_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'زاد',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _dataService.watchUnreadNotifications(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.docs.length : 0;

              return Stack(
                children: [
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CharityNotificationsScreen(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dataService.watchAllDonations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('حدث خطأ أثناء تحميل البيانات'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final stats = _dataService.calculateHomeStatistics(
            snapshot.data!.docs,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              WelcomeCard(user: user),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'قيد المراجعة',
                      value: '${stats.pending}',
                      icon: Icons.pending_actions_rounded,
                      color: Colors.orange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CharityDonationsScreen(
                            initialTab: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'مقبولة',
                      value: '${stats.approved}',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CharityDonationsScreen(
                            initialTab: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      title: 'موزّعة',
                      value: '${stats.redistributed}',
                      icon: Icons.share_rounded,
                      color: AppColors.primary,
                      onTap: () => onNavigate(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'إجراءات سريعة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              ActionTile(
                icon: Icons.volunteer_activism_rounded,
                title: 'مراجعة التبرعات',
                subtitle: 'قبول أو رفض التبرعات المقدمة من المستخدمين',
                color: const Color(0xFFE11D48),
                onTap: () => onNavigate(1),
              ),
              ActionTile(
                icon: Icons.search_rounded,
                title: 'تصفح العروض',
                subtitle: 'تصفح عروض المطاعم والأفراد واحجز للجمعية',
                color: AppColors.primary,
                onTap: () => onNavigate(2),
              ),
              ActionTile(
                icon: Icons.history_rounded,
                title: 'سجل التبرعات',
                subtitle: 'عرض التبرعات المقبولة والمرفوضة والموزّعة',
                color: const Color(0xFF7C3AED),
                onTap: () => onNavigate(4),
              ),
              ActionTile(
                icon: Icons.share_rounded,
                title: 'إعادة توزيع الفائض',
                subtitle: 'نشر الطعام المتبقي ليستفيد منه المستحقون',
                color: AppColors.success,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CharityPublishSurplusScreen(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
