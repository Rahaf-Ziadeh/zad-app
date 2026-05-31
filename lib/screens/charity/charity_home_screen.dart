import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../common/notifications_screen.dart';
import 'charity_publish_surplus_screen.dart';

class CharityHomeScreen extends StatelessWidget {
  final AppUser user;
  final ValueChanged<int> onNavigate;

  const CharityHomeScreen({
    super.key,
    required this.user,
    required this.onNavigate,
  });

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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ إصلاح — نجيب كل التبرعات بدون فلتر charityUserId
        // لأن التبرعات الجديدة ما عندها charityUserId وقت الإنشاء
        stream: FirebaseFirestore.instance.collection('donations').snapshots(),
        builder: (context, snapshot) {
          final donations = snapshot.hasData
              ? snapshot.data!.docs
              : <QueryDocumentSnapshot>[];

          int pending = 0, approved = 0, redistributed = 0;

          for (final doc in donations) {
            final data = doc.data() as Map<String, dynamic>;
            // ✅ نستخدم 'status' بدل 'donationStatus'
            final s = data['status'] ?? 'pending';
            if (s == 'pending') pending++;
            if (s == 'approved') approved++;
            if (s == 'redistributed') redistributed++;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              _WelcomeCard(user: user),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'قيد المراجعة',
                      value: '$pending',
                      icon: Icons.pending_actions_rounded,
                      color: Colors.orange,
                      onTap: () => onNavigate(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      title: 'مقبولة',
                      value: '$approved',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      onTap: () => onNavigate(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      title: 'موزّعة',
                      value: '$redistributed',
                      icon: Icons.share_rounded,
                      color: AppColors.primary,
                      onTap: () => onNavigate(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('إجراءات سريعة',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.volunteer_activism_rounded,
                title: 'مراجعة التبرعات',
                subtitle: 'قبول أو رفض التبرعات المقدمة من المستخدمين',
                color: const Color(0xFFE11D48),
                onTap: () => onNavigate(1),
              ),
              _ActionTile(
                icon: Icons.search_rounded,
                title: 'تصفح العروض',
                subtitle: 'تصفح عروض المطاعم والأفراد واحجز للجمعية',
                color: AppColors.primary,
                onTap: () => onNavigate(2),
              ),
              _ActionTile(
                icon: Icons.history_rounded,
                title: 'سجل التبرعات',
                subtitle: 'عرض التبرعات المقبولة والمرفوضة والموزّعة',
                color: const Color(0xFF7C3AED),
                onTap: () => onNavigate(3),
              ),
              _ActionTile(
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

// ─────────────────────────────────────────────
// Widgets
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
          colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withOpacity(0.25),
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
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'ج',
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
                const Text('مرحباً بعودتك ❤️',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 3),
                Text(user.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                const Text('راجعي التبرعات وساعدي في توزيع الطعام',
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
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
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
