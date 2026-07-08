import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────
// الملف الشخصي العام للمستخدم — يظهر للمطعم من شاشة الحجوزات
// يعرض معلومات آمنة فقط (الاسم وسجل الحجوزات مع هذا المطعم)،
// دون أي بيانات حساسة (هوية وطنية، بريد إلكتروني، أو موقع خاص).
// ─────────────────────────────────────────────
class UserPublicProfileScreen extends StatelessWidget {
  final String userId;
  final String userName;
  final String reservationId;
  final String offerId;
  final String offerTitle;
  final String reservationStatus;

  const UserPublicProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.reservationId,
    required this.offerId,
    required this.offerTitle,
    required this.reservationStatus,
  });

  String get _providerUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> _historyStream() => FirebaseFirestore.instance
      .collection('reservations')
      .where('userId', isEqualTo: userId)
      .where('providerUserId', isEqualTo: _providerUid)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // ── نتابع مستند الحجز نفسه لمعرفة إن تم تقييم المستخدم مسبقاً ──
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservations')
            .doc(reservationId)
            .snapshots(),
        builder: (context, resSnap) {
          final resData =
              resSnap.data?.data() as Map<String, dynamic>? ?? {};
          final status = (resData['status'] as String?) ?? reservationStatus;
          final alreadyRated = resData['userRatedByProvider'] == true;
          final canRate = status == 'picked_up' && !alreadyRated;

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '؟',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(userName,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    const Text('مستخدم زاد',
                        style:
                            TextStyle(color: AppColors.textLight, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── سجل الحجوزات مع هذا المطعم فقط (لا نعرض نشاط المستخدم في المطاعم الأخرى) ──
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('سجل الحجوزات معك',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark)),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: _historyStream(),
                        builder: (context, histSnap) {
                          final docs = histSnap.data?.docs ?? [];
                          final total = docs.length;
                          final completed = docs.where((d) {
                            final s =
                                (d.data() as Map<String, dynamic>)['status'];
                            return s == 'picked_up';
                          }).length;

                          return Row(
                            children: [
                              Expanded(
                                child: _MiniStat(
                                    label: 'إجمالي الحجوزات', value: '$total'),
                              ),
                              Container(
                                  width: 1,
                                  height: 34,
                                  color: AppColors.border),
                              Expanded(
                                child: _MiniStat(
                                    label: 'مكتملة', value: '$completed'),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── إجراءات ──
              OutlinedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _ReportUserDialog(
                    reportedUserId: userId,
                    reportedUserName: userName,
                    relatedOfferId: offerId,
                  ),
                ),
                icon: const Icon(Icons.flag_outlined, color: AppColors.danger),
                label: const Text('الإبلاغ عن المستخدم',
                    style: TextStyle(color: AppColors.danger)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),

              if (alreadyRated)
                const Center(
                  child: Text('⭐ لقد قيّمت هذا المستخدم بالفعل',
                      style:
                          TextStyle(color: AppColors.textLight, fontSize: 13)),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canRate
                        ? () => showDialog(
                              context: context,
                              builder: (_) => _RateUserDialog(
                                reservationId: reservationId,
                                userId: userId,
                                userName: userName,
                                offerTitle: offerTitle,
                              ),
                            )
                        : null,
                    icon: const Icon(Icons.star_outline_rounded),
                    label: Text(canRate
                        ? 'تقييم المستخدم'
                        : 'التقييم متاح بعد اكتمال الاستلام'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// نافذة الإبلاغ عن المستخدم — تُعيد استخدام مجموعة complaints نفسها
// المستخدمة في شاشة شكاوى المستخدم العادي، مع حقول إضافية لتحديد المُبلَّغ عنه
// ─────────────────────────────────────────────
class _ReportUserDialog extends StatefulWidget {
  final String reportedUserId;
  final String reportedUserName;
  final String relatedOfferId;

  const _ReportUserDialog({
    required this.reportedUserId,
    required this.reportedUserName,
    required this.relatedOfferId,
  });

  @override
  State<_ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<_ReportUserDialog> {
  final _descController = TextEditingController();
  String? _selectedType;
  bool _loading = false;

  final _types = [
    'سلوك غير لائق',
    'عدم الحضور للاستلام',
    'معلومات خاطئة',
    'مشكلة أخرى',
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة وصف البلاغ')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final reporterId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance.collection('complaints').add({
        'userId': reporterId,
        'reporterRole': 'restaurant',
        'reportedUserId': widget.reportedUserId,
        'reportedUserName': widget.reportedUserName,
        'type': _selectedType ?? 'مشكلة أخرى',
        'description': _descController.text.trim(),
        'relatedOfferId': widget.relatedOfferId,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال البلاغ إلى الإدارة'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('الإبلاغ عن ${widget.reportedUserName}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((type) {
                final selected = _selectedType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.danger.withValues(alpha: 0.10)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.danger : AppColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(type,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.danger
                                : AppColors.textLight)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'اكتب تفاصيل البلاغ...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('إرسال البلاغ'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// نافذة تقييم المستخدم — تُعيد نفس نمط تقييم المطعم في user_orders_screen.dart
// لكن بالاتجاه المعاكس، وبحقول مستقلة لتفادي التعارض مع تقييم العميل للمطعم
// ─────────────────────────────────────────────
class _RateUserDialog extends StatefulWidget {
  final String reservationId;
  final String userId;
  final String userName;
  final String offerTitle;

  const _RateUserDialog({
    required this.reservationId,
    required this.userId,
    required this.userName,
    required this.offerTitle,
  });

  @override
  State<_RateUserDialog> createState() => _RateUserDialogState();
}

class _RateUserDialogState extends State<_RateUserDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار تقييم')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final providerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final reservationRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId);
      final reviewRef =
          FirebaseFirestore.instance.collection('user_reviews').doc();

      await reservationRef.update({
        'userRatedByProvider': true,
        'userRating': _rating,
        'userRatingComment': _commentController.text.trim(),
        'userRatedAt': FieldValue.serverTimestamp(),
      });

      await reviewRef.set({
        'reviewId': reviewRef.id,
        'reservationId': widget.reservationId,
        'offerTitle': widget.offerTitle,
        'raterUserId': providerUid,
        'targetUserId': widget.userId,
        'targetUserName': widget.userName,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال تقييمك ⭐')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('تقييم ${widget.userName}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.offerTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(widget.offerTitle,
                  style: const TextStyle(
                      color: AppColors.textLight, fontSize: 12)),
            ),
          const Text(
            'كيف كانت تجربتك مع هذا المستخدم؟',
            style: TextStyle(color: AppColors.textLight, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    star <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 34,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'أضف تعليقاً (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('إرسال'),
        ),
      ],
    );
  }
}
