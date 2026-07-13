import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/verification_utils.dart';

/// Shared offer actions (delete / toggle status) used by both RestaurantOffersScreen
/// and RestaurantOfferDetailsScreen — keeps the active-reservation check in one place.

Future<void> confirmDeleteOffer(BuildContext context, String offerId) async {
  // Prevents double-pop on rapid double-tap of the same dialog button.
  var dialogPopped = false;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('حذف العرض'),
      content: const Text('هل أنت متأكد من حذف هذا العرض؟ لا يمكن التراجع.'),
      actions: [
        TextButton(
          onPressed: () {
            if (dialogPopped) return;
            dialogPopped = true;
            Navigator.of(dialogContext).pop(false);
          },
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () {
            if (dialogPopped) return;
            dialogPopped = true;
            Navigator.of(dialogContext).pop(true);
          },
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return;

  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  try {
    // Business rule: offers with active or completed reservations cannot be deleted.
    final blockingSnap = await FirebaseFirestore.instance
        .collection('reservations')
        .where('offerId', isEqualTo: offerId)
        .where('status', whereIn: ['reserved', 'picked_up'])
        .get();

    if (blockingSnap.docs.isNotEmpty) {
      final hasReserved = blockingSnap.docs.any(
        (d) => d.data()['status'] == 'reserved',
      );
      final message = hasReserved
          ? 'لا يمكن حذف هذا العرض لأنه محجوز حالياً.'
          : 'لا يمكن حذف هذا العرض لأنه تم استلامه من قبل أحد المستخدمين.';

      if (!context.mounted) return;
      var infoDialogPopped = false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: AppColors.danger, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text('تعذّر الحذف',
                    style: TextStyle(color: AppColors.danger, fontSize: 17)),
              ),
            ],
          ),
          content: Text(message,
              style: const TextStyle(
                  color: AppColors.textDark, fontSize: 14, height: 1.6)),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (infoDialogPopped) return;
                infoDialogPopped = true;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('offers').doc(offerId).delete();

    try {
      await NotificationService().sendNotification(
        userId: uid,
        title: 'تم حذف العرض',
        message: 'تم حذف العرض بنجاح',
        type: 'offer',
      );
    } catch (_) {}

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم حذف العرض')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('خطأ: $e')));
  }
}

Future<void> toggleOfferStatus(
    BuildContext context, String offerId, String currentStatus) async {
  final newStatus = currentStatus == 'available' ? 'closed' : 'available';

  // Closing is always allowed during re-review or rejection; only the closed→available
  // direction is blocked. Firestore is checked directly as the actual write-time guard.
  if (newStatus == 'available') {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final canReactivate = await canPublishOrReactivateOffers(uid);
    if (!context.mounted) return;
    if (!canReactivate) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final vs = doc.data()?['verificationStatus'] as String?;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publishBlockedMessage(vs)),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
  }

  try {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            newStatus == 'available' ? 'تم تفعيل العرض' : 'تم إغلاق العرض')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('خطأ: $e')));
  }
}
