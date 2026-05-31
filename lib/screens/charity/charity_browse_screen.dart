import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/location_service.dart';
import '../../services/reservation_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';

class CharityBrowseScreen extends StatefulWidget {
  const CharityBrowseScreen({super.key});

  @override
  State<CharityBrowseScreen> createState() => _CharityBrowseScreenState();
}

class _CharityBrowseScreenState extends State<CharityBrowseScreen> {
  String _filterType = 'all'; // all | free | paid
  bool _locationLoading = true;
  double? _userLat;
  double? _userLng;
  double _radiusKm = 10.0;

  final _radiusOptions = [2.0, 5.0, 10.0, 20.0, 50.0];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _locationLoading = true);
    final pos = await LocationService().getCurrentLocation();
    setState(() {
      _userLat = pos?.latitude;
      _userLng = pos?.longitude;
      _locationLoading = false;
    });
  }

  double? _calcDistance(Map<String, dynamic> data) {
    if (_userLat == null || _userLng == null) return null;
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (lat == null || lng == null) return null;
    return LocationService().distanceKm(
      lat1: _userLat!,
      lon1: _userLng!,
      lat2: (lat as num).toDouble(),
      lon2: (lng as num).toDouble(),
    );
  }

  List<QueryDocumentSnapshot> _filterAndSort(List<QueryDocumentSnapshot> docs) {
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (_filterType == 'free') return data['isFree'] == true;
      if (_filterType == 'paid') return data['isFree'] != true;
      return true;
    }).toList();

    if (_userLat != null) {
      filtered.sort((a, b) {
        final da = _calcDistance(a.data() as Map<String, dynamic>);
        final db = _calcDistance(b.data() as Map<String, dynamic>);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

      filtered = filtered.where((doc) {
        final d = _calcDistance(doc.data() as Map<String, dynamic>);
        return d == null || d <= _radiusKm;
      }).toList();
    }

    return filtered;
  }

  String _providerLabel(String role) {
    switch (role) {
      case 'restaurant':
        return 'مطعم';
      case 'individual':
        return 'فرد';
      case 'charity':
        return 'جمعية';
      default:
        return 'مزوّد طعام';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تصفح العروض'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── شريط الفلترة ──
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_list_rounded,
                        size: 18, color: AppColors.textLight),
                    const SizedBox(width: 8),
                    ...[('الكل', 'all'), ('مجاني', 'free'), ('مدفوع', 'paid')]
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _FilterChip(
                                label: e.$1,
                                selected: _filterType == e.$2,
                                onTap: () => setState(() => _filterType = e.$2),
                              ),
                            )),
                    const Spacer(),
                    GestureDetector(
                      onTap: _loadLocation,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _userLat != null
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _userLat != null
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.near_me_rounded,
                                size: 14,
                                color: _userLat != null
                                    ? Colors.white
                                    : AppColors.textLight),
                            const SizedBox(width: 4),
                            Text('الأقرب',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _userLat != null
                                        ? Colors.white
                                        : AppColors.textLight)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // النطاق
                if (_userLat != null) ...[
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
                                  '${r.round()} كم',
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

                // حالة الموقع
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
                ] else if (_userLat == null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _loadLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
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
                          Text('الموقع غير متاح — اضغط للمحاولة',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.secondary)),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.my_location_rounded,
                          size: 13, color: AppColors.success),
                      const SizedBox(width: 5),
                      Text(
                        'موقعك محدد — ضمن ${_radiusKm.round()} كم',
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
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                      child: Text('حدث خطأ أثناء تحميل العروض'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sorted = _filterAndSort(snap.data!.docs);

                if (sorted.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.no_food_rounded,
                              size: 60,
                              color: AppColors.primary.withOpacity(0.3)),
                          const SizedBox(height: 14),
                          Text(
                            _userLat != null
                                ? 'لا توجد عروض ضمن ${_radiusKm.round()} كم'
                                : 'لا توجد عروض متاحة حالياً',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 14),
                          ),
                          if (_userLat != null) ...[
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () => setState(() => _radiusKm = 50),
                              icon: const Icon(Icons.zoom_out_map_rounded,
                                  size: 18),
                              label: const Text('توسيع النطاق'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final doc = sorted[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final distance = _calcDistance(data);
                    return _CharityOfferCard(
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
      ),
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة العرض للجمعية
// ─────────────────────────────────────────────
class _CharityOfferCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String providerLabel;
  final double? distance;

  const _CharityOfferCard({
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
    final remainingQuantity = data['remainingQuantity'] ?? 0;
    final currency = data['currency'] ?? 'ILS';
    final imageUrl = data['imageUrl'] ?? '';
    final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
    final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
    final isFree = data['isFree'] == true || discountPrice == 0;
    final discountPercent = calcDiscountPercent(originalPrice, discountPrice);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── صورة ──
          Stack(
            children: [
              imageUrl.isNotEmpty
                  ? Image.network(imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => buildImagePlaceholder(
                          icon: Icons.restaurant_rounded, height: 160))
                  : buildImagePlaceholder(
                      icon: Icons.restaurant_rounded, height: 160),
              Positioned(
                top: 10,
                right: 10,
                child: buildPriceBadge(
                    isFree: isFree, discountPercent: discountPercent),
              ),
              Positioned(
                top: 10,
                left: 10,
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
              if (distance != null)
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.9),
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
                ),
            ],
          ),

          // ── تفاصيل ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textLight,
                          height: 1.5,
                          fontSize: 13)),
                ],
                const SizedBox(height: 12),
                OfferPriceRow(
                  isFree: isFree,
                  originalPrice: originalPrice,
                  discountPrice: discountPrice,
                  currency: currency,
                ),
                const SizedBox(height: 10),
                OfferInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'مكان الاستلام',
                  value: distance != null
                      ? '$pickupLocation  •  ${LocationService().formatDistance(distance!)}'
                      : pickupLocation,
                ),
                OfferInfoRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'الكمية المتاحة',
                  value: '$remainingQuantity',
                ),
                const SizedBox(height: 12),
                _ReserveButton(docId: docId, data: data),
              ],
            ),
          ),
        ],
      ),
    );
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
    setState(() => _loading = true);
    try {
      final reservationId = await ReservationService().reserveOffer(
        offerId: widget.docId,
        offerData: widget.data,
      );
      final userId = FirebaseAuth.instance.currentUser!.uid;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('تم الحجز! رقم الحجز: $reservationId'),
            ],
          ),
          backgroundColor: AppColors.success,
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
        label: Text(_loading ? 'جاري الحجز...' : 'حجز للجمعية'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Filter Chip
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
