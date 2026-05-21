import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/screens/restaurant/scan_qr_screen.dart';
import 'package:zad_app/theme/app_colors.dart';
import 'package:zad_app/widgets/offer_widgets.dart';
import '../../services/notification_service.dart';

class RestaurantReservationsScreen extends StatelessWidget {
  const RestaurantReservationsScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> _reservationsStream() => FirebaseFirestore.instance
      .collection('reservations')
      .where('providerUserId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .snapshots();

  String _statusLabel(String status) {
    switch (status) {
      case 'reserved':
        return 'بانتظار الاستلام';
      case 'picked_up':
        return 'تم الاستلام';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'reserved':
        return Colors.orange;
      case 'picked_up':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.textLight;
    }
  }

  Future<void> _markPickedUp(BuildContext context, String reservationId,
      String userId, String offerTitle) async {
    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .update({
        'status': 'picked_up',
        'pickedAt': FieldValue.serverTimestamp(),
      });

      await NotificationService().sendNotification(
        userId: userId,
        title: 'تم تأكيد الاستلام ✅',
        message: 'تم استلام طلبك "$offerTitle" بنجاح. نتمنى لك وجبة شهية ❤️',
        type: 'pickup',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد الاستلام ✅'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('الطلبات والحجوزات'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'بانتظار الاستلام'),
              Tab(text: 'المكتملة'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _reservationsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('حدث خطأ أثناء تحميل الطلبات'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final all = snapshot.data!.docs;
            final pending = all
                .where((d) => (d.data() as Map)['status'] == 'reserved')
                .toList();
            final completed = all
                .where((d) => (d.data() as Map)['status'] == 'picked_up')
                .toList();

            return TabBarView(
              children: [
                _ReservationList(
                  docs: pending,
                  emptyMessage: 'لا توجد طلبات بانتظار الاستلام',
                  onConfirm: (doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    _markPickedUp(
                      context,
                      doc.id,
                      data['userId'] ?? '',
                      data['offerTitle'] ?? 'طلب طعام',
                    );
                  },
                  statusColor: _statusColor,
                  statusLabel: _statusLabel,
                ),
                _ReservationList(
                  docs: completed,
                  emptyMessage: 'لا توجد طلبات مكتملة بعد',
                  onConfirm: null,
                  statusColor: _statusColor,
                  statusLabel: _statusLabel,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReservationList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String emptyMessage;
  final void Function(QueryDocumentSnapshot)? onConfirm;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;

  const _ReservationList({
    required this.docs,
    required this.emptyMessage,
    required this.onConfirm,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: AppColors.primary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(emptyMessage,
                style: const TextStyle(color: AppColors.textLight)),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;

        final offerTitle = data['offerTitle'] ?? 'طلب طعام';
        final userName = data['userName'] ?? 'مستخدم';
        final status = data['status'] ?? 'reserved';
        final pickupLocation = data['pickupLocation'] ?? 'غير محدد';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(offerTitle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                  fontSize: 14)),
                          Text(userName,
                              style: const TextStyle(
                                  color: AppColors.textLight, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor(status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel(status),
                        style: TextStyle(
                            color: statusColor(status),
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OfferInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'الاستلام',
                  value: pickupLocation,
                ),
                if (onConfirm != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                title: const Text('تأكيد الاستلام'),
                                content: Text(
                                    'هل تأكد من استلام "$offerTitle" من قبل $userName؟'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('إلغاء'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('تأكيد'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) onConfirm!(doc);
                          },
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('تأكيد يدوياً'),
                          style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ScanQrScreen()),
                        ),
                        icon:
                            const Icon(Icons.qr_code_scanner_rounded, size: 16),
                        label: const Text('مسح QR'),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
