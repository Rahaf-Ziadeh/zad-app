import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../screens/admin/admin_offer_details_screen.dart';
import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';

class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({super.key});

  @override
  State<AdminOffersScreen> createState() => _AdminOffersScreenState();
}

class _AdminOffersScreenState extends State<AdminOffersScreen> {
  // ── filter state ──
  String _providerTypeFilter = 'all';
  String _offerTypeFilter    = 'all';
  String _statusFilter       = 'all';
  String _priceFilter        = 'all';
  String _categoryFilter     = 'all';
  String _sortOrder          = 'newest';
  bool   _deleting           = false;

  // ── publisher name cache (keyed by providerUserId) ──
  final Map<String, String> _nameCache = {};

  final _svc = AdminService();

  // ── known categories (same set as AppConstants.foodCategories minus 'أخرى') ──
  static const _knownCats = {'وجبات', 'مخبوزات', 'خضار وفواكه', 'معلبات', 'حلويات'};

  // ─── active filter count / chips ─────────────────────────────────────────────

  int get _activeFilterCount {
    int c = 0;
    if (_providerTypeFilter != 'all') c++;
    if (_offerTypeFilter    != 'all') c++;
    if (_statusFilter       != 'all') c++;
    if (_priceFilter        != 'all') c++;
    if (_categoryFilter     != 'all') c++;
    if (_sortOrder          != 'newest') c++;
    return c;
  }

  List<(String, VoidCallback)> get _activeChips {
    final chips = <(String, VoidCallback)>[];

    const provLabels = {'restaurant': 'مطعم', 'charity': 'جمعية', 'individual': 'فرد'};
    if (_providerTypeFilter != 'all') {
      chips.add((
        provLabels[_providerTypeFilter] ?? _providerTypeFilter,
        () => setState(() => _providerTypeFilter = 'all'),
      ));
    }

    const typeLabels = {
      'clear_offer': 'عرض واضح',
      'mystery_package': 'باقة غامضة',
      'restaurant_package': 'باقة مطعم',
    };
    if (_offerTypeFilter != 'all') {
      chips.add((
        typeLabels[_offerTypeFilter] ?? _offerTypeFilter,
        () => setState(() => _offerTypeFilter = 'all'),
      ));
    }

    const statusLabels = {
      'available': 'متاح',
      'reserved': 'محجوز',
      'picked_up': 'تم الاستلام',
      'expired': 'منتهي',
      'cancelled': 'ملغي',
    };
    if (_statusFilter != 'all') {
      chips.add((
        statusLabels[_statusFilter] ?? _statusFilter,
        () => setState(() => _statusFilter = 'all'),
      ));
    }

    if (_priceFilter == 'free') {
      chips.add(('مجاني', () => setState(() => _priceFilter = 'all')));
    } else if (_priceFilter == 'paid') {
      chips.add(('مدفوع / مخفّض', () => setState(() => _priceFilter = 'all')));
    }

    if (_categoryFilter != 'all') {
      chips.add((_categoryFilter, () => setState(() => _categoryFilter = 'all')));
    }

    const sortLabels = {
      'oldest': 'الأقدم',
      'price_asc': 'الأقل سعراً',
      'price_desc': 'الأعلى سعراً',
    };
    if (_sortOrder != 'newest') {
      chips.add((
        sortLabels[_sortOrder] ?? _sortOrder,
        () => setState(() => _sortOrder = 'newest'),
      ));
    }

    return chips;
  }

  // ─── filter + sort (client-side) ─────────────────────────────────────────────

  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    var filtered = docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;

      if (_providerTypeFilter != 'all' && d['providerRole'] != _providerTypeFilter) {
        return false;
      }
      if (_offerTypeFilter != 'all' && d['offerType'] != _offerTypeFilter) {
        return false;
      }
      if (_statusFilter != 'all' && d['status'] != _statusFilter) {
        return false;
      }
      if (_priceFilter != 'all') {
        final isFree = d['isFree'] == true;
        if (_priceFilter == 'free' && !isFree) return false;
        if (_priceFilter == 'paid'  &&  isFree) return false;
      }
      if (_categoryFilter != 'all') {
        final cat = (d['category'] as String? ?? '').trim();
        if (_categoryFilter == 'أخرى') {
          if (_knownCats.contains(cat)) return false;
        } else if (cat != _categoryFilter) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_sortOrder) {
      case 'oldest':
        filtered.sort((a, b) {
          final at = (a.data() as Map<String, dynamic>)['createdAt'];
          final bt = (b.data() as Map<String, dynamic>)['createdAt'];
          if (at is Timestamp && bt is Timestamp) return at.compareTo(bt);
          return 0;
        });
      case 'price_asc':
        filtered.sort((a, b) {
          final pa = _effectivePrice(a.data() as Map<String, dynamic>);
          final pb = _effectivePrice(b.data() as Map<String, dynamic>);
          return pa.compareTo(pb);
        });
      case 'price_desc':
        filtered.sort((a, b) {
          final pa = _effectivePrice(a.data() as Map<String, dynamic>);
          final pb = _effectivePrice(b.data() as Map<String, dynamic>);
          return pb.compareTo(pa);
        });
      default: // 'newest' — Firestore already returns newest-first
        filtered.sort((a, b) {
          final at = (a.data() as Map<String, dynamic>)['createdAt'];
          final bt = (b.data() as Map<String, dynamic>)['createdAt'];
          if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
          return 0;
        });
    }

