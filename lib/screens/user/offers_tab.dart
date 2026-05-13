import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/reservation_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';
import 'qr_code_screen.dart';

class OffersTab extends StatefulWidget {
  const OffersTab({super.key});

  @override
  State<OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends State<OffersTab> {
  String _filterType = 'all'; // all | free | paid

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

  Query _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('offers')
        .where('status', isEqualTo: 'available')
        .where('offerType', whereNotIn: ['restaurant_package']);

    if (_filterType == 'free') {
      query = query.where('isFree', isEqualTo: true);
    } else if (_filterType == 'paid') {
      query = query.where('isFree', isEqualTo: false);
    }

    return query;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── شريط الفلترة ──
        Container(
          color: AppColors.card,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded,
                  size: 18, color: AppColors.textLight),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'الكل',
                selected: _filterType == 'all',
                onTap: () => setState(() => _filterType = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'مجاني',
                selected: _filterType == 'free',
                onTap: () => setState(() => _filterType = 'free'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'مخفّض',
                selected: _filterType == 'paid',
                onTap: () => setState(() => _filterType = 'paid'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── قائمة العروض ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _ErrorState(message: 'حدث خطأ أثناء تحميل العروض');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final offers = snapshot.data!.docs;

              if (offers.isEmpty) {
                return const _EmptyState(message: 'لا توجد عروض متاحة حالياً');
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  final doc = offers[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _OfferCard(
                    docId: doc.id,
                    data: data,
                    providerLabel: _providerLabel(data['providerRole'] ?? ''),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة العرض
// ─────────────────────────────────────────────
class _OfferCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String providerLabel;

  const _OfferCard({
    required this.docId,
    required this.data,
    required this.providerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'عرض طعام';
    final description = data['description'] ?? '';
    final pickupLocation = data['pickupLocation'] ?? 'غير محدد';
    final remainingQuantity = data['remainingQuantity'] ?? 0;
    final currency = data['currency'] ?? 'ILS';
    final imageUrl = data['imageUrl'] ?? '';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── صورة ──
          Stack(
            children: [
              imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          buildImagePlaceholder(icon: Icons.restaurant_rounded),
                    )
                  : buildImagePlaceholder(icon: Icons.restaurant_rounded),
              Positioned(
                top: 12,
                right: 12,
                child: buildPriceBadge(
                    isFree: isFree, discountPercent: discountPercent),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    providerLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
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
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textLight, height: 1.5, fontSize: 13),
                  ),
                ],
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
                  label: 'الكمية المتاحة',
                  value: '$remainingQuantity',
                ),
                const SizedBox(height: 14),
                _ReserveButton(docId: docId, data: data),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// زر الحجز
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
        label: Text(_loading ? 'جاري الحجز...' : 'حجز العرض'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widgets مساعدة
// ─────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textLight,
          ),
        ),
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

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_food_rounded,
              size: 60, color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 14),
          Text(message,
              style: const TextStyle(color: AppColors.textLight, fontSize: 14)),
        ],
      ),
    );
  }
}
