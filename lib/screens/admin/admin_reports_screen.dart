import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/screens/admin/admin_widgets.dart';
import 'package:zad_app/services/admin_service.dart';
import 'package:zad_app/theme/app_colors.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  String _actionLabel(String action) {
    switch (action) {
      case 'approve_account':
        return 'موافقة على حساب';
      case 'reject_account':
        return 'رفض حساب';
      case 'suspend_user':
        return 'تعليق مستخدم';
      case 'unsuspend_user':
        return 'إعادة تفعيل مستخدم';
      default:
        return action;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'approve_account':
        return Icons.check_circle_rounded;
      case 'reject_account':
        return Icons.cancel_rounded;
      case 'suspend_user':
        return Icons.pause_circle_rounded;
      case 'unsuspend_user':
        return Icons.play_circle_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'approve_account':
      case 'unsuspend_user':
        return AppColors.success;
      case 'reject_account':
      case 'suspend_user':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('التقارير والسجلات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // ── إحصائيات سريعة ──
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: adminService.getRedistributedDonations(),
                  builder: (_, snap) => MiniStatCard(
                    title: 'تبرعات موزّعة',
                    value: snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.volunteer_activism_rounded,
                    color: const Color(0xFFE11D48),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: adminService.getPickedUpMeals(),
                  builder: (_, snap) => MiniStatCard(
                    title: 'وجبات وُزّعت',
                    value: snap.hasData ? '${snap.data!.docs.length}' : '...',
                    icon: Icons.fastfood_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text('آخر إجراءات الإدارة',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: adminService.getAdminLogs(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final logs = snap.data!.docs;
              if (logs.isEmpty) {
                return const EmptyState(message: 'لا توجد سجلات حالياً');
              }
              return Column(
                children: logs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final action = data['action'] ?? '';
                  final color = _actionColor(action);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(_actionIcon(action), color: color, size: 20),
                      ),
                      title: Text(
                        _actionLabel(action),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        data['reason'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        data['targetType'] ?? '',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textLight),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
