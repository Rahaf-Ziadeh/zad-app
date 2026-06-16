import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/reservation_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';
import 'offer_details_screen.dart';
import 'qr_code_screen.dart';

class PackagesTab extends StatelessWidget {
  const PackagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('offerType', isEqualTo: 'restaurant_package')
          .where('status', isEqualTo: 'available')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ErrorState(message: 'حدث خطأ أثناء تحميل الباقات');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final packages = snapshot.data!.docs;

        if (packages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.card_giftcard_rounded,
                    size: 60, color: AppColors.primary.withOpacity(0.3)),
                const SizedBox(height: 14),
                const Text(
                  'لا توجد باقات متاحة حالياً',
                  style: TextStyle(color: AppColors.textLight, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: packages.length,
          itemBuilder: (context, index) {
            final doc = packages[index];
            final data = doc.data() as Map<String, dynamic>;
            return _PackageCard(docId: doc.id, data: data);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة الباقة
// ─────────────────────────────────────────────
class _PackageCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _PackageCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'باقة غامضة';
    final description =
        data['description'] ?? 'باقة طعام فائض من المطعم بسعر مخفّض.';
    final isMysteryPackage =
        data['isMysteryPackage'] == true || data['packageType'] == 'mystery';

    final packageLabel = isMysteryPackage ? 'باقة غامضة' : 'باقة واضحة';
    final imageUrl = data['imageUrl'] ?? '';
    final currency = data['currency'] ?? 'ILS';
    final pickupLocation = data['pickupLocation'] ?? 'غير محدد';
    final remainingQuantity = data['remainingQuantity'] ?? 0;
    final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
    final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
    final isFree = data['isFree'] == true || discountPrice == 0;
    final discountPercent = calcDiscountPercent(originalPrice, discountPrice);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OfferDetailsScreen(
              docId: docId,
              data: data,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── صورة ──
            Stack(
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 175,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => buildImagePlaceholder(
                            icon: Icons.card_giftcard_rounded, height: 175),
                      )
                    : buildImagePlaceholder(
                        icon: Icons.card_giftcard_rounded, height: 175),
                Positioned(
                  top: 12,
                  right: 12,
                  child: buildPriceBadge(
                      isFree: isFree, discountPercent: discountPercent),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.card_giftcard_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          packageLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── تفاصيل ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textLight, height: 1.5, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  OfferPriceRow(
                    isFree: isFree,
                    originalPrice: originalPrice,
                    discountPrice: discountPrice,
                    currency: currency,
                  ),
                  const SizedBox(height: 12),
                  OfferInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'مكان الاستلام',
                    value: pickupLocation,
                  ),
                  OfferInfoRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'عدد الباقات المتاحة',
                    value: '$remainingQuantity',
                  ),
                  const OfferInfoRow(
                    icon: Icons.info_outline_rounded,
                    label: 'ملاحظة',
                    value: 'محتوى الباقة يحدده المطعم حسب الطعام الفائض',
                  ),
                  const SizedBox(height: 14),
                  _ReserveButton(docId: docId, data: data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// زر الحجز مع loading state
// ─────────────────────────────────────────────
class _ReserveButton extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _ReserveButton({required this.docId, required this.data});

  @override
  State<_ReserveButton> createState() => _ReserveButtonState();
}

class _ReserveButtonState extends State<_ReserveButton> {
  bool _loading = false;

  Future<void> _reserve() async {
    if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('يجب تسجيل الدخول أولاً للحجز'),
    ),
  );
  return;
}
    setState(() => _loading = true);
    try {
      final reservationId = await ReservationService().reserveOffer(
        offerId: widget.docId,
        offerData: widget.data,
      );
      final userId = FirebaseAuth.instance.currentUser!.uid;
      if (!mounted) return;
      Navigator.push(
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
        onPressed: _loading ? null : _reserve,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.shopping_bag_outlined),
        label: Text(_loading ? 'جاري الحجز...' : 'حجز الباقة'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: AppColors.textLight, fontSize: 14)),
        ],
      ),
    );
  }
}
