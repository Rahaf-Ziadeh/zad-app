import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/screens/restaurant/pickup_confirmation_sheet.dart';
import 'package:zad_app/screens/restaurant/restaurant_offer_details_screen.dart';
import 'package:zad_app/screens/restaurant/restaurant_widgets.dart';
import 'package:zad_app/screens/restaurant/scan_qr_screen.dart';
import 'package:zad_app/screens/restaurant/user_public_profile_screen.dart';
import 'package:zad_app/theme/app_colors.dart';
import 'package:zad_app/widgets/offer_widgets.dart';
import '../../services/reservation_service.dart';

const _kReservedColor = AppColors.primary;
const _kPickedUpColor = AppColors.success;
const _kCancelledColor = AppColors.danger;
const _kPendingCashColor = Color(0xFFF59E0B); // amber
const _kPendingOnlineColor = Color(0xFF7C3AED); // purple
const _kPaidColor = AppColors.success;

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

/// Converts any Firestore value to a safe string with a fallback — avoids calling
/// .trim() or .isNotEmpty on a dynamic null.
String _safeStr(dynamic raw, String fallback) {
  if (raw == null) return fallback;
  final s = raw.toString().trim();
  return s.isEmpty ? fallback : s;
}

// Opens the offer linked to a reservation using the real offerId stored on the
// reservation doc. Uses a regular Navigator.push from within the current tab so
// the bottom nav stays visible — same pattern as UserPublicProfileScreen and ScanQrScreen.
Future<void> _openOfferFromReservation(
    BuildContext context, String offerId) async {
  if (offerId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('هذا العرض لم يعد متوفرًا.')),
    );
    return;
  }
  try {
    final doc =
        await FirebaseFirestore.instance.collection('offers').doc(offerId).get();
    if (!context.mounted) return;
    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا العرض لم يعد متوفرًا.')),
      );
      return;
    }
    final data = doc.data() as Map<String, dynamic>;
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RestaurantOfferDetailsScreen(offerId: offerId, offerData: data),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('هذا العرض لم يعد متوفرًا.')),
    );
  }
}

class RestaurantReservationsScreen extends StatefulWidget {
  // Tab indices: 0=all, 1=pending pickup, 2=completed, 3=cancelled.
  final int initialTabIndex;

  const RestaurantReservationsScreen({super.key, this.initialTabIndex = 0});

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
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
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

