import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
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
        return "محجوز";
      case 'picked_up':
        return "تم الاستلام";
      case 'cancelled':
        return "ملغي";
      default:
        return "غير معروف";
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'reserved':
        return Colors.orange;
      case 'picked_up':
        return AppColors.primary;
      case 'cancelled':
        return Colors.red;
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
        final reservationSnapshot = await transaction.get(reservationRef);
        final offerSnapshot = await transaction.get(offerRef);

        if (!reservationSnapshot.exists) {
          throw Exception("الحجز غير موجود");
        }

        final reservationData =
            reservationSnapshot.data() as Map<String, dynamic>;

        if (reservationData['status'] != 'reserved') {
          throw Exception("لا يمكن إلغاء هذا الطلب");
        }

        int remainingQuantity = 0;

        if (offerSnapshot.exists) {
          final offerData = offerSnapshot.data() as Map<String, dynamic>;
          remainingQuantity = offerData['remainingQuantity'] ?? 0;

          transaction.update(offerRef, {
            'remainingQuantity': remainingQuantity + 1,
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
        const SnackBar(content: Text("تم إلغاء الحجز بنجاح")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll("Exception: ", "")),
        ),
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
        title: const Text("إلغاء الحجز"),
        content: const Text("هل أنتِ متأكدة من إلغاء هذا الحجز؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("تراجع"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelReservation(
                context: context,
                reservationId: reservationId,
                offerId: offerId,
              );
            },
            child: const Text("إلغاء الحجز"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("طلباتي"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _ordersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("حدث خطأ أثناء تحميل الطلبات"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const _EmptyOrders();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['offerTitle'] ?? "طلب طعام";
              final status = data['status'] ?? "reserved";
              final offerId = data['offerId'] ?? "";
              final reservationId = doc.id;
              final userId = FirebaseAuth.instance.currentUser!.uid;
              final providerRole = data['providerRole'] ?? "";
              final pickupLocation = data['pickupLocation'] ?? "غير محدد";

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.fastfood_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              _statusLabel(status),
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: _statusColor(status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _InfoRow(
                        icon: Icons.confirmation_number_outlined,
                        label: "رقم الحجز",
                        value: reservationId,
                      ),
                      _InfoRow(
                        icon: Icons.storefront_outlined,
                        label: "المزوّد",
                        value: providerRole.isEmpty ? "غير محدد" : providerRole,
                      ),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: "مكان الاستلام",
                        value: pickupLocation,
                      ),
                      const SizedBox(height: 14),
                      if (status == 'reserved') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QrCodeScreen(
                                        reservationId: reservationId,
                                        offerId: offerId,
                                        userId: userId,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.qr_code_rounded),
                                label: const Text("عرض رمز QR"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _confirmCancel(
                                    context: context,
                                    reservationId: reservationId,
                                    offerId: offerId,
                                  );
                                },
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text("إلغاء"),
                              ),
                            ),
                          ],
                        ),
                      ] else if (status == 'picked_up') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            "تم تأكيد استلام هذا الطلب بنجاح",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else if (status == 'cancelled') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            "تم إلغاء هذا الحجز",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            "$label: ",
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
              size: 70,
              color: AppColors.primary.withOpacity(0.45),
            ),
            const SizedBox(height: 16),
            const Text(
              "لا توجد طلبات بعد",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "عند حجز عرض أو باقة، ستظهر تفاصيل الطلب ورمز الاستلام هنا.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
