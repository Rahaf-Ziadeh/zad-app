import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';
import '../user/provider_public_profile_screen.dart';
import '../user/qr_code_screen.dart';

class CharityReservationsScreen extends StatefulWidget {
  // ── يُستخدم فقط لتحديد التبويب المبدئي عند فتح الشاشة، وإلا فالتبويبات
  // الأربعة الجديدة هي المصدر الفعلي للفلترة أثناء الاستخدام ──
  final String? statusFilter;

  const CharityReservationsScreen({
    super.key,
    this.statusFilter,
  });

  @override
  State<CharityReservationsScreen> createState() =>
      _CharityReservationsScreenState();
}

class _CharityReservationsScreenState extends State<CharityReservationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── null = "الكل"، وإلا القيمة الفعلية لحقل status في مجموعة reservations ──
  static const List<String?> _statuses = [
    null,
    'reserved',
    'picked_up',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = _statuses.indexOf(widget.statusFilter);
    _tabController = TabController(
      length: _statuses.length,
      vsync: this,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _ordersStream(String? status) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    Query query = FirebaseFirestore.instance
        .collection('reservations')
        .where('userId', isEqualTo: userId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  // ── تسميات التبويبات (مختلفة عن شارة الحالة داخل البطاقة والتي تبقى كما هي) ──
  String _tabLabel(String? status) {
    switch (status) {
      case 'reserved':
        return 'بانتظار الاستلام';
      case 'picked_up':
        return 'تم الاستلام';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'الكل';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'reserved':
        return 'محجوز';
      case 'picked_up':
        return 'تم الاستلام';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'reserved':
        return Colors.orange;
      case 'picked_up':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.danger;
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelReservation({
    required BuildContext context,
    required String reservationId,
    required String offerId,
  }) async {
    try {
      final reservationRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId);
      final offerRef =
          FirebaseFirestore.instance.collection('offers').doc(offerId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final reservationSnap = await transaction.get(reservationRef);
        final offerSnap = await transaction.get(offerRef);

        if (!reservationSnap.exists) throw Exception('الحجز غير موجود');

        final resData = reservationSnap.data() as Map<String, dynamic>;
        if (resData['status'] != 'reserved') {
          throw Exception('لا يمكن إلغاء هذا الطلب');
        }

        // ── قيد الإلغاء: 10 دقائق فقط من وقت الحجز ──
        final createdAt = resData['createdAt'] as Timestamp?;
        if (createdAt == null ||
            DateTime.now().difference(createdAt.toDate()).inMinutes > 10) {
          throw Exception('لا يمكن إلغاء الحجز بعد مرور 10 دقائق.');
        }

        final cancelQty = (resData['quantity'] as num?)?.toInt() ?? 1;

        if (offerSnap.exists) {
          final offerData = offerSnap.data() as Map<String, dynamic>;
          final qty = (offerData['remainingQuantity'] as num?)?.toInt() ?? 0;
          transaction.update(offerRef, {
            'remainingQuantity': qty + cancelQty,
            'status': 'available',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(reservationRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الحجز بنجاح')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cancelErrorMessage(e))),
      );
    }
  }

  // يستخرج رسالة الخطأ العربية المناسبة من أي استثناء
  // (بما فيها الاستثناءات المغلّفة من Firestore transaction على Android)
  static String _cancelErrorMessage(Object e) {
    final raw = e.toString();
    // ابحث عن النصوص العربية المعروفة أينما كانت في الاستثناء المغلّف
    if (raw.contains('لا يمكن إلغاء الحجز بعد مرور 10 دقائق')) {
      return 'لا يمكن إلغاء الحجز بعد مرور 10 دقائق.';
    }
    if (raw.contains('لا يمكن إلغاء هذا الطلب')) {
      return 'لا يمكن إلغاء هذا الطلب.';
    }
    if (raw.contains('الحجز غير موجود')) {
      return 'الحجز غير موجود.';
    }
    // fallback: نظّف البادئة الافتراضية
    return raw.replaceAll('Exception: ', '').trim();
  }

  void _confirmCancel({
    required BuildContext context,
    required String reservationId,
    required String offerId,
  }) {
    showDialog(
      context: context,
      // ── نستخدم سياق النافذة الخاص بها (dialogContext) لإغلاقها، وليس سياق
      // الشاشة الخارجية: هذه الشاشة قد تكون متداخلة ضمن Navigator خاص بتبويبها ──
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: const Text('هل أنت متأكد من إلغاء هذا الحجز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(dialogContext);
              _cancelReservation(
                context: context,
                reservationId: reservationId,
                offerId: offerId,
              );
            },
            child: const Text('إلغاء الحجز'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حجوزاتي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: _statuses.map((s) => Tab(text: _tabLabel(s))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses.map(_buildOrdersList).toList(),
      ),
    );
  }

  Widget _buildOrdersList(String? status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream(status),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
              '[CharityReservationsScreen] stream error: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return _EmptyOrders(statusFilter: status);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final doc = orders[index];
            final data = doc.data() as Map<String, dynamic>;

            final title = data['offerTitle'] ?? 'طلب طعام';
            final status = data['status'] ?? 'reserved';
            final offerId = data['offerId'] ?? '';
            final reservationId = doc.id;
            final reservationCode =
                (data['reservationCode'] as String? ?? '').trim().isNotEmpty
                    ? data['reservationCode'] as String
                    : reservationId;
            final userId = FirebaseAuth.instance.currentUser!.uid;
            final providerRole = (data['providerRole'] as String?) ?? '';
            final providerUserId =
                (data['providerUserId'] as String? ?? '').trim();
            final providerName = (data['providerName'] as String? ?? '').trim();
            final displayProvider =
                providerName.isNotEmpty ? providerName : providerRole;
            // ── الملف العام متاح فقط للمطاعم والجمعيات، وليس للأفراد ──
            final isClickableProvider =
                (providerRole == 'restaurant' || providerRole == 'charity') &&
                    providerUserId.isNotEmpty;
            final pickupLocation = data['pickupLocation'] ?? 'غير محدد';
            final reservedQty = (data['quantity'] as num?)?.toInt() ?? 1;
            final allergens =
                AppConstants.parseAllergyInfo(data['allergyInfo']);
            final hasKnownAllergens = allergens.isNotEmpty &&
                !(allergens.length == 1 &&
                    allergens.first == AppConstants.noKnownAllergens);

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: status == 'reserved'
                      ? Colors.orange.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.fastfood_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    OfferInfoRow(
                      icon: Icons.confirmation_number_outlined,
                      label: 'رقم الحجز',
                      value: reservationCode,
                    ),
                    if (displayProvider.isNotEmpty)
                      OfferInfoRow(
                        icon: Icons.storefront_outlined,
                        label: 'المزوّد',
                        value: displayProvider,
                        onTap: isClickableProvider
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProviderPublicProfileScreen(
                                      providerUserId: providerUserId,
                                      providerRole: providerRole,
                                    ),
                                  ),
                                )
                            : null,
                      ),
                    OfferInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'مكان الاستلام',
                      value: pickupLocation,
                    ),
                    if (reservedQty > 1)
                      OfferInfoRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'الكمية المحجوزة',
                        value: '$reservedQty وحدات',
                      ),
                    if (hasKnownAllergens)
                      OfferInfoRow(
                        icon: Icons.warning_amber_rounded,
                        label: 'مسببات الحساسية',
                        value: allergens.join('، '),
                      ),
                    const SizedBox(height: 12),
                    if (status == 'reserved') ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QrCodeScreen(
                                    reservationId: reservationId,
                                    offerId: offerId,
                                    userId: userId,
                                    providerName: displayProvider,
                                    reservationCode: reservationCode,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.qr_code_rounded, size: 18),
                              label: const Text('رمز QR'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmCancel(
                                context: context,
                                reservationId: reservationId,
                                offerId: offerId,
                              ),
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: const Text('إلغاء'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (status == 'picked_up') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'تم تأكيد الاستلام بنجاح',
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (status == 'cancelled') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel_rounded,
                                color: AppColors.danger, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'تم إلغاء هذا الحجز',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
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

class _EmptyOrders extends StatelessWidget {
  final String? statusFilter;

  const _EmptyOrders({this.statusFilter});

  String get _message {
    switch (statusFilter) {
      case 'reserved':
        return 'لا توجد حجوزات نشطة حالياً';
      case 'picked_up':
        return 'لا توجد حجوزات مستلمة بعد';
      case 'cancelled':
        return 'لا توجد حجوزات ملغية';
      default:
        return 'لا توجد حجوزات بعد';
    }
  }

  String get _subtitle {
    switch (statusFilter) {
      case 'reserved':
        return 'عند حجز عرض أو باقة، ستظهر الحجوزات النشطة هنا.';
      case 'picked_up':
        return 'بعد تأكيد الاستلام، ستظهر الحجوزات المستلمة هنا.';
      case 'cancelled':
        return 'أي حجز يتم إلغاؤه سيظهر هنا.';
      default:
        return 'عند حجز عرض أو باقة، ستظهر تفاصيل الحجز ورمز الاستلام هنا.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _message,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textLight, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
