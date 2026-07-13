import 'package:flutter/material.dart';
import 'package:zad_app/screens/charity/charity_publish_new_surplus_screen.dart';

import '../../services/charity_data_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/charity_widgets.dart';

class CharityDonationsScreen extends StatefulWidget {
  final int initialTab;

  const CharityDonationsScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<CharityDonationsScreen> createState() => _CharityDonationsScreenState();
}

class _CharityDonationsScreenState extends State<CharityDonationsScreen>
    with SingleTickerProviderStateMixin {
  final CharityDataService _dataService = CharityDataService();

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
      await _dataService.updateDonationStatus(
        donationId: donationId,
        newStatus: newStatus,
        userId: userId,
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
                    : 'تم تحديث حالة التبرع',
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

  Future<void> _confirmReceipt(
    BuildContext context,
    String donationId,
    String donorUserId,
    String foodName,
  ) async {
    try {
      await _dataService.confirmDonationReceipt(
        donationId: donationId,
        donorUserId: donorUserId,
        foodName: foodName,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد استلام التبرع ✅'),
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
          DonationList(
            stream: _dataService.watchPendingDonations(),
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
                      data['foodName'] ?? data['title'] ?? '',
                    ),
                    icon: const Icon(
                      Icons.check_rounded,
                      size: 16,
                    ),
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
                      data['foodName'] ?? data['title'] ?? '',
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                    ),
                    label: const Text('رفض'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            emptyMessage: 'لا توجد تبرعات بانتظار المراجعة 🎉',
          ),

          DonationList(
            stream: _dataService.watchAcceptedDonations(),
            filterByCharity: false,
            buildActions: (context, doc, data) {
              final status = data['status'] as String? ?? 'approved';
              final donorUserId = (data['userId'] as String? ??
                      data['donorUserId'] as String? ??
                      '')
                  .trim();
              final foodName = data['foodName'] as String? ??
                  data['title'] as String? ??
                  'التبرع';

              // approved → show "confirm receipt" button.
              if (status == 'approved') {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmReceipt(
                      context,
                      doc.id,
                      donorUserId,
                      foodName,
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 16),
                    label: const Text('تأكيد استلام التبرع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                );
              }

              // received → show "publish to beneficiaries" button.
              if (status == 'received') {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublishNewSurplusScreen(
                          prefillDonationId: doc.id,
                          prefillData: data,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.publish_rounded, size: 16),
                    label: const Text('نشر التبرع للمستفيدين'),
                  ),
                );
              }

              // redistributed / published → read-only state indicator.
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: AppColors.primary, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'تمت إعادة التوزيع ✅',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
              );
            },
            emptyMessage: 'لا توجد تبرعات مقبولة حالياً',
          ),

          DonationList(
            stream: _dataService.watchRejectedDonations(),
            filterByCharity: false,
            buildActions: (context, doc, data) => const SizedBox.shrink(),
            emptyMessage: 'لا توجد تبرعات مرفوضة',
          ),
        ],
      ),
    );
  }
}
