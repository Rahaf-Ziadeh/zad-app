import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

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
  String _filterType = 'all';
  String _providerTypeFilter = 'all';
  Position? _userPosition;
  bool _locationLoading = true;
  bool _sortByDistance = true;

  // نطاق الفلترة بالكيلومتر
  double _radiusKm = 10.0;
  final _radiusOptions = [2.0, 5.0, 10.0, 20.0, 50.0];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _locationLoading = true);

    final position = await LocationService().getCurrentLocation();

    print('LAT: ${position?.latitude}');
    print('LNG: ${position?.longitude}');

    setState(() {
      _userPosition = position;
      _locationLoading = false;
    });
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

  // ── فلترة وترتيب العروض بالمسافة ──
  List<QueryDocumentSnapshot> _sortAndFilter(List<QueryDocumentSnapshot> docs) {
    // فلترة السعر
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (_filterType == 'free') return data['isFree'] == true;
      if (_filterType == 'paid') return data['isFree'] != true;
      return true;
    }).toList();
    filtered = filtered.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final providerRole = data['providerRole'] ?? '';

      if (_providerTypeFilter == 'all') return true;
      return providerRole == _providerTypeFilter;
    }).toList();
    // ترتيب بالمسافة لو عندنا موقع
    if (_userPosition != null && _sortByDistance) {
      filtered.sort((a, b) {
        final da = a.data() as Map<String, dynamic>;
        final db = b.data() as Map<String, dynamic>;

        final distA = _calcDistance(da);
        final distB = _calcDistance(db);

        // العروض بدون موقع تجي في الآخر
        if (distA == null && distB == null) return 0;
        if (distA == null) return 1;
        if (distB == null) return -1;
        return distA.compareTo(distB);
      });

      // فلترة بالنطاق المحدد
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final dist = _calcDistance(data);
        if (dist == null) return false;
        return dist <= _radiusKm;
      }).toList();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── شريط الفلترة والموقع ──
        Container(
          color: AppColors.card,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            children: [
              // فلتر السعر + ترتيب المسافة
              Row(
                children: [
                  const Icon(Icons.filter_list_rounded,
                      size: 18, color: AppColors.textLight),
                  const SizedBox(width: 8),
                  ...[('الكل', 'all'), ('مجاني', 'free'), ('مخفّض', 'paid')]
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _FilterChip(
                              label: e.$1,
                              selected: _filterType == e.$2,
                              onTap: () => setState(() => _filterType = e.$2),
                            ),
                          )),
                  const Spacer(),
                  // زر ترتيب بالمسافة
                  GestureDetector(
                    onTap: () =>
                        setState(() => _sortByDistance = !_sortByDistance),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _sortByDistance && _userPosition != null
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _sortByDistance && _userPosition != null
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.near_me_rounded,
                            size: 14,
                            color: _sortByDistance && _userPosition != null
                                ? Colors.white
                                : AppColors.textLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'الأقرب',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _sortByDistance && _userPosition != null
                                  ? Colors.white
                                  : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 18, color: AppColors.textLight),
                  const SizedBox(width: 8),
                  ...[
                    ('كل المزودين', 'all'),
                    ('مطعم', 'restaurant'),
                    ('جمعية', 'charity'),
                    ('فرد', 'individual'),
                  ].map((e) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChip(
                          label: e.$1,
                          selected: _providerTypeFilter == e.$2,
                          onTap: () =>
                              setState(() => _providerTypeFilter = e.$2),
                        ),
                      )),
                ],
              ),
              // ── شريط النطاق (يظهر فقط لو الترتيب بالمسافة مفعّل) ──
              if (_sortByDistance && _userPosition != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.radar_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text('النطاق:',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    ..._radiusOptions.map((r) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _radiusKm = r),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _radiusKm == r
                                    ? AppColors.primary.withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _radiusKm == r
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                r < 1
                                    ? '${(r * 1000).round()}م'
                                    : '${r.round()} كم',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _radiusKm == r
                                      ? AppColors.primary
                                      : AppColors.textLight,
                                ),
                              ),
                            ),
                          ),
                        )),
                  ],
                ),
              ],

              // ── حالة الموقع ──
              if (_locationLoading) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('جاري تحديد موقعك...',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ] else if (_userPosition == null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _loadLocation,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.secondary.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_off_rounded,
                            size: 14, color: AppColors.secondary),
                        SizedBox(width: 6),
                        Text(
                          'الموقع غير متاح — اضغط للمحاولة مجدداً',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.my_location_rounded,
                        size: 13, color: AppColors.success),
                    const SizedBox(width: 5),
                    Text(
                      'موقعك محدد — يعرض العروض ضمن ${_radiusKm.round()} كم',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.success),
                    ),
                  ],
                ),
              ],
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
                .where('offerType',
                    whereNotIn: ['restaurant_package']).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print(snapshot.error);

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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

              final sorted = _sortAndFilter(snapshot.data!.docs);

              if (sorted.isEmpty) {
                return _EmptyState(
                  message: _userPosition != null && _sortByDistance
                      ? 'لا توجد عروض ضمن ${_radiusKm.round()} كم منك'
                      : 'لا توجد عروض متاحة حالياً',
                  onRetry: _userPosition != null && _sortByDistance
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
                  final distance = _calcDistance(data);
                  return _OfferCard(
                    docId: doc.id,
                    data: data,
                    providerLabel: _providerLabel(data['providerRole'] ?? ''),
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
// بطاقة العرض مع المسافة
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
            // ── صورة ──
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

                // Badge السعر
                Positioned(
                  top: 12,
                  right: 12,
                  child: buildPriceBadge(
                      isFree: isFree, discountPercent: discountPercent),
                ),

                // Badge المزوّد
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(providerLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                // ── Badge المسافة ──
                if (distance != null)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _distanceColor(distance!).withOpacity(0.9),
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
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off_rounded,
                              size: 12, color: Colors.white70),
                          SizedBox(width: 4),
                          Text('بدون موقع',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // ── تفاصيل ──
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

  // لون الـ badge حسب المسافة
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

  Future<void> _reserve() async {
    if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً للحجز'),
        ),
      );
      return;
    }

    
    setState(() => _loading = true);
    try {
      final reservationId = await ReservationService().reserveOffer(
        offerId: widget.docId,
        offerData: widget.data,
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _reserve,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.shopping_bag_outlined),
        label: Text(_loading ? 'جاري الحجز...' : 'حجز العرض'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widgets مساعدة
// ─────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textLight)),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: AppColors.textLight, fontSize: 14)),
        ],
      ),
    );
  }
}

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
                size: 60, color: AppColors.primary.withOpacity(0.3)),
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
