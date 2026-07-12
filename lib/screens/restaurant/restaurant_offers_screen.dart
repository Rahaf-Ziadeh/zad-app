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

// ── نتيجة معالجة عرض واحد محسوبة مرة واحدة فقط لكل مستند عند كل لقطة
// Firestore (بدل إعادة حساب isOfferExpired/effectiveOfferStatus حتى 5 مرات:
// مرة لكل تبويب من التبويبات الأربعة المُفلترة + مرة لشارة الحالة على
// البطاقة). هذا هو سبب بطء تبويب "منتهية" ملموساً عن غيره: فحص انتهاء
// الصلاحية (تحويل Timestamp إلى DateTime ومقارنته بـ DateTime.now) كان
// يُعاد تنفيذه لكل مستند مرات متعددة على كل إعادة بناء، وبما أن العروض
// المنتهية تتراكم لدى المطعم بمرور الوقت (لا تُؤرشَف أو تُحذف تلقائياً)
// فهي غالباً أكبر التبويبات، فتتضاعف كلفة إعادة الحساب هذه فيها أكثر من
// غيرها. حساب واحد بسيط (expired/remaining/status) لكل مستند هنا يكفي
// لتغذية كل التبويبات والشارة معاً، دون أي تغيير في نتيجة الفلترة ──
class _OfferEntry {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final bool expired;
  final int remaining;
  final String effective; // 'expired' أو حقل status الخام (أو 'available')
  final String badgeStatus;
  // ── null لأي مستند بلا createdAt صالح — تُرتَّب هذه دائماً في الآخر بصرف
  // النظر عن كونها الأحدث أو الأقدم فعلياً، لأن تاريخها الحقيقي غير معروف ──
  final int? createdAtMillis;

  _OfferEntry({
    required this.doc,
    required this.data,
    required this.expired,
    required this.remaining,
    required this.effective,
    required this.badgeStatus,
    required this.createdAtMillis,
  });

  factory _OfferEntry.from(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final expired = isOfferExpired(data);
    final remaining = (data['remainingQuantity'] as num?)?.toInt() ?? 0;
    final rawStatus = data['status'] as String?;
    final effective = expired ? 'expired' : (rawStatus ?? 'available');
    final String badgeStatus;
    if (expired) {
      badgeStatus = 'expired';
    } else if (rawStatus == 'closed') {
      badgeStatus = 'closed';
    } else if (remaining <= 0) {
      badgeStatus = 'sold_out';
    } else if (rawStatus == 'available') {
      badgeStatus = 'available';
    } else {
      badgeStatus =
          (rawStatus == null || rawStatus.isEmpty) ? 'unknown' : rawStatus;
    }
    final createdAtRaw = data['createdAt'];
    final createdAtMillis =
        createdAtRaw is Timestamp ? createdAtRaw.millisecondsSinceEpoch : null;
    return _OfferEntry(
      doc: doc,
      data: data,
      expired: expired,
      remaining: remaining,
      effective: effective,
      badgeStatus: badgeStatus,
      createdAtMillis: createdAtMillis,
    );
  }
}

/// ترتيب "الأحدث أولاً" — أي عرض بلا createdAt صالح يُوضَع في نهاية القائمة
/// دائماً بدل استبعاده أو ترتيبه عشوائياً.
int _compareNewestFirst(_OfferEntry a, _OfferEntry b) {
  final am = a.createdAtMillis;
  final bm = b.createdAtMillis;
  if (am == null && bm == null) return 0;
  if (am == null) return 1;
  if (bm == null) return -1;
  return bm.compareTo(am);
}

