import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/verification_utils.dart';

/// إجراءات مشتركة على عرض المطعم (حذف/تبديل الحالة)، تُستخدم من كل من
/// RestaurantOffersScreen وRestaurantOfferDetailsScreen حتى لا يتكرر منطق
/// التحقق من الحجوزات النشطة قبل الحذف في أكثر من مكان.

Future<void> confirmDeleteOffer(BuildContext context, String offerId) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('حذف العرض'),
      content: const Text('هل أنت متأكد من حذف هذا العرض؟ لا يمكن التراجع.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return;

  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  try {
    // ── قاعدة أعمال: لا يمكن حذف عرض مرتبط بحجز نشط أو مكتمل ──
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
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
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
              onPressed: () => Navigator.pop(context),
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

  // ── إغلاق عرض مسموح دائماً أثناء إعادة المراجعة أو الرفض (لا يُغلق سوى
  // اتجاه إعادة التفعيل closed→available)؛ يُتحقَّق من Firestore مباشرة
  // كخط دفاع فعلي على مستوى الكتابة ──
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
