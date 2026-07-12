import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/screens/restaurant/edit_offer_screen.dart';
import 'package:zad_app/screens/restaurant/offer_actions.dart';
import 'package:zad_app/screens/restaurant/restaurant_offer_details_screen.dart';
import 'package:zad_app/screens/restaurant/restaurant_widgets.dart';
import 'package:zad_app/theme/app_colors.dart';
import 'package:zad_app/utils/offer_utils.dart';
import 'package:zad_app/widgets/fullscreen_image_viewer.dart';
import 'package:zad_app/widgets/offer_widgets.dart';

// ── فلاتر التبويبات بنفس ترتيب ظهورها؛ null يعني "الكل" (بلا فلترة) ──
const List<String?> _kFilterKeys = [null, 'available', 'expired', 'closed', 'sold_out'];
const List<String> _kTabLabels = ['الكل', 'نشطة', 'منتهية', 'مغلقة', 'نفدت الكمية'];

// ── يطابق عرضاً واحداً مع الفلتر المطلوب اعتماداً على effectiveOfferStatus
// (الحالة الفعلية بعد اعتبار انتهاء الصلاحية) وليس حقل status الخام مباشرة؛
// هذا يضمن أن فلتر "نشطة" يستثني المنتهية، وأن فلتر "منتهية" يعمل فعلياً رغم
// عدم وجود أي مستند بحقل status حرفي = "expired" (فالانتهاء يُحسب دائماً من
// expiresAt/expiryDate على العميل ولا يُكتب كحالة منفصلة في Firestore).
//
// "نشطة" (available): status الفعلي 'available' + كمية متبقية > 0 — نفس
// الشرط الثلاثي المستخدم في بطاقات إحصائيات الرئيسية والإحصائيات، حتى لا
// يظهر في هذه القائمة عرض لم يُحتسَب كـ"نشط" هناك (أو العكس).
//
// "sold_out" (نفدت الكمية): أي عرض غير منتهي الصلاحية نفدت كميته بالكامل —
// سواء كانت حالته المخزَّنة 'reserved' (الحالة القياسية التي يضبطها
// ReservationService عند نفاد remainingQuantity)، أو 'available' بكمية
// متبقية صفر في حالات نادرة (كتعديل يدوي للكمية دون تحديث الحالة) ──
bool _matchesFilter(Map<String, dynamic> data, String filter) {
  final effective = effectiveOfferStatus(data);
  final remaining = (data['remainingQuantity'] as num?)?.toInt() ?? 0;

  if (filter == 'available') return effective == 'available' && remaining > 0;
  if (filter == 'sold_out') {
    return !isOfferExpired(data) && remaining <= 0;
  }
  return effective == filter;
}

// ── الحالة الفعلية المعروضة على شارة البطاقة — نفس منطق الفلترة أعلاه
// بالضبط، محوَّلاً إلى قيمة واحدة بدل فحص كل فلتر على حدة، حتى تبقى شارة كل
// بطاقة متّسقة تماماً مع التبويب الذي تظهر ضمنه ──
String _effectiveBadgeStatus(Map<String, dynamic> data) {
  if (isOfferExpired(data)) return 'expired';
  final remaining = (data['remainingQuantity'] as num?)?.toInt() ?? 0;
  final rawStatus = (data['status'] as String?) ?? '';
  if (rawStatus == 'closed') return 'closed';
  if (remaining <= 0) return 'sold_out';
  if (rawStatus == 'available') return 'available';
  return rawStatus.isEmpty ? 'unknown' : rawStatus;
}

Color _badgeColor(String status) {
  switch (status) {
    case 'available':
      return AppColors.success;
    case 'closed':
      return AppColors.textLight;
    case 'sold_out':
      return Colors.orange;
    case 'expired':
      return AppColors.danger;
    default:
      return AppColors.textLight;
  }
}

String _badgeLabel(String status) {
  switch (status) {
    case 'available':
      return 'نشط';
    case 'closed':
      return 'مغلق';
    case 'sold_out':
      return 'نفدت الكمية';
    case 'expired':
      return 'منتهي';
    default:
      return status;
  }
}

class RestaurantOffersScreen extends StatefulWidget {
  // ── فلترة أولية اختيارية تحدّد التبويب المفتوح مبدئياً: 'available'
  // (نشطة)، 'expired' (منتهية)، 'closed' (مغلقة)، 'sold_out' (نفدت الكمية)،
  // أو null لفتح تبويب "الكل" ──
  final String? initialFilter;

  const RestaurantOffersScreen({super.key, this.initialFilter});