// ── يطابق عرضاً واحداً (بحقوله المحسوبة مسبقاً) مع الفلتر المطلوب اعتماداً
// على الحالة الفعلية بعد اعتبار انتهاء الصلاحية وليس حقل status الخام
// مباشرة؛ هذا يضمن أن فلتر "نشطة" يستثني المنتهية، وأن فلتر "منتهية" يعمل
// فعلياً رغم عدم وجود أي مستند بحقل status حرفي = "expired" (فالانتهاء
// يُحسب دائماً من expiresAt/expiryDate على العميل ولا يُكتب كحالة منفصلة
// في Firestore).
//
// "نشطة" (available): status الفعلي 'available' + كمية متبقية > 0 — نفس
// الشرط الثلاثي المستخدم في بطاقات إحصائيات الرئيسية والإحصائيات، حتى لا
// يظهر في هذه القائمة عرض لم يُحتسَب كـ"نشط" هناك (أو العكس).
//
// "مغلقة" (closed): الحالة الفعلية == 'closed' فقط — الحقل الخام المستخدم
// فعلياً في المشروع لإغلاق عرض هو 'closed' (راجع toggleOfferStatus في
// offer_actions.dart)، وليس completed/inactive/cancelled/sold_out؛ الأخيرة
// حالة منفصلة تماماً (نفدت الكمية) لها تبويبها الخاص أدناه.
//
// "sold_out" (نفدت الكمية): أي عرض غير منتهي الصلاحية نفدت كميته بالكامل —
// سواء كانت حالته المخزَّنة 'reserved' (الحالة القياسية التي يضبطها
// ReservationService عند نفاد remainingQuantity)، أو 'available' بكمية
// متبقية صفر في حالات نادرة (كتعديل يدوي للكمية دون تحديث الحالة) ──
bool _matchesFilter(_OfferEntry entry, String filter) {
  if (filter == 'available') {
    return entry.effective == 'available' && entry.remaining > 0;
  }
  if (filter == 'sold_out') {
    return !entry.expired && entry.remaining <= 0;
  }
  return entry.effective == filter;
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

  // ── فلتر مساواة وحيد بلا orderBy عمداً: Firestore يستبعد كلياً من نتائج
  // الاستعلام أي مستند لا يملك حقل الترتيب (createdAt)، فلو وُجد عرض قديم
  // بلا createdAt لاختفى من كل التبويبات دون أي تنبيه. الترتيب "الأحدث
  // أولاً" يتم بدلاً من ذلك على العميل بعد الجلب (انظر SortByCreatedAt
  // أدناه)، وهذا يُلغي أيضاً الحاجة لفهرس مركّب (providerUserId+createdAt) ──
  Stream<QuerySnapshot> _myOffersStream() => FirebaseFirestore.instance
      .collection('offers')
      .where('providerUserId', isEqualTo: _uid)
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
          // نفس القائمة محلياً، بلا استعلامات Firestore إضافية. حالة كل
          // عرض (منتهي/متبقٍّ/شارة) تُحسب مرة واحدة هنا بدل إعادة حسابها
          // لكل تبويب على حدة، وهو ما كان يجعل تبويب "منتهية" (أكبر تبويب
          // عادةً لأن العروض المنتهية تتراكم ولا تُحذف) أبطأ ملموساً ──
          final entries = snapshot.data!.docs.map(_OfferEntry.from).toList()
            ..sort(_compareNewestFirst);

          return TabBarView(
            controller: _tabController,
            children: _kFilterKeys.map((filter) {
              final rows = filter == null
                  ? entries
                  : entries.where((e) => _matchesFilter(e, filter)).toList();
              return _OffersListView(entries: rows);
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
  final List<_OfferEntry> entries;
  const _OffersListView({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
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
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final doc = entry.doc;
        final data = entry.data;

        final title = data['title'] ?? 'باقة طعام';
        final description = data['description'] ?? '';
        final imageUrl = data['imageUrl'] ?? '';
        final quantity = data['quantity'] ?? 0;
        final remainingQuantity = data['remainingQuantity'] ?? 0;
        final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
        final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
        final currency = data['currency'] ?? 'ILS';
        final rawStatus = (data['status'] as String?) ?? 'unknown';
        final expired = entry.expired;
        final badgeStatus = entry.badgeStatus;
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
