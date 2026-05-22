import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'charity_notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';
// ─────────────────────────────────────────────
// شاشة التبرعات — بانتظار المراجعة
// ─────────────────────────────────────────────
class CharityDonationsScreen extends StatelessWidget {
  const CharityDonationsScreen({super.key});

 Future<void> _updateStatus(
  BuildContext context,
  String donationId,
  String newStatus,
  String userId,
  String foodName,
) async {
  try {
    final currentCharityId = FirebaseAuth.instance.currentUser?.uid ?? '';

    final updateData = {
      'status': newStatus,
      'donationStatus': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == 'approved') {
      updateData['charityUserId'] = currentCharityId;
      updateData['acceptedAt'] = FieldValue.serverTimestamp();
    }

    await FirebaseFirestore.instance
        .collection('donations')
        .doc(donationId)
        .update(updateData);

    await CharityNotificationService().sendDonationStatusNotification(
      userId: userId,
      status: newStatus,
      foodName: foodName,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == 'approved'
              ? 'تم قبول التبرع ✅'
              : newStatus == 'rejected'
                  ? 'تم رفض التبرع'
                  : 'تم تأكيد التوزيع ❤️',
        ),
        backgroundColor:
            newStatus == 'rejected' ? AppColors.danger : AppColors.success,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خطأ: $e')),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('التبرعات الواردة'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'بانتظار المراجعة'),
              Tab(text: 'مقبولة'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── بانتظار المراجعة ──
            _DonationList(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('status', isEqualTo: 'pending')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              buildActions: (context, doc, data) => Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(
                          context,
                          doc.id,
                          'approved',
                          data['userId'] ?? '',
                          data['foodName'] ?? ''),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('قبول'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateStatus(
                          context,
                          doc.id,
                          'rejected',
                          data['userId'] ?? '',
                          data['foodName'] ?? ''),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('رفض'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                    ),
                  ),
                ],
              ),
              emptyMessage: 'لا توجد تبرعات بانتظار المراجعة 🎉',
            ),

            // ── مقبولة — بانتظار التوزيع ──
            _DonationList(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('status', isEqualTo: 'approved')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              buildActions: (context, doc, data) => SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(
                      context,
                      doc.id,
                      'redistributed',
                      data['userId'] ?? '',
                      data['foodName'] ?? ''),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('تأكيد إعادة التوزيع'),
                ),
              ),
              emptyMessage: 'لا توجد تبرعات مقبولة حالياً',
            ),
          ],
        ),
      ),
    );
  }
}

class _DonationList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final Widget Function(
      BuildContext, QueryDocumentSnapshot, Map<String, dynamic>) buildActions;
  final String emptyMessage;

  const _DonationList({
    required this.stream,
    required this.buildActions,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
       if (snapshot.hasError) {
  debugPrint('DONATIONS ERROR: ${snapshot.error}');
  return Center(
    child: Text('حدث خطأ أثناء تحميل التبرعات\n${snapshot.error}'),
  );
}
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism_outlined,
                    size: 56, color: AppColors.primary.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text(emptyMessage,
                    style: const TextStyle(color: AppColors.textLight)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final foodName = data['foodName'] ?? 'تبرع طعام';
            final quantity = data['quantity'] ?? 'غير محدد';
            final category = data['category'] ?? 'غير مصنف';
            final location = data['location'] ?? 'غير محدد';
            final notes = data['notes'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.volunteer_activism_rounded,
                              color: Color(0xFFE11D48), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            foodName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OfferInfoRow(
                        icon: Icons.category_outlined,
                        label: 'الفئة',
                        value: category),
                    OfferInfoRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'الكمية',
                        value: quantity),
                    OfferInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'الموقع',
                        value: location),
                    if (notes.toString().isNotEmpty)
                      OfferInfoRow(
                          icon: Icons.notes_outlined,
                          label: 'ملاحظات',
                          value: notes),
                    const SizedBox(height: 14),
                    buildActions(context, doc, data),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}