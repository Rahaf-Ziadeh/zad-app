import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/constants/app_constants.dart';
import 'package:zad_app/models/user.dart';
import 'package:zad_app/utils/phone_formatter.dart';

import '../../services/charity_browse_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/active_reservation_dialog.dart';
import '../../widgets/fullscreen_image_viewer.dart';
import '../../widgets/offer_widgets.dart';

// ─────────────────────────────────────────────
// Active filter model
// ─────────────────────────────────────────────
class ActiveFilter {
  final String label;
  final VoidCallback onClear;

  const ActiveFilter({
    required this.label,
    required this.onClear,
  });
}

// ─────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────
class FilterBar extends StatelessWidget {
  final int activeFilterCount;
  final List<ActiveFilter> activeFilters;
  final bool locationLoading;
  final bool hasLocation;
  final VoidCallback onOpenFilters;
  final VoidCallback onReloadLocation;

  const FilterBar({
    super.key,
    required this.activeFilterCount,
    required this.activeFilters,
    required this.locationLoading,
    required this.hasLocation,
    required this.onOpenFilters,
    required this.onReloadLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpenFilters,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: activeFilterCount > 0
                    ? AppColors.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activeFilterCount > 0
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: activeFilterCount > 0
                        ? Colors.white
                        : AppColors.textLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'فلترة',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: activeFilterCount > 0
                          ? Colors.white
                          : AppColors.textLight,
                    ),
                  ),
                  if (activeFilterCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$activeFilterCount',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (activeFilters.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: activeFilters
                      .map(
                        (filter) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ActiveFilterChip(
                            label: filter.label,
                            onClear: filter.onClear,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(width: 8),
          if (locationLoading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (hasLocation)
            const Icon(
              Icons.my_location_rounded,
              size: 16,
              color: AppColors.success,
            )
          else
            GestureDetector(
              onTap: onReloadLocation,
              child: const Icon(
                Icons.location_off_rounded,
                size: 16,
                color: AppColors.secondary,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Active filter chip
// ─────────────────────────────────────────────
class ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const ActiveFilterChip({
    super.key,
    required this.label,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Offer card
// ─────────────────────────────────────────────
class OfferCard extends StatelessWidget {
  final CharityBrowseService browseService;
  final String docId;
  final Map<String, dynamic> data;
  final String providerLabel;
  final double? distance;

  const OfferCard({
    super.key,
    required this.browseService,
    required this.docId,
    required this.data,
    required this.providerLabel,
    this.distance,
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
    final discountPercent = calcDiscountPercent(
      originalPrice,
      discountPrice,
    );

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
          Stack(
            children: [
              TappableOfferImage(
                imageUrl: imageUrl,
                title: title,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => buildImagePlaceholder(
                          icon: Icons.restaurant_rounded,
                          height: 160,
                        ),
                      )
                    : buildImagePlaceholder(
                        icon: Icons.restaurant_rounded,
                        height: 160,
                      ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: buildPriceBadge(
                  isFree: isFree,
                  discountPercent: discountPercent,
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    providerLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (distance != null)
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.near_me_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          browseService.formatDistance(distance!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OfferPriceRow(
                  isFree: isFree,
                  originalPrice: originalPrice,
                  discountPrice: discountPrice,
                  currency: currency,
                ),
                const SizedBox(height: 10),
                OfferInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'مكان الاستلام',
                  value: distance != null
                      ? '$pickupLocation  •  ${browseService.formatDistance(distance!)}'
                      : pickupLocation,
                ),
                OfferInfoRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'الكمية المتاحة',
                  value: '$remainingQuantity',
                ),
                const SizedBox(height: 12),
                ReserveButton(
                  browseService: browseService,
                  docId: docId,
                  data: data,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reserve button
// ─────────────────────────────────────────────
class ReserveButton extends StatefulWidget {
  final CharityBrowseService browseService;
  final String docId;
  final Map<String, dynamic> data;

  const ReserveButton({
    super.key,
    required this.browseService,
    required this.docId,
    required this.data,
  });

  @override
  State<ReserveButton> createState() => _CharityReserveButtonState();
}

class _CharityReserveButtonState extends State<ReserveButton> {
  bool _loading = false;

  Future<void> _reserve() async {
    if (widget.browseService.isExpired(widget.data)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'انتهت مدة هذا العرض ولم يعد متاحًا للحجز.',
          ),
        ),
      );
      return;
    }

    final hasActive = await hasActiveReservationForOffer(
      context,
      widget.docId,
    );

    if (hasActive || !mounted) return;

    final quantity = await showCharityReservationDialog(
      context: context,
      offerData: widget.data,
    );

    if (quantity == null || !mounted) return;

    setState(() => _loading = true);

    try {
      await widget.browseService.reserveOfferForCharity(
        offerId: widget.docId,
        offerData: widget.data,
        selectedQuantity: quantity,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                quantity > 1
                    ? 'تم حجز $quantity وحدات بنجاح! ✅'
                    : 'تم الحجز بنجاح! ✅',
              ),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceAll('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnOffer = widget.browseService.isOwnOffer(widget.data);

    if (isOwnOffer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.block_rounded),
              label: const Text('لا يمكنك حجز عرضك'),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'لا يمكن للجمعية حجز عرض قامت بنشره.',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _reserve,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.shopping_bag_outlined),
        label: Text(
          _loading ? 'جاري الحجز...' : 'حجز للجمعية',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reservation confirmation dialog
// ─────────────────────────────────────────────
Future<int?> showCharityReservationDialog({
  required BuildContext context,
  required Map<String, dynamic> offerData,
}) async {
  final title = offerData['title'] as String? ?? 'عرض طعام';
  final currency = offerData['currency'] as String? ?? 'ILS';
  final pickupLocation = offerData['pickupLocation'] as String? ?? 'غير محدد';

  final rawPrice = offerData['discountPrice'] ?? offerData['price'] ?? 0;
  final discountPrice = (rawPrice as num).toDouble();
  final isFree = offerData['isFree'] == true || discountPrice == 0;
  final maxQty = (offerData['remainingQuantity'] as num?)?.toInt() ?? 1;

  var quantity = 1;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Widget infoRow(
            IconData icon,
            String label,
            String value,
          ) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$label: ',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: AppColors.card,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bookmark_add_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'تأكيد الحجز',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 16),
                infoRow(
                  Icons.restaurant_menu_rounded,
                  'العرض',
                  title,
                ),
                const SizedBox(height: 10),
                infoRow(
                  Icons.attach_money_rounded,
                  'السعر',
                  isFree
                      ? 'مجاني'
                      : '${discountPrice.toStringAsFixed(0)} $currency',
                ),
                const SizedBox(height: 10),
                infoRow(
                  Icons.location_on_outlined,
                  'مكان الاستلام',
                  pickupLocation,
                ),
                if (maxQty > 1) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'الكمية:',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: quantity > 1
                            ? () => setDialogState(() => quantity--)
                            : null,
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 24,
                        ),
                        color: AppColors.primary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: quantity < maxQty
                            ? () => setDialogState(() => quantity++)
                            : null,
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 24,
                        ),
                        color: AppColors.primary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  Text(
                    'الحد الأقصى: $maxQty وحدة',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (!isFree && quantity > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'الإجمالي: ${(discountPrice * quantity).toStringAsFixed(0)} $currency',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لا يمكن تكرار الحجز لنفس العرض. تأكد من رغبتك قبل المتابعة.',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: AppColors.textLight,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('تأكيد الحجز'),
              ),
            ],
          );
        },
      );
    },
  );

  return confirmed == true ? quantity : null;
}

class SheetSection extends StatelessWidget {
  final String title;
  final List<Widget> chips;

  const SheetSection({
    super.key,
    required this.title,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class SheetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool disabled;
  final String? subtitle;

  const SheetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final dimColor = AppColors.textLight.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : disabled
                  ? AppColors.background
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : disabled
                    ? AppColors.border.withValues(alpha: 0.5)
                    : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : disabled
                        ? dimColor
                        : AppColors.textDark,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 10,
                  color: disabled ? dimColor : AppColors.textLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DonationList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final Widget Function(
      BuildContext, QueryDocumentSnapshot, Map<String, dynamic>) buildActions;
  final bool filterByCharity;
  final String emptyMessage;

  const DonationList({
    required this.stream,
    required this.buildActions,
    required this.filterByCharity,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final currentCharityId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('DONATIONS ERROR: ${snapshot.error}');
          return Center(
            child: Text('حدث خطأ أثناء تحميل التبرعات\n${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs;

        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final targetCharityId = data['targetCharityId']?.toString() ?? '';

          final charityId = data['charityId']?.toString() ?? '';

          final charityUserId = data['charityUserId']?.toString() ?? '';

          final reviewedBy = data['reviewedBy']?.toString() ?? '';

          return targetCharityId == currentCharityId ||
              charityId == currentCharityId ||
              charityUserId == currentCharityId ||
              reviewedBy == currentCharityId;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism_outlined,
                    size: 56, color: AppColors.primary.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(emptyMessage,
                    style: const TextStyle(color: AppColors.textLight)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final foodName = data['foodName'] ?? data['title'] ?? 'تبرع طعام';
            final quantity = data['quantity'] ?? 'غير محدد';
            final category = data['category'] ?? 'غير مصنف';
            final location =
                data['pickupLocation'] ?? data['location'] ?? 'غير محدد';
            final notes = data['notes'] ?? '';
            final donorName = data['donorName'] ?? data['userName'] ?? '';
            final imageUrl = data['imageUrl'] as String? ?? '';
            final pickupTime = data['pickupTime'] as String? ?? '';
            final startTime = data['pickupStartTime'] as String? ?? '';
            final endTime = data['pickupEndTime'] as String? ?? '';
            final displayPickup = pickupTime.isNotEmpty
                ? pickupTime
                : (startTime.isNotEmpty && endTime.isNotEmpty
                    ? '$startTime - $endTime'
                    : '');
            final allergens =
                AppConstants.parseAllergyInfo(data['allergyInfo']);
            final hasKnownAllergens = allergens.isNotEmpty &&
                !(allergens.length == 1 &&
                    allergens.first == AppConstants.noKnownAllergens);

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── صورة التبرع ──
                  if (imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── رأس البطاقة ──
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                  Icons.volunteer_activism_rounded,
                                  color: Color(0xFFE11D48),
                                  size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    foodName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  if (donorName.isNotEmpty)
                                    Text(
                                      'المتبرع: $donorName',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textLight),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        OfferInfoRow(
                            icon: Icons.category_outlined,
                            label: 'الفئة',
                            value: category),
                        OfferInfoRow(
                            icon: Icons.inventory_2_outlined,
                            label: 'الكمية',
                            value: quantity.toString()),
                        OfferInfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'الموقع',
                            value: location),
                        if (displayPickup.isNotEmpty)
                          OfferInfoRow(
                              icon: Icons.access_time_rounded,
                              label: 'وقت الاستلام',
                              value: displayPickup),
                        if (notes.toString().isNotEmpty)
                          OfferInfoRow(
                              icon: Icons.notes_outlined,
                              label: 'ملاحظات',
                              value: notes.toString()),
                        if (hasKnownAllergens)
                          OfferInfoRow(
                              icon: Icons.warning_amber_rounded,
                              label: 'مسببات الحساسية',
                              value: allergens.join('، ')),

                        const SizedBox(height: 14),
                        buildActions(context, doc, data),
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

class WelcomeCard extends StatelessWidget {
  final AppUser user;

  const WelcomeCard({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE11D48),
            Color(0xFFBE123C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'ج',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مرحباً بعودتك ❤️',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                const Text(
                  'راجعي التبرعات وساعدي في توزيع الطعام',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const StatCard({
    super.key,
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
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const ActionTile({
    super.key,
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
        side: const BorderSide(
          color: AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditableField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final bool readOnly;
  final TextInputType? keyboardType;
  final bool isPhone;

  const EditableField({
    super.key,
    required this.icon,
    required this.label,
    required this.controller,
    required this.isEditing,
    this.readOnly = false,
    this.keyboardType,
    this.isPhone = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 14,
      color: readOnly ? AppColors.textLight : AppColors.textDark,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                isEditing && !readOnly
                    ? TextField(
                        controller: controller,
                        keyboardType: keyboardType,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 6,
                          ),
                          border: UnderlineInputBorder(),
                        ),
                      )
                    : controller.text.isEmpty
                        ? Text(
                            '—',
                            style: valueStyle,
                          )
                        : isPhone
                            ? PhoneText(
                                controller.text,
                                style: valueStyle,
                              )
                            : Text(
                                controller.text,
                                style: valueStyle,
                              ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WorkingHoursField extends StatelessWidget {
  final TimeOfDay? start;
  final TimeOfDay? end;
  final bool isEditing;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const WorkingHoursField({
    super.key,
    required this.start,
    required this.end,
    required this.isEditing,
    required this.onPickStart,
    required this.onPickEnd,
  });

  String _format(
    TimeOfDay time,
  ) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.access_time_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ساعات العمل',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                if (!isEditing)
                  Text(
                    start != null && end != null
                        ? '${_format(start!)} - ${_format(end!)}'
                        : '—',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onPickStart,
                          child: Text(
                            start != null
                                ? _format(
                                    start!,
                                  )
                                : 'البداية',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onPickEnd,
                          child: Text(
                            end != null
                                ? _format(
                                    end!,
                                  )
                                : 'النهاية',
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SurplusCard extends StatelessWidget {
  final String donationId;
  final Map<String, dynamic> data;
  final bool isPublished;

  const SurplusCard({
    required this.donationId,
    required this.data,
    required this.isPublished,
  });

  @override
  Widget build(BuildContext context) {
    final foodName = data['foodName'] ?? 'طعام';
    final quantity = data['quantity'] ?? '—';
    final category = data['category'] ?? '—';
    final location = data['location'] ?? 'غير محدد';
    final notes = data['notes'] ?? '';
    final donorName = data['userName'] ?? 'متبرع';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.volunteer_activism_rounded,
                      color: AppColors.success, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(foodName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textDark)),
                      Text('من: $donorName',
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('جاهز للنشر',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── تفاصيل ──
            OfferInfoRow(
                icon: Icons.category_outlined, label: 'الفئة', value: category),
            OfferInfoRow(
                icon: Icons.inventory_2_outlined,
                label: 'الكمية',
                value: '$quantity'),
            OfferInfoRow(
                icon: Icons.location_on_outlined,
                label: 'الموقع',
                value: location),
            if (notes.toString().isNotEmpty)
              OfferInfoRow(
                  icon: Icons.notes_outlined, label: 'ملاحظات', value: notes),

            const SizedBox(height: 14),

            // ── زرّ النشر ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublishNewSurplusScreen(
                      prefillDonationId: donationId,
                      prefillData: data,
                    ),
                  ),
                ),
                icon: const Icon(Icons.publish_rounded),
                label: const Text('نشر كعرض للمستفيدين'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة العرض المنشور
// ─────────────────────────────────────────────
class PublishedOfferCard extends StatelessWidget {
  final String offerId;
  final Map<String, dynamic> data;

  const PublishedOfferCard({
    required this.offerId,
    required this.data,
  });

  Color statusColor(String s) {
    switch (s) {
      case 'available':
        return AppColors.success;
      case 'closed':
        return AppColors.textLight;
      case 'reserved':
        return Colors.orange;
      default:
        return AppColors.textLight;
    }
  }

  String statusLabel(String s) {
    switch (s) {
      case 'available':
        return 'متاح';
      case 'closed':
        return 'مغلق';
      case 'reserved':
        return 'محجوز';
      default:
        return s;
    }
  }

  Future<void> closeOffer(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .update({
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إغلاق العرض')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'عرض طعام';
    final status = data['status'] ?? 'available';
    final remaining = data['remainingQuantity'] ?? 0;
    final total = data['quantity'] ?? 0;
    final location = data['pickupLocation'] ?? 'غير محدد';
    final color = statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fastfood_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(location,
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel(status),
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // شريط تقدم الكمية
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الكمية المتبقية',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                    Text('$remaining / $total',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? remaining / total : 0,
                    minHeight: 7,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),

            if (status == 'available') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => closeOffer(context),
                  icon: const Icon(Icons.close_rounded,
                      size: 16, color: AppColors.danger),
                  label: const Text('إغلاق العرض',
                      style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
