import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/screens/admin/admin_widgets.dart';
import 'package:zad_app/services/admin_service.dart';
import 'package:zad_app/theme/app_colors.dart';

class AdminComplaintsScreen extends StatelessWidget {
  const AdminComplaintsScreen({super.key});
  static final AdminService _adminService = AdminService();

  Future<void> _resolveComplaint(
      BuildContext context, String complaintId) async {
    await _adminService.resolveComplaint(complaintId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حل الشكوى ✅'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.danger;
      case 'resolved':
        return AppColors.success;
      default:
        return AppColors.textLight;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'مفتوحة';
      case 'resolved':
        return 'تم الحل';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('الشكاوى والبلاغات'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'مفتوحة'),
              Tab(text: 'تم الحل'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ComplaintsList(
              stream: _adminService.getOpenComplaints(),
              onResolve: _resolveComplaint,
              statusColor: _statusColor,
              statusLabel: _statusLabel,
              showResolveButton: true,
            ),
            _ComplaintsList(
              stream: _adminService.getResolvedComplaints(),
              onResolve: null,
              statusColor: _statusColor,
              statusLabel: _statusLabel,
              showResolveButton: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintsList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final Future<void> Function(BuildContext, String)? onResolve;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final bool showResolveButton;

  const _ComplaintsList({
    required this.stream,
    required this.onResolve,
    required this.statusColor,
    required this.statusLabel,
    required this.showResolveButton,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return EmptyState(
            message: showResolveButton
                ? 'لا توجد شكاوى مفتوحة 🎉'
                : 'لا توجد شكاوى محلولة',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'open';
            final description = data['description'] ?? 'لا يوجد وصف';
            final relatedOffer = data['relatedOfferId'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: statusColor(status).withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.report_rounded,
                              color: AppColors.danger, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('شكوى مستخدم',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              if (relatedOffer.isNotEmpty)
                                Text('رقم العرض: $relatedOffer',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textLight)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
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
                    Text(
                      description,
                      style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                          height: 1.5),
                    ),
                    if (showResolveButton && onResolve != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => onResolve!(context, doc.id),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('تمييز كمحلول'),
                          style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10)),
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
    );
  }
}