    return filtered;
  }

  num _effectivePrice(Map<String, dynamic> d) {
    final dp = d['discountPrice'];
    final p  = d['price'];
    if (dp is num) return dp;
    if (p  is num) return p;
    return 0;
  }

  // ─── filter bottom sheet ──────────────────────────────────────────────────────

  void _openFilterSheet() {
    var tempProvider = _providerTypeFilter;
    var tempType     = _offerTypeFilter;
    var tempStatus   = _statusFilter;
    var tempPrice    = _priceFilter;
    var tempCat      = _categoryFilter;
    var tempSort     = _sortOrder;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Container(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // handle bar
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
              // header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                child: Row(
                  children: [
                    const Text(
                      'خيارات الفلترة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _providerTypeFilter = 'all';
                          _offerTypeFilter    = 'all';
                          _statusFilter       = 'all';
                          _priceFilter        = 'all';
                          _categoryFilter     = 'all';
                          _sortOrder          = 'newest';
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'مسح الفلاتر',
                        style: TextStyle(color: AppColors.secondary),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // scrollable sections
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SheetSection(
                        title: 'نوع المزود',
                        chips: [
                          _SheetChip(label: 'الكل',    selected: tempProvider == 'all',        onTap: () => ss(() => tempProvider = 'all')),
                          _SheetChip(label: 'مطعم',    selected: tempProvider == 'restaurant',  onTap: () => ss(() => tempProvider = 'restaurant')),
                          _SheetChip(label: 'جمعية',   selected: tempProvider == 'charity',     onTap: () => ss(() => tempProvider = 'charity')),
                          _SheetChip(label: 'مستخدم',  selected: tempProvider == 'individual',  onTap: () => ss(() => tempProvider = 'individual')),
                        ],
                      ),
                      _SheetSection(
                        title: 'نوع العرض',
                        chips: [
                          _SheetChip(label: 'الكل',         selected: tempType == 'all',                onTap: () => ss(() => tempType = 'all')),
                          _SheetChip(label: 'عرض واضح',     selected: tempType == 'clear_offer',        onTap: () => ss(() => tempType = 'clear_offer')),
                          _SheetChip(label: 'باقة غامضة',   selected: tempType == 'mystery_package',    onTap: () => ss(() => tempType = 'mystery_package')),
                          _SheetChip(label: 'باقة مطعم',    selected: tempType == 'restaurant_package', onTap: () => ss(() => tempType = 'restaurant_package')),
                        ],
                      ),
                      _SheetSection(
                        title: 'الحالة',
                        chips: [
                          _SheetChip(label: 'الكل',         selected: tempStatus == 'all',       onTap: () => ss(() => tempStatus = 'all')),
                          _SheetChip(label: 'متاح',         selected: tempStatus == 'available', onTap: () => ss(() => tempStatus = 'available')),
                          _SheetChip(label: 'محجوز',        selected: tempStatus == 'reserved',  onTap: () => ss(() => tempStatus = 'reserved')),
                          _SheetChip(label: 'تم الاستلام',  selected: tempStatus == 'picked_up', onTap: () => ss(() => tempStatus = 'picked_up')),
                          _SheetChip(label: 'منتهي',        selected: tempStatus == 'expired',   onTap: () => ss(() => tempStatus = 'expired')),
                          _SheetChip(label: 'ملغي',         selected: tempStatus == 'cancelled', onTap: () => ss(() => tempStatus = 'cancelled')),
                        ],
                      ),
                      _SheetSection(
                        title: 'السعر',
                        chips: [
                          _SheetChip(label: 'الكل',           selected: tempPrice == 'all',  onTap: () => ss(() => tempPrice = 'all')),
                          _SheetChip(label: 'مجاني',          selected: tempPrice == 'free', onTap: () => ss(() => tempPrice = 'free')),
                          _SheetChip(label: 'مدفوع / مخفّض', selected: tempPrice == 'paid', onTap: () => ss(() => tempPrice = 'paid')),
                        ],
                      ),
                      _SheetSection(
                        title: 'الفئة',
                        chips: [
                          _SheetChip(label: 'الكل',          selected: tempCat == 'all',          onTap: () => ss(() => tempCat = 'all')),
                          _SheetChip(label: 'وجبات',         selected: tempCat == 'وجبات',        onTap: () => ss(() => tempCat = 'وجبات')),
                          _SheetChip(label: 'مخبوزات',       selected: tempCat == 'مخبوزات',      onTap: () => ss(() => tempCat = 'مخبوزات')),
                          _SheetChip(label: 'خضار وفواكه',   selected: tempCat == 'خضار وفواكه',  onTap: () => ss(() => tempCat = 'خضار وفواكه')),
                          _SheetChip(label: 'معلبات',        selected: tempCat == 'معلبات',       onTap: () => ss(() => tempCat = 'معلبات')),
                          _SheetChip(label: 'حلويات',        selected: tempCat == 'حلويات',       onTap: () => ss(() => tempCat = 'حلويات')),
                          _SheetChip(label: 'أخرى',          selected: tempCat == 'أخرى',         onTap: () => ss(() => tempCat = 'أخرى')),
                        ],
                      ),
                      _SheetSection(
                        title: 'الترتيب',
                        chips: [
                          _SheetChip(label: 'الأحدث',      selected: tempSort == 'newest',     onTap: () => ss(() => tempSort = 'newest')),
                          _SheetChip(label: 'الأقدم',      selected: tempSort == 'oldest',     onTap: () => ss(() => tempSort = 'oldest')),
                          _SheetChip(label: 'الأعلى سعراً', selected: tempSort == 'price_desc', onTap: () => ss(() => tempSort = 'price_desc')),
                          _SheetChip(label: 'الأقل سعراً', selected: tempSort == 'price_asc',  onTap: () => ss(() => tempSort = 'price_asc')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              // apply button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _providerTypeFilter = tempProvider;
                        _offerTypeFilter    = tempType;
                        _statusFilter       = tempStatus;
                        _priceFilter        = tempPrice;
                        _categoryFilter     = tempCat;
                        _sortOrder          = tempSort;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'تطبيق',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── delete (with reservation protection, inherited from original) ───────────

  Future<void> _confirmDelete(String docId, Map<String, dynamic> data) async {
    final title = (data['title'] as String? ?? '').trim();
    final displayTitle = title.isNotEmpty ? title : 'العرض';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العرض'),
        content: Text('هل تريد حذف "$displayTitle"؟\nهذا الإجراء لا يمكن التراجع عنه.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _deleting = true);
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _svc.deleteOffer(
        offerId: docId,
        offerTitle: displayTitle,
        providerUserId: (data['providerUserId'] as String? ?? ''),
        adminId: adminId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف العرض ✅'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  // ─── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chips = _activeChips;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إدارة العروض'),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
      ),
      body: Column(
        children: [
          // ── شريط الفلترة + active chips ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // filter button
                GestureDetector(
                  onTap: _openFilterSheet,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _activeFilterCount > 0
                          ? AppColors.primary
                          : Colors.white,
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
                        Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: _activeFilterCount > 0
                              ? Colors.white
                              : AppColors.textLight,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'فلترة',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _activeFilterCount > 0
                                ? Colors.white
                                : AppColors.textLight,
                          ),
                        ),
                        if (_activeFilterCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$_activeFilterCount',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // active filter chips (scrollable)
                if (chips.isNotEmpty)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 6),
                      child: Row(
                        children: chips
                            .map((c) =>
                                _ActiveFilterChip(label: c.$1, onRemove: c.$2))
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── القائمة ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _svc.getAllOffersStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'خطأ: ${snap.error}',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  );
                }

                final all      = snap.data?.docs ?? [];
                final filtered = _applyFilters(all);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          size: 56,
                          color: AppColors.textLight.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد عروض بهذه المعايير',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final doc  = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _OfferCard(
                      key: ValueKey(doc.id),
                      docId: doc.id,
                      data: data,
                      deleting: _deleting,
                      nameCache: _nameCache,
                      onNameResolved: (uid, name) =>
                          setState(() => _nameCache[uid] = name),
                      onDelete: () => _confirmDelete(doc.id, data),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminOfferDetailsScreen(
                            docId: doc.id,
                            data: data,
                            onDeleted: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم حذف العرض ✅'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
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

// ─── Offer card (StatefulWidget for async publisher name resolution) ──────────

class _OfferCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool deleting;
  final Map<String, String> nameCache;
  final void Function(String uid, String name) onNameResolved;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _OfferCard({
    super.key,
    required this.docId,
    required this.data,
    required this.deleting,
    required this.nameCache,
    required this.onNameResolved,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  String? _localName;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _resolveIfNeeded();
  }

  void _resolveIfNeeded() {
    final stored = (widget.data['providerName'] as String? ?? '').trim();
    if (stored.isNotEmpty) return; // name already in offer doc

    final uid = (widget.data['providerUserId'] as String? ?? '').trim();
    if (uid.isEmpty) return;
    if (widget.nameCache.containsKey(uid)) return; // already cached by parent
    if (_fetching) return;

    _fetching = true;
    FirebaseFirestore.instance.collection('users').doc(uid).get().then((snap) {
      if (!mounted) return;
      final d = snap.data();
      if (d == null) return;
      String name = '';
      for (final key in ['restaurantName', 'charityName', 'name', 'fullName']) {
        final v = (d[key] as String? ?? '').trim();
        if (v.isNotEmpty) {
          name = v;
          break;
        }
      }
      if (name.isNotEmpty) {
        widget.onNameResolved(uid, name); // update parent cache → all cards refresh
        if (mounted) setState(() => _localName = name);
      }
    });
  }

  String get _displayName {
    final d = widget.data;
    final stored = (d['providerName'] as String? ?? '').trim();
    if (stored.isNotEmpty) return stored;
    if (_localName != null) return _localName!;
    final uid = (d['providerUserId'] as String? ?? '').trim();
    if (uid.isNotEmpty && widget.nameCache.containsKey(uid)) {
      return widget.nameCache[uid]!;
    }
    return _roleLabel(d['providerRole'] as String? ?? '');
  }

  String _statusLabel(String s) => switch (s) {
        'available'  => 'متاح',
        'reserved'   => 'محجوز',
        'picked_up'  => 'تم الاستلام',
        'expired'    => 'منتهي',
        'cancelled'  => 'ملغي',
        _            => s.isEmpty ? '—' : s,
      };

  Color _statusColor(String s) => switch (s) {
        'available'  => AppColors.success,
        'reserved'   => AppColors.secondary,
        'picked_up'  => AppColors.primary,
        'expired'    => AppColors.textLight,
        'cancelled'  => AppColors.danger,
        _            => AppColors.textLight,
      };

  String _typeLabel(String t) => switch (t) {
        'clear_offer'         => 'عرض واضح',
        'mystery_package'     => 'باقة غامضة',
        'restaurant_package'  => 'باقة مطعم',
        _                     => t.isEmpty ? '—' : t,
      };

  String _roleLabel(String r) => switch (r) {
        'restaurant' => 'مطعم',
        'charity'    => 'جمعية',
        'individual' => 'فرد',
        _            => r.isEmpty ? '—' : r,
      };

  String _formatDate(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final d           = widget.data;
    final title       = (d['title'] as String? ?? '').trim();
    final displayTitle = title.isNotEmpty ? title : 'عرض غير مسمى';
    final offerType   = d['offerType'] as String? ?? '';
    final status      = d['status']   as String? ?? '';
    final rawQty      = d['remainingQuantity'];
    final qty         = rawQty is num ? rawQty.toInt() : 0;
    final isFree      = d['isFree'] == true;
    final price       = d['discountPrice'] ?? d['price'];
    final currency    = (d['currency'] as String? ?? 'ILS');
    final pickup      = (d['pickupLocation'] as String? ?? '').trim();
    final statusColor = _statusColor(status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── عنوان + شارة الحالة ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ── مزوّد + نوع ──
              Row(
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 13, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _displayName,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.label_outline_rounded,
                      size: 13, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    _typeLabel(offerType),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // ── كمية + سعر ──
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 13, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    'متبقي: $qty',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLight),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.payments_outlined,
                      size: 13, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    isFree
                        ? 'مجاني'
                        : price != null
                            ? '$price $currency'
                            : '—',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              ),
              if (pickup.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        pickup,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              // ── تاريخ + أزرار ──
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(d['createdAt']),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLight),
                  ),
                  const Spacer(),
                  // details hint
                  const Icon(Icons.chevron_left_rounded,
                      size: 16, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: widget.deleting
                        ? null
                        : () {
                            // Prevent card tap from firing
                            widget.onDelete();
                          },
                    icon: const Icon(Icons.delete_outline_rounded, size: 15),
                    label: const Text('حذف', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom-sheet shared widgets ──────────────────────────────────────────────

class _SheetSection extends StatelessWidget {
  final String title;
  final List<Widget> chips;

  const _SheetSection({required this.title, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : AppColors.textDark,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.only(left: 4, right: 10, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
