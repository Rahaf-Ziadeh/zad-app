import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class OffersTab extends StatelessWidget {
  const OffersTab({super.key});

  String _providerLabel(String role) {
    switch (role) {
      case 'restaurant':
        return 'مطعم';
      case 'charity':
        return 'جمعية';
      case 'individual':
        return 'فرد';
      default:
        return 'مزود طعام';
    }
  }

  int _discountPercent(num originalPrice, num discountPrice) {
    if (originalPrice <= 0 || discountPrice < 0) return 0;
    final percent = ((originalPrice - discountPrice) / originalPrice) * 100;
    return percent.round();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('status', isEqualTo: 'available')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("حدث خطأ أثناء تحميل العروض"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final offers = snapshot.data!.docs;

        if (offers.isEmpty) {
          return const Center(
            child: Text(
              "لا توجد عروض متاحة حالياً",
              style: TextStyle(color: AppColors.textLight),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final data = offers[index].data() as Map<String, dynamic>;

            final title = data['title'] ?? 'عرض طعام';
            final description = data['description'] ?? 'لا يوجد وصف';
            final providerRole = _providerLabel(data['providerRole'] ?? '');
            final pickupLocation = data['pickupLocation'] ?? 'غير محدد';
            final remainingQuantity = data['remainingQuantity'] ?? 0;
            final currency = data['currency'] ?? 'ILS';

            final imageUrl = data['imageUrl'] ?? '';
            final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
            final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;

            final isFree = data['isFree'] ?? discountPrice == 0;
            final discountPercent =
                _discountPercent(originalPrice, discountPrice);

            return Card(
              margin: const EdgeInsets.only(bottom: 18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OfferImage(
                    imageUrl: imageUrl,
                    isFree: isFree,
                    discountPercent: discountPercent,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _PriceRow(
                          isFree: isFree,
                          originalPrice: originalPrice,
                          discountPrice: discountPrice,
                          currency: currency,
                        ),
                        const SizedBox(height: 14),
                        _InfoRow(
                          icon: Icons.storefront_rounded,
                          label: "المزوّد",
                          value: providerRole,
                        ),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: "مكان الاستلام",
                          value: pickupLocation,
                        ),
                        _InfoRow(
                          icon: Icons.inventory_2_outlined,
                          label: "الكمية المتاحة",
                          value: "$remainingQuantity",
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text("ميزة الحجز سيتم إضافتها لاحقاً"),
                                ),
                              );
                            },
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: const Text("حجز العرض"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OfferImage extends StatelessWidget {
  final String imageUrl;
  final bool isFree;
  final int discountPercent;

  const _OfferImage({
    required this.imageUrl,
    required this.isFree,
    required this.discountPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (imageUrl.isNotEmpty)
          Image.network(
            imageUrl,
            height: 170,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _placeholder(),
          )
        else
          _placeholder(),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isFree ? AppColors.primary : const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              isFree
                  ? "مجاني"
                  : discountPercent > 0
                      ? "خصم $discountPercent%"
                      : "عرض مخفض",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      height: 170,
      width: double.infinity,
      color: AppColors.primary.withOpacity(0.08),
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 54,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final bool isFree;
  final num originalPrice;
  final num discountPrice;
  final String currency;

  const _PriceRow({
    required this.isFree,
    required this.originalPrice,
    required this.discountPrice,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    if (isFree) {
      return const Text(
        "مجاني",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      );
    }

    return Row(
      children: [
        Text(
          "$discountPrice $currency",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          "$originalPrice $currency",
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textLight,
            decoration: TextDecoration.lineThrough,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }
}
