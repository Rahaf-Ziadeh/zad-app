import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../services/reservation_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';
import 'provider_public_profile_screen.dart';
import 'qr_code_screen.dart';

class UserOrdersScreen extends StatefulWidget {
  // ── يُستخدم فقط لتحديد التبويب المبدئي عند فتح الشاشة، وإلا فالتبويبات
  // الأربعة الجديدة هي المصدر الفعلي للفلترة أثناء الاستخدام ──
  final String? statusFilter;

  const UserOrdersScreen({
    super.key,
    this.statusFilter,
  });

  @override
  State<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends State<UserOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── معرّفات الحجوزات الجاري إلغاؤها حالياً: تمنع ضغطة ثانية سريعة على
  // نفس الحجز من بدء عملية إلغاء موازية، وتُستخدم لتعطيل زر "إلغاء" الخاص
  // بتلك البطاقة فقط أثناء المعالجة ──
  final Set<String> _cancellingIds = {};

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

  // ── يستدعي ReservationService().cancelReservation — مصدر واحد لمنطق
  // الإلغاء الذرّي (كانت هذه الشاشة تكرر معاملة Firestore بنفسها سابقاً،
  // منفصلة عن ReservationService.cancelReservation ولا تستخدمها إطلاقاً).
  // حارس _cancellingIds يُضبط قبل أول await فيمنع أي ضغطة إلغاء ثانية
  // سريعة على نفس الحجز من بدء عملية موازية ──
  Future<void> _cancelReservation({
    required BuildContext context,
    required String reservationId,
    required String offerId,
  }) async {
    if (_cancellingIds.contains(reservationId)) {
      debugPrint('[UserOrdersScreen] cancel tap IGNORED — already '
          'processing reservationId=$reservationId');
      return;
    }
    setState(() => _cancellingIds.add(reservationId));
    debugPrint('[UserOrdersScreen] cancel requested reservationId='
        '$reservationId offerId=$offerId');

    try {
      await ReservationService().cancelReservation(
        reservationId: reservationId,
        offerId: offerId,
      );
      debugPrint(
          '[UserOrdersScreen] cancel SUCCESS reservationId=$reservationId');

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الحجز بنجاح')),
      );
    } catch (e, stackTrace) {
      debugPrint('[UserOrdersScreen] cancel FAILED reservationId='
          '$reservationId error=$e');
      debugPrint('[UserOrdersScreen] cancel stackTrace:\n$stackTrace');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cancelErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _cancellingIds.remove(reservationId));
    }
  }

  // ── يسمح فقط بمرور رسائل الاستثناءات العربية النظيفة التي يضمنها
  // ReservationService.cancelReservation بالفعل (فهي تلتقط أي خطأ غير
  // متوقع بنفسها وتستبدله برسالة عربية آمنة قبل الرمي). تُطابَق ببادئة
  // ثابتة بدل نص كامل حتى تبقى متزامنة مع cancellationWindowMinutes دون
  // تكرار الرقم هنا. أي نص آخر غير معروف — بما فيه أخطاء JS-interop الخام
  // على الويب مثل "Dart exception thrown from converted Future..." — لا
  // يُعرض أبداً كما هو، بل يُستبدل بنفس الرسالة العامة الآمنة ──
  static String _cancelErrorMessage(Object e) {
    final raw = e.toString().replaceAll('Exception: ', '').trim();
    const knownPrefixes = [
      'الحجز غير موجود',
      'تعذّر قراءة بيانات الحجز',
      'تم إلغاء هذا الحجز مسبقاً',
      'لا يمكن إلغاء هذا الطلب',
      'انتهت مهلة إلغاء الحجز',
      'تعذّر إلغاء الحجز، يرجى المحاولة مرة أخرى.',
    ];
    for (final prefix in knownPrefixes) {
      if (raw.startsWith(prefix)) return raw;
    }
    return 'تعذّر إلغاء الحجز، يرجى المحاولة مرة أخرى.';
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

  void _showRatingDialog({
    required BuildContext context,
    required String reservationId,
    required String offerTitle,
    required String providerName,
  }) {
    showDialog(
      context: context,
      builder: (_) => _RatingDialog(
        reservationId: reservationId,
        offerTitle: offerTitle,
        providerName: providerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('طلباتي'),
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
          debugPrint('[UserOrdersScreen] stream error: ${snapshot.error}');
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
            final hasRated = data['hasRated'] ?? false;
            final reservedQty = (data['quantity'] as num?)?.toInt() ?? 1;
            final allergens = AppConstants.parseAllergyInfo(data['allergyInfo']);
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
                              onPressed: _cancellingIds.contains(reservationId)
                                  ? null
                                  : () => _confirmCancel(
                                        context: context,
                                        reservationId: reservationId,
                                        offerId: offerId,
                                      ),
                              icon: _cancellingIds.contains(reservationId)
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.danger),
                                    )
                                  : const Icon(Icons.cancel_outlined,
                                      size: 18),
                              label: Text(
                                  _cancellingIds.contains(reservationId)
                                      ? 'جارٍ الإلغاء...'
                                      : 'إلغاء'),
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
                            Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 18),
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
                      if (!hasRated) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showRatingDialog(
                              context: context,
                              reservationId: reservationId,
                              offerTitle: title,
                              providerName: displayProvider,
                            ),
                            icon: const Icon(Icons.star_outline_rounded,
                                size: 18),
                            label: const Text('قيّم تجربتك'),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            '⭐ شكراً على تقييمك',
                            style: TextStyle(
                                color: AppColors.textLight, fontSize: 12),
                          ),
                        ),
                      ],
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

