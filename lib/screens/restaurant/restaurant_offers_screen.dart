import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/screens/restaurant/edit_offer_screen.dart';
import 'package:zad_app/screens/restaurant/restaurant_widgets.dart';
import 'package:zad_app/services/notification_service.dart';
import 'package:zad_app/theme/app_colors.dart';
import 'package:zad_app/widgets/offer_widgets.dart';

class RestaurantOffersScreen extends StatelessWidget {
  const RestaurantOffersScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> _myOffersStream() => FirebaseFirestore.instance
      .collection('offers')
      .where('providerUserId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .snapshots();

  Future<void> _confirmDelete(BuildContext context, String offerId) async {
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
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .delete();
      await NotificationService().sendNotification(
        userId: _uid,
        title: 'تم حذف العرض',
        message: 'تم حذف العرض بنجاح',
        type: 'offer',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف العرض')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _toggleStatus(
      BuildContext context, String offerId, String currentStatus) async {
    final newStatus = currentStatus == 'available' ? 'closed' : 'available';
    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .update({
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

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.success;
      case 'closed':
        return AppColors.textLight;
      case 'reserved':
        return Colors.orange;
      case 'picked_up':
        return AppColors.primary;
      default:
        return AppColors.textLight;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'available':
        return 'متاح';
      case 'closed':
        return 'مغلق';
      case 'reserved':
        return 'محجوز';
      case 'picked_up':
        return 'تم الاستلام';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('عروضي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _myOffersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ أثناء تحميل العروض'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final offers = snapshot.data!.docs;

          if (offers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fastfood_outlined,
                      size: 64, color: AppColors.primary.withOpacity(0.3)),
                  const SizedBox(height: 14),
                  const Text('لا توجد عروض بعد',
                      style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('أضف أول باقة فائض الآن',
                      style: TextStyle(color: AppColors.textLight)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final doc = offers[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'باقة طعام';
              final description = data['description'] ?? '';
              final imageUrl = data['imageUrl'] ?? '';
              final quantity = data['quantity'] ?? 0;
              final remainingQuantity = data['remainingQuantity'] ?? 0;
              final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
              final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
              final currency = data['currency'] ?? 'ILS';
              final status = data['status'] ?? 'unknown';
              final pickupLocation = data['pickupLocation'] ?? 'غير محدد';
              final isFree = data['isFree'] == true || discountPrice == 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: status == 'available'
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── صورة ──
                    Stack(
                      children: [
                        imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    buildImagePlaceholder(
                                        icon: Icons.restaurant_menu_rounded,
                                        height: 150),
                              )
                            : buildImagePlaceholder(
                                icon: Icons.restaurant_menu_rounded,
                                height: 150),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditOfferScreen(
                                          offerId: doc.id,
                                          offerData: data,
                                        ),
                                      ),
                                    );
                                  } else if (value == 'toggle') {
                                    _toggleStatus(context, doc.id, status);
                                  } else if (value == 'delete') {
                                    _confirmDelete(context, doc.id);
                                  }
                                },
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_rounded,
                                            color: AppColors.primary, size: 18),
                                        SizedBox(width: 8),
                                        Text('تعديل العرض'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(
                                          status == 'available'
                                              ? Icons.pause_circle_outline
                                              : Icons.play_circle_outline,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(status == 'available'
                                            ? 'إغلاق العرض'
                                            : 'تفعيل العرض'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded,
                                            color: AppColors.danger, size: 18),
                                        SizedBox(width: 8),
                                        Text('حذف العرض',
                                            style: TextStyle(
                                                color: AppColors.danger)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 13,
                                  height: 1.5),
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
                          // شريط تقدم الكمية
                          QuantityBar(
                            remaining: remainingQuantity,
                            total: quantity,
                          ),
                          const SizedBox(height: 10),
                          OfferInfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'مكان الاستلام',
                            value: pickupLocation,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
