import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';

class AdminOfferDetailsScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback? onDeleted;

  const AdminOfferDetailsScreen({
    super.key,
    required this.docId,
    required this.data,
    this.onDeleted,
  });

  @override
  State<AdminOfferDetailsScreen> createState() =>
      _AdminOfferDetailsScreenState();
}

class _AdminOfferDetailsScreenState extends State<AdminOfferDetailsScreen> {
  Map<String, dynamic>? _publisherData;
  bool _loadingPublisher = false;
  bool _deleting = false;

  final _svc = AdminService();

  @override
  void initState() {
    super.initState();
    _loadPublisher();
  }

  Future<void> _loadPublisher() async {
    final uid = (widget.data['providerUserId'] as String? ?? '').trim();
    if (uid.isEmpty) return;
    setState(() => _loadingPublisher = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (mounted && doc.exists) {
        setState(() => _publisherData = doc.data());
      }
    } finally {
      if (mounted) setState(() => _loadingPublisher = false);
    }
  }

  // ─── helpers ─────────────────────────────────────────────────────────────────

  String get _publisherDisplayName {
    final stored = (widget.data['providerName'] as String? ?? '').trim();
    if (stored.isNotEmpty) return stored;

    if (_publisherData != null) {
      for (final key in ['restaurantName', 'charityName', 'name', 'fullName']) {
        final v = (_publisherData![key] as String? ?? '').trim();
        if (v.isNotEmpty) return v;
      }
    }
    return _roleLabel(widget.data['providerRole'] as String? ?? '');
  }

  String _roleLabel(String r) => switch (r) {
        'restaurant' => 'مطعم',
        'charity'    => 'جمعية خيرية',
        'individual' => 'مستخدم فردي',
        _            => r.isEmpty ? '—' : r,
      };

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

  String _verificationLabel(String v) => switch (v) {
        'approved' => 'موثّق ✅',
        'pending'  => 'قيد المراجعة ⏳',
        'rejected' => 'مرفوض ❌',
        _          => '—',
      };