  @override
  State<RestaurantOffersScreen> createState() => _RestaurantOffersScreenState();
}

class _RestaurantOffersScreenState extends State<RestaurantOffersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int get _initialTabIndex {
    final idx = _kFilterKeys.indexOf(widget.initialFilter);
    return idx == -1 ? 0 : idx;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _kFilterKeys.length,
      vsync: this,
      initialIndex: _initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> _myOffersStream() => FirebaseFirestore.instance
      .collection('offers')
      .where('providerUserId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('عروضي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: _kTabLabels.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _myOffersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ أثناء تحميل العروض'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // ── ستريم واحد فقط يُشترَك بين كل التبويبات؛ كل تبويب يُصفّي
          // نفس القائمة محلياً، بلا استعلامات Firestore إضافية ──
          final allDocs = snapshot.data!.docs;

          return TabBarView(
            controller: _tabController,
            children: _kFilterKeys.map((filter) {
              final docs = filter == null
                  ? allDocs
                  : allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _matchesFilter(data, filter);
                    }).toList();
              return _OffersListView(docs: docs);
            }).toList(),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// قائمة بطاقات العروض لتبويب واحد
// ─────────────────────────────────────────────
class _OffersListView extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const _OffersListView({required this.docs});

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_outlined,
                size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 14),
            const Text('لا توجد عروض هنا',
                style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('أضف أول باقة فائض الآن',
                style: TextStyle(color: AppColors.textLight)),
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

        final title = data['title'] ?? 'باقة طعام';
        final description = data['description'] ?? '';
        final imageUrl = data['imageUrl'] ?? '';
        final quantity = data['quantity'] ?? 0;
        final remainingQuantity = data['remainingQuantity'] ?? 0;
        final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
        final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
        final currency = data['currency'] ?? 'ILS';
        final rawStatus = (data['status'] as String?) ?? 'unknown';
        final expired = isOfferExpired(data);
        final badgeStatus = _effectiveBadgeStatus(data);
        final pickupLocation = data['pickupLocation'] ?? 'غير محدد';
        final isFree = data['isFree'] == true || discountPrice == 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: badgeStatus == 'available'
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
          ),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RestaurantOfferDetailsScreen(
                  offerId: doc.id,
                  offerData: data,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── صورة — قابلة للنقر لفتح معاينة ملء الشاشة، منفصلة عن
                // نقرة البطاقة العامة (التي تفتح تفاصيل العرض) ──
                Stack(
                  children: [
                    TappableOfferImage(
                      imageUrl: imageUrl,
                      title: title,
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  buildImagePlaceholder(
                                      icon: Icons.restaurant_menu_rounded,
                                      height: 150),
                            )
                          : buildImagePlaceholder(
                              icon: Icons.restaurant_menu_rounded,
                              height: 150),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _badgeColor(badgeStatus).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _badgeLabel(badgeStatus),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          // ── القائمة المنسدلة (اختصار) — تبقى موجودة كما
                          // هي، دون الحاجة لفتحها لرؤية العرض ──
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditOfferScreen(
                                      offerId: doc.id,
                                      offerData: data,
                                    ),
                                  ),
                                );
                              } else if (value == 'toggle') {
                                toggleOfferStatus(context, doc.id, rawStatus);
                              } else if (value == 'delete') {
                                confirmDeleteOffer(context, doc.id);
                              }
                            },
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        color: AppColors.primary, size: 18),
                                    SizedBox(width: 8),
                                    Text('تعديل العرض'),
                                  ],
                                ),
                              ),
                              if (!expired)
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(
                                        rawStatus == 'available'
                                            ? Icons.pause_circle_outline
                                            : Icons.play_circle_outline,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(rawStatus == 'available'
                                          ? 'إغلاق العرض'
                                          : 'تفعيل العرض'),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'delete',
                                child: const Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        color: AppColors.danger, size: 18),
                                    SizedBox(width: 8),
                                    Text('حذف العرض',
                                        style:
                                            TextStyle(color: AppColors.danger)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 13,
                              height: 1.5),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OfferPriceRow(
                        isFree: isFree,
                        originalPrice: originalPrice,
                        discountPrice: discountPrice,
                        currency: currency,
                      ),
                      const SizedBox(height: 10),
                      // شريط تقدم الكمية
                      QuantityBar(
                        remaining: remainingQuantity,
                        total: quantity,
                      ),
                      const SizedBox(height: 10),
                      OfferInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'مكان الاستلام',
                        value: pickupLocation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