  // Manual confirmation opens the same full preview sheet as QR scan — same ownership/status
  // pre-check, same data view, same ReservationService.confirmPickup call. No security
  // difference between the two entry points.
  Future<void> _openManualConfirmation(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final validationError =
        validateReservationForPickupPreview(data, _uid);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }
    await showPickupConfirmationSheet(
      context,
      reservationId: doc.id,
      data: data,
      confirmationMethod: 'manual',
    );
  }

  // No time-window restriction unlike user cancellation; quantity restore,
  // refund, and notification are all handled atomically in rejectReservationByProvider.
  Future<void> _rejectReservation(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final offerTitle = _safeStr(data['offerTitle'], 'طلب طعام');

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RejectReasonDialog(offerTitle: offerTitle),
    );
    if (reason == null) return;
    if (!context.mounted) return;

    try {
      await ReservationService().rejectReservationByProvider(
        reservationId: doc.id,
        reason: reason,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفض الطلب'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
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
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          // Returns status without throwing — guards against pending writes and unexpected types.
          String safeStatus(QueryDocumentSnapshot d) {
            try {
              final raw = d.data();
              if (raw == null) return '';
              return ((raw as Map<String, dynamic>)['status'] as String?) ?? '';
            } catch (_) {
              return '';
            }
          }

          // Client-side sort — avoids the composite index Firestore would require for orderBy.
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

          // Both 'reserved' and 'confirmed' land in the "pending pickup" tab.
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
              _SummaryRow(
                total: all.length,
                active: reserved.length,
                completed: pickedUp.length,
                cancelled: cancelled.length,
                tabController: _tabController,
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ReservationList(
                      docs: all,
                      emptyMessage: 'لا توجد حجوزات حالياً على عروضك',
                      onConfirm: (doc) => _openManualConfirmation(context, doc),
                      onReject: (doc) => _rejectReservation(context, doc),
                    ),
                    _ReservationList(
                      docs: reserved,
                      emptyMessage: 'لا توجد حجوزات بانتظار الاستلام',
                      onConfirm: (doc) => _openManualConfirmation(context, doc),
                      onReject: (doc) => _rejectReservation(context, doc),
                    ),
                    _ReservationList(
                      docs: pickedUp,
                      emptyMessage: 'لا توجد طلبات مكتملة بعد',
                      onConfirm: null,
                      onReject: null,
                    ),
                    _ReservationList(
                      docs: cancelled,
                      emptyMessage: 'لا توجد طلبات ملغاة',
                      onConfirm: null,
                      onReject: null,
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

class _SummaryRow extends StatelessWidget {
  final int total;
  final int active;
  final int completed;
  final int cancelled;
  final TabController tabController;

  const _SummaryRow({
    required this.total,
    required this.active,
    required this.completed,
    required this.cancelled,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => tabController.animateTo(0),
              child: StatCard(
                title: 'الكل',
                value: '$total',
                icon: Icons.receipt_long_rounded,
                color: AppColors.textLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => tabController.animateTo(1),
              child: StatCard(
                title: 'نشطة',
                value: '$active',
                icon: Icons.hourglass_top_rounded,
                color: _kReservedColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => tabController.animateTo(2),
              child: StatCard(
                title: 'مستلمة',
                value: '$completed',
                icon: Icons.check_circle_rounded,
                color: _kPickedUpColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => tabController.animateTo(3),
              child: StatCard(
                title: 'ملغية',
                value: '$cancelled',
                icon: Icons.cancel_rounded,
                color: _kCancelledColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String emptyMessage;
  final void Function(QueryDocumentSnapshot)? onConfirm;
  final void Function(QueryDocumentSnapshot)? onReject;

  const _ReservationList({
    required this.docs,
    required this.emptyMessage,
    required this.onConfirm,
    required this.onReject,
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

          final showActions = status == 'reserved' || status == 'confirmed';
          return _ReservationCard(
            doc: doc,
            data: data,
            onConfirm: showActions ? onConfirm : null,
            onReject: showActions ? onReject : null,
          );
        } catch (e, stack) {
          debugPrint('[Reservations] error building card at index $index: $e\n$stack');
          return const SizedBox.shrink();
        }
      },
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final void Function(QueryDocumentSnapshot)? onConfirm;
  final void Function(QueryDocumentSnapshot)? onReject;

  const _ReservationCard({
    required this.doc,
    required this.data,
    required this.onConfirm,
    required this.onReject,
  });

  // Guards against crashes from pending writes or unexpected field types.
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
    final offerTitle = _safeStr(data['offerTitle'], 'طلب طعام');
    final userName = _safeStr(data['userName'], 'مستخدم');
    final status = _safeStr(data['status'], 'reserved');
    final pickupLocation = _safeStr(data['pickupLocation'], 'غير محدد');
    // Resolution order: reservationCode → reservationId → doc.id.
    final reservationCode = () {
      final code = _safeStr(data['reservationCode'], '');
      if (code.isNotEmpty) return code;
      final rid = _safeStr(data['reservationId'], '');
      return rid.isNotEmpty ? rid : doc.id;
    }();
    final pickupTime = data['pickupTime']?.toString() ?? '';
    final price = data['price'];
    final currency = _safeStr(data['currency'], 'ILS');
    // null payment fields mean the offer was free.
    final paymentMethod = data['paymentMethod']?.toString();
    final paymentStatus = data['paymentStatus']?.toString();
    final createdAt = _ts('createdAt');
    final pickedAt = _ts('pickedAt');
    final qrValidatedAt = _ts('qrValidatedAt');
    // is-check instead of `as num?` — avoids a throw when the field is a non-numeric type.
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
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _openOfferFromReservation(
                          context,
                          _safeStr(data['offerId'], ''),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                offerTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_left_rounded,
                                size: 14, color: AppColors.textLight),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserPublicProfileScreen(
                              userId: _safeStr(data['userId'], ''),
                              userName: userName,
                              reservationId: doc.id,
                              offerId: _safeStr(data['offerId'], ''),
                              offerTitle: offerTitle,
                              reservationStatus: status,
                            ),
                          ),
                        ),
                        child: Text(
                          userName,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: status),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),

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

            // "Confirm manually" opens the full preview sheet directly; the sheet
            // itself has the final confirm/reject buttons, so no extra dialog is needed.
            if (onConfirm != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onConfirm!(doc),
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
              if (onReject != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => onReject!(doc),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('رفض الطلب'),
                  ),
                ),
              ],
            ],

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

// Returns the trimmed rejection reason on submit, or null if dismissed.
// Submit is blocked if the field is empty.
class _RejectReasonDialog extends StatefulWidget {
  final String offerTitle;
  const _RejectReasonDialog({required this.offerTitle});

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة سبب الرفض')),
      );
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('رفض طلب "${widget.offerTitle}"',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'سيتم إلغاء الحجز وإرجاع الكمية، واسترداد المبلغ تلقائياً إن كان '
            'مدفوعاً إلكترونياً. سيصل المستخدم إشعار بالرفض.',
            style: TextStyle(color: AppColors.textLight, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'سبب الرفض...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('تراجع'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('رفض الطلب'),
        ),
      ],
    );
  }
}

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
