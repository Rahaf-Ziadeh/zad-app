import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';

/// Tries to open the content linked to a notification. Handles "no longer exists"
/// gracefully (friendly SnackBar instead of crashing) and returns true only when
/// an actual screen was pushed. Wired to the "Open related content" button here.
typedef NotificationOpenHandler = Future<bool> Function(
  BuildContext context,
  Map<String, dynamic> data,
);

IconData _iconByType(String type) {
  switch (type) {
    case 'reservation':
      return Icons.shopping_bag_rounded;
    case 'pickup':
      return Icons.qr_code_rounded;
    case 'donation':
      return Icons.volunteer_activism_rounded;
    case 'account':
    case 'identity_verification_request':
    case 'identity_verification_resubmitted':
      return Icons.verified_user_rounded;
    case 'identity_additional_info_required':
      return Icons.info_outline_rounded;
    case 'complaint':
    case 'new_complaint':
    case 'report':
      return Icons.report_problem_rounded;
    case 'offer':
      return Icons.fastfood_rounded;
    case 'support':
      return Icons.support_agent_rounded;
    case 'provider':
      return Icons.storefront_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

Color _colorByType(String type) {
  switch (type) {
    case 'reservation':
      return AppColors.primary;
    case 'pickup':
      return const Color(0xFF7C3AED);
    case 'donation':
      return const Color(0xFFE11D48);
    case 'account':
    case 'identity_verification_request':
    case 'identity_verification_resubmitted':
      return AppColors.secondary;
    case 'identity_additional_info_required':
      return Colors.amber;
    case 'complaint':
    case 'new_complaint':
    case 'report':
      return AppColors.danger;
    case 'offer':
      return AppColors.primary;
    case 'support':
      return const Color(0xFF0EA5E9);
    default:
      return AppColors.textLight;
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'reservation':
      return 'حجز';
    case 'pickup':
      return 'استلام';
    case 'donation':
      return 'تبرع';
    case 'account':
      return 'الحساب';
    case 'identity_verification_request':
      return 'توثيق هوية';
    case 'identity_additional_info_required':
      return 'معلومات إضافية';
    case 'identity_verification_resubmitted':
      return 'إعادة توثيق';
    case 'complaint':
    case 'new_complaint':
      return 'شكوى';
    case 'report':
      return 'بلاغ';
    case 'offer':
      return 'عرض';
    case 'support':
      return 'الدعم الفني';
    case 'provider':
      return 'مزوّد';
    default:
      return 'عام';
  }
}

String _formatDateTime(Timestamp? ts) {
  if (ts == null) return '—';
  final dt = ts.toDate().toLocal();
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year;
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$d/$m/$y — $h:$min';
}

// Shows a notification's title, full body, date, and read state, with a button that
// opens the related content via a role-specific resolver (restaurant/charity/admin/user).
class NotificationDetailsScreen extends StatefulWidget {
  final String notificationId;
  final Map<String, dynamic> data;
  final NotificationOpenHandler onOpenRelated;

  const NotificationDetailsScreen({
    super.key,
    required this.notificationId,
    required this.data,
    required this.onOpenRelated,
  });

  @override
  State<NotificationDetailsScreen> createState() =>
      _NotificationDetailsScreenState();
}

class _NotificationDetailsScreenState extends State<NotificationDetailsScreen> {
  bool _opening = false;
  late bool _isRead;

  @override
  void initState() {
    super.initState();
    _isRead = widget.data['isRead'] == true;
    if (!_isRead) {
      // Mark as read immediately on open; failure is non-critical.
      NotificationService().markAsRead(widget.notificationId).catchError((_) {});
      _isRead = true;
    }
  }

  Future<void> _openRelated() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.onOpenRelated(context, widget.data);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final type = (data['type'] as String? ?? 'general');
    final title = (data['title'] as String? ?? 'إشعار');
    final message = (data['message'] as String? ?? '');
    final createdAt = data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;
    final relatedId = (data['relatedId'] as String? ?? '').trim();
    final color = _colorByType(type);
    final hasRelated = relatedId.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تفاصيل الإشعار'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconByType(type), color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_typeLabel(type),
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.isEmpty ? 'لا يوجد نص إضافي' : message,
                    style: const TextStyle(
                        color: AppColors.textDark, fontSize: 14, height: 1.7)),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'تاريخ الإشعار',
                    value: _formatDateTime(createdAt)),
                _InfoRow(
                  icon: Icons.mark_email_read_outlined,
                  label: 'حالة القراءة',
                  value: 'مقروء',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (hasRelated)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _opening ? null : _openRelated,
                icon: _opening
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.open_in_new_rounded),
                label: Text(_opening ? 'جاري الفتح...' : 'فتح المحتوى المرتبط'),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.textLight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'لا يوجد محتوى مرتبط بهذا الإشعار لعرضه.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textLight)),
          ),
        ],
      ),
    );
  }
}
