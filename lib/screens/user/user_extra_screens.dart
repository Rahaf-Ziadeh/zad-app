import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';
import 'provider_public_profile_screen.dart';

// ─────────────────────────────────────────────
// تبرعاتي — سجل تبرعات المستخدم فقط (لا علاقة له بـ"طلباتي")
// ─────────────────────────────────────────────
class UserDonationsHistoryScreen extends StatefulWidget {
  const UserDonationsHistoryScreen({super.key});

  @override
  State<UserDonationsHistoryScreen> createState() =>
      _UserDonationsHistoryScreenState();
}

class _UserDonationsHistoryScreenState
    extends State<UserDonationsHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── null = الكل، وإلا القيمة الفعلية لحقل status في مجموعة donations ──
  static const List<String?> _statuses = [
    null,
    'pending',
    'approved',
    'rejected',
    'redistributed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'بانتظار المراجعة';
      case 'approved':
        return 'مقبولة';
      case 'rejected':
        return 'مرفوضة';
      case 'redistributed':
        return 'مكتملة';
      default:
        return status.isEmpty ? 'غير محدد' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      case 'redistributed':
        return AppColors.primary;
      default:
        return AppColors.textLight;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'redistributed':
        return Icons.task_alt_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Stream<QuerySnapshot> _donationsStream(String? status) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    // ── تبرعات هذا المستخدم فقط، مهما كان التبويب ──
    Query query = FirebaseFirestore.instance
        .collection('donations')
        .where('donorUserId', isEqualTo: uid);
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تبرعاتي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: [
            const Tab(text: 'الكل'),
            for (final s in _statuses.skip(1)) Tab(text: _statusLabel(s!)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses.map((status) {
          return _DonationsList(
            stream: _donationsStream(status),
            statusLabel: _statusLabel,
            statusColor: _statusColor,
            statusIcon: _statusIcon,
          );
        }).toList(),
      ),
    );
  }
}

