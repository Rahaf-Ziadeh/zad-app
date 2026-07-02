import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/screens/restaurant/restaurant_widgets.dart';
import 'package:zad_app/screens/restaurant/scan_qr_screen.dart';
import 'package:zad_app/theme/app_colors.dart';
import 'package:zad_app/widgets/offer_widgets.dart';
import '../../services/notification_service.dart';

// ─────────────────────────────────────────────
// ثوابت الألوان للحجز والدفع
// ─────────────────────────────────────────────
const _kReservedColor = AppColors.primary;
const _kPickedUpColor = AppColors.success;
const _kCancelledColor = AppColors.danger;
const _kPendingCashColor = Color(0xFFF59E0B); // amber
const _kPendingOnlineColor = Color(0xFF7C3AED); // purple
const _kPaidColor = AppColors.success;

// ─────────────────────────────────────────────
// مساعدات على مستوى الملف
// ─────────────────────────────────────────────
String _statusLabel(String status) {
  switch (status) {
    case 'reserved':
    case 'confirmed':
      return 'بانتظار الاستلام';
    case 'picked_up':
      return 'مكتملة';
    case 'cancelled':
      return 'ملغاة';
    default:
      return status;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'reserved':
    case 'confirmed':
      return _kReservedColor;
    case 'picked_up':
      return _kPickedUpColor;
    case 'cancelled':
      return _kCancelledColor;
    default:
      return AppColors.textLight;
  }
}

String _paymentStatusLabel(String? paymentStatus) {
  switch (paymentStatus) {
    case 'pending_cash':
      return 'كاش عند الاستلام';
    case 'pending_online':
      return 'دفع إلكتروني — قيد الانتظار';
    case 'paid':
      return 'مدفوع';
    default:
      return 'مجاني';
  }
}

Color _paymentStatusColor(String? paymentStatus) {
  switch (paymentStatus) {
    case 'pending_cash':
      return _kPendingCashColor;
    case 'pending_online':
      return _kPendingOnlineColor;
    case 'paid':
      return _kPaidColor;
    default:
      return AppColors.textLight;
  }
}

