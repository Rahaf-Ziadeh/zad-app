import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../theme/app_colors.dart';

class QrCodeScreen extends StatelessWidget {
  final String reservationId;
  final String offerId;
  final String userId;

  const QrCodeScreen({
    super.key,
    required this.reservationId,
    required this.offerId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = "$reservationId|$offerId|$userId";

    return Scaffold(
      appBar: AppBar(
        title: const Text("رمز الاستلام"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  size: 58,
                  color: AppColors.primary,
                ),
                SizedBox(height: 12),
                Text(
                  "اعرض هذا الرمز عند الاستلام",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "يقوم مزوّد الطعام بمسح رمز QR للتأكد من الحجز وتأكيد عملية الاستلام.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textLight,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: QrImageView(
                      data: qrData,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "صالح لطلب واحد فقط",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _InfoBox(
            title: "رقم الحجز",
            value: reservationId,
            icon: Icons.confirmation_number_outlined,
          ),
          const SizedBox(height: 12),
          _InfoBox(
            title: "رقم العرض",
            value: offerId,
            icon: Icons.restaurant_menu_rounded,
          ),
          const SizedBox(height: 22),
          const Text(
            "ملاحظة: لا تشارك رمز الاستلام مع أي شخص آخر، لأنه يستخدم لتأكيد استلام الطلب.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            "$title: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textLight),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}