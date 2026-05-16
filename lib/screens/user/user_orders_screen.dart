import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';
import 'qr_code_screen.dart';

class UserOrdersScreen extends StatelessWidget {
  const UserOrdersScreen({super.key});

  Stream<QuerySnapshot> _ordersStream() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'reserved':
        return 'محجوز';
      case 'picked_up':
        return 'تم الاستلام';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'reserved':
        return Colors.orange;
      case 'picked_up':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.danger;
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelReservation({
    required BuildContext context,
    required String reservationId,
    required String offerId,
  }) async {
    try {
      final reservationRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId);
      final offerRef =
          FirebaseFirestore.instance.collection('offers').doc(offerId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final reservationSnap = await transaction.get(reservationRef);
        final offerSnap = await transaction.get(offerRef);

        if (!reservationSnap.exists) throw Exception('الحجز غير موجود');

        final resData = reservationSnap.data() as Map<String, dynamic>;
        if (resData['status'] != 'reserved') {
          throw Exception('لا يمكن إلغاء هذا الطلب');
        }

        if (offerSnap.exists) {
          final offerData = offerSnap.data() as Map<String, dynamic>;
          final qty = offerData['remainingQuantity'] ?? 0;
          transaction.update(offerRef, {
            'remainingQuantity': qty + 1,
            'status': 'available',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(reservationRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الحجز بنجاح')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  void _confirmCancel({
    required BuildContext context,
    required String reservationId,
    required String offerId,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: const Text('هل أنت متأكد من إلغاء هذا الحجز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(context);
              _cancelReservation(
                context: context,
                reservationId: reservationId,
                offerId: offerId,
              );
            },
            child: const Text('إلغاء الحجز'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog({
    required BuildContext context,
    required String reservationId,
  }) {
    showDialog(
      context: context,
      builder: (_) => _RatingDialog(reservationId: reservationId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('طلباتي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _ordersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ أثناء تحميل الطلبات'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs;
          if (orders.isEmpty) return const _EmptyOrders();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['offerTitle'] ?? 'طلب طعام';
              final status = data['status'] ?? 'reserved';
              final offerId = data['offerId'] ?? '';
              final reservationId = doc.id;
              final userId = FirebaseAuth.instance.currentUser!.uid;
              final providerRole = data['providerRole'] ?? '';
              final pickupLocation = data['pickupLocation'] ?? 'غير محدد';
              final hasRated = data['hasRated'] ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: status == 'reserved'
                        ? Colors.orange.withOpacity(0.4)
                        : AppColors.border,
                  ),
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
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.fastfood_rounded,
                                color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color:
                                  _statusColor(status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // ── معلومات ──
                      OfferInfoRow(
                        icon: Icons.confirmation_number_outlined,
                        label: 'رقم الحجز',
                        value: reservationId,
                      ),
                      if (providerRole.isNotEmpty)
                        OfferInfoRow(
                          icon: Icons.storefront_outlined,
                          label: 'المزوّد',
                          value: providerRole,
                        ),
                      OfferInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'مكان الاستلام',
                        value: pickupLocation,
                      ),

                      const SizedBox(height: 12),

                      // ── أزرار حسب الحالة ──
                      if (status == 'reserved') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => QrCodeScreen(
                                      reservationId: reservationId,
                                      offerId: offerId,
                                      userId: userId,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.qr_code_rounded,
                                    size: 18),
                                label: const Text('رمز QR'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _confirmCancel(
                                  context: context,
                                  reservationId: reservationId,
                                  offerId: offerId,
                                ),
                                icon: const Icon(Icons.cancel_outlined,
                                    size: 18),
                                label: const Text('إلغاء'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(
                                      color: AppColors.danger),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (status == 'picked_up') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'تم تأكيد الاستلام بنجاح',
                                style: TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // زر التقييم — FR-23
                        if (!hasRated) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showRatingDialog(
                                context: context,
                                reservationId: reservationId,
                              ),
                              icon: const Icon(Icons.star_outline_rounded,
                                  size: 18),
                              label: const Text('قيّم تجربتك'),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              '⭐ شكراً على تقييمك',
                              style: TextStyle(
                                  color: AppColors.textLight, fontSize: 12),
                            ),
                          ),
                        ],
                      ] else if (status == 'cancelled') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cancel_rounded,
                                  color: AppColors.danger, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'تم إلغاء هذا الحجز',
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Dialog التقييم — FR-23
// ─────────────────────────────────────────────
class _RatingDialog extends StatefulWidget {
  final String reservationId;
  const _RatingDialog({required this.reservationId});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار تقييم')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .update({
        'rating': _rating,
        'ratingComment': _commentController.text.trim(),
        'hasRated': true,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شكراً على تقييمك! ⭐')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('قيّم تجربتك',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('كيف كانت تجربتك مع هذا الطلب؟',
              style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'أضف تعليقاً (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('إرسال'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────
class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: AppColors.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد طلبات بعد',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'عند حجز عرض أو باقة، ستظهر تفاصيل الطلب ورمز الاستلام هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}