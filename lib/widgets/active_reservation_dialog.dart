import 'package:flutter/material.dart';

import '../screens/user/user_orders_screen.dart';
import '../services/reservation_service.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────
// يتحقق من وجود حجز نشط للمستخدم الحالي على هذا العرض قبل فتح صحيفة اختيار
// الكمية أو الدفع في أي نقطة دخول للحجز. إن وُجد حجز نشط، تُعرض رسالة توضح
// ذلك بدل فتح تدفق حجز جديد، ويُعاد true لإلغاء المتابعة في المستدعي.
// يبقى التحقق الموجود داخل ReservationService.reserveOffer كشبكة أمان
// احتياطية دون أي تغيير ──
Future<bool> hasActiveReservationForOffer(
  BuildContext context,
  String offerId,
) async {
  final existing = await ReservationService().getActiveReservation(offerId);
  if (existing == null) return false;
  if (!context.mounted) return true;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.card,
      title: const Text('لديك حجز نشط',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textDark)),
      content: const Text(
        'لديك حجز نشط لهذا العرض.\nيمكنك متابعة الحجز من صفحة "طلباتي".',
        style: TextStyle(color: AppColors.textDark, height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('إغلاق',
              style: TextStyle(color: AppColors.textLight)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            // ── يفتح ضمن الـ Navigator المتداخل الحالي فيبقى شريط التنقّل
            // السفلي ظاهراً، بنفس أسلوب فتح الشاشات الأخرى من داخل التبويبات ──
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const UserOrdersScreen(statusFilter: 'reserved'),
              ),
            );
          },
          child: const Text('عرض الحجز'),
        ),
      ],
    ),
  );
  return true;
}
