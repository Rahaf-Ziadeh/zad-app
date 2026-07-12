import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/reservation_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────
// نقطة الدخول المشتركة بين شاشة مسح QR والتأكيد اليدوي (Part 7/8): تعرض
// صحيفة معاينة كاملة قبل تأكيد الاستلام فعلياً، ولا تكتب أي شيء في
// Firestore إلا بعد ضغط المطعم على "تأكيد الاستلام" — والتحقق الملزم
// النهائي (الملكية، الحالة، الدفع) يبقى داخل ReservationService.confirmPickup
// ولا يمكن لهذه الشاشة تجاوزه مهما عُرِض هنا.
//
// تُعيد true فقط إذا تم تأكيد الاستلام فعلياً بنجاح.
// ─────────────────────────────────────────────
Future<bool> showPickupConfirmationSheet(
  BuildContext context, {
  required String reservationId,
  required Map<String, dynamic> data,
  required String confirmationMethod, // 'qr' | 'manual'
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (_) => _PickupConfirmationSheet(
      reservationId: reservationId,
      data: data,
      confirmationMethod: confirmationMethod,
    ),
  );
  return result ?? false;
}

// ── فحص تفاؤلي (لتجربة المستخدم فقط) قبل حتى فتح صحيفة المعاينة؛ يُعيد
// رسالة الخطأ العربية المناسبة إن كان الحجز غير صالح للتأكيد، أو null إن
// بدا صالحاً. لا يُعتَمد عليه كتحقق نهائي — ReservationService.confirmPickup
// يعيد كل هذا التحقق داخل معاملة Firestore ملزمة ──
String? validateReservationForPickupPreview(
  Map<String, dynamic>? data,
  String currentProviderUid,
) {
  if (data == null) return 'رمز QR غير صالح أو أن الحجز غير موجود.';
  final providerUserId = (data['providerUserId'] as String?) ?? '';
  if (providerUserId != currentProviderUid) {
    return 'هذا الحجز لا يتبع مطعمك.';
  }
  final status = (data['status'] as String?) ?? '';
  if (status == 'picked_up') {
    return 'تم استخدام رمز QR لهذا الطلب مسبقًا وتم تأكيد الاستلام.';
  }
  if (status == 'cancelled') {
    return 'هذا الطلب ملغي ولا يمكن تأكيد استلامه.';
  }
  if (status != 'reserved') {
    return 'لا يمكن تأكيد الاستلام لحالة هذا الحجز الحالية.';
  }
  return null;
}

String _methodLabel(String? method) {
  switch (method) {
    case 'cash':
      return 'كاش عند الاستلام';
    case 'online':
      return 'دفع إلكتروني';
    default:
      return 'مجاني';
  }
}

String _paymentStatusLabel(String? status) {
  switch (status) {
    case 'pending_cash':
      return 'كاش عند الاستلام — لم يُحصَّل بعد';
    case 'pending_online':
      return 'دفع إلكتروني — قيد الانتظار';
    case 'paid':
      return 'مدفوع';
    case ReservationService.paymentStatusRefunded:
      return 'مسترد';
    default:
      return 'مجاني';
  }
}

String _reservationStatusLabel(String status) {
  switch (status) {
    case 'reserved':
      return 'بانتظار الاستلام';
    case 'picked_up':
      return 'تم الاستلام';
    case 'cancelled':
      return 'ملغي';
    default:
      return status;
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
  return '$d/$m/$y  $h:$min';
}

// ── يُحلّل "HH:mm" إلى TimeOfDay اليوم؛ يُعيد null إن كانت الصيغة غير صالحة ──
DateTime? _todayAt(String? hhmm) {
  if (hhmm == null || !hhmm.contains(':')) return null;
  final parts = hhmm.split(':');
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts.length > 1 ? parts[1] : '');
  if (h == null || m == null) return null;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, h, m);
}

