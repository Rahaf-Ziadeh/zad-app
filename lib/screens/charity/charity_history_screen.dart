import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────
// سجل التبرعات
// ─────────────────────────────────────────────
class CharityHistoryScreen extends StatelessWidget {
  const CharityHistoryScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      case 'redistributed':
        return AppColors.primary;
      default:
        return AppColors.textLight;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'redistributed':
        return 'تم توزيعه';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCharityId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('سجل التبرعات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('donations').where(
          'status',
          whereIn: ['approved', 'rejected', 'redistributed'],
        ).snapshots(),
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

          final history = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final charityUserId = data['charityUserId']?.toString() ?? '';

            final reviewedBy = data['reviewedBy']?.toString() ?? '';

            final charityId = data['charityId']?.toString() ?? '';

            final targetCharityId = data['targetCharityId']?.toString() ?? '';

            return charityUserId == currentCharityId ||
                reviewedBy == currentCharityId ||
                charityId == currentCharityId ||
                targetCharityId == currentCharityId;
          }).toList()
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;

              final aTime = aData['createdAt'];
              final bTime = bData['createdAt'];

              final aMs = aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;

              final bMs = bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;

              return bMs.compareTo(aMs);
            });

          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 56,
                    color: AppColors.primary.withValues(alpha: 0.3),
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
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: color.withValues(alpha: 0.25),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
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
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
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
