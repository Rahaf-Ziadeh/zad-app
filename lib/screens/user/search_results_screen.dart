import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/offer_utils.dart';
import 'offer_details_screen.dart';
import 'provider_public_profile_screen.dart';

// ─────────────────────────────────────────────
// نتائج البحث الشامل: يجلب العروض والباقات والمطاعم والجمعيات النشطة مرة
// واحدة، ثم يُطبّق فلترة نصية من جهة العميل (Firestore لا يدعم بحثاً نصياً
// كاملاً مباشرة). النتائج مقسّمة إلى تبويبات: الكل/العروض/الباقات/المطاعم/
// الجمعيات ──
class SearchResultsScreen extends StatefulWidget {
  final String initialQuery;
  const SearchResultsScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final TabController _tabController;

  String _query = '';
  bool _loading = true;
  String? _error;

  List<QueryDocumentSnapshot> _allOffers = [];
  List<QueryDocumentSnapshot> _allPackages = [];
  List<QueryDocumentSnapshot> _allRestaurants = [];
  List<QueryDocumentSnapshot> _allCharities = [];

  List<QueryDocumentSnapshot> _offers = [];
  List<QueryDocumentSnapshot> _packages = [];
  List<QueryDocumentSnapshot> _restaurants = [];
  List<QueryDocumentSnapshot> _charities = [];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _searchController = TextEditingController(text: widget.initialQuery);
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── يجلب البيانات النشطة مرة واحدة فقط عند فتح الشاشة، ثم كل عملية بحث
  // لاحقة تُصفّي القوائم المحمَّلة مسبقاً دون إعادة الاستعلام من Firestore ──
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('offers')
            .where('status', isEqualTo: 'available')
            .where('offerType', whereNotIn: [
          'restaurant_package',
          'mystery_package',
        ]).get(),
        FirebaseFirestore.instance
            .collection('offers')
            .where('status', isEqualTo: 'available')
            .where('offerType',
                whereIn: ['mystery_package', 'restaurant_package']).get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'restaurant')
            .where('status', isEqualTo: 'active')
            .where('isApproved', isEqualTo: true)
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'charity')
            .where('status', isEqualTo: 'active')
            .where('isApproved', isEqualTo: true)
            .get(),
      ]);

      if (!mounted) return;
      setState(() {
        _allOffers = results[0].docs.where((d) {
          return !isOfferExpired(d.data());
        }).toList();
        _allPackages = results[1].docs.where((d) {
          return !isOfferExpired(d.data());
        }).toList();
        _allRestaurants = results[2].docs;
        _allCharities = results[3].docs;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل نتائج البحث';
        _loading = false;
      });
    }
  }

  bool _textMatches(String haystack, String query) =>
      haystack.toLowerCase().contains(query.toLowerCase());

  bool _offerMatches(QueryDocumentSnapshot doc, String q) {
    if (q.isEmpty) return true;
    final data = doc.data() as Map<String, dynamic>;
    final title = (data['title'] as String? ?? '');
    final category = (data['category'] as String? ?? '');
    final description = (data['description'] as String? ?? '');
    return _textMatches(title, q) ||
        _textMatches(category, q) ||
        _textMatches(description, q);
  }

  bool _providerMatches(QueryDocumentSnapshot doc, String q) {
    if (q.isEmpty) return true;
    final data = doc.data() as Map<String, dynamic>;
    final name =
        (data['name'] as String? ?? data['fullName'] as String? ?? '');
    return _textMatches(name, q);
  }

  void _applyFilter() {
    final q = _query.trim();
    setState(() {
      _offers = _allOffers.where((d) => _offerMatches(d, q)).toList();
      _packages = _allPackages.where((d) => _offerMatches(d, q)).toList();
      _restaurants =
          _allRestaurants.where((d) => _providerMatches(d, q)).toList();
      _charities = _allCharities.where((d) => _providerMatches(d, q)).toList();
    });
  }

  void _onQueryChanged(String value) {
    _query = value;
    _applyFilter();
  }

  int get _totalCount =>
      _offers.length + _packages.length + _restaurants.length + _charities.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: widget.initialQuery.isEmpty,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'ابحث عن عرض أو مطعم أو جمعية...',
                hintStyle:
                    const TextStyle(color: AppColors.textLight, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.textLight),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textLight, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              ),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'الكل${_query.isEmpty ? '' : ' ($_totalCount)'}'),
            Tab(text: 'العروض${_query.isEmpty ? '' : ' (${_offers.length})'}'),
            Tab(text: 'الباقات${_query.isEmpty ? '' : ' (${_packages.length})'}'),
            Tab(
                text:
                    'المطاعم${_query.isEmpty ? '' : ' (${_restaurants.length})'}'),
            Tab(
                text:
                    'الجمعيات${_query.isEmpty ? '' : ' (${_charities.length})'}'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.danger)),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _AllResultsTab(
                      offers: _offers,
                      packages: _packages,
                      restaurants: _restaurants,
                      charities: _charities,
                    ),
                    _ResultsList(
                      emptyMessage: 'لا توجد عروض مطابقة',
                      children: _offers
                          .map((d) => _OfferResultTile(doc: d))
                          .toList(),
                    ),
                    _ResultsList(
                      emptyMessage: 'لا توجد باقات مطابقة',
                      children: _packages
                          .map((d) => _OfferResultTile(doc: d))
                          .toList(),
                    ),
                    _ResultsList(
                      emptyMessage: 'لا توجد مطاعم مطابقة',
                      children: _restaurants
                          .map((d) =>
                              _ProviderResultTile(doc: d, role: 'restaurant'))
                          .toList(),
                    ),
                    _ResultsList(
                      emptyMessage: 'لا توجد جمعيات مطابقة',
                      children: _charities
                          .map((d) => _ProviderResultTile(doc: d, role: 'charity'))
                          .toList(),
                    ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────
// تبويب "الكل": أقسام مجمّعة لكل نوع نتيجة، بنفس نمط عناوين الأقسام
// المستخدم في بقية الشاشات ──
class _AllResultsTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> offers;
  final List<QueryDocumentSnapshot> packages;
  final List<QueryDocumentSnapshot> restaurants;
  final List<QueryDocumentSnapshot> charities;

  const _AllResultsTab({
    required this.offers,
    required this.packages,
    required this.restaurants,
    required this.charities,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny = offers.isNotEmpty ||
        packages.isNotEmpty ||
        restaurants.isNotEmpty ||
        charities.isNotEmpty;

    if (!hasAny) {
      return const _EmptyState(message: 'لا توجد نتائج مطابقة لبحثك');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (offers.isNotEmpty) ...[
          const _SectionHeader(title: 'العروض'),
          ...offers.take(5).map((d) => _OfferResultTile(doc: d)),
          const SizedBox(height: 8),
        ],
        if (packages.isNotEmpty) ...[
          const _SectionHeader(title: 'الباقات'),
          ...packages.take(5).map((d) => _OfferResultTile(doc: d)),
          const SizedBox(height: 8),
        ],
        if (restaurants.isNotEmpty) ...[
          const _SectionHeader(title: 'المطاعم'),
          ...restaurants
              .take(5)
              .map((d) => _ProviderResultTile(doc: d, role: 'restaurant')),
          const SizedBox(height: 8),
        ],
        if (charities.isNotEmpty) ...[
          const _SectionHeader(title: 'الجمعيات'),
          ...charities
              .take(5)
              .map((d) => _ProviderResultTile(doc: d, role: 'charity')),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark)),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final String emptyMessage;
  final List<Widget> children;

  const _ResultsList({required this.emptyMessage, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return _EmptyState(message: emptyMessage);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
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
            Icon(Icons.search_off_rounded,
                size: 56, color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textLight, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة نتيجة عرض/باقة
// ─────────────────────────────────────────────
class _OfferResultTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _OfferResultTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final title = (data['title'] as String? ?? 'عرض طعام');
    final category = (data['category'] as String? ?? '');
    final imageUrl = (data['imageUrl'] as String? ?? '');
    final isFree = data['isFree'] == true ||
        (data['discountPrice'] ?? data['price'] ?? 0) == 0;
    final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
    final currency = (data['currency'] as String? ?? 'ILS');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OfferDetailsScreen(docId: doc.id, data: data),
          ),
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textDark)),
        subtitle: category.isNotEmpty
            ? Text(category,
                style: const TextStyle(fontSize: 12, color: AppColors.textLight))
            : null,
        trailing: Text(
          isFree ? 'مجاني' : '$discountPrice $currency',
          style: TextStyle(
            color: isFree ? AppColors.success : AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 50,
        height: 50,
        color: AppColors.primary.withValues(alpha: 0.08),
        child: const Icon(Icons.fastfood_rounded,
            color: AppColors.primary, size: 22),
      );
}

// ─────────────────────────────────────────────
// بطاقة نتيجة مطعم/جمعية
// ─────────────────────────────────────────────
class _ProviderResultTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String role; // 'restaurant' | 'charity'

  const _ProviderResultTile({required this.doc, required this.role});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final isCharity = role == 'charity';
    final name = (data['name'] as String? ??
        data['fullName'] as String? ??
        (isCharity ? 'جمعية' : 'مطعم'));
    final email = (data['email'] as String? ?? '');
    final color = isCharity ? const Color(0xFFE11D48) : AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderPublicProfileScreen(
              providerUserId: doc.id,
              providerRole: role,
            ),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(
            isCharity ? Icons.volunteer_activism_rounded : Icons.restaurant_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textDark)),
        subtitle: email.isNotEmpty
            ? Text(email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textLight))
            : null,
      ),
    );
  }
}
