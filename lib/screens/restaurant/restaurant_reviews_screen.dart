import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'restaurant_offer_details_screen.dart';

// Reviews the restaurant received from users after pickup. Same data source as
// provider_public_profile_screen.dart (reviews where providerUserId == uid),
// but in a restaurant-owner view: read-only, no edit or delete.
class RestaurantReviewsScreen extends StatelessWidget {
  const RestaurantReviewsScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('التقييمات والآراء'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // Single equality filter (no orderBy) — same query pattern as
      // provider_public_profile_screen.dart. Adding orderBy on a different field
      // requires a composite index we don't have, and drops old docs without createdAt.
      // Newest-first sorting is done client-side.
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('providerUserId', isEqualTo: _uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('[RestaurantReviews] error=${snap.error}');
            return const Center(child: Text('حدث خطأ أثناء تحميل التقييمات'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final ta = (a.data() as Map<String, dynamic>)['createdAt'];
              final tb = (b.data() as Map<String, dynamic>)['createdAt'];
              if (ta is! Timestamp && tb is! Timestamp) return 0;
              if (ta is! Timestamp) return 1;
              if (tb is! Timestamp) return -1;
              return tb.compareTo(ta);
            });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_outline_rounded,
                      size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 14),
                  const Text('لا توجد تقييمات بعد',
                      style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          double avg = 0;
          for (final d in docs) {
            avg += ((d.data() as Map)['rating'] as num? ?? 0).toDouble();
          }
          avg = avg / docs.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _AverageRatingCard(average: avg, count: docs.length),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _ReviewTile(data: data);
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

class _AverageRatingCard extends StatelessWidget {
  final double average;
  final int count;
  const _AverageRatingCard({required this.average, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(average.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < average.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 20,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text('$count تقييم',
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReviewTile({required this.data});

  // Opens the offer linked to this review if it still exists. Same existence-check
  // pattern as restaurant_home_screen.dart._openRelatedNotification.
  Future<void> _openRelatedOffer(BuildContext context) async {
    final offerId = (data['offerId'] as String? ?? '').trim();
    if (offerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد عرض مرتبط بهذا التقييم')),
      );
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .get();
      if (!context.mounted) return;
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذا العرض لم يعد متوفرًا.')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantOfferDetailsScreen(
            offerId: doc.id,
            offerData: doc.data() as Map<String, dynamic>,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  String _formatDate(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final rating = (data['rating'] as num?)?.toInt() ?? 0;
    final comment = (data['comment'] as String? ?? '').trim();
    final userName = (data['userName'] as String? ?? 'مستخدم').trim();
    final offerTitle = (data['offerTitle'] as String? ?? '').trim();
    final reservationId = (data['reservationId'] as String? ?? '').trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openRelatedOffer(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'م',
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        if (offerTitle.isNotEmpty)
                          Text(offerTitle,
                              style: const TextStyle(
                                  color: AppColors.textLight, fontSize: 12)),
                      ],
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
                Text(comment,
                    style: const TextStyle(
                        color: AppColors.textDark, fontSize: 13, height: 1.4)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (reservationId.isNotEmpty) ...[
                    const Icon(Icons.confirmation_number_outlined,
                        size: 13, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text('رمز الحجز: $reservationId',
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 11)),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  Text(_formatDate(data['createdAt']),
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
