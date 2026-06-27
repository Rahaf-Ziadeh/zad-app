import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';

class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({super.key});

  @override
  State<AdminOffersScreen> createState() => _AdminOffersScreenState();
}

class _AdminOffersScreenState extends State<AdminOffersScreen> {
  String _statusFilter = 'all';
  String _roleFilter = 'all';
  String _typeFilter = 'all';
  bool _deleting = false;

  final _svc = AdminService();

  List<QueryDocumentSnapshot> _applyFilters(
      List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      if (_statusFilter != 'all' && d['status'] != _statusFilter) {
        return false;
      }
      if (_roleFilter != 'all' && d['providerRole'] != _roleFilter) {
        return false;
      }
      if (_typeFilter != 'all' && d['offerType'] != _typeFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _confirmDelete(
      String docId, Map<String, dynamic> data) async {
    final title =
        (data['title'] as String? ?? '').trim().isNotEmpty
            ? data['title'] as String
            : 'العرض';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العرض'),
        content: Text(
          'هل تريد حذف "$title"؟\nهذا الإجراء لا يمكن التراجع عنه.',
        ),
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
        offerTitle: title,
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

  @override
  Widget build(BuildContext context) {
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
          // ── شريط الفلاتر ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _FilterRow(
                  label: 'الحالة:',
                  options: const {
                    'all': 'الكل',
                    'available': 'متاح',
                    'reserved': 'محجوز',
                    'cancelled': 'ملغي',
                  },
                  selected: _statusFilter,
                  onSelect: (v) => setState(() => _statusFilter = v),
                ),
                const SizedBox(width: 16),
                _FilterRow(
                  label: 'المزوّد:',
                  options: const {
                    'all': 'الكل',
                    'restaurant': 'مطعم',
                    'charity': 'جمعية',
                    'individual': 'فرد',
                  },
                  selected: _roleFilter,
                  onSelect: (v) => setState(() => _roleFilter = v),
                ),
                const SizedBox(width: 16),
                _FilterRow(
                  label: 'النوع:',
                  options: const {
                    'all': 'الكل',
                    'clear_offer': 'واضح',
                    'mystery_package': 'غامض',
                    'restaurant_package': 'باقة',
                  },
                  selected: _typeFilter,
                  onSelect: (v) => setState(() => _typeFilter = v),
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

                final all = snap.data?.docs ?? [];
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
                    final doc = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _OfferCard(
                      docId: doc.id,
                      data: data,
                      deleting: _deleting,
                      onDelete: () => _confirmDelete(doc.id, data),
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

// ─── Filter row ───────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final String label;
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        ...options.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSelect(e.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selected == e.key ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected == e.key
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected == e.key ? Colors.white : AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Offer card ───────────────────────────────────────────────────────────────

class _OfferCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool deleting;
  final VoidCallback onDelete;

  const _OfferCard({
    required this.docId,
    required this.data,
    required this.deleting,
    required this.onDelete,
  });

  String _statusLabel(String s) => switch (s) {
        'available' => 'متاح',
        'reserved' => 'محجوز',
        'cancelled' => 'ملغي',
        _ => s.isEmpty ? '—' : s,
      };

  Color _statusColor(String s) => switch (s) {
        'available' => AppColors.success,
        'reserved' => AppColors.secondary,
        'cancelled' => AppColors.danger,
        _ => AppColors.textLight,
      };

  String _typeLabel(String t) => switch (t) {
        'clear_offer' => 'عرض واضح',
        'mystery_package' => 'باقة غامضة',
        'restaurant_package' => 'باقة مطعم',
        _ => t.isEmpty ? '—' : t,
      };

  String _roleLabel(String r) => switch (r) {
        'restaurant' => 'مطعم',
        'charity' => 'جمعية',
        'individual' => 'فرد',
        _ => r.isEmpty ? '—' : r,
      };

  String _formatDate(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d = ts.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] as String? ?? '').trim();
    final displayTitle = title.isNotEmpty ? title : 'عرض غير مسمى';

    final providerName = (data['providerName'] as String? ?? '').trim();
    final providerRole = (data['providerRole'] as String? ?? '');
    final displayProvider =
        providerName.isNotEmpty ? providerName : _roleLabel(providerRole);

    final offerType = data['offerType'] as String? ?? '';
    final status = data['status'] as String? ?? '';
    final rawQty = data['remainingQuantity'];
    final qty = rawQty is num ? rawQty.toInt() : 0;
    final price = data['price'];
    final currency = (data['currency'] as String? ?? 'ILS');
    final pickup = (data['pickupLocation'] as String? ?? '').trim();
    final createdAt = data['createdAt'];
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  displayProvider,
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
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
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
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              if (price != null) ...[
                const SizedBox(width: 10),
                const Icon(Icons.payments_outlined,
                    size: 13, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  price == 0 ? 'مجاني' : '$price $currency',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textLight),
                ),
              ],
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

          // ── تاريخ + زر الحذف ──
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: deleting ? null : onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                label: const Text('حذف', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
