import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../theme/app_colors.dart';
import '../../utils/offer_utils.dart';
import '../../widgets/fullscreen_image_viewer.dart';
import '../../widgets/offer_widgets.dart';
import 'edit_offer_screen.dart';
import 'offer_actions.dart';
import 'restaurant_widgets.dart';

// Offer detail screen from the restaurant owner's perspective: live status and data
// via StreamBuilder, with edit/toggle/delete actions. Auto-closes if the offer is
// deleted from here or anywhere else.
class RestaurantOfferDetailsScreen extends StatelessWidget {
  final String offerId;
  final Map<String, dynamic> offerData;

  const RestaurantOfferDetailsScreen({
    super.key,
    required this.offerId,
    required this.offerData,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.success;
      case 'closed':
        return AppColors.textLight;
      case 'reserved':
        return Colors.orange;
      case 'picked_up':
        return AppColors.primary;
      case 'expired':
        return AppColors.danger;
      default:
        return AppColors.textLight;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'available':
        return 'متاح';
      case 'closed':
        return 'مغلق';
      case 'reserved':
        return 'محجوز';
      case 'picked_up':
        return 'تم الاستلام';
      case 'expired':
        return 'منتهي';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('offers')
            .doc(offerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorScaffold(
                message: 'حدث خطأ أثناء تحميل تفاصيل العرض');
          }

          final doc = snapshot.data;
          if (doc != null && !doc.exists) {
            // Offer was deleted — auto-pop back to the previous screen.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) Navigator.pop(context);
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final data = (doc?.data() as Map<String, dynamic>?) ?? offerData;

          final title = data['title'] ?? 'باقة طعام';
          final description = data['description'] ?? '';
          final imageUrl = data['imageUrl'] ?? '';
          final quantity = data['quantity'] ?? 0;
          final remainingQuantity = data['remainingQuantity'] ?? 0;
          final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
          final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
          final currency = data['currency'] ?? 'ILS';
          final rawStatus = (data['status'] as String?) ?? 'unknown';
          final expired = isOfferExpired(data);
          final displayStatus = expired ? 'expired' : rawStatus;
          final pickupLocation = data['pickupLocation'] ?? 'غير محدد';
          final pickupTime = (data['pickupTime'] ?? '').toString();
          final isFree = data['isFree'] == true || discountPrice == 0;
          final offerType = data['offerType'] ?? '';
          final expiryTs = offerExpiryTimestamp(data);
          final allergens = AppConstants.parseAllergyInfo(data['allergyInfo']);
          final sold = (quantity is num && remainingQuantity is num)
              ? (quantity - remainingQuantity)
              : 0;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textDark,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      TappableOfferImage(
                        imageUrl: imageUrl,
                        title: title,
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    buildImagePlaceholder(
                                        icon: Icons.restaurant_menu_rounded,
                                        height: 260),
                              )
                            : buildImagePlaceholder(
                                icon: Icons.restaurant_menu_rounded,
                                height: 260),
                      ),
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
                                Colors.black.withValues(alpha: 0.5),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 90,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                _statusColor(displayStatus).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(displayStatus),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
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
                    Text(title,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    const SizedBox(height: 14),
                    OfferPriceRow(
                      isFree: isFree,
                      originalPrice: originalPrice,
                      discountPrice: discountPrice,
                      currency: currency,
                    ),
                    const SizedBox(height: 18),
                    QuantityBar(remaining: remainingQuantity, total: quantity),
                    const SizedBox(height: 18),
                    _DetailCard(
                      children: [
                        OfferInfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'مكان الاستلام',
                          value: pickupLocation,
                        ),
                        if (pickupTime.isNotEmpty)
                          OfferInfoRow(
                            icon: Icons.access_time_outlined,
                            label: 'وقت الاستلام',
                            value: pickupTime,
                          ),
                        OfferInfoRow(
                          icon: Icons.event_busy_rounded,
                          label: 'تاريخ الانتهاء',
                          value: formatOfferExpiry(expiryTs),
                        ),
                        OfferInfoRow(
                          icon: Icons.shopping_bag_outlined,
                          label: 'الكمية المباعة',
                          value: '$sold وحدة',
                        ),
                        if (offerType.isNotEmpty)
                          OfferInfoRow(
                            icon: Icons.category_outlined,
                            label: 'نوع العرض',
                            value: (offerType == 'mystery_package' ||
                                    offerType == 'restaurant_package')
                                ? 'باقة غامضة'
                                : offerType == 'clear_offer'
                                    ? 'عرض واضح المحتوى'
                                    : 'عرض طعام',
                          ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 16),
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
                    ],
                    if (allergens.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _DetailCard(
                        title: 'مسببات الحساسية الغذائية',
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: allergens.map((allergen) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          AppColors.danger.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  allergen,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditOfferScreen(
                                  offerId: offerId,
                                  offerData: data,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('تعديل'),
                          ),
                        ),
                        if (!expired) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  toggleOfferStatus(context, offerId, rawStatus),
                              icon: Icon(
                                rawStatus == 'available'
                                    ? Icons.pause_circle_outline
                                    : Icons.play_circle_outline,
                                size: 18,
                              ),
                              label: Text(rawStatus == 'available'
                                  ? 'إغلاق العرض'
                                  : 'تفعيل العرض'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => confirmDeleteOffer(context, offerId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('حذف العرض'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Text(message, style: const TextStyle(color: AppColors.danger)),
      ),
    );
  }
}
