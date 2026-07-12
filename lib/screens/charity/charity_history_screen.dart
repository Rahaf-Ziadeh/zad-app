import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/charity_data_service.dart';
import '../../services/charity_helper_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────
// سجل التبرعات
// ─────────────────────────────────────────────
class CharityHistoryScreen extends StatelessWidget {
  CharityHistoryScreen({super.key});

  final CharityDataService _dataService = CharityDataService();

  final CharityHelperService _helperService = const CharityHelperService();

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'received':
        return AppColors.primary;
      case 'rejected':
        return AppColors.danger;
      case 'redistributed':
        return Colors.orange;
      case 'published':
        return Colors.teal;
      default:
        return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('سجل التبرعات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dataService.watchDonationHistory(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('حدث خطأ أثناء تحميل السجل'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final history = _dataService.filterDonationHistoryForCurrentCharity(
            snapshot.data!.docs,
          );

          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 56,
                    color: AppColors.primary.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'لا يوجد سجل حتى الآن',
                    style: TextStyle(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final data = history[index].data() as Map<String, dynamic>;

              final foodName = data['foodName'] ?? data['title'] ?? 'تبرع طعام';

              final quantity = data['quantity'] ?? '—';

              final status = data['status']?.toString() ?? '';

              final color = _statusColor(status);

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: color.withValues(
                      alpha: 0.25,
                    ),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(
                        alpha: 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: color,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    foodName.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'الكمية: $quantity',
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _helperService.donationStatusLabel(status),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
