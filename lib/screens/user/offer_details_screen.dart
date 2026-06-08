import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/reservation_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';
import 'qr_code_screen.dart';
import 'payment_method_screen.dart';

class OfferDetailsScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final double? distance;

  const OfferDetailsScreen({
    super.key,
    required this.docId,
    required this.data,
    this.distance,
  });

  String _providerLabel(String role) {
    switch (role) {
      case 'restaurant':
        return 'مطعم';
      case 'charity':
        return 'جمعية خيرية';
      case 'individual':
        return 'فرد';
      default:
        return 'مزوّد طعام';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'عرض طعام';
    final description = data['description'] ?? '';
    final pickupLocation = data['pickupLocation'] ?? 'غير محدد';
    final pickupTime = data['pickupTime'] ?? '';
    final remainingQuantity = data['remainingQuantity'] ?? 0;
    final currency = data['currency'] ?? 'ILS';
    final imageUrl = data['imageUrl'] ?? '';
    final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
    final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
    final isFree = data['isFree'] == true || discountPrice == 0;
    final discountPercent = calcDiscountPercent(originalPrice, discountPrice);
    final providerRole = data['providerRole'] ?? '';
    final offerType = data['offerType'] ?? '';
    final isCash = data['isCash'] ?? true;
    final isOnline = data['isOnline'] ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── صورة كبيرة مع AppBar شفاف ──
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textDark,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => buildImagePlaceholder(
                              icon: Icons.restaurant_rounded, height: 280),
                        )
                      : buildImagePlaceholder(
                          icon: Icons.restaurant_rounded, height: 280),
                  // gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Badge السعر
                  Positioned(
                    top: 90,
                    right: 16,
                    child: buildPriceBadge(
                        isFree: isFree, discountPercent: discountPercent),
                  ),
                  // Badge المسافة
                  if (distance != null)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              LocationService().formatDistance(distance!),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(18),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── العنوان والمزوّد ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_providerLabel(providerRole),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── السعر ──
                OfferPriceRow(
                  isFree: isFree,
                  originalPrice: originalPrice,
                  discountPrice: discountPrice,
                  currency: currency,
                ),

                const SizedBox(height: 20),

                // ── تفاصيل ──
                _DetailCard(
                  children: [
                    OfferInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'مكان الاستلام',
                      value: pickupLocation,
                    ),
                    if (pickupTime.toString().isNotEmpty)
                      OfferInfoRow(
                        icon: Icons.access_time_outlined,
                        label: 'وقت الاستلام',
                        value: pickupTime.toString(),
                      ),
                    OfferInfoRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'الكمية المتاحة',
                      value: '$remainingQuantity وحدة',
                    ),
                    if (offerType.isNotEmpty)
                      OfferInfoRow(
                        icon: Icons.category_outlined,
                        label: 'نوع العرض',
                        value: offerType == 'restaurant_package'
                            ? 'باقة مطعم'
                            : 'عرض فردي',
                      ),
                    // طرق الدفع المتاحة
                    if (!isFree)
                      OfferInfoRow(
                        icon: Icons.payment_rounded,
                        label: 'طرق الدفع',
                        value: [
                          if (isCash) 'كاش عند الاستلام',
                          if (isOnline) 'دفع إلكتروني',
                        ].join(' • '),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── الوصف ──
                if (description.isNotEmpty) ...[
                  _DetailCard(
                    title: 'الوصف',
                    children: [
                      Text(description,
                          style: const TextStyle(
                              color: AppColors.textLight,
                              height: 1.7,
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // ── تحذير الكمية ──
                if (remainingQuantity <= 3 && remainingQuantity > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'تبقّى $remainingQuantity فقط — احجز الآن!',
                          style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── تقييمات هذا العرض ──
                _OfferRatings(offerId: docId),

                const SizedBox(height: 24),

                // ── زر الحجز ──
                if (remainingQuantity > 0)
                  _ReserveButton(
                    docId: docId,
                    data: data,
                    isFree: isFree,
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('نفدت الكمية المتاحة',
                          style: TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                  ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// زر الحجز — يفتح شاشة الدفع لو مدفوع
// ─────────────────────────────────────────────
class _ReserveButton extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isFree;

  const _ReserveButton({
    required this.docId,
    required this.data,
    required this.isFree,
  });

  @override
  State<_ReserveButton> createState() => _ReserveButtonState();
}

class _ReserveButtonState extends State<_ReserveButton> {
  bool _loading = false;

  Future<void> _proceed() async {
    // لو مجاني — احجز مباشرة
    // لو مدفوع — افتح شاشة اختيار طريقة الدفع
    if (!widget.isFree) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentMethodScreen(
            docId: widget.docId,
            data: widget.data,
          ),
        ),
      );
      // لو اليوزر ما كمّل الدفع — ما نحجز
      if (result != true) return;
    } else {
      await _reserve();
    }
  }

  Future<void> _reserve() async {
    setState(() => _loading = true);
    try {
      final reservationId = await ReservationService().reserveOffer(
        offerId: widget.docId,
        offerData: widget.data,
      );
      final userId = FirebaseAuth.instance.currentUser!.uid;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QrCodeScreen(
            reservationId: reservationId,
            offerId: widget.docId,
            userId: userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _proceed,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(widget.isFree
                ? Icons.volunteer_activism_rounded
                : Icons.shopping_bag_outlined),
        label: Text(
          _loading
              ? 'جاري الحجز...'
              : widget.isFree
                  ? 'احجز مجاناً'
                  : 'احجز وادفع',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// تقييمات العرض
// ─────────────────────────────────────────────
class _OfferRatings extends StatelessWidget {
  final String offerId;
  const _OfferRatings({required this.offerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('offerId', isEqualTo: offerId)
          .where('hasRated', isEqualTo: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snap.data!.docs;
        double avgRating = 0;
        for (final d in docs) {
          avgRating += ((d.data() as Map)['rating'] ?? 0) as num;
        }
        avgRating = avgRating / docs.length;

        return _DetailCard(
          title: 'التقييمات  (${docs.length})',
          children: [
            Row(
              children: [
                Text(avgRating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < avgRating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                    ),
                    Text('${docs.length} تقييم',
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final comment = data['ratingComment'] ?? '';
              final rating = data['rating'] ?? 0;
              final userName = data['userName'] ?? 'مستخدم';
              if (comment.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'م',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(userName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const Spacer(),
                              Row(
                                children: List.generate(
                                    5,
                                    (i) => Icon(
                                          i < rating
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          color: Colors.amber,
                                          size: 14,
                                        )),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(comment,
                              style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 12,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة تفاصيل
// ─────────────────────────────────────────────
class _DetailCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _DetailCard({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}