String _methodLabel(String? method) {
  switch (method) {
    case 'cash':
      return 'كاش';
    case 'online':
      return 'إلكتروني';
    default:
      return '—';
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

/// يُحوّل أي قيمة من Firestore إلى نص آمن مع fallback.
/// يتجنب استدعاء .trim() أو .isNotEmpty على dynamic null.
String _safeStr(dynamic raw, String fallback) {
  if (raw == null) return fallback;
  final s = raw.toString().trim();
  return s.isEmpty ? fallback : s;
}

// ─────────────────────────────────────────────
// الشاشة الرئيسية
// ─────────────────────────────────────────────
class RestaurantReservationsScreen extends StatefulWidget {
  const RestaurantReservationsScreen({super.key});

  @override
  State<RestaurantReservationsScreen> createState() =>
      _RestaurantReservationsScreenState();
}

class _RestaurantReservationsScreenState
    extends State<RestaurantReservationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // No orderBy in the Firestore query — avoids the composite-index requirement.
  // Results are sorted client-side in the StreamBuilder.
  Stream<QuerySnapshot> _reservationsStream() =>
      FirebaseFirestore.instance
          .collection('reservations')
          .where('providerUserId', isEqualTo: _uid)
          .snapshots();

  Future<void> _markPickedUp(
    BuildContext context,
    String reservationId,
    String userId,
    String offerTitle,
  ) async {
    // ── 1. تحديث الحالة في Firestore (الخطوة الأساسية) ──
    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .update({
        'status': 'picked_up',
        'pickedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ في تحديث الحالة: $e')));
      return;
    }

    // ── 2. إشعار المستخدم (غير حرج — فشله لا يُلغي التأكيد) ──
    try {
      await NotificationService().sendNotification(
        userId: userId,
        title: 'تم تأكيد الاستلام ✅',
        message:
            'تم استلام طلبك "$offerTitle" بنجاح. نتمنى لك وجبة شهية ❤️',
        type: 'pickup',
      );
    } catch (e) {
      debugPrint('[Reservations] notification failed (non-critical): $e');
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تأكيد الاستلام ✅'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حجوزات العروض'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'الكل'),
            Tab(text: 'بانتظار الاستلام'),
            Tab(text: 'مكتملة'),
            Tab(text: 'ملغاة'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _reservationsStream(),
        builder: (context, snapshot) {
          // ── حالة الخطأ ──
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          // ── حالة التحميل ──
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          // مساعد آمن: يُعيد قيمة حقل status دون أي استثناء
          String safeStatus(QueryDocumentSnapshot d) {
            try {
              final raw = d.data();
              if (raw == null) return '';
              return ((raw as Map<String, dynamic>)['status'] as String?) ?? '';
            } catch (_) {
              return '';
            }
          }

          // ترتيب client-side بدلاً من orderBy في الاستعلام (يتجنب الحاجة لـ composite index)
          final all = List<QueryDocumentSnapshot>.from(snapshot.data!.docs)
            ..sort((a, b) {
              final aRaw = (a.data() as Map<String, dynamic>)['createdAt'];
              final bRaw = (b.data() as Map<String, dynamic>)['createdAt'];
              final aTs = aRaw is Timestamp ? aRaw : null;
              final bTs = bRaw is Timestamp ? bRaw : null;
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return bTs.compareTo(aTs);
            });

          // reserved + confirmed معاً في تبويب "بانتظار الاستلام"
          final reserved = all
              .where((d) =>
                  safeStatus(d) == 'reserved' || safeStatus(d) == 'confirmed')
              .toList();
          final pickedUp =
              all.where((d) => safeStatus(d) == 'picked_up').toList();
          final cancelled =
              all.where((d) => safeStatus(d) == 'cancelled').toList();

          return Column(
            children: [
              // ── بطاقات الملخص ──
              _SummaryRow(
                total: all.length,
                active: reserved.length,
                completed: pickedUp.length,
                cancelled: cancelled.length,
              ),

              // ── قوائم التبويب ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ReservationList(
                      docs: all,
                      emptyMessage: 'لا توجد حجوزات حالياً على عروضك',
                      onConfirm: (doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        _markPickedUp(
                          context,
                          doc.id,
                          data['userId'] ?? '',
                          data['offerTitle'] ?? 'طلب طعام',
                        );
                      },
                    ),
                    _ReservationList(
                      docs: reserved,
                      emptyMessage: 'لا توجد حجوزات بانتظار الاستلام',
                      onConfirm: (doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        _markPickedUp(
                          context,
                          doc.id,
                          data['userId'] ?? '',
                          data['offerTitle'] ?? 'طلب طعام',
                        );
                      },
                    ),
                    _ReservationList(
                      docs: pickedUp,
                      emptyMessage: 'لا توجد طلبات مكتملة بعد',
                      onConfirm: null,
                    ),
                    _ReservationList(
                      docs: cancelled,
                      emptyMessage: 'لا توجد طلبات ملغاة',
                      onConfirm: null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// صف بطاقات الملخص
// ─────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final int total;
  final int active;
  final int completed;
  final int cancelled;

  const _SummaryRow({
    required this.total,
    required this.active,
    required this.completed,
    required this.cancelled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              title: 'الكل',
              value: '$total',
              icon: Icons.receipt_long_rounded,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatCard(
              title: 'نشطة',
              value: '$active',
              icon: Icons.hourglass_top_rounded,
              color: _kReservedColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatCard(
              title: 'مستلمة',
              value: '$completed',
              icon: Icons.check_circle_rounded,
              color: _kPickedUpColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatCard(
              title: 'ملغية',
              value: '$cancelled',
              icon: Icons.cancel_rounded,
              color: _kCancelledColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// قائمة الحجوزات
// ─────────────────────────────────────────────
class _ReservationList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String emptyMessage;
  final void Function(QueryDocumentSnapshot)? onConfirm;

  const _ReservationList({
    required this.docs,
    required this.emptyMessage,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return _EmptyState(message: emptyMessage);
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        try {
          final doc = docs[index];
          final raw = doc.data();
          if (raw == null) return const SizedBox.shrink();
          final data = raw as Map<String, dynamic>;

          final status = data['status']?.toString() ?? 'reserved';

          return _ReservationCard(
            doc: doc,
            data: data,
            // أظهر أزرار التأكيد للحجوزات المنتظرة والمؤكدة
            onConfirm: (status == 'reserved' || status == 'confirmed')
                ? onConfirm
                : null,
          );
        } catch (e, stack) {
          debugPrint('[Reservations] error building card at index $index: $e\n$stack');
          return const SizedBox.shrink();
        }
      },
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة الحجز الواحد
// ─────────────────────────────────────────────
class _ReservationCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final void Function(QueryDocumentSnapshot)? onConfirm;

  const _ReservationCard({
    required this.doc,
    required this.data,
    required this.onConfirm,
  });

  // استخراج Timestamp بأمان: يتجنب الأعطال عند وجود pending write
  Timestamp? _ts(String key) {
    final v = data[key];
    return v is Timestamp ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildCard(context);
    } catch (e, stack) {
      debugPrint('[ReservationCard] build error for doc ${doc.id}: $e\n$stack');
      return const SizedBox.shrink();
    }
  }

  Widget _buildCard(BuildContext context) {
    // _safeStr: يعالج null وأنواع غير String بأمان كامل
    final offerTitle = _safeStr(data['offerTitle'], 'طلب طعام');
    final userName = _safeStr(data['userName'], 'مستخدم');
    final status = _safeStr(data['status'], 'reserved');
    final pickupLocation = _safeStr(data['pickupLocation'], 'غير محدد');
    // رقم الحجز: reservationCode → reservationId → doc.id
    final reservationCode = () {
      final code = _safeStr(data['reservationCode'], '');
      if (code.isNotEmpty) return code;
      final rid = _safeStr(data['reservationId'], '');
      return rid.isNotEmpty ? rid : doc.id;
    }();
    final pickupTime = data['pickupTime']?.toString() ?? '';
    final price = data['price'];
    final currency = _safeStr(data['currency'], 'ILS');
    // حقول الدفع: null يعني العرض مجاني
    final paymentMethod = data['paymentMethod']?.toString();
    final paymentStatus = data['paymentStatus']?.toString();
    // Timestamp: is-check يحمي من pending-write أو بيانات غير متوقعة
    final createdAt = _ts('createdAt');
    final pickedAt = _ts('pickedAt');
    final qrValidatedAt = _ts('qrValidatedAt');
    // الكمية: is-check آمن بدل as num? الذي يرمي عند أنواع غير رقمية
    final rawQty = data['quantity'];
    final quantity = rawQty is num ? rawQty.toInt() : 1;
    final statusColor = _statusColor(status);

    final card = Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── رأس البطاقة: أيقونة + العنوان + شارة الحالة ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_long_rounded,
                      color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offerTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userName,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // شارة الحالة
                _StatusBadge(status: status),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),

            // ── تفاصيل الحجز ──
            OfferInfoRow(
              icon: Icons.confirmation_number_outlined,
              label: 'رقم الحجز',
              value: reservationCode,
            ),
            OfferInfoRow(
              icon: Icons.location_on_outlined,
              label: 'مكان الاستلام',
              value: pickupLocation,
            ),
            if (pickupTime.isNotEmpty)
              OfferInfoRow(
                icon: Icons.access_time_outlined,
                label: 'وقت الاستلام',
                value: pickupTime,
              ),
            OfferInfoRow(
              icon: Icons.production_quantity_limits_rounded,
              label: 'الكمية',
              value: '$quantity',
            ),
            if (price != null)
              OfferInfoRow(
                icon: Icons.payments_outlined,
                label: 'السعر',
                value: price == 0 ? 'مجاني' : '$price $currency',
              ),
            if (paymentMethod != null)
              OfferInfoRow(
                icon: Icons.credit_card_rounded,
                label: 'طريقة الدفع',
                value: _methodLabel(paymentMethod),
              ),
            OfferInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'تاريخ الحجز',
              value: _formatDateTime(createdAt),
            ),
            if (status == 'picked_up' && pickedAt != null)
              OfferInfoRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'تاريخ الاستلام',
                value: _formatDateTime(pickedAt),
              ),

            // ── شارة حالة الدفع ──
            if (paymentStatus != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.payments_rounded,
                      size: 14, color: AppColors.textLight),
                  const SizedBox(width: 6),
                  const Text(
                    'حالة الدفع: ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark),
                  ),
                  _PaymentBadge(paymentStatus: paymentStatus),
                ],
              ),
            ],

            // ── مؤشر مسح QR ──
            if (qrValidatedAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.qr_code_2_rounded,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'تم المسح بـ QR — ${_formatDateTime(qrValidatedAt)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ],

            // ── أزرار العمل (فقط للحجوزات بانتظار الاستلام) ──
            if (onConfirm != null) ...[
  const SizedBox(height: 10),
  Row(
    children: [
      Expanded(
        child: ElevatedButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text('تأكيد الاستلام'),
                content: Text(
                  'هل تأكد من استلام "$offerTitle" من قبل $userName؟',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('تأكيد'),
                  ),
                ],
              ),
            );

            if (confirm == true && onConfirm != null) {
              onConfirm!(doc);
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: const Text('تأكيد يدوياً'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ScanQrScreen(),
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: const Text('مسح QR'),
        ),
      ),
    ],
  ),
],

            // ── مؤشر اكتمال الاستلام ──
            if (status == 'picked_up') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kPickedUpColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: _kPickedUpColor, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'تم تأكيد الاستلام بنجاح',
                      style: TextStyle(
                          color: _kPickedUpColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            // ── مؤشر الإلغاء ──
            if (status == 'cancelled') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kCancelledColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel_rounded,
                        color: _kCancelledColor, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'تم إلغاء هذا الحجز',
                      style: TextStyle(
                          color: _kCancelledColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return card;
  }
}

// ─────────────────────────────────────────────
// شارة حالة الحجز
// ─────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    );
  }
}

// ─────────────────────────────────────────────
// شارة حالة الدفع
// ─────────────────────────────────────────────
class _PaymentBadge extends StatelessWidget {
  final String paymentStatus;
  const _PaymentBadge({required this.paymentStatus});

  @override
  Widget build(BuildContext context) {
    final color = _paymentStatusColor(paymentStatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _paymentStatusLabel(paymentStatus),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// حالة فارغة
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ستظهر الحجوزات هنا فور إنشائها',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppColors.textLight, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// حالة الخطأ
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 52, color: AppColors.danger),
            const SizedBox(height: 12),
            const Text(
              'حدث خطأ أثناء تحميل الحجوزات',
              style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
