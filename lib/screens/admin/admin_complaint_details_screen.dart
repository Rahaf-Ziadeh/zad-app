import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';

class AdminComplaintDetailsScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const AdminComplaintDetailsScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<AdminComplaintDetailsScreen> createState() =>
      _AdminComplaintDetailsScreenState();
}

class _AdminComplaintDetailsScreenState
    extends State<AdminComplaintDetailsScreen> {
  Map<String, dynamic>? _userData;
  bool _loadingUser = false;
  bool _resolving   = false;
  bool _reopening   = false;

  final _noteController = TextEditingController();
  final _svc = AdminService();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ─── load complainant from users collection ───────────────────────────────

  // Scans complaint doc for any recognised UID field.
  String _resolveUid() {
    for (final key in [
      'userId', 'complainantId', 'submittedBy', 'reporterId', 'uid'
    ]) {
      final v = (widget.data[key] as String? ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  Future<void> _loadUser() async {
    debugPrint('[Complaint] doc data: ${widget.data}');

    final uid = _resolveUid();
    debugPrint('[Complaint] resolved UID: "$uid"');
    if (uid.isEmpty) return;

    setState(() => _loadingUser = true);
    try {
      // Primary: document ID == Firebase Auth UID
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      debugPrint('[Complaint] users.doc($uid).exists = ${doc.exists}');

      Map<String, dynamic>? data = doc.exists ? doc.data() : null;

      // Fallback: search by 'uid' field (handles mismatched doc IDs)
      if (data == null) {
        debugPrint('[Complaint] fallback: where(uid == $uid)');
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) data = q.docs.first.data();
        debugPrint('[Complaint] where-query found: ${q.docs.isNotEmpty}');
      }

      debugPrint('[Complaint] user data: $data');

      if (mounted && data != null) {
        setState(() => _userData = data);
      }
    } catch (e) {
      debugPrint('[Complaint] _loadUser error: $e');
    } finally {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  String get _complainantName {
    // A. Name already stored in complaint doc
    for (final key in ['userName', 'complainantName', 'reporterName']) {
      final v = (widget.data[key] as String? ?? '').trim();
      if (v.isNotEmpty) return v;
    }

    // B. From fetched user document
    if (_userData != null) {
      for (final key in ['fullName', 'name', 'username', 'email']) {
        final v = (_userData![key] as String? ?? '').trim();
        if (v.isNotEmpty) return v;
      }
    }

    debugPrint('[Complaint] name fallback — _userData=$_userData uid="${_resolveUid()}"');
    return 'مستخدم غير معروف';
  }

  String _roleLabel(String r) => switch (r) {
        'restaurant' => 'مطعم',
        'charity'    => 'جمعية',
        'individual' => 'مستخدم',
        'admin'      => 'مسؤول',
        _            => r.isEmpty ? '—' : r,
      };

  String _formatDateTime(dynamic ts) {
    if (ts is! Timestamp) return '—';
    final d    = ts.toDate();
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'م' : 'ص';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} - '
        '${hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  // ─── admin actions ────────────────────────────────────────────────────────

  Future<void> _resolveWithNote() async {
    setState(() => _resolving = true);
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _svc.resolveComplaintWithNote(
        complaintId: widget.docId,
        adminId: adminId,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حل الشكوى ✅'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _reopenComplaint() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة فتح الشكوى'),
        content: const Text('هل تريد إعادة فتح هذه الشكوى؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: AppColors.secondary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إعادة فتح'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reopening = true);
    try {
      await _svc.reopenComplaint(widget.docId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إعادة فتح الشكوى'),
          backgroundColor: AppColors.secondary,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _reopening = false);
    }
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d       = widget.data;
    final status  = d['status'] as String? ?? 'open';
    final isOpen  = status == 'open';
    final desc    = (d['description'] as String? ?? '').trim();
    final images  = (d['images'] as List<dynamic>? ?? [])
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تفاصيل الشكوى'),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── معلومات الشكوى ──
            _SectionCard(
              title: 'معلومات الشكوى',
              icon: Icons.report_outlined,
              children: [
                _InfoRow(label: 'رقم الشكوى', value: '#${widget.docId}'),
                _InfoRow(
                  label: 'الحالة',
                  value: isOpen ? 'مفتوحة' : 'تم الحل',
                  valueColor: isOpen ? AppColors.danger : AppColors.success,
                ),
                if (desc.isNotEmpty)
                  _InfoRow(
                      label: 'نص الشكوى',
                      value: desc,
                      multiline: true),
                _InfoRow(
                  label: 'تاريخ الإرسال',
                  value: _formatDateTime(d['createdAt']),
                ),
                if (d['updatedAt'] != null)
                  _InfoRow(
                      label: 'آخر تعديل',
                      value: _formatDateTime(d['updatedAt'])),
                if (d['resolvedAt'] != null)
                  _InfoRow(
                      label: 'تاريخ الحل',
                      value: _formatDateTime(d['resolvedAt'])),
                if ((d['resolvedBy'] as String? ?? '').isNotEmpty)
                  _InfoRow(
                      label: 'حُلّت بواسطة',
                      value: d['resolvedBy'] as String),
                if ((d['resolutionNote'] as String? ?? '').isNotEmpty)
                  _InfoRow(
                    label: 'ملاحظة الحل',
                    value: d['resolutionNote'] as String,
                    multiline: true,
                  ),
                if ((d['relatedOfferId'] as String? ?? '').isNotEmpty)
                  _InfoRow(
                      label: 'العرض المرتبط',
                      value: d['relatedOfferId'] as String),
                if ((d['relatedReservationId'] as String? ?? '').isNotEmpty)
                  _InfoRow(
                      label: 'الحجز المرتبط',
                      value: d['relatedReservationId'] as String),
              ],
            ),
            const SizedBox(height: 12),

            // ── مقدم الشكوى ──
            _SectionCard(
              title: 'مقدم الشكوى',
              icon: Icons.person_outline_rounded,
              children: _buildComplainantRows(),
            ),

            // ── صور مرفقة ──
            if (images.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: 'الصور المرفقة',
                icon: Icons.image_outlined,
                children: [
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          images[i],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.textLight),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ── إجراءات المسؤول ──
            if (isOpen) ...[
              // ملاحظة الحل (اختيارية)
              Container(
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
                    const Row(
                      children: [
                        Icon(Icons.edit_note_rounded,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'ملاحظة الحل (اختيارية)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'أدخل ملاحظة الحل هنا...',
                        hintStyle: const TextStyle(
                            color: AppColors.textLight, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Resolve button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _resolving ? null : _resolveWithNote,
                  icon: _resolving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _resolving ? 'جاري الحل...' : 'تمييز كمحلول',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              // Reopen button (for resolved complaints)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _reopening ? null : _reopenComplaint,
                  icon: _reopening
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.secondary),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _reopening ? 'جاري...' : 'إعادة فتح الشكوى',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── complainant rows ─────────────────────────────────────────────────────

  List<Widget> _buildComplainantRows() {
    final rows = <Widget>[
      _InfoRow(label: 'الاسم', value: _complainantName),
    ];

    // Role: try complaint doc first, then user doc
    final roleFromComplaint =
        (widget.data['userRole'] as String? ?? '').trim();
    if (roleFromComplaint.isNotEmpty) {
      rows.add(
          _InfoRow(label: 'الدور', value: _roleLabel(roleFromComplaint)));
    } else if (_userData != null) {
      final r = (_userData!['role'] as String? ?? '').trim();
      if (r.isNotEmpty) {
        rows.add(_InfoRow(label: 'الدور', value: _roleLabel(r)));
      }
    }

    if (_loadingUser) {
      rows.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ));
      return rows;
    }

    final u = _userData;
    if (u != null) {
      if ((u['email'] as String? ?? '').trim().isNotEmpty) {
        rows.add(_InfoRow(
            label: 'البريد الإلكتروني', value: u['email'] as String));
      }
      if ((u['phone'] as String? ?? '').trim().isNotEmpty) {
        rows.add(
            _InfoRow(label: 'الهاتف', value: u['phone'] as String));
      }
    }
    return rows;
  }
}

// ─── Shared private widgets ───────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String       title;
  final IconData     icon;
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
  final String  label;
  final String  value;
  final Color?  valueColor;
  final bool    multiline;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 13,
      color: valueColor ?? AppColors.textDark,
      height: 1.5,
    );

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
                Text(value, style: valueStyle),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: Text(value, style: valueStyle)),
              ],
            ),
    );
  }
}
