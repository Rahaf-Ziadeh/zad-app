import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import 'admin_verification_details_screen.dart';

class AdminVerificationPanel extends StatelessWidget {
  const AdminVerificationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('مراجعة التحقق'),
          backgroundColor: Colors.white,
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            tabs: [
              Tab(text: 'المطاعم'),
              Tab(text: 'الجمعيات'),
              Tab(text: 'الهويات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PendingList(role: 'restaurant'),
            _PendingList(role: 'charity'),
            _IdentityList(),
          ],
        ),
      ),
    );
  }
}

// ─── Restaurant / Charity pending list ───────────────────────────────────────

class _PendingList extends StatelessWidget {
  final String role;
  const _PendingList({required this.role});

  @override
  Widget build(BuildContext context) {
    final String roleCollection =
        role == 'restaurant' ? 'restaurants' : 'charities';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .where('verificationStatus', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              role == 'restaurant'
                  ? 'لا توجد مطاعم بانتظار المراجعة'
                  : 'لا توجد جمعيات بانتظار المراجعة',
              style: const TextStyle(color: AppColors.textLight),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            // ── جلب المستند التفصيلي (restaurants/charities) لعرض بيانات الترخيص والشعار ──
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection(roleCollection)
                  .doc(doc.id)
                  .get(),
              builder: (context, roleSnap) {
                final roleData =
                    roleSnap.data?.data() as Map<String, dynamic>? ?? {};
                return _OrgVerificationCard(
                  docId: doc.id,
                  data: {...data, ...roleData},
                  role: role,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── User identity pending list ───────────────────────────────────────────────

class _IdentityList extends StatelessWidget {
  const _IdentityList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('identityVerificationStatus', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد طلبات هوية بانتظار المراجعة',
              style: TextStyle(color: AppColors.textLight),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _IdentityVerificationCard(docId: doc.id, data: data);
          },
        );
      },
    );
  }
}

// ─── Organisation card (restaurant / charity) ─────────────────────────────────

class _OrgVerificationCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String role;

  const _OrgVerificationCard({
    required this.docId,
    required this.data,
    required this.role,
  });

  @override
  State<_OrgVerificationCard> createState() => _OrgVerificationCardState();
}

class _OrgVerificationCardState extends State<_OrgVerificationCard> {
  bool _busy = false;

  String get _name =>
      widget.data['name'] ?? widget.data['fullName'] ?? 'غير محدد';
  String get _logoUrl => (widget.data['photoUrl'] as String? ?? '').isNotEmpty
      ? widget.data['photoUrl'] as String
      : (widget.data['logoUrl'] as String? ?? '');
  String get _ownerOrPerson => widget.role == 'restaurant'
      ? (widget.data['ownerName'] as String? ?? '—')
      : (widget.data['responsiblePerson'] as String? ?? '—');
  String get _number => widget.role == 'restaurant'
      ? (widget.data['licenseNumber'] as String? ?? '—')
      : (widget.data['registrationNumber'] as String? ?? '—');
  String get _docUrl => widget.role == 'restaurant'
      ? (widget.data['businessLicenseUrl'] as String? ?? '')
      : (widget.data['charityDocumentUrl'] as String? ?? '');

