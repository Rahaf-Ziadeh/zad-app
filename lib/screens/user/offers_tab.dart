import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'payment_method_screen.dart';
import '../../services/reservation_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';
import 'offer_details_screen.dart';
import 'qr_code_screen.dart';

class OffersTab extends StatefulWidget {
  const OffersTab({super.key});

  @override
  State<OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends State<OffersTab> {
  // ── فلاتر ──
  String _priceFilter = 'all';        // all | free | paid
  String _providerTypeFilter = 'all'; // all | restaurant | charity | individual
  String _categoryFilter = 'all';
  String _sortOrder = 'newest';       // newest | nearest | price_asc
  double _radiusKm = 10.0;

  // ── موقع ──
  Position? _userPosition;
  bool _locationLoading = true;

  static const _radiusOptions = [2.0, 5.0, 10.0, 20.0, 50.0];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _locationLoading = true);
    final pos = await LocationService().getCurrentLocation();
    setState(() {
      _userPosition = pos;
      _locationLoading = false;
    });
  }

  // ── عدد الفلاتر النشطة ──
  int get _activeFilterCount {
    int c = 0;
    if (_priceFilter != 'all') c++;
    if (_providerTypeFilter != 'all') c++;
    if (_categoryFilter != 'all') c++;
    if (_sortOrder != 'newest') c++;
    return c;
  }

  // ── الفلاتر النشطة كـ chips ──
  List<(String, VoidCallback)> get _activeChips {
    final chips = <(String, VoidCallback)>[];

    const priceLabels = {'free': 'مجاني', 'paid': 'مخفّض'};
    if (_priceFilter != 'all') {
      chips.add((priceLabels[_priceFilter]!,
          () => setState(() => _priceFilter = 'all')));
    }

    const provLabels = {
      'restaurant': 'مطعم',
      'charity': 'جمعية',
      'individual': 'مستخدم',
    };
    if (_providerTypeFilter != 'all') {
      chips.add((provLabels[_providerTypeFilter]!,
          () => setState(() => _providerTypeFilter = 'all')));
    }

    if (_categoryFilter != 'all') {
      chips.add((_categoryFilter,
          () => setState(() => _categoryFilter = 'all')));
    }

    if (_sortOrder == 'nearest') {
      chips.add(('الأقرب (${_radiusKm.round()} كم)',
          () => setState(() => _sortOrder = 'newest')));
    } else if (_sortOrder == 'price_asc') {
      chips.add(
          ('الأقل سعراً', () => setState(() => _sortOrder = 'newest')));
    }

    return chips;
  }

  // ── فتح صحيفة الفلترة ──
  void _openFilterSheet() {
    var tempPrice = _priceFilter;
    var tempProvider = _providerTypeFilter;
    var tempCategory = _categoryFilter;
    var tempSort = _sortOrder;
    var tempRadius = _radiusKm;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── handle ──
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── عنوان + مسح ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                child: Row(
                  children: [
                    const Text('خيارات الفلترة',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _priceFilter = 'all';
                          _providerTypeFilter = 'all';
                          _categoryFilter = 'all';
                          _sortOrder = 'newest';
                          _radiusKm = 10.0;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('مسح الفلاتر',
                          style: TextStyle(color: AppColors.secondary)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── محتوى قابل للتمرير ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // نوع المزود
                      _SheetSection(title: 'نوع المزود', chips: [
                        _SheetChip(
                            label: 'الكل',
                            selected: tempProvider == 'all',
                            onTap: () => ss(() => tempProvider = 'all')),
                        _SheetChip(
                            label: 'مطعم',
                            selected: tempProvider == 'restaurant',
                            onTap: () => ss(() => tempProvider = 'restaurant')),
                        _SheetChip(
                            label: 'جمعية',
                            selected: tempProvider == 'charity',
                            onTap: () => ss(() => tempProvider = 'charity')),
                        _SheetChip(
                            label: 'مستخدم',
                            selected: tempProvider == 'individual',
                            onTap: () => ss(() => tempProvider = 'individual')),
                      ]),

                      // السعر
                      _SheetSection(title: 'السعر', chips: [
                        _SheetChip(
                            label: 'الكل',
                            selected: tempPrice == 'all',
                            onTap: () => ss(() => tempPrice = 'all')),
                        _SheetChip(
                            label: 'مجاني',
                            selected: tempPrice == 'free',
                            onTap: () => ss(() => tempPrice = 'free')),
                        _SheetChip(
                            label: 'مخفّض',
                            selected: tempPrice == 'paid',
                            onTap: () => ss(() => tempPrice = 'paid')),
                      ]),

                      // الفئة
                      _SheetSection(title: 'الفئة', chips: [
                        _SheetChip(
                            label: 'الكل',
                            selected: tempCategory == 'all',
                            onTap: () => ss(() => tempCategory = 'all')),
                        _SheetChip(
                            label: 'وجبات',
                            selected: tempCategory == 'وجبات',
                            onTap: () => ss(() => tempCategory = 'وجبات')),
                        _SheetChip(
                            label: 'مخبوزات',
                            selected: tempCategory == 'مخبوزات',
                            onTap: () => ss(() => tempCategory = 'مخبوزات')),
                        _SheetChip(
                            label: 'خضار وفواكه',
                            selected: tempCategory == 'خضار وفواكه',
                            onTap: () =>
                                ss(() => tempCategory = 'خضار وفواكه')),
                        _SheetChip(
                            label: 'حلويات',
                            selected: tempCategory == 'حلويات',
                            onTap: () => ss(() => tempCategory = 'حلويات')),
                        _SheetChip(
                            label: 'أخرى',
                            selected: tempCategory == 'أخرى',
                            onTap: () => ss(() => tempCategory = 'أخرى')),
                      ]),

                      // الترتيب
                      _SheetSection(title: 'الترتيب', chips: [
                        _SheetChip(
                            label: 'الأحدث',
                            selected: tempSort == 'newest',
                            onTap: () => ss(() => tempSort = 'newest')),
                        _SheetChip(
                          label: 'الأقرب',
                          selected: tempSort == 'nearest',
                          disabled: _userPosition == null,
                          subtitle: _userPosition == null
                              ? 'الموقع غير متاح حالياً'
                              : null,
                          onTap: () => ss(() => tempSort = 'nearest'),
                        ),
                        _SheetChip(
                            label: 'الأقل سعراً',
                            selected: tempSort == 'price_asc',
                            onTap: () => ss(() => tempSort = 'price_asc')),
                      ]),

                      // النطاق — يظهر فقط عند اختيار الأقرب
                      if (tempSort == 'nearest' &&
                          _userPosition != null) ...[
                        const Text('النطاق',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _radiusOptions
                              .map((r) => _SheetChip(
                                    label: '${r.round()} كم',
                                    selected: tempRadius == r,
                                    onTap: () => ss(() => tempRadius = r),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),
              // ── تطبيق ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _priceFilter = tempPrice;
                        _providerTypeFilter = tempProvider;
                        _categoryFilter = tempCategory;
                        _sortOrder = tempSort;
                        _radiusKm = tempRadius;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('تطبيق'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── فلترة وترتيب ──
  List<QueryDocumentSnapshot> _sortAndFilter(
      List<QueryDocumentSnapshot> docs) {
    var filtered = List<QueryDocumentSnapshot>.from(docs);

    if (_priceFilter != 'all') {
      filtered = filtered.where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return _priceFilter == 'free'
            ? d['isFree'] == true
            : d['isFree'] != true;
      }).toList();
    }

    if (_providerTypeFilter != 'all') {
      filtered = filtered.where((doc) {
        return (doc.data() as Map<String, dynamic>)['providerRole'] ==
            _providerTypeFilter;
      }).toList();
    }

    if (_categoryFilter != 'all') {
      const knownCats = {
        'وجبات',
        'مخبوزات',
        'خضار وفواكه',
        'معلبات',
        'حلويات'
      };
      filtered = filtered.where((doc) {
        final cat =
            ((doc.data() as Map<String, dynamic>)['category'] as String? ?? '')
                .trim();
        if (_categoryFilter == 'أخرى') {
          return cat.isEmpty || !knownCats.contains(cat);
        }
        return cat == _categoryFilter;
      }).toList();
    }

    if (_sortOrder == 'newest') {
      filtered.sort((a, b) {
        final at = (a.data() as Map<String, dynamic>)['createdAt'];
        final bt = (b.data() as Map<String, dynamic>)['createdAt'];
        if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
        return 0;
      });
    } else if (_sortOrder == 'nearest' && _userPosition != null) {
      filtered.sort((a, b) {
        final da = _calcDistance(a.data() as Map<String, dynamic>);
        final db = _calcDistance(b.data() as Map<String, dynamic>);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
      filtered = filtered.where((doc) {
        final dist = _calcDistance(doc.data() as Map<String, dynamic>);
        return dist == null || dist <= _radiusKm;
      }).toList();
    } else if (_sortOrder == 'price_asc') {
      filtered.sort((a, b) {
        final pa = ((a.data() as Map<String, dynamic>)['discountPrice'] ??
            (a.data() as Map<String, dynamic>)['price'] ??
            0) as num;
        final pb = ((b.data() as Map<String, dynamic>)['discountPrice'] ??
            (b.data() as Map<String, dynamic>)['price'] ??
            0) as num;
        return pa.compareTo(pb);
      });
    }

    return filtered;
  }

  double? _calcDistance(Map<String, dynamic> data) {
    if (_userPosition == null) return null;
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (lat == null || lng == null) return null;
    return LocationService().distanceKm(
      lat1: _userPosition!.latitude,
      lon1: _userPosition!.longitude,
      lat2: (lat as num).toDouble(),
      lon2: (lng as num).toDouble(),
    );
  }

  String _providerLabel(String role) {
    switch (role) {
      case 'restaurant':
        return 'مطعم';
      case 'charity':
        return 'جمعية خيرية';
      case 'individual':
        return 'فرد';
      default:
        return 'مزوّد طعام';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chips = _activeChips;

    return Column(
      children: [
        // ── شريط الفلاتر ──
        Container(
          color: AppColors.card,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              // زر فلترة
              GestureDetector(
                onTap: _openFilterSheet,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _activeFilterCount > 0
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _activeFilterCount > 0
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 16,
                          color: _activeFilterCount > 0
                              ? Colors.white
                              : AppColors.textLight),
                      const SizedBox(width: 6),
                      Text('فلترة',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _activeFilterCount > 0
                                  ? Colors.white
                                  : AppColors.textLight)),
                      if (_activeFilterCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('$_activeFilterCount',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // الفلاتر النشطة
              if (chips.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: chips
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _ActiveFilterChip(
                                    label: c.$1, onClear: c.$2),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ] else
                const Spacer(),

              // مؤشر الموقع
              const SizedBox(width: 8),
              if (_locationLoading)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else if (_userPosition != null)
                const Icon(Icons.my_location_rounded,
                    size: 16, color: AppColors.success)
              else
                GestureDetector(
                  onTap: _loadLocation,
                  child: const Icon(Icons.location_off_rounded,
                      size: 16, color: AppColors.secondary),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── قائمة العروض ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('offers')
                .where('status', isEqualTo: 'available')
                .where('offerType', whereNotIn: [
              'restaurant_package',
              'mystery_package'
            ]).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(snapshot.error.toString(),
                        style: const TextStyle(color: Colors.red)),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final sorted = _sortAndFilter(snapshot.data!.docs);

              if (sorted.isEmpty) {
                return _EmptyState(
                  message: _sortOrder == 'nearest' && _userPosition != null
                      ? 'لا توجد عروض ضمن ${_radiusKm.round()} كم منك'
                      : 'لا توجد عروض تطابق الفلتر المحدد',
                  onRetry: _sortOrder == 'nearest' && _userPosition != null
                      ? () => setState(() => _radiusKm = 50)
                      : null,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final doc = sorted[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final distance = _userPosition != null
                      ? _calcDistance(data)
                      : null;
                  return _OfferCard(
                    docId: doc.id,
                    data: data,
                    providerLabel:
                        _providerLabel(data['providerRole'] ?? ''),
                    distance: distance,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة العرض
// ─────────────────────────────────────────────
class _OfferCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String providerLabel;
  final double? distance;

  const _OfferCard({
    required this.docId,
    required this.data,
    required this.providerLabel,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'عرض طعام';
    final description = data['description'] ?? '';
    final pickupLocation = data['pickupLocation'] ?? 'غير محدد';
    final pickupTime = data['pickupTime'] ?? '';
    final remainingQuantity = data['remainingQuantity'] ?? 0;
    final currency = data['currency'] ?? 'ILS';
    final imageUrl = data['imageUrl'] ?? '';
    final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
    final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
    final isFree = data['isFree'] == true || discountPrice == 0;
    final discountPercent = calcDiscountPercent(originalPrice, discountPrice);
    final hasLocation = data['hasLocation'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OfferDetailsScreen(
              docId: docId,
              data: data,
              distance: distance,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 170,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => buildImagePlaceholder(
                            icon: Icons.restaurant_rounded),
                      )
                    : buildImagePlaceholder(icon: Icons.restaurant_rounded),

                Positioned(
                  top: 12,
                  right: 12,
                  child: buildPriceBadge(
                      isFree: isFree, discountPercent: discountPercent),
                ),

                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(providerLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                if (distance != null)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _distanceColor(distance!).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me_rounded,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            LocationService().formatDistance(distance!),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!hasLocation)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off_rounded,
                              size: 12, color: Colors.white70),
                          SizedBox(width: 4),
                          Text('بدون موقع',
                              style:
                                  TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textLight,
                            height: 1.5,
                            fontSize: 13)),
                  ],
                  const SizedBox(height: 14),
                  OfferPriceRow(
                    isFree: isFree,
                    originalPrice: originalPrice,
                    discountPrice: discountPrice,
                    currency: currency,
                  ),
                  const SizedBox(height: 12),
                  OfferInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'مكان الاستلام',
                    value: distance != null
                        ? '$pickupLocation  •  ${LocationService().formatDistance(distance!)}'
                        : pickupLocation,
                  ),
                  if (pickupTime.toString().isNotEmpty)
                    OfferInfoRow(
                      icon: Icons.access_time_outlined,
                      label: 'وقت الاستلام',
                      value: pickupTime.toString(),
                    ),
                  OfferInfoRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'الكمية المتاحة',
                    value: '$remainingQuantity',
                  ),
                  const SizedBox(height: 14),
                  _ReserveButton(docId: docId, data: data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _distanceColor(double km) {
    if (km <= 1) return AppColors.success;
    if (km <= 5) return AppColors.primary;
    if (km <= 15) return AppColors.secondary;
    return Colors.grey;
  }
}

// ─────────────────────────────────────────────
// زر الحجز
// ─────────────────────────────────────────────
class _ReserveButton extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _ReserveButton({required this.docId, required this.data});

  @override
  State<_ReserveButton> createState() => _ReserveButtonState();
}

class _ReserveButtonState extends State<_ReserveButton> {
  bool _loading = false;

  Future<int?> _askQuantity(int maxQty) async {
    if (maxQty <= 1) return 1;
    final qty = [1];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setQtyState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.card,
          title: const Text('اختر الكمية',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textDark)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed:
                    qty[0] > 1 ? () => setQtyState(() => qty[0]--) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Text('${qty[0]}',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              const SizedBox(width: 12),
              IconButton(
                onPressed: qty[0] < maxQty
                    ? () => setQtyState(() => qty[0]++)
                    : null,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                color: AppColors.primary,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.textLight)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return null;
    return qty[0];
  }

  Future<void> _reserve() async {
    if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً للحجز')),
      );
      return;
    }

    final maxQty = (widget.data['remainingQuantity'] as num?)?.toInt() ?? 1;
    final selectedQty = await _askQuantity(maxQty);
    if (selectedQty == null || !mounted) return;

    final discountPrice =
        widget.data['discountPrice'] ?? widget.data['price'] ?? 0;
    final isFree = widget.data['isFree'] == true || discountPrice == 0;

    if (!isFree) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentMethodScreen(
            docId: widget.docId,
            data: widget.data,
            selectedQuantity: selectedQty,
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final reservationId = await ReservationService().reserveOffer(
        offerId: widget.docId,
        offerData: widget.data,
        selectedQuantity: selectedQty,
      );
      final userId = FirebaseAuth.instance.currentUser!.uid;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrCodeScreen(
            reservationId: reservationId,
            offerId: widget.docId,
            userId: userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final discountPrice =
        widget.data['discountPrice'] ?? widget.data['price'] ?? 0;
    final isFree = widget.data['isFree'] == true || discountPrice == 0;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _reserve,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Icon(isFree
                ? Icons.volunteer_activism_rounded
                : Icons.payment_rounded),
        label: Text(_loading
            ? 'جاري الحجز...'
            : isFree
                ? 'حجز مجاني'
                : 'احجز وادفع'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widgets مشتركة
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _EmptyState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_food_rounded,
                size: 60,
                color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textLight, fontSize: 14)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
                label: const Text('توسيع النطاق'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  final List<Widget> chips;
  const _SheetSection({required this.title, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SheetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool disabled;
  final String? subtitle;

  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        disabled ? AppColors.textLight.withValues(alpha: 0.4) : null;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (disabled
                  ? AppColors.background
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (disabled
                    ? AppColors.border.withValues(alpha: 0.5)
                    : AppColors.border),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : (effectiveColor ?? AppColors.textDark))),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: TextStyle(
                      fontSize: 10,
                      color:
                          effectiveColor ?? AppColors.textLight)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;
  const _ActiveFilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