class _DonationsList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final IconData Function(String) statusIcon;

  const _DonationsList({
    required this.stream,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('حدث خطأ: ${snap.error}'));
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = List<QueryDocumentSnapshot>.from(snap.data!.docs)
          ..sort((a, b) {
            final ad = (a.data() as Map<String, dynamic>)['createdAt'];
            final bd = (b.data() as Map<String, dynamic>)['createdAt'];
            if (ad is Timestamp && bd is Timestamp) {
              return bd.compareTo(ad);
            }
            return 0;
          });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism_outlined,
                    size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
                const SizedBox(height: 14),
                const Text(
                  'لا توجد تبرعات هنا',
                  style: TextStyle(color: AppColors.textLight, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _DonationCard(
              data: data,
              statusLabel: statusLabel,
              statusColor: statusColor,
              statusIcon: statusIcon,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة تبرع واحد — بنفس أسلوب بطاقات "طلباتي" (رأس بشارة الحالة + صفوف تفاصيل)
// ─────────────────────────────────────────────
class _DonationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final IconData Function(String) statusIcon;

  const _DonationCard({
    required this.data,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
  });

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] as String?) ?? 'pending';
    final color = statusColor(status);

    final title = (data['title'] as String?) ??
        (data['foodName'] as String?) ??
        'تبرع طعام';
    final category = (data['category'] as String? ?? '').trim();
    final quantity = (data['quantity']?.toString() ?? '').trim();
    final pickupLocation = ((data['pickupLocation'] as String?) ??
            (data['location'] as String?) ??
            '')
        .trim();
    final notes = (data['notes'] as String? ?? '').trim();
    final charityId = ((data['charityId'] as String?) ??
            (data['targetCharityId'] as String?) ??
            '')
        .trim();
    final charityName = ((data['charityName'] as String?) ??
            (data['targetCharityName'] as String?) ??
            '')
        .trim();
    final dateStr = _formatDate(data['createdAt'] as Timestamp?);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon(status), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel(status),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // ── اسم الجمعية قابل للنقر فقط عند توفر معرّف حسابها ──
            if (charityName.isNotEmpty)
              OfferInfoRow(
                icon: Icons.volunteer_activism_outlined,
                label: 'الجمعية',
                value: charityName,
                onTap: charityId.isNotEmpty
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProviderPublicProfileScreen(
                              providerUserId: charityId,
                              providerRole: 'charity',
                            ),
                          ),
                        )
                    : null,
              ),
            if (category.isNotEmpty)
              OfferInfoRow(
                icon: Icons.category_outlined,
                label: 'الفئة',
                value: category,
              ),
            if (quantity.isNotEmpty)
              OfferInfoRow(
                icon: Icons.inventory_2_outlined,
                label: 'الكمية',
                value: quantity,
              ),
            if (pickupLocation.isNotEmpty)
              OfferInfoRow(
                icon: Icons.location_on_outlined,
                label: 'الموقع',
                value: pickupLocation,
              ),
            if (dateStr.isNotEmpty)
              OfferInfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'التاريخ',
                value: dateStr,
              ),
            if (notes.isNotEmpty)
              OfferInfoRow(
                icon: Icons.notes_outlined,
                label: 'ملاحظات',
                value: notes,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// تقييماتي
// ─────────────────────────────────────────────
class UserRatingsScreen extends StatelessWidget {
  const UserRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تقييماتي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservations')
            .where('userId', isEqualTo: uid)
            .where('hasRated', isEqualTo: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('حدث خطأ: ${snap.error}'));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          docs.sort((a, b) {
            final ad = (a.data() as Map<String, dynamic>)['ratedAt'];
            final bd = (b.data() as Map<String, dynamic>)['ratedAt'];

            if (ad is Timestamp && bd is Timestamp) {
              return bd.compareTo(ad);
            }
            return 0;
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_outline_rounded,
                      size: 64, color: Colors.amber.withOpacity(0.4)),
                  const SizedBox(height: 14),
                  const Text(
                    'لم تقيّم أي طلب بعد',
                    style: TextStyle(color: AppColors.textLight, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'بعد استلام أي طلب يمكنك تقييم تجربتك',
                    style: TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          double total = 0;
          for (final d in docs) {
            total += ((d.data() as Map<String, dynamic>)['rating'] ?? 0) as num;
          }
          final avg = total / docs.length;

          return Column(
            children: [
              Container(
                color: AppColors.card,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      avg.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < avg.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: Colors.amber,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${docs.length} تقييم',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final rating = data['rating'] ?? 0;
                    final comment = data['ratingComment'] ?? '';
                    final offerTitle = data['offerTitle'] ?? 'طلب طعام';

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
                                Expanded(
                                  child: Text(
                                    offerTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < rating
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (comment.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                comment,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
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
// شكاواي
// ─────────────────────────────────────────────
class UserComplaintsScreen extends StatelessWidget {
  const UserComplaintsScreen({super.key});

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
        return status.isEmpty ? 'غير محدد' : status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('شكاواي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .where('reportedByUserId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('حدث خطأ: ${snap.error}'));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          docs.sort((a, b) {
            final ad = (a.data() as Map<String, dynamic>)['createdAt'];
            final bd = (b.data() as Map<String, dynamic>)['createdAt'];

            if (ad is Timestamp && bd is Timestamp) {
              return bd.compareTo(ad);
            }
            return 0;
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.report_problem_outlined,
                      size: 64, color: AppColors.primary.withOpacity(0.3)),
                  const SizedBox(height: 14),
                  const Text(
                    'لا توجد شكاوى مسجّلة',
                    style: TextStyle(color: AppColors.textLight, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final status = data['status'] ?? 'open';
              final color = _statusColor(status);
              final description =
                  data['description'] ?? data['complaintText'] ?? '';
              final type = data['type'] ?? 'مشكلة أخرى';
              final relatedOffer =
                  data['relatedOfferId'] ?? data['offerId'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: color.withOpacity(0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              status == 'resolved'
                                  ? Icons.check_circle_rounded
                                  : Icons.report_rounded,
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if ('$relatedOffer'.isNotEmpty)
                                  Text(
                                    'رقم العرض: $relatedOffer',
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ('$description'.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 13,
                            height: 1.5,
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
      ),
    );
  }
}