  String get _roleCollection =>
      widget.role == 'restaurant' ? 'restaurants' : 'charities';

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
      // item 79): إغلاقها بضبط status='closed' يكفي لإخفائها تلقائياً من
      // كل شاشات التصفح العامة (كلها تُصفّي status=='available' بالفعل)
      // دون أي تعديل عليها. الحجوزات القائمة قبل الرفض تبقى تعمل — هذا
      // يمنع فقط حجوزات جديدة (reserveOffer يرفض أي عرض status != available
      // أصلاً). عملية غير حرجة: فشلها لا يُبطل قرار الرفض نفسه ──
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
        debugPrint('[AdminVerificationPanel] failed to hide offers after '
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminVerificationDetailsScreen(
          docId: widget.docId,
          data: widget.data,
          role: widget.role,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRestaurant = widget.role == 'restaurant';
    return Container(
      padding: const EdgeInsets.all(14),
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
          // ── Header: tappable → opens full details ──
          GestureDetector(
            onTap: () => _openDetails(context),
            behavior: HitTestBehavior.translucent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // شعار
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _logoUrl.isNotEmpty
                          ? Image.network(_logoUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _iconPlaceholder())
                          : _iconPlaceholder(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textDark)),
                          const SizedBox(height: 3),
                          Text(
                            isRestaurant
                                ? 'صاحب العمل: $_ownerOrPerson'
                                : 'المسؤول: $_ownerOrPerson',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textLight),
                          ),
                          Text(
                            isRestaurant
                                ? 'رقم الرخصة: $_number'
                                : 'رقم التسجيل: $_number',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppColors.textLight),
                  ],
                ),
                if (_docUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DocumentPreview(
                      url: _docUrl,
                      label: isRestaurant ? 'الرخصة التجارية' : 'وثيقة التسجيل'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('رفض'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _approve,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_rounded, size: 16),
                  label: const Text('قبول'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconPlaceholder() => Container(
        width: 52,
        height: 52,
        color: AppColors.primary.withValues(alpha: 0.10),
        child: const Icon(Icons.storefront_rounded,
            color: AppColors.primary, size: 28),
      );
}

// ─── Identity verification card ───────────────────────────────────────────────

class _IdentityVerificationCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _IdentityVerificationCard(
      {required this.docId, required this.data});

  @override
  State<_IdentityVerificationCard> createState() =>
      _IdentityVerificationCardState();
}

class _IdentityVerificationCardState
    extends State<_IdentityVerificationCard> {
  bool _busy = false;

  String get _name =>
      widget.data['name'] ?? widget.data['fullName'] ?? 'مستخدم';
  String get _idNumber =>
      widget.data['identityNumber'] as String? ?? '—';
  String get _docUrl =>
      widget.data['identityDocumentUrl'] as String? ?? '';

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
        },
      );
      batch.set(
        FirebaseFirestore.instance.collection('individuals').doc(widget.docId),
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
          'identityVerificationStatus': 'rejected',
          'identityVerificationReviewedBy': adminId,
          'identityVerificationReviewedAt': FieldValue.serverTimestamp(),
          'identityRejectionReason': reason,
        },
      );
      batch.set(
        FirebaseFirestore.instance.collection('individuals').doc(widget.docId),
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
    return Container(
      padding: const EdgeInsets.all(14),
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
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  _name.isNotEmpty ? _name[0].toUpperCase() : 'م',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textDark)),
                    Text('رقم الهوية: $_idNumber',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ),
            ],
          ),
          if (_docUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DocumentPreview(url: _docUrl, label: 'وثيقة الهوية'),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('رفض'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _approve,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_rounded, size: 16),
                  label: const Text('قبول'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared document preview widget ──────────────────────────────────────────

class _DocumentPreview extends StatelessWidget {
  final String url;
  final String label;

  const _DocumentPreview({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    final isPdf = url.toLowerCase().contains('.pdf') ||
        url.toLowerCase().contains('upload/') &&
            !url.toLowerCase().contains('.jpg') &&
            !url.toLowerCase().contains('.png');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textLight)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: isPdf
              ? Container(
                  width: double.infinity,
                  height: 60,
                  color: AppColors.background,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded,
                          color: AppColors.danger, size: 28),
                      const SizedBox(width: 8),
                      const Text('ملف PDF',
                          style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            size: 16, color: AppColors.textLight),
                        tooltip: 'نسخ الرابط',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ رابط المستند')),
                          );
                        },
                      ),
                    ],
                  ),
                )
              : Image.network(
                  url,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: double.infinity,
                    height: 60,
                    color: AppColors.background,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.insert_drive_file_outlined,
                            color: AppColors.textLight),
                        SizedBox(width: 8),
                        Text('تعذر عرض المستند',
                            style: TextStyle(color: AppColors.textLight)),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Rejection reason dialog ──────────────────────────────────────────────────

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
