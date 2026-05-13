import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// صف معلومة واحدة — أيقونة + عنوان + قيمة
class OfferInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const OfferInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textDark,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textLight,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// سعر العرض — مجاني أو مخفض
class OfferPriceRow extends StatelessWidget {
  final bool isFree;
  final num originalPrice;
  final num discountPrice;
  final String currency;

  const OfferPriceRow({
    super.key,
    required this.isFree,
    required this.originalPrice,
    required this.discountPrice,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    if (isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volunteer_activism_rounded,
                size: 16, color: AppColors.primary),
            SizedBox(width: 6),
            Text(
              'مجاني',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Text(
          '$discountPrice $currency',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$originalPrice $currency',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textLight,
            decoration: TextDecoration.lineThrough,
          ),
        ),
      ],
    );
  }
}

/// حساب نسبة الخصم
int calcDiscountPercent(num originalPrice, num discountPrice) {
  if (originalPrice <= 0 || discountPrice < 0) return 0;
  return (((originalPrice - discountPrice) / originalPrice) * 100).round();
}

/// Badge السعر فوق الصورة
Widget buildPriceBadge({required bool isFree, required int discountPercent}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isFree ? AppColors.primary : const Color(0xFFDC2626),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      isFree
          ? 'مجاني'
          : discountPercent > 0
              ? 'خصم $discountPercent%'
              : 'سعر مخفّض',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );
}

/// Placeholder للصورة
Widget buildImagePlaceholder({required IconData icon, double height = 180}) {
  return Container(
    height: height,
    width: double.infinity,
    color: AppColors.primary.withOpacity(0.07),
    child: Center(
      child: Icon(icon, size: 56, color: AppColors.primary.withOpacity(0.4)),
    ),
  );
}
