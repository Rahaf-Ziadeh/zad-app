import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'charity_notification_service.dart';
import '../../constants/app_constants.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';
import 'charity_publish_surplus_screen.dart';

// ─────────────────────────────────────────────
// شاشة التبرعات — بانتظار المراجعة
// ─────────────────────────────────────────────
class CharityDonationsScreen extends StatefulWidget {
  final int initialTab;

  const CharityDonationsScreen({super.key, this.initialTab = 0});

  @override
  State<CharityDonationsScreen> createState() => _CharityDonationsScreenState();
}

class _CharityDonationsScreenState extends State<CharityDonationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(
    BuildContext context,
    String donationId,
    String newStatus,
    String userId,
    String foodName,
  ) async {
    try {
      final currentCharityId = FirebaseAuth.instance.currentUser?.uid ?? '';

      await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .update({
        'status': newStatus,
        'donationStatus': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': currentCharityId,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'approved') ...{
          'charityUserId': currentCharityId,
          'acceptedAt': FieldValue.serverTimestamp(),
        },
      });

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('التبرعات الواردة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'بانتظار المراجعة'),
            Tab(text: 'مقبولة'),
            Tab(text: 'مرفوضة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── بانتظار المراجعة ──
          _DonationList(
            stream: FirebaseFirestore.instance
                .collection('donations')
                .where('status', isEqualTo: 'pending')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            filterByCharity: true,
            buildActions: (context, doc, data) => Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(
                        context,
                        doc.id,
                        'approved',
                        data['userId'] ?? data['donorUserId'] ?? '',
                        data['foodName'] ?? data['title'] ?? ''),
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
                        data['userId'] ?? data['donorUserId'] ?? '',
                        data['foodName'] ?? data['title'] ?? ''),
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
            filterByCharity: false,
            buildActions: (context, doc, data) => SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublishNewSurplusScreen(
                        prefillDonationId: doc.id,
                        prefillData: data,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.publish_rounded, size: 16),
                label: const Text('نشر التبرع للمستفيدين'),
              ),
            ),
            emptyMessage: 'لا توجد تبرعات مقبولة حالياً',
          ),

          // ── مرفوضة ──
          _DonationList(
            stream: FirebaseFirestore.instance
                .collection('donations')
                .where('status', isEqualTo: 'rejected')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            filterByCharity: false,
            buildActions: (context, doc, data) => const SizedBox.shrink(),
            emptyMessage: 'لا توجد تبرعات مرفوضة',
          ),
        ],
      ),
    );
  }
}

class _DonationList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final Widget Function(
      BuildContext, QueryDocumentSnapshot, Map<String, dynamic>) buildActions;
  final bool filterByCharity;
  final String emptyMessage;

  const _DonationList({
    required this.stream,
    required this.buildActions,
    required this.filterByCharity,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final currentCharityId = FirebaseAuth.instance.currentUser?.uid ?? '';

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

        final allDocs = snapshot.data!.docs;

        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final targetCharityId = data['targetCharityId']?.toString() ?? '';

          final charityId = data['charityId']?.toString() ?? '';

          final charityUserId = data['charityUserId']?.toString() ?? '';

          final reviewedBy = data['reviewedBy']?.toString() ?? '';

          return targetCharityId == currentCharityId ||
              charityId == currentCharityId ||
              charityUserId == currentCharityId ||
              reviewedBy == currentCharityId;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism_outlined,
                    size: 56, color: AppColors.primary.withValues(alpha: 0.3)),
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
            final foodName = data['foodName'] ?? data['title'] ?? 'تبرع طعام';
            final quantity = data['quantity'] ?? 'غير محدد';
            final category = data['category'] ?? 'غير مصنف';
            final location =
                data['pickupLocation'] ?? data['location'] ?? 'غير محدد';
            final notes = data['notes'] ?? '';
            final donorName = data['donorName'] ?? data['userName'] ?? '';
            final imageUrl = data['imageUrl'] as String? ?? '';
            final pickupTime = data['pickupTime'] as String? ?? '';
            final startTime = data['pickupStartTime'] as String? ?? '';
            final endTime = data['pickupEndTime'] as String? ?? '';
            final displayPickup = pickupTime.isNotEmpty
                ? pickupTime
                : (startTime.isNotEmpty && endTime.isNotEmpty
                    ? '$startTime - $endTime'
                    : '');
            final allergens =
                AppConstants.parseAllergyInfo(data['allergyInfo']);
            final hasKnownAllergens = allergens.isNotEmpty &&
                !(allergens.length == 1 &&
                    allergens.first == AppConstants.noKnownAllergens);

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── صورة التبرع ──
                  if (imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── رأس البطاقة ──
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                  Icons.volunteer_activism_rounded,
                                  color: Color(0xFFE11D48),
                                  size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    foodName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  if (donorName.isNotEmpty)
                                    Text(
                                      'المتبرع: $donorName',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textLight),
                                    ),
                                ],
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
                            value: quantity.toString()),
                        OfferInfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'الموقع',
                            value: location),
                        if (displayPickup.isNotEmpty)
                          OfferInfoRow(
                              icon: Icons.access_time_rounded,
                              label: 'وقت الاستلام',
                              value: displayPickup),
                        if (notes.toString().isNotEmpty)
                          OfferInfoRow(
                              icon: Icons.notes_outlined,
                              label: 'ملاحظات',
                              value: notes.toString()),
                        if (hasKnownAllergens)
                          OfferInfoRow(
                              icon: Icons.warning_amber_rounded,
                              label: 'مسببات الحساسية',
                              value: allergens.join('، ')),

                        const SizedBox(height: 14),
                        buildActions(context, doc, data),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
