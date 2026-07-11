import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/screens/admin/admin_complaint_details_screen.dart';
import 'package:zad_app/screens/admin/admin_widgets.dart';
import 'package:zad_app/services/admin_service.dart';
import 'package:zad_app/theme/app_colors.dart';
import 'package:zad_app/utils/complaint_user_resolver.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  final _svc = AdminService();

  // ── Shared user cache across both tabs ──
  final Map<String, String>  _nameCache  = {};
  final Map<String, String?> _photoCache = {};

  void _onUserResolved(String uid, String name, String? photo) {
    if (mounted) {
      setState(() {
        _nameCache[uid]  = name;
        _photoCache[uid] = photo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('الشكاوى والبلاغات'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'مفتوحة'),
              Tab(text: 'تم الحل'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ComplaintsList(
              stream: _svc.getOpenComplaints(),
              showResolveButton: true,
              nameCache: _nameCache,
              photoCache: _photoCache,
              onUserResolved: _onUserResolved,
            ),
            _ComplaintsList(
              stream: _svc.getResolvedComplaints(),
              showResolveButton: false,
              nameCache: _nameCache,
              photoCache: _photoCache,
              onUserResolved: _onUserResolved,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Complaints list (one per tab) ───────────────────────────────────────────

class _ComplaintsList extends StatefulWidget {
  final Stream<QuerySnapshot> stream;
  final bool showResolveButton;
  final Map<String, String>  nameCache;
  final Map<String, String?> photoCache;
  final void Function(String uid, String name, String? photo) onUserResolved;

  const _ComplaintsList({
    required this.stream,
    required this.showResolveButton,
    required this.nameCache,
    required this.photoCache,
    required this.onUserResolved,
  });

  @override
  State<_ComplaintsList> createState() => _ComplaintsListState();
}

class _ComplaintsListState extends State<_ComplaintsList>
    with AutomaticKeepAliveClientMixin {
  String _sortOrder = 'newest';
  final _svc = AdminService();

  @override
  bool get wantKeepAlive => true;

  // ── sorting ────────────────────────────────────────────────────────────────

  List<QueryDocumentSnapshot> _sort(List<QueryDocumentSnapshot> docs) {
    final sorted = List<QueryDocumentSnapshot>.from(docs);
    sorted.sort((a, b) {
      final aMs = ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
          ?.millisecondsSinceEpoch;
      final bMs = ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
          ?.millisecondsSinceEpoch;
      if (aMs == null && bMs == null) return 0;
      if (aMs == null) return 1;  // no createdAt → always at end
      if (bMs == null) return -1;
      return _sortOrder == 'newest' ? bMs.compareTo(aMs) : aMs.compareTo(bMs);
    });
    return sorted;
  }

  // ── quick resolve from card ────────────────────────────────────────────────

  Future<void> _resolveComplaint(String docId) async {
    await _svc.resolveComplaint(docId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حل الشكوى ✅'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // ── شريط الترتيب ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Text(
                'الترتيب:',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              AdminFilterChip(
                label: 'الأحدث أولاً',
                selected: _sortOrder == 'newest',
                onTap: () => setState(() => _sortOrder = 'newest'),
              ),
              const SizedBox(width: 8),
              AdminFilterChip(
                label: 'الأقدم أولاً',
                selected: _sortOrder == 'oldest',
                onTap: () => setState(() => _sortOrder = 'oldest'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── القائمة ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.stream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = _sort(snap.data!.docs);
              if (docs.isEmpty) {
                return EmptyState(
                  message: widget.showResolveButton
                      ? 'لا توجد شكاوى مفتوحة 🎉'
                      : 'لا توجد شكاوى محلولة',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc  = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _ComplaintCard(
                    key: ValueKey(doc.id),
                    docId: doc.id,
                    data: data,
                    nameCache: widget.nameCache,
                    photoCache: widget.photoCache,
                    onUserResolved: widget.onUserResolved,
                    showResolveButton: widget.showResolveButton,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminComplaintDetailsScreen(
                          docId: doc.id,
                          data: data,
                        ),
                      ),
                    ),
                    onResolve: () => _resolveComplaint(doc.id),
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

// ─── Complaint card ───────────────────────────────────────────────────────────

class _ComplaintCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Map<String, String>  nameCache;
  final Map<String, String?> photoCache;
  final void Function(String uid, String name, String? photo) onUserResolved;
  final bool showResolveButton;
  final VoidCallback onTap;
  final Future<void> Function() onResolve;

  const _ComplaintCard({
    super.key,
    required this.docId,
    required this.data,
    required this.nameCache,
    required this.photoCache,
    required this.onUserResolved,
    required this.showResolveButton,
    required this.onTap,
    required this.onResolve,
  });

  @override
  State<_ComplaintCard> createState() => _ComplaintCardState();
}

class _ComplaintCardState extends State<_ComplaintCard> {
  String? _localName;
  String? _localPhoto;
  bool _fetching   = false;
  bool _resolving  = false;

  @override
  void initState() {
    super.initState();
    _resolveIfNeeded();
  }

  void _resolveIfNeeded() {
    // A. Name already stored in complaint doc — no fetch needed
    for (final key in ['userName', 'complainantName', 'reporterName']) {
      if ((widget.data[key] as String? ?? '').trim().isNotEmpty) return;
    }

    final uid = extractComplaintUid(widget.data);
    if (uid.isEmpty) return;

    // B. Already in parent cache
    if (widget.nameCache.containsKey(uid)) return;

    if (_fetching) return;
    _fetching = true;

    _doFetch(uid);
  }

  Future<void> _doFetch(String uid) async {
    try {
      final info = await resolveComplaintUser(widget.docId, widget.data);
      widget.onUserResolved(uid, info.name, info.photoUrl);
      if (mounted) {
        setState(() {
          _localName  = info.name;
          _localPhoto = info.photoUrl;
        });
      }
    } catch (e) {
      debugPrint('[Complaint] card fetch failed: $e');
    }
  }

  String get _displayName {
    // A. Stored in complaint doc
    for (final key in ['userName', 'complainantName', 'reporterName']) {
      final v = (widget.data[key] as String? ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    // B. Local fetch result
    if (_localName != null) return _localName!;
    // C. Parent cache
    final uid = extractComplaintUid(widget.data);
    if (uid.isNotEmpty && widget.nameCache.containsKey(uid)) {
      return widget.nameCache[uid]!;
    }
    return 'مستخدم غير معروف';
  }

  String? get _displayPhoto {
    for (final key in ['userPhoto', 'photoUrl']) {
      final v = (widget.data[key] as String? ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    if (_localPhoto != null) return _localPhoto;
    final uid = extractComplaintUid(widget.data);
    if (uid.isNotEmpty && widget.photoCache.containsKey(uid)) {
      return widget.photoCache[uid];
    }
    return null;
  }

  String _statusLabel(String s) => switch (s) {
        'open'     => 'مفتوحة',
        'resolved' => 'تم الحل',
        _          => s,
      };

  Color _statusColor(String s) => switch (s) {
        'open'     => AppColors.danger,
        'resolved' => AppColors.success,
        _          => AppColors.textLight,
      };

  String _formatDateTime(dynamic ts) {
    if (ts is! Timestamp) return 'تاريخ غير متوفر';
    final d    = ts.toDate();
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'م' : 'ص';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} - '
        '${hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _quickResolve() async {
    setState(() => _resolving = true);
    try {
      await widget.onResolve();
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d           = widget.data;
    final status      = d['status']      as String?  ?? 'open';
    final description = (d['description'] as String? ?? '').trim();
    final relatedOffer = (d['relatedOfferId'] as String? ?? '').trim();
    final statusColor = _statusColor(status);
    final name        = _displayName;
    final photo       = _displayPhoto;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
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
                // ── رأس البطاقة: صورة + اسم + تاريخ + شارة الحالة ──
                Row(
                  children: [
                    _UserAvatar(name: name, photoUrl: photo, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDateTime(d['createdAt']),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── نص الشكوى ──
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],

                // ── رقم العرض المرتبط ──
                if (relatedOffer.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.local_offer_outlined,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        'رقم العرض: $relatedOffer',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ],

                // ── إجراءات ──
                if (widget.showResolveButton) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Tap hint
                      const Icon(Icons.info_outline_rounded,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      const Text(
                        'اضغط للتفاصيل',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.textLight),
                      ),
                      const Spacer(),
                      // Quick resolve button
                      ElevatedButton.icon(
                        onPressed: _resolving ? null : _quickResolve,
                        icon: _resolving
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, size: 14),
                        label: const Text('حل سريع',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── User avatar (photo or initials) ─────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final String  name;
  final String? photoUrl;
  final double  size;

  const _UserAvatar({
    required this.name,
    required this.photoUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty ? name.trim()[0] : '؟';
    final bg       = AppColors.danger.withValues(alpha: 0.1);

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            photoUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _Initials(
                initials: initials, size: size, bg: bg),
          ),
        ),
      );
    }
    return _Initials(initials: initials, size: size, bg: bg);
  }
}

class _Initials extends StatelessWidget {
  final String initials;
  final double size;
  final Color  bg;

  const _Initials({
    required this.initials,
    required this.size,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.danger,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