class _RatingDialog extends StatefulWidget {
  final String reservationId;
  final String offerTitle;
  final String providerName;

  const _RatingDialog({
    required this.reservationId,
    required this.offerTitle,
    required this.providerName,
  });

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار تقييم')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final reservationRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId);

      final reservationDoc = await reservationRef.get();
      final reservationData = reservationDoc.data() ?? {};

      final reviewRef = FirebaseFirestore.instance.collection('reviews').doc();

      await reservationRef.update({
        'rating': _rating,
        'ratingComment': _commentController.text.trim(),
        'hasRated': true,
        'ratedAt': FieldValue.serverTimestamp(),
        'reviewId': reviewRef.id,
      });

      await reviewRef.set({
        'reviewId': reviewRef.id,
        'reservationId': widget.reservationId,
        'offerId': reservationData['offerId'] ?? '',
        'offerTitle': reservationData['offerTitle'] ?? 'طلب طعام',
        'providerUserId': reservationData['providerUserId'] ?? '',
        'providerName': reservationData['providerName'] ?? '',
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'userName': reservationData['userName'] ?? '',
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شكراً على تقييمك! ⭐')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('قيّم تجربتك',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.offerTitle.isNotEmpty || widget.providerName.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.offerTitle.isNotEmpty)
                    Text(
                      widget.offerTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        fontSize: 13,
                      ),
                    ),
                  if (widget.providerName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.providerName,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const Text(
            'كيف كانت تجربتك مع هذا الطلب؟',
            style: TextStyle(color: AppColors.textLight, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    star <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'أضف تعليقاً (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('إرسال'),
        ),
      ],
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  final String? statusFilter;

  const _EmptyOrders({this.statusFilter});

  String get _message {
    switch (statusFilter) {
      case 'reserved':
        return 'لا توجد طلبات نشطة حالياً';
      case 'picked_up':
        return 'لا توجد طلبات مستلمة بعد';
      case 'cancelled':
        return 'لا توجد طلبات ملغية';
      default:
        return 'لا توجد طلبات بعد';
    }
  }

  String get _subtitle {
    switch (statusFilter) {
      case 'reserved':
        return 'عند حجز عرض أو باقة، ستظهر الطلبات النشطة هنا.';
      case 'picked_up':
        return 'بعد تأكيد الاستلام، ستظهر الطلبات المستلمة هنا.';
      case 'cancelled':
        return 'أي طلب يتم إلغاؤه سيظهر هنا.';
      default:
        return 'عند حجز عرض أو باقة، ستظهر تفاصيل الطلب ورمز الاستلام هنا.';
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
