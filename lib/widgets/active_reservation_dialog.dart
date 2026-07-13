import 'package:flutter/material.dart';

import '../screens/user/user_orders_screen.dart';
import '../services/reservation_service.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────
// Checks for an active reservation on this offer before opening the
// quantity/payment sheet. Shows a dialog instead of starting a new
// booking flow, and returns true so the caller aborts.
// ReservationService.reserveOffer still has its own guard as a final
// safety net — this is just an early-exit UX shortcut.
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
            // Push within the nested Navigator so the bottom bar stays visible.
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
