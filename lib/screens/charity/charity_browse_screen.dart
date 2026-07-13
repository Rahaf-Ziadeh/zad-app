import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/charity_browse_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/charity_widgets.dart';

class CharityBrowseScreen extends StatefulWidget {
  const CharityBrowseScreen({super.key});

  @override
  State<CharityBrowseScreen> createState() => _CharityBrowseScreenState();
}

class _CharityBrowseScreenState extends State<CharityBrowseScreen> {
  final CharityBrowseService _browseService = CharityBrowseService();

  String _priceFilter = 'all'; // all | free | paid
  String _providerTypeFilter = 'all'; // all | restaurant | charity | individual
  String _categoryFilter = 'all';
  String _sortOrder = 'newest'; // newest | nearest | price_asc
  double _radiusKm = 10.0;

  double? _userLat;
  double? _userLng;
  bool _locationLoading = true;

  static const _radiusOptions = [2.0, 5.0, 10.0, 20.0, 50.0];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _locationLoading = true);

    try {
      final coordinates = await _browseService.loadCurrentCoordinates();

      if (!mounted) return;
      setState(() {
        _userLat = coordinates.latitude;
        _userLng = coordinates.longitude;
        _locationLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userLat = null;
        _userLng = null;
        _locationLoading = false;
      });
    }
  }

  bool get _hasLocation => _browseService.hasLocation(
        userLat: _userLat,
        userLng: _userLng,
      );

  double? _calcDistance(Map<String, dynamic> data) {
    return _browseService.calculateDistance(
      offerData: data,
      userLat: _userLat,
      userLng: _userLng,
    );
  }

  int get _activeFilterCount => _browseService.activeFilterCount(
        priceFilter: _priceFilter,
        providerTypeFilter: _providerTypeFilter,
        categoryFilter: _categoryFilter,
        sortOrder: _sortOrder,
      );

  List<(String, VoidCallback)> get _activeChips {
    final chips = <(String, VoidCallback)>[];

    const priceLabels = {'free': 'مجاني', 'paid': 'مخفّض'};
    if (_priceFilter != 'all') {
      chips.add((
        priceLabels[_priceFilter]!,
        () => setState(() => _priceFilter = 'all')
      ));
    }

    const provLabels = {
      'restaurant': 'مطعم',
      'charity': 'جمعية',
      'individual': 'مستخدم',
    };
    if (_providerTypeFilter != 'all') {
      chips.add((
        provLabels[_providerTypeFilter]!,
        () => setState(() => _providerTypeFilter = 'all')
      ));
    }

    if (_categoryFilter != 'all') {
      chips.add(
          (_categoryFilter, () => setState(() => _categoryFilter = 'all')));
    }

    if (_sortOrder == 'nearest') {
      chips.add((
        'الأقرب (${_radiusKm.round()} كم)',
        () => setState(() => _sortOrder = 'newest')
      ));
    } else if (_sortOrder == 'price_asc') {
      chips.add(('الأقل سعراً', () => setState(() => _sortOrder = 'newest')));
    }

    return chips;
  }

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
              // handle
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

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SheetSection(title: 'نوع المزود', chips: [
                        SheetChip(
                            label: 'الكل',
                            selected: tempProvider == 'all',
                            onTap: () => ss(() => tempProvider = 'all')),
                        SheetChip(
                            label: 'مطعم',
                            selected: tempProvider == 'restaurant',
                            onTap: () => ss(() => tempProvider = 'restaurant')),
                        SheetChip(
                            label: 'جمعية',
                            selected: tempProvider == 'charity',
                            onTap: () => ss(() => tempProvider = 'charity')),
                        SheetChip(
                            label: 'مستخدم',
                            selected: tempProvider == 'individual',
                            onTap: () => ss(() => tempProvider = 'individual')),
                      ]),

                      SheetSection(title: 'السعر', chips: [
                        SheetChip(
                            label: 'الكل',
                            selected: tempPrice == 'all',
                            onTap: () => ss(() => tempPrice = 'all')),
                        SheetChip(
                            label: 'مجاني',
                            selected: tempPrice == 'free',
                            onTap: () => ss(() => tempPrice = 'free')),
                        SheetChip(
                            label: 'مخفّض',
                            selected: tempPrice == 'paid',
                            onTap: () => ss(() => tempPrice = 'paid')),
                      ]),

                      SheetSection(title: 'الفئة', chips: [
                        SheetChip(
                            label: 'الكل',
                            selected: tempCategory == 'all',
                            onTap: () => ss(() => tempCategory = 'all')),
                        SheetChip(
                            label: 'وجبات',
                            selected: tempCategory == 'وجبات',
                            onTap: () => ss(() => tempCategory = 'وجبات')),
                        SheetChip(
                            label: 'مخبوزات',
                            selected: tempCategory == 'مخبوزات',
                            onTap: () => ss(() => tempCategory = 'مخبوزات')),
                        SheetChip(
                            label: 'خضار وفواكه',
                            selected: tempCategory == 'خضار وفواكه',
                            onTap: () =>
                                ss(() => tempCategory = 'خضار وفواكه')),
                        SheetChip(
                            label: 'حلويات',
                            selected: tempCategory == 'حلويات',
                            onTap: () => ss(() => tempCategory = 'حلويات')),
                        SheetChip(
                            label: 'أخرى',
                            selected: tempCategory == 'أخرى',
                            onTap: () => ss(() => tempCategory = 'أخرى')),
                      ]),

                      SheetSection(title: 'الترتيب', chips: [
                        SheetChip(
                            label: 'الأحدث',
                            selected: tempSort == 'newest',
                            onTap: () => ss(() => tempSort = 'newest')),
                        SheetChip(
                          label: 'الأقرب',
                          selected: tempSort == 'nearest',
                          disabled: !_hasLocation,
                          subtitle:
                              !_hasLocation ? 'الموقع غير متاح حالياً' : null,
                          onTap: () => ss(() => tempSort = 'nearest'),
                        ),
                        SheetChip(
                            label: 'الأقل سعراً',
                            selected: tempSort == 'price_asc',
                            onTap: () => ss(() => tempSort = 'price_asc')),
                      ]),

                      if (tempSort == 'nearest' && _hasLocation) ...[
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
                              .map((r) => SheetChip(
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

  List<QueryDocumentSnapshot> _filterAndSort(
    List<QueryDocumentSnapshot> docs,
  ) {
    return _browseService.filterAndSortOffers(
      documents: docs,
      priceFilter: _priceFilter,
      providerTypeFilter: _providerTypeFilter,
      categoryFilter: _categoryFilter,
      sortOrder: _sortOrder,
      radiusKm: _radiusKm,
      userLat: _userLat,
      userLng: _userLng,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = _activeChips;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تصفح العروض'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
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
                if (chips.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: chips
                            .map((c) => Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: ActiveFilterChip(
                                      label: c.$1, onClear: c.$2),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                const SizedBox(width: 8),
                if (_locationLoading)
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else if (_hasLocation)
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

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _browseService.watchAvailableOffers(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                      child: Text('حدث خطأ أثناء تحميل العروض'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final visibleDocs =
                    _browseService.removeExpiredOffers(snap.data!.docs);
                final sorted = _filterAndSort(visibleDocs);

                if (sorted.isEmpty) {
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
                          Text(
                            _sortOrder == 'nearest' && _hasLocation
                                ? 'لا توجد عروض ضمن ${_radiusKm.round()} كم'
                                : 'لا توجد عروض تطابق الفلتر الحالي',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 14),
                          ),
                          if (_sortOrder == 'nearest' && _hasLocation) ...[
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
                    final distance = _hasLocation ? _calcDistance(data) : null;
                    return OfferCard(
                      browseService: _browseService,
                      docId: doc.id,
                      data: data,
                      providerLabel: _browseService
                          .providerLabel(data['providerRole'] ?? ''),
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
