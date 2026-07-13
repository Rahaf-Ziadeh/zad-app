import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../admin/admin_complaint_details_screen.dart'
    show ComplaintSectionCard, ComplaintInfoRow;

// Complaints filed against this restaurant — read-only, no resolve/delete/edit;
// admin decisions stay with admins. Filters on reportedUserId (the field that
// _ReportProviderDialog in provider_public_profile_screen.dart writes when a user
// reports a restaurant from its public profile).
class RestaurantComplaintsHistoryScreen extends StatelessWidget {
  const RestaurantComplaintsHistoryScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('سجل الشكاوى'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // Single equality filter (no orderBy) — avoids a composite index we don't have.
      // Newest-first sorting is client-side; docs without a valid createdAt go last.
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .where('reportedUserId', isEqualTo: _uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('[RestaurantComplaints] error=${snap.error}');
            return const Center(child: Text('حدث خطأ أثناء تحميل الشكاوى'));
          }
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final ta = (a.data() as Map<String, dynamic>)['createdAt'];
              final tb = (b.data() as Map<String, dynamic>)['createdAt'];
              if (ta is! Timestamp && tb is! Timestamp) return 0;
              if (ta is! Timestamp) return 1;
              if (tb is! Timestamp) return -1;
              return tb.compareTo(ta);
            });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.report_off_outlined,
                      size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 14),
                  const Text('لا توجد شكاوى بخصوص مطعمك',
                      style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
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
              final isOpen = (data['status'] as String? ?? 'open') == 'open';
              final type = (data['type'] as String? ?? 'شكوى').trim();
              final desc = (data['description'] as String? ?? '').trim();
              final complainantName =
                  (data['userName'] as String? ?? '').trim();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          _RestaurantComplaintDetailsScreen(data: data),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                        (isOpen ? AppColors.danger : AppColors.success)
                            .withValues(alpha: 0.12),
                    child: Icon(
                      isOpen
                          ? Icons.report_problem_outlined
                          : Icons.check_circle_outline_rounded,
                      color: isOpen ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  title: Text(type,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    complainantName.isNotEmpty
                        ? 'من: $complainantName'
                        : (desc.isNotEmpty ? desc : '—'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isOpen ? AppColors.danger : AppColors.success)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOpen ? 'مفتوحة' : 'تم الحل',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOpen ? AppColors.danger : AppColors.success,
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

// Detail view for one complaint — read-only, no actions (no resolve/reopen/delete;
// admin decisions stay with admins exclusively).
class _RestaurantComplaintDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RestaurantComplaintDetailsScreen({required this.data});

  String _formatDateTime(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'م' : 'ص';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} - '
        '${hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = (data['status'] as String? ?? 'open') == 'open';
    final desc = (data['description'] as String? ?? '').trim();
    final type = (data['type'] as String? ?? '—').trim();
    final complainantName = (data['userName'] as String? ?? '').trim();
    final relatedOfferId = (data['relatedOfferId'] as String? ?? '').trim();
    final relatedReservationId =
        (data['relatedReservationId'] as String? ?? '').trim();
    final resolutionNote = (data['resolutionNote'] as String? ?? '').trim();
    final resolvedAt = data['resolvedAt'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تفاصيل الشكوى')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ComplaintSectionCard(
              title: 'معلومات الشكوى',
              icon: Icons.report_outlined,
              children: [
                ComplaintInfoRow(
                  label: 'الحالة',
                  value: isOpen ? 'مفتوحة' : 'تم الحل',
                  valueColor: isOpen ? AppColors.danger : AppColors.success,
                ),
                ComplaintInfoRow(label: 'نوع الشكوى', value: type),
                if (complainantName.isNotEmpty)
                  ComplaintInfoRow(label: 'مقدّم الشكوى', value: complainantName),
                if (desc.isNotEmpty)
                  ComplaintInfoRow(
                      label: 'نص الشكوى', value: desc, multiline: true),
                if (relatedOfferId.isNotEmpty)
                  ComplaintInfoRow(label: 'العرض المرتبط', value: relatedOfferId),
                if (relatedReservationId.isNotEmpty)
                  ComplaintInfoRow(
                      label: 'الحجز المرتبط', value: relatedReservationId),
                ComplaintInfoRow(
                  label: 'تاريخ الإرسال',
                  value: _formatDateTime(data['createdAt']),
                ),
                if (resolvedAt != null)
                  ComplaintInfoRow(
                      label: 'تاريخ الحل', value: _formatDateTime(resolvedAt)),
                if (resolutionNote.isNotEmpty)
                  ComplaintInfoRow(
                    label: 'ملاحظة الحل',
                    value: resolutionNote,
                    multiline: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
