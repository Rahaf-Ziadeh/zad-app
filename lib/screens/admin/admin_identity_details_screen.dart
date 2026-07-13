import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';

// Identity verification detail screen — shows the submitted ID photo and allows approve/reject/
// request-more-info. Opened from: AdminVerificationPanel's identity card or an
// 'identity_verification_request' notification.
class AdminIdentityDetailsScreen extends StatefulWidget {
  final String docId; // = Firebase Auth UID
  final Map<String, dynamic> data; // users/{uid} doc data

  const AdminIdentityDetailsScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<AdminIdentityDetailsScreen> createState() =>
      _AdminIdentityDetailsScreenState();
}

class _AdminIdentityDetailsScreenState
    extends State<AdminIdentityDetailsScreen> {
  bool _busy = false;

  // Live copy of users data — updated optimistically after approve/reject so
  // the screen reflects the new status without requiring a full rebuild.
  late Map<String, dynamic> _usersData;
  Map<String, dynamic>? _individualsData;
  bool _loadingIndividuals = true;

  @override
  void initState() {
    super.initState();
    _usersData = Map<String, dynamic>.from(widget.data);
    _loadIndividuals();
  }

  Future<void> _loadIndividuals() async {
    try {
      debugPrint('[Identity][Admin] lookupUid=${widget.docId}');
      final byId = await FirebaseFirestore.instance
          .collection('individuals')
          .doc(widget.docId)
          .get();
      debugPrint('[Identity][Admin] individualsDocExists=${byId.exists}');

      if (byId.exists) {
        if (mounted) setState(() => _individualsData = byId.data());
        return;
      }

      // Fallback: some legacy docs store a different doc ID
      final q = await FirebaseFirestore.instance
          .collection('individuals')
          .where('uid', isEqualTo: widget.docId)
          .limit(1)
          .get();
      final found = q.docs.isNotEmpty;
      debugPrint('[Identity][Admin] usersFallbackExists=$found');
      if (found && mounted) setState(() => _individualsData = q.docs.first.data());
    } catch (e) {
      debugPrint('[Identity][Admin] individuals load error: $e');
    } finally {
      if (mounted) setState(() => _loadingIndividuals = false);
    }
  }

  // Resolves a string field checking users doc first, then individuals fallback.
  String _str(String key, [String fallback = '—']) {
    final vU = _usersData[key];
    if (vU != null) {
      final s = vU.toString().trim();
      if (s.isNotEmpty) return s;
    }
    final vI = _individualsData?[key];
    if (vI != null) {
      final s = vI.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  String get _displayName {
    for (final key in ['name', 'fullName']) {
      final v = (_usersData[key] as String? ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    for (final key in ['name', 'fullName']) {
      final v = (_individualsData?[key] as String? ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    return 'مستخدم';
  }

  String get _nationalId {
    for (final key in ['nationalId', 'identityNumber', 'identityCard']) {
      final v = (_usersData[key] as String? ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    for (final key in ['nationalId', 'identityCard']) {
      final v = (_individualsData?[key] as String? ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    return '—';
  }

  // Check all known field names for backward compat:
  //   identityDocumentUrl  — written by IdentityVerificationScreen + NationalIdStepScreen (after fix)
  //   nationalIdImageUrl   — written by NationalIdStepScreen (before fix, in users doc)
  //   identityImageUrl     — written by IdentityVerificationScreen (in individuals doc)
  //   idImageUrl           — legacy
  String get _imageUrl {
    const keys = [
      'identityDocumentUrl',
      'nationalIdImageUrl',
      'identityImageUrl',
      'idImageUrl',
    ];
    for (final key in keys) {
      final v = (_usersData[key] as String? ?? '').trim();
      if (v.isNotEmpty) {
        debugPrint('[Identity][Admin] resolvedImageUrl=$v (source=users)');
        return v;
      }
    }
    if (_individualsData != null) {
      for (final key in keys) {
        final v = (_individualsData![key] as String? ?? '').trim();
        if (v.isNotEmpty) {
          debugPrint('[Identity][Admin] resolvedImageUrl=$v (source=individuals)');
          return v;
        }
      }
    }
    debugPrint('[Identity][Admin] resolvedImageUrl=(none)');
    return '';
  }

  String get _status =>
      (_usersData['identityVerificationStatus'] as String? ?? 'pending');

  String get _roleLabelStr {
    final r = _str('role');
    switch (r) {
      case 'restaurant':
        return 'مطعم';
      case 'charity':
        return 'جمعية';
      case 'individual':
      case 'user':
        return 'مستخدم';
      case 'admin':
        return 'مدير';
      default:
        return r == '—' ? '—' : r;
    }
  }

  String get _accountStatusStr {
    final s = _str('status', 'active');
    switch (s) {
      case 'active':
        return 'نشط';
      case 'suspended':
        return 'معلّق';
      case 'rejected':
        return 'مرفوض';
      default:
        return s;
    }
  }

  Color get _accountStatusColor {
    final s = _str('status', 'active');
    if (s == 'suspended' || s == 'rejected') return AppColors.danger;
    return AppColors.success;
  }

  String _formatTs(dynamic ts) {
    if (ts == null) return '—';
    DateTime dt;
    try {
      dt = (ts as Timestamp).toDate().toLocal();
    } catch (_) {
      return '—';
    }
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} — $h:$min';
  }

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.docId),
        {
          'identityVerificationStatus': 'approved',
          'identityVerificationReviewedBy': adminId,
          'identityVerificationReviewedAt': FieldValue.serverTimestamp(),
          'identityRejectionReason': null,
        },
      );
      batch.set(
        FirebaseFirestore.instance
            .collection('individuals')
            .doc(widget.docId),
        {
          'verificationStatus': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      await NotificationService().sendNotification(
        userId: widget.docId,
        title: 'تم توثيق هويتك ✅',
        message: 'تمت الموافقة على توثيق هويتك ويمكنك الآن نشر تبرعاتك.',
        type: 'account',
      );
      if (!mounted) return;
      setState(() {
        _usersData = {
          ..._usersData,
          'identityVerificationStatus': 'approved',
          'identityVerificationReviewedBy': adminId,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم توثيق الهوية ✅'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestAdditionalInfo() async {
    final ctrl = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب معلومات إضافية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيصل هذا الطلب للمستخدم مع توضيح المعلومات المطلوبة.',
              style: TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'اكتب توضيحاً للمستخدم...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              final r = ctrl.text.trim();
              if (r.isEmpty) return;
              Navigator.pop(ctx, r);
            },
            child: const Text('إرسال', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (message == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.docId),
        {
          'identityVerificationStatus': 'pending_additional_info',
          'additionalInfoRequestMessage': message,
          'additionalInfoRequestedAt': FieldValue.serverTimestamp(),
          'additionalInfoRequestedBy': adminId,
          'additionalInfoRequested': true,
        },
      );
      batch.set(
        FirebaseFirestore.instance.collection('individuals').doc(widget.docId),
        {
          'additionalInfoRequested': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      await NotificationService().sendNotification(
        userId: widget.docId,
        title: 'مطلوب معلومات إضافية لتوثيق هويتك',
        message: message,
        type: 'identity_additional_info_required',
        relatedId: widget.docId,
      );
      if (!mounted) return;
      setState(() {
        _usersData = {
          ..._usersData,
          'identityVerificationStatus': 'pending_additional_info',
          'additionalInfoRequestMessage': message,
          'additionalInfoRequestedBy': adminId,
          'additionalInfoRequested': true,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب المعلومات للمستخدم'),
          backgroundColor: Colors.amber,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب سبب الرفض...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              final r = ctrl.text.trim();
              if (r.isEmpty) return;
              Navigator.pop(ctx, r);
            },
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.docId),
        {
          'identityVerificationStatus': 'rejected',
          'identityVerificationReviewedBy': adminId,
          'identityVerificationReviewedAt': FieldValue.serverTimestamp(),
          'identityRejectionReason': reason,
        },
      );
      batch.set(
        FirebaseFirestore.instance
            .collection('individuals')
            .doc(widget.docId),
        {
          'verificationStatus': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      await NotificationService().sendNotification(
        userId: widget.docId,
        title: 'طلب التوثيق مرفوض',
        message: 'تم رفض طلب توثيق هويتك. السبب: $reason',
        type: 'account',
      );
      if (!mounted) return;
      setState(() {
        _usersData = {
          ..._usersData,
          'identityVerificationStatus': 'rejected',
          'identityVerificationReviewedBy': adminId,
          'identityRejectionReason': reason,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الرفض')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = _imageUrl;
    final rejectionReason =
        (_usersData['identityRejectionReason'] as String? ?? '').trim();
    final reviewedBy =
        (_usersData['identityVerificationReviewedBy'] as String? ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        title: Text(
          _displayName,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark),
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              title: 'المعلومات الشخصية',
              icon: Icons.person_outline_rounded,
              children: [
                _InfoRow(label: 'الاسم الكامل', value: _displayName),
                _InfoRow(label: 'البريد الإلكتروني', value: _str('email')),
                _InfoRow(label: 'رقم الهاتف', value: _str('phone')),
                _InfoRow(label: 'الدور', value: _roleLabelStr),
                _InfoRow(
                  label: 'حالة الحساب',
                  value: _accountStatusStr,
                  valueColor: _accountStatusColor,
                ),
                _InfoRow(label: 'رقم الهوية', value: _nationalId),
                _InfoRow(
                  label: 'تاريخ التسجيل',
                  value: _formatTs(_usersData['createdAt']),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _SectionCard(
              title: 'حالة التحقق',
              icon: Icons.verified_user_outlined,
              children: [
                _InfoRow(
                  label: 'الحالة',
                  valueWidget: _StatusBadge(status: _status),
                ),
                if (reviewedBy.isNotEmpty)
                  _InfoRow(label: 'مراجع بواسطة', value: reviewedBy),
                if (_usersData['identityVerificationReviewedAt'] != null)
                  _InfoRow(
                    label: 'تاريخ المراجعة',
                    value: _formatTs(
                        _usersData['identityVerificationReviewedAt']),
                  ),
                if (rejectionReason.isNotEmpty)
                  _InfoRow(
                    label: 'سبب الرفض',
                    value: rejectionReason,
                    valueColor: AppColors.danger,
                  ),
                if ((_usersData['additionalInfoRequestMessage'] as String? ?? '').isNotEmpty) ...[
                  _InfoRow(
                    label: 'المعلومات المطلوبة',
                    value: _usersData['additionalInfoRequestMessage'] as String,
                    valueColor: Colors.amber.shade700,
                  ),
                  if (_usersData['additionalInfoRequestedAt'] != null)
                    _InfoRow(
                      label: 'تاريخ الطلب',
                      value: _formatTs(_usersData['additionalInfoRequestedAt']),
                    ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            _SectionCard(
              title: 'صورة الهوية',
              icon: Icons.badge_outlined,
              children: [
                if (imgUrl.isNotEmpty)
                  _TappableImage(url: imgUrl, title: 'صورة الهوية')
                else if (_loadingIndividuals)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  const _MissingDoc(label: 'لا توجد صورة هوية مرفقة'),
              ],
            ),

            const SizedBox(height: 24),

            // Review actions — shown while pending or awaiting additional info.
            if (_status == 'pending' || _status == 'pending_additional_info')
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _reject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('رفض', style: TextStyle(fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _approve,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_rounded, size: 18),
                          label: const Text('قبول', style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _requestAdditionalInfo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber.shade700,
                        side: BorderSide(color: Colors.amber.shade600),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      label: const Text('طلب معلومات إضافية',
                          style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Tappable image → full-screen with zoom ───────────────────────────────────

class _TappableImage extends StatelessWidget {
  final String url;
  final String title;

  const _TappableImage({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    final isPdf = url.toLowerCase().contains('.pdf') ||
        url.toLowerCase().contains('/raw/upload/');
    if (isPdf) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded,
                color: AppColors.danger, size: 32),
            SizedBox(width: 12),
            Text('ملف PDF',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FullScreenImage(url: url, title: title),
        ),
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const _MissingDoc(label: 'تعذر تحميل صورة الهوية'),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('عرض كامل',
                    style:
                        TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Full-screen image with zoom ─────────────────────────────────────────────

class _FullScreenImage extends StatelessWidget {
  final String url;
  final String title;

  const _FullScreenImage({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        elevation: 0,
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, __, ___) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text('تعذر تحميل الصورة',
                    style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Missing document placeholder ────────────────────────────────────────────

class _MissingDoc extends StatelessWidget {
  final String label;
  const _MissingDoc({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.insert_drive_file_outlined,
              color: AppColors.textLight.withValues(alpha: 0.5), size: 36),
          const SizedBox(height: 8),
          Text(label,
              style:
                  const TextStyle(color: AppColors.textLight, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

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
        border: Border.all(color: AppColors.border),
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
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textLight)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: valueWidget ??
                Text(
                  value ?? '—',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textDark,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'approved' => ('تمت الموافقة', AppColors.success, Icons.check_circle_rounded),
      'rejected' => ('مرفوض', AppColors.danger, Icons.cancel_rounded),
      'pending_additional_info' => ('بانتظار معلومات إضافية', Colors.amber.shade700, Icons.info_outline_rounded),
      _ => ('قيد المراجعة', AppColors.secondary, Icons.hourglass_top_rounded),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ],
    );
  }
}