  String _formatDate(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ─── delete ───────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final d     = widget.data;
    final title = (d['title'] as String? ?? '').trim();
    final displayTitle = title.isNotEmpty ? title : 'العرض';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العرض'),
        content: Text(
            'هل تريد حذف "$displayTitle"؟\nهذا الإجراء لا يمكن التراجع عنه.'),
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
        offerId: widget.docId,
        offerTitle: displayTitle,
        providerUserId: (d['providerUserId'] as String? ?? ''),
        adminId: adminId,
      );
      if (!mounted) return;
      widget.onDeleted?.call();
      Navigator.of(context).pop();
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
    final d       = widget.data;
    final title   = (d['title'] as String? ?? '').trim();
    final imageUrl = d['imageUrl'] as String?;
    final status  = d['status'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── صورة + شريط العنوان ──
          SliverAppBar(
            expandedHeight: imageUrl != null && imageUrl.isNotEmpty ? 240 : 0,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textDark,
            title: Text(
              title.isNotEmpty ? title : 'تفاصيل العرض',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            flexibleSpace: imageUrl != null && imageUrl.isNotEmpty
                ? FlexibleSpaceBar(
                    background: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.border,
                        child: Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: AppColors.textLight, size: 40),
                        ),
                      ),
                    ),
                  )
                : null,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── حالة + نوع ──
                  Row(
                    children: [
                      _StatusBadge(
                        label: _statusLabel(status),
                        color: _statusColor(status),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(
                        label: _typeLabel(d['offerType'] as String? ?? ''),
                        color: AppColors.primary,
                      ),
                      if ((d['category'] as String? ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _StatusBadge(
                          label: d['category'] as String,
                          color: AppColors.textLight,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── معلومات العرض ──
                  _SectionCard(
                    title: 'تفاصيل العرض',
                    icon: Icons.local_offer_outlined,
                    children: [
                      if ((d['description'] as String? ?? '').trim().isNotEmpty)
                        _InfoRow(
                          label: 'الوصف',
                          value: d['description'] as String,
                          multiline: true,
                        ),
                      _buildPriceRow(d),
                      _InfoRow(
                        label: 'الكمية المتبقية',
                        value: '${d['remainingQuantity'] ?? 0}',
                      ),
                      if ((d['pickupLocation'] as String? ?? '').trim().isNotEmpty)
                        _InfoRow(
                          label: 'موقع الاستلام',
                          value: d['pickupLocation'] as String,
                        ),
                      if (d['pickupStartTime'] != null ||
                          d['pickupEndTime'] != null)
                        _InfoRow(
                          label: 'وقت الاستلام',
                          value:
                              '${_formatTime(d['pickupStartTime'])} — ${_formatTime(d['pickupEndTime'])}',
                        ),
                      _buildPaymentRow(d),
                      _InfoRow(
                        label: 'تاريخ النشر',
                        value: _formatDate(d['createdAt']),
                      ),
                      if (d['updatedAt'] != null)
                        _InfoRow(
                          label: 'آخر تعديل',
                          value: _formatDate(d['updatedAt']),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── مسببات الحساسية ──
                  _buildAllergenSection(d),

                  const SizedBox(height: 12),

                  // ── معلومات الناشر ──
                  _SectionCard(
                    title: 'معلومات الناشر',
                    icon: Icons.person_outline_rounded,
                    children: _buildPublisherRows(),
                  ),

                  const SizedBox(height: 24),

                  // ── زر الحذف ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _deleting ? null : _confirmDelete,
                      icon: _deleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        _deleting ? 'جاري الحذف...' : 'حذف العرض',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── section builders ─────────────────────────────────────────────────────────

  Widget _buildPriceRow(Map<String, dynamic> d) {
    final isFree        = d['isFree'] == true;
    final currency      = (d['currency'] as String? ?? 'ILS');
    final originalPrice = d['originalPrice'];
    final discountPrice = d['discountPrice'];
    final price         = d['price'];

    if (isFree) {
      return const _InfoRow(label: 'السعر', value: 'مجاني');
    }
    if (discountPrice != null && originalPrice != null) {
      return _InfoRow(
        label: 'السعر',
        value: '$discountPrice $currency (الأصلي: $originalPrice $currency)',
      );
    }
    final p = discountPrice ?? price;
    return _InfoRow(
      label: 'السعر',
      value: p != null ? '$p $currency' : '—',
    );
  }

  Widget _buildPaymentRow(Map<String, dynamic> d) {
    final methods = <String>[];
    if (d['isCash'] == true) methods.add('نقداً');
    if (d['isOnline'] == true) methods.add('دفع إلكتروني');
    if (methods.isEmpty) return const SizedBox.shrink();
    return _InfoRow(label: 'طرق الدفع', value: methods.join(' · '));
  }

  Widget _buildAllergenSection(Map<String, dynamic> d) {
    final allergens = AppConstants.parseAllergyInfo(d['allergyInfo']);
    if (allergens.isEmpty) return const SizedBox.shrink();
    return _SectionCard(
      title: 'مسببات الحساسية',
      icon: Icons.warning_amber_rounded,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: allergens.map((a) {
            final isNone = a == AppConstants.noKnownAllergens;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isNone
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isNone
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                a,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isNone ? AppColors.success : AppColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildPublisherRows() {
    final d = widget.data;

    final rows = <Widget>[
      _InfoRow(label: 'الاسم', value: _publisherDisplayName),
      _InfoRow(
        label: 'الدور',
        value: _roleLabel(d['providerRole'] as String? ?? ''),
      ),
    ];

    if (_loadingPublisher) {
      rows.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      ));
      return rows;
    }

    final p = _publisherData;
    if (p != null) {
      if ((p['email'] as String? ?? '').trim().isNotEmpty) {
        rows.add(_InfoRow(label: 'البريد الإلكتروني', value: p['email'] as String));
      }
      if ((p['phone'] as String? ?? '').trim().isNotEmpty) {
        rows.add(_InfoRow(label: 'الهاتف', value: p['phone'] as String));
      }
      if ((p['address'] as String? ?? '').trim().isNotEmpty) {
        rows.add(_InfoRow(
            label: 'العنوان', value: p['address'] as String, multiline: true));
      }
      final vs = (p['verificationStatus'] as String? ?? '').trim();
      if (vs.isNotEmpty) {
        rows.add(_InfoRow(
            label: 'حالة التوثيق', value: _verificationLabel(vs)));
      }
    }

    return rows;
  }
}

// ─── Shared private widgets ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool multiline;

  const _InfoRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: multiline
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                    height: 1.5,
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color == AppColors.textLight ? AppColors.textLight : color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
