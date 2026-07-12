import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// شاشة تفاصيل طلب التحقق — تعرض جميع بيانات التسجيل للمطعم أو الجمعية
// ─────────────────────────────────────────────────────────────────────────────
class AdminVerificationDetailsScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String role;

  const AdminVerificationDetailsScreen({
    super.key,
    required this.docId,
    required this.data,
    required this.role,
  });

  @override
  State<AdminVerificationDetailsScreen> createState() =>
      _AdminVerificationDetailsScreenState();
}

class _AdminVerificationDetailsScreenState
    extends State<AdminVerificationDetailsScreen> {
  bool _busy = false;

  // ── اسم المؤسسة ──
  String get _orgName =>
      (widget.data['restaurantName'] as String? ??
          widget.data['charityName'] as String? ??
          widget.data['name'] as String? ??
          widget.data['fullName'] as String? ??
          '')
          .trim()
          .let((s) => s.isNotEmpty ? s : 'غير محدد');

  bool get _isRestaurant => widget.role == 'restaurant';

  String get _roleCollection =>
      _isRestaurant ? 'restaurants' : 'charities';

  // ── حقل مساعد: قراءة نص من data مع fallback ──
  String _str(String key, [String fallback = '—']) {
    final v = widget.data[key];
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isNotEmpty ? s : fallback;
  }

  // ── تنسيق Timestamp ──
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
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y - $h:$min';
  }

  // ── ساعات العمل ──
  String get _workingHoursStr {
    final wh = widget.data['workingHours'];
    if (wh is Map) {
      final start = (wh['start'] as String? ?? '').trim();
      final end = (wh['end'] as String? ?? '').trim();
      if (start.isNotEmpty && end.isNotEmpty) return 'من $start إلى $end';
    }
    return '—';
  }

  // ── عناوين URLs ──
  String get _logoUrl {
    final a = (widget.data['logoUrl'] as String? ?? '').trim();
    if (a.isNotEmpty) return a;
    return (widget.data['photoUrl'] as String? ?? '').trim();
  }

  String get _docUrl => _isRestaurant
      ? (widget.data['businessLicenseUrl'] as String? ?? '').trim()
      : (widget.data['charityDocumentUrl'] as String? ?? '').trim();

  // ── حالة التحقق ──
  String get _status =>
      (widget.data['verificationStatus'] as String? ?? 'pending');

  // ── موافقة ──
  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.docId),
        {
          'verificationStatus': 'approved',
          'isApproved': true,
          'verificationReviewedBy': adminId,
          'verificationReviewedAt': FieldValue.serverTimestamp(),
          'rejectionReason': null,
          // ── علامة دائمة لا تُعاد أبداً إلى false: تُستخدَم لاحقاً للسماح
          // بدخول محدود إن رُفض تحديث لاحق (كتعديل الرخصة) بدل حظر كامل —
          // راجع AuthService.login وmain.dart ──
          'wasEverApproved': true,
        },
      );
      batch.set(
        FirebaseFirestore.instance
            .collection(_roleCollection)
            .doc(widget.docId),
        {
          'isVerified': true,
          'verificationStatus': 'approved',
          'rejectionReason': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      await NotificationService().sendNotification(
        userId: widget.docId,
        title: 'تم قبول حسابك ✅',
        message: 'تمت الموافقة على حسابك ويمكنك الآن استخدام التطبيق.',
        type: 'account',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت الموافقة ✅'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── رفض ──
  Future<void> _reject() async {
    final reason = await _askReason(context);
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.docId),
        {
          'verificationStatus': 'rejected',
          'isApproved': false,
          'verificationReviewedBy': adminId,
          'verificationReviewedAt': FieldValue.serverTimestamp(),
          'rejectionReason': reason,
        },
      );
      batch.set(
        FirebaseFirestore.instance
            .collection(_roleCollection)
            .doc(widget.docId),
        {
          'isVerified': false,
          'verificationStatus': 'rejected',
          'rejectionReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      // ── إخفاء/تعليق العروض العامة النشطة لهذا المزوّد فور الرفض (Part 9
      // item 79) — نفس المنطق المستخدم في admin_verification_panel.dart،
      // غير حرج: فشله لا يُبطل قرار الرفض نفسه ──
      try {
        final activeOffers = await FirebaseFirestore.instance
            .collection('offers')
            .where('providerUserId', isEqualTo: widget.docId)
            .where('status', isEqualTo: 'available')
            .get();
        if (activeOffers.docs.isNotEmpty) {
          final offersBatch = FirebaseFirestore.instance.batch();
          for (final doc in activeOffers.docs) {
            offersBatch.update(doc.reference, {
              'status': 'closed',
              'closedDueToRejection': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          await offersBatch.commit();
        }
      } catch (e) {
        debugPrint('[AdminVerificationDetails] failed to hide offers after '
            'rejection (non-critical): $e');
      }

      await NotificationService().sendNotification(
        userId: widget.docId,
        title: 'طلبك مرفوض',
        message: 'تم رفض حسابك. السبب: $reason',
        type: 'account',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الرفض'),
          backgroundColor: AppColors.danger,
        ),
      );
      Navigator.pop(context);
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
    final lat = widget.data['latitude'] as double?;
    final lng = widget.data['longitude'] as double?;
    final hasLocation = lat != null && lng != null;
    final reviewedBy = (widget.data['verificationReviewedBy'] as String? ?? '').trim();
    final rejectionReason = (widget.data['rejectionReason'] as String? ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        title: Text(_orgName,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── شعار (لافتة كبيرة) ──
            if (_logoUrl.isNotEmpty)
              _LogoBanner(url: _logoUrl, title: 'شعار $_orgName'),

            const SizedBox(height: 16),

            // ── المعلومات العامة ──
            _SectionCard(
              title: 'المعلومات العامة',
              icon: Icons.info_outline_rounded,
              children: [
                _InfoRow(
                  label: _isRestaurant ? 'اسم المطعم' : 'اسم الجمعية',
                  value: _orgName,
                ),
                if (_isRestaurant)
                  _InfoRow(label: 'صاحب العمل', value: _str('ownerName')),
                if (!_isRestaurant)
                  _InfoRow(label: 'الشخص المسؤول', value: _str('responsiblePerson')),
                _InfoRow(label: 'البريد الإلكتروني', value: _str('email')),
                _InfoRow(label: 'رقم الهاتف', value: _str('phone')),
                _InfoRow(
                  label: _isRestaurant ? 'رقم الرخصة' : 'رقم التسجيل',
                  value: _isRestaurant
                      ? _str('licenseNumber')
                      : _str('registrationNumber'),
                ),
                _InfoRow(label: 'ساعات العمل', value: _workingHoursStr),
                _InfoRow(label: 'الوصف', value: _str('description')),
                _InfoRow(label: 'العنوان', value: _str('address')),
                _InfoRow(
                  label: 'تاريخ التسجيل',
                  value: _formatTs(widget.data['createdAt']),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── حالة التحقق ──
            _SectionCard(
              title: 'التحقق',
              icon: Icons.verified_user_outlined,
              children: [
                _InfoRow(
                  label: 'حالة الطلب',
                  valueWidget: _StatusBadge(status: _status),
                ),
                if (reviewedBy.isNotEmpty)
                  _InfoRow(label: 'مراجع بواسطة', value: reviewedBy),
                if (widget.data['verificationReviewedAt'] != null)
                  _InfoRow(
                    label: 'تاريخ المراجعة',
                    value: _formatTs(widget.data['verificationReviewedAt']),
                  ),
                if (rejectionReason.isNotEmpty)
                  _InfoRow(
                    label: 'سبب الرفض',
                    value: rejectionReason,
                    valueColor: AppColors.danger,
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ── الوثائق ──
            _SectionCard(
              title: 'الوثائق',
              icon: Icons.folder_outlined,
              children: [
                const _DocLabel(label: 'شعار المؤسسة'),
                const SizedBox(height: 6),
                _logoUrl.isNotEmpty
                    ? _TappableImage(url: _logoUrl, title: 'شعار المؤسسة')
                    : const _MissingDoc(label: 'لا توجد صورة للشعار'),
                const SizedBox(height: 14),
                _DocLabel(
                  label: _isRestaurant ? 'الرخصة التجارية' : 'وثيقة التسجيل',
                ),
                const SizedBox(height: 6),
                _docUrl.isNotEmpty
                    ? _TappableImage(
                        url: _docUrl,
                        title: _isRestaurant ? 'الرخصة التجارية' : 'وثيقة التسجيل',
                      )
                    : const _MissingDoc(label: 'لا توجد وثيقة مرفقة'),
              ],
            ),

            // ── الموقع ──
            if (hasLocation) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: 'الموقع',
                icon: Icons.location_on_outlined,
                children: [
                  _InfoRow(label: 'خط العرض', value: lat.toStringAsFixed(6)),
                  _InfoRow(label: 'خط الطول', value: lng.toStringAsFixed(6)),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ── إجراءات المراجعة ──
            if (_status == 'pending')
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
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('قبول', style: TextStyle(fontSize: 15)),
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

// ─────────────────────────────────────────────────────────────────────────────
// لافتة الشعار العلوية (قابلة للنقر → عرض كامل الشاشة)
// ─────────────────────────────────────────────────────────────────────────────
class _LogoBanner extends StatelessWidget {
  final String url;
  final String title;

  const _LogoBanner({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context, url, title),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_rounded,
                    color: AppColors.primary, size: 48),
                SizedBox(height: 8),
                Text('تعذر تحميل الشعار',
                    style: TextStyle(color: AppColors.textLight)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// صورة قابلة للنقر (داخل قسم الوثائق)
// ─────────────────────────────────────────────────────────────────────────────
class _TappableImage extends StatelessWidget {
  final String url;
  final String title;

  const _TappableImage({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    final isPdf = _isPdfUrl(url);
    if (isPdf) {
      return _PdfTile(url: url);
    }
    return GestureDetector(
      onTap: () => _openFullScreen(context, url, title),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const _MissingDoc(label: 'تعذر تحميل الصورة'),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// عرض ملف PDF (نسخ الرابط)
// ─────────────────────────────────────────────────────────────────────────────
class _PdfTile extends StatelessWidget {
  final String url;
  const _PdfTile({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_rounded,
              color: AppColors.danger, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('ملف PDF',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ),
          TextButton.icon(
            onPressed: () async {
              await _copyToClipboard(context, url);
            },
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text('نسخ الرابط', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// وثيقة مفقودة
// ─────────────────────────────────────────────────────────────────────────────
class _MissingDoc extends StatelessWidget {
  final String label;
  const _MissingDoc({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.insert_drive_file_outlined,
              color: AppColors.textLight.withValues(alpha: 0.5), size: 36),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textLight, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// تسمية الوثيقة
// ─────────────────────────────────────────────────────────────────────────────
class _DocLabel extends StatelessWidget {
  final String label;
  const _DocLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// بطاقة قسم
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// صف معلومة
// ─────────────────────────────────────────────────────────────────────────────
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
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textLight),
            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// شارة حالة التحقق
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'approved' => ('تمت الموافقة', AppColors.success, Icons.check_circle_rounded),
      'rejected' => ('مرفوض', AppColors.danger, Icons.cancel_rounded),
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

// ─────────────────────────────────────────────────────────────────────────────
// شاشة الصورة كاملة الشاشة
// ─────────────────────────────────────────────────────────────────────────────
class _FullScreenImagePage extends StatelessWidget {
  final String url;
  final String title;
  const _FullScreenImagePage({required this.url, required this.title});

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

// ─────────────────────────────────────────────────────────────────────────────
// مساعدات مشتركة
// ─────────────────────────────────────────────────────────────────────────────
void _openFullScreen(BuildContext context, String url, String title) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _FullScreenImagePage(url: url, title: title),
    ),
  );
}

bool _isPdfUrl(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('.pdf')) return true;
  // Cloudinary raw PDF uploads contain /raw/upload/ in the path
  if (lower.contains('/raw/upload/')) return true;
  return false;
}

Future<void> _copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('تم نسخ الرابط')),
  );
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}

// ── نافذة إدخال سبب الرفض (مشتركة) ──
Future<String?> _askReason(BuildContext context) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
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
  return result;
}
