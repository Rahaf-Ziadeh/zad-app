import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class RestaurantStatsScreen extends StatelessWidget {
  const RestaurantStatsScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> _offersStream() => FirebaseFirestore.instance
      .collection('offers')
      .where('providerUserId', isEqualTo: _uid)
      .snapshots();

  Stream<QuerySnapshot> _reservationsStream() => FirebaseFirestore.instance
      .collection('reservations')
      .where('providerUserId', isEqualTo: _uid)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإحصائيات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _offersStream(),
        builder: (context, offersSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: _reservationsStream(),
            builder: (context, resSnap) {
              if (!offersSnap.hasData || !resSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final offers = offersSnap.data!.docs;
              final reservations = resSnap.data!.docs;

              // ── حسابات ──
              final totalOffers = offers.length;
              final activeOffers = offers
                  .where((d) => (d.data() as Map)['status'] == 'available')
                  .length;
              final closedOffers = offers
                  .where((d) => (d.data() as Map)['status'] == 'closed')
                  .length;

              final totalReservations = reservations.length;
              final completedRes = reservations
                  .where((d) => (d.data() as Map)['status'] == 'picked_up')
                  .length;
              final pendingRes = reservations
                  .where((d) => (d.data() as Map)['status'] == 'reserved')
                  .length;
              final cancelledRes = reservations
                  .where((d) => (d.data() as Map)['status'] == 'cancelled')
                  .length;

              // مجموع الكميات المباعة
              int totalSold = 0;
              for (final doc in offers) {
                final data = doc.data() as Map<String, dynamic>;
                final qty = data['quantity'] ?? 0;
                final remaining = data['remainingQuantity'] ?? 0;
                totalSold += (qty - remaining) as int;
              }

              // تقييم متوسط
              double totalRating = 0;
              int ratedCount = 0;
              for (final doc in reservations) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['hasRated'] == true && data['rating'] != null) {
                  totalRating += (data['rating'] as num).toDouble();
                  ratedCount++;
                }
              }
              final avgRating =
                  ratedCount > 0 ? (totalRating / ratedCount) : 0.0;

              final completionRate = totalReservations > 0
                  ? (completedRes / totalReservations * 100).round()
                  : 0;

              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // ── بطاقة ملخص ──
                  Container(
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
                    child: Column(
                      children: [
                        const Text(
                          'ملخص الأداء',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$totalSold',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'وجبة تم توزيعها',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MiniStat(
                                label: 'نسبة الإتمام',
                                value: '$completionRate%'),
                            Container(
                                width: 1, height: 36, color: Colors.white24),
                            _MiniStat(
                                label: 'متوسط التقييم',
                                value: ratedCount > 0
                                    ? '${avgRating.toStringAsFixed(1)} ⭐'
                                    : 'لا يوجد'),
                            Container(
                                width: 1, height: 36, color: Colors.white24),
                            _MiniStat(label: 'تقييمات', value: '$ratedCount'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── إحصائيات العروض ──
                  _SectionTitle(title: 'العروض والباقات'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'إجمالي العروض',
                          value: '$totalOffers',
                          icon: Icons.fastfood_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          title: 'نشطة',
                          value: '$activeOffers',
                          icon: Icons.check_circle_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          title: 'مغلقة',
                          value: '$closedOffers',
                          icon: Icons.pause_circle_rounded,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── إحصائيات الطلبات ──
                  _SectionTitle(title: 'الحجوزات والطلبات'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'إجمالي',
                          value: '$totalReservations',
                          icon: Icons.receipt_long_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          title: 'مكتملة',
                          value: '$completedRes',
                          icon: Icons.done_all_rounded,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'بانتظار',
                          value: '$pendingRes',
                          icon: Icons.pending_rounded,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          title: 'ملغاة',
                          value: '$cancelledRes',
                          icon: Icons.cancel_rounded,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── شريط تقدم الإتمام ──
                  _SectionTitle(title: 'نسبة إتمام الطلبات'),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('طلبات مكتملة',
                                  style: TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 13)),
                              Text(
                                '$completionRate%',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: completionRate >= 70
                                      ? AppColors.success
                                      : completionRate >= 40
                                          ? AppColors.secondary
                                          : AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: completionRate / 100,
                              minHeight: 10,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                completionRate >= 70
                                    ? AppColors.success
                                    : completionRate >= 40
                                        ? AppColors.secondary
                                        : AppColors.danger,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$completedRes من أصل $totalReservations طلب',
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── آخر الحجوزات ──
                  _SectionTitle(title: 'آخر الحجوزات'),
                  const SizedBox(height: 12),
                  if (reservations.isEmpty)
                    const Center(
                      child: Text('لا توجد حجوزات بعد',
                          style: TextStyle(color: AppColors.textLight)),
                    )
                  else
                    ...reservations.take(5).map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'reserved';
                      final title = data['offerTitle'] ?? 'طلب طعام';
                      final userName = data['userName'] ?? 'مستخدم';

                      Color statusColor;
                      String statusLabel;
                      switch (status) {
                        case 'picked_up':
                          statusColor = AppColors.success;
                          statusLabel = 'مكتمل';
                          break;
                        case 'reserved':
                          statusColor = Colors.orange;
                          statusLabel = 'بانتظار';
                          break;
                        case 'cancelled':
                          statusColor = AppColors.danger;
                          statusLabel = 'ملغي';
                          break;
                        default:
                          statusColor = AppColors.textLight;
                          statusLabel = status;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.receipt_rounded,
                                color: statusColor, size: 18),
                          ),
                          title: Text(title,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text(userName,
                              style: const TextStyle(fontSize: 12)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(statusLabel,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
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