class _PickupConfirmationSheet extends StatefulWidget {
  final String reservationId;
  final Map<String, dynamic> data;
  final String confirmationMethod;

  const _PickupConfirmationSheet({
    required this.reservationId,
    required this.data,
    required this.confirmationMethod,
  });

  @override
  State<_PickupConfirmationSheet> createState() =>
      _PickupConfirmationSheetState();
}

class _PickupConfirmationSheetState extends State<_PickupConfirmationSheet> {
  bool _cashCollected = false;
  bool _confirming = false;

  Map<String, dynamic> get _d => widget.data;

  String get _userName => (_d['userName'] as String? ?? 'مستخدم').trim();
  String get _offerTitle => (_d['offerTitle'] as String? ?? 'طلب طعام').trim();
  int get _quantity {
    final raw = _d['quantity'];
    return raw is num ? raw.toInt() : 1;
  }

  String get _reservationCode {
    final code = (_d['reservationCode'] as String? ?? '').trim();
    if (code.isNotEmpty) return code;
    return widget.reservationId;
  }

  String get _pickupLocation =>
      (_d['pickupLocation'] as String? ?? 'غير محدد').trim();
  String get _pickupTime => (_d['pickupTime'] as String? ?? '').trim();
  String? get _paymentMethod => _d['paymentMethod'] as String?;
  String? get _paymentStatus => _d['paymentStatus'] as String?;
  String get _status => (_d['status'] as String? ?? 'reserved');
  Timestamp? get _createdAt =>
      _d['createdAt'] is Timestamp ? _d['createdAt'] as Timestamp : null;
  List<String> get _allergyInfo {
    final raw = _d['allergyInfo'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  String get _notes => (_d['notes'] as String? ?? _d['orderNotes'] as String? ?? '').trim();

  num get _unitPrice {
    final raw = _d['price'];
    return raw is num ? raw : 0;
  }

  num get _totalAmount {
    final raw = _d['totalAmount'];
    if (raw is num) return raw;
    return _unitPrice * _quantity;
  }

  String get _currency => (_d['currency'] as String? ?? 'ILS');

  bool get _isFree => _paymentMethod == null || _paymentMethod!.isEmpty || _unitPrice == 0;
  bool get _isCash => _paymentMethod == 'cash';
  bool get _isOnline => _paymentMethod == 'online';
  bool get _onlinePaid => _paymentStatus == 'paid';

  // ── الشرط الوحيد الذي يُفعّل زر "تأكيد الاستلام" ──
  bool get _canAttemptConfirm {
    if (_isOnline && !_onlinePaid) return false;
    if (_isCash && !_cashCollected) return false;
    return true;
  }

  Future<bool> _checkPickupTiming() async {
    final start = _todayAt(_d['pickupStartTime'] as String?);
    final end = _todayAt(_d['pickupEndTime'] as String?);
    final now = DateTime.now();

    if (start != null && now.isBefore(start)) {
      return await _showTimingWarning(
              'وقت الاستلام لم يبدأ بعد. هل تريد المتابعة؟') ??
          false;
    }
    if (end != null && now.isAfter(end)) {
      return await _showTimingWarning(
              'انتهى وقت الاستلام المحدد لهذا الطلب. هل تريد تأكيد الاستلام '
              'رغم ذلك؟') ??
          false;
    }
    return true;
  }

  Future<bool?> _showTimingWarning(String message) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.access_time_filled_rounded,
                color: Colors.orange, size: 22),
            SizedBox(width: 8),
            Text('تنبيه وقت الاستلام'),
          ],
        ),
        content: Text(message, style: const TextStyle(height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    if (_confirming || !_canAttemptConfirm) return;

    final timingOk = await _checkPickupTiming();
    if (!mounted || !timingOk) return;

    setState(() => _confirming = true);
    try {
      await ReservationService().confirmPickup(
        reservationId: widget.reservationId,
        confirmationMethod: widget.confirmationMethod,
        paymentCollectedConfirmed: _isCash && _cashCollected,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تأكيد الاستلام لـ "$_offerTitle" بنجاح ✅'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long_rounded,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('مراجعة الطلب قبل تأكيد الاستلام',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    _Field(icon: Icons.person_outline_rounded, label: 'العميل', value: _userName),
                    _Field(icon: Icons.fastfood_rounded, label: 'العرض', value: _offerTitle),
                    _Field(
                        icon: Icons.production_quantity_limits_rounded,
                        label: 'الكمية المحجوزة',
                        value: '$_quantity'),
                    _Field(
                        icon: Icons.confirmation_number_outlined,
                        label: 'رقم الحجز',
                        value: _reservationCode),
                    if (_pickupLocation.isNotEmpty)
                      _Field(
                          icon: Icons.location_on_outlined,
                          label: 'مكان الاستلام',
                          value: _pickupLocation),
                    if (_pickupTime.isNotEmpty)
                      _Field(
                          icon: Icons.access_time_outlined,
                          label: 'وقت الاستلام',
                          value: _pickupTime),
                    _Field(
                        icon: Icons.info_outline_rounded,
                        label: 'حالة الحجز',
                        value: _reservationStatusLabel(_status)),
                    _Field(
                        icon: Icons.calendar_today_outlined,
                        label: 'تاريخ إنشاء الحجز',
                        value: _formatDateTime(_createdAt)),
                    if (_allergyInfo.isNotEmpty)
                      _Field(
                          icon: Icons.warning_amber_rounded,
                          label: 'مسببات الحساسية',
                          value: _allergyInfo.join('، ')),
                    if (_notes.isNotEmpty)
                      _Field(
                          icon: Icons.sticky_note_2_outlined,
                          label: 'ملاحظات الطلب',
                          value: _notes),

                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),

                    // ── القسم المالي ──
                    const Text('تفاصيل المبلغ',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    if (_isFree)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.volunteer_activism_rounded,
                                color: AppColors.success, size: 18),
                            SizedBox(width: 8),
                            Text('مجاني',
                                style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else ...[
                      _Field(
                          icon: Icons.sell_outlined,
                          label: 'سعر الوحدة',
                          value: '$_unitPrice $_currency'),
                      _Field(
                          icon: Icons.payments_rounded,
                          label: 'المبلغ الإجمالي',
                          value: '$_totalAmount $_currency'),
                      _Field(
                          icon: Icons.credit_card_rounded,
                          label: 'طريقة الدفع',
                          value: _methodLabel(_paymentMethod)),
                      _Field(
                          icon: Icons.fact_check_outlined,
                          label: 'حالة الدفع',
                          value: _paymentStatusLabel(_paymentStatus)),
                    ],

                    if (_isCash) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.payments_outlined,
                                color: Colors.orange, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'الدفع نقدًا عند الاستلام — تأكد من استلام '
                                'مبلغ $_totalAmount $_currency قبل تأكيد الاستلام.',
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            setState(() => _cashCollected = !_cashCollected),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _cashCollected,
                              onChanged: (v) =>
                                  setState(() => _cashCollected = v ?? false),
                              activeColor: AppColors.primary,
                            ),
                            const Expanded(
                              child: Text('أؤكد استلام المبلغ نقداً',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_isOnline && !_onlinePaid) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _paymentStatus == 'pending_online'
                                    ? 'الدفع الإلكتروني لم يكتمل بعد، لا يمكن '
                                        'تأكيد الاستلام.'
                                    : 'حالة الدفع الإلكتروني لهذا الطلب غير '
                                        'مكتملة، لا يمكن تأكيد الاستلام.',
                                style: const TextStyle(
                                    color: AppColors.danger, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _confirming
                                ? null
                                : () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (_confirming || !_canAttemptConfirm)
                                ? null
                                : _confirm,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _confirming
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('تأكيد الاستلام',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Field({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.textDark)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textLight, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
