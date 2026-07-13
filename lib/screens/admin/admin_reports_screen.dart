import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/screens/admin/admin_widgets.dart';
import 'package:zad_app/services/admin_service.dart';
import 'package:zad_app/theme/app_colors.dart';

String _loginStatusLabel(bool success) => success ? 'نجح' : 'فشل';
Color _loginStatusColor(bool success) =>
    success ? AppColors.success : AppColors.danger;
IconData _loginStatusIcon(bool success) =>
    success ? Icons.check_circle_rounded : Icons.cancel_rounded;

String _loginReasonLabel(String? reason) {
  switch (reason) {
    case 'wrong-password':
    case 'invalid-credential':
      return 'كلمة مرور خاطئة';
    case 'user-not-found':
      return 'مستخدم غير موجود';
    case 'email_not_verified':
      return 'البريد غير مُفعَّل';
    case 'pending_approval':
      return 'بانتظار الموافقة';
    case 'rejected':
    case 'rejected_provider':
      return 'حساب مرفوض';
    case 'suspended':
      return 'حساب معلّق';
    case 'inactive':
      return 'حساب غير نشط';
    case 'user_not_found':
      return 'بيانات غير موجودة';
    case null:
      return '';
    default:
      return reason;
  }
}

String _formatLoginTime(Timestamp? ts) {
  if (ts == null) return '—';
  final dt = ts.toDate().toLocal();
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$d/$m — $h:$min';
}

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
                          color: color.withValues(alpha: 0.12),
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

          const SizedBox(height: 28),

          const Text(
            'سجل محاولات تسجيل الدخول',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: adminService.getLoginLogs(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final logs = snap.data!.docs;
              if (logs.isEmpty) {
                return const EmptyState(message: 'لا توجد محاولات دخول مسجّلة');
              }
              return Column(
                children: logs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final success = data['success'] == true;
                  final email = data['email'] as String? ?? '—';
                  final reason = _loginReasonLabel(
                      data['failureReason'] as String?);
                  final timeStr = _formatLoginTime(
                      data['timestamp'] as Timestamp?);
                  final statusColor = _loginStatusColor(success);
                  final statusLabel = _loginStatusLabel(success);
                  final statusIcon = _loginStatusIcon(success);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  statusColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(statusIcon,
                                color: statusColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (reason.isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 2),
                                    child: Text(
                                      reason,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textLight),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textLight),
                              ),
                            ],
                          ),
                        ],
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
