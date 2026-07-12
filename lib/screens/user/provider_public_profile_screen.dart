import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/offer_utils.dart';
import '../../widgets/offer_widgets.dart';
import 'donate_tab.dart';
import 'national_id_step_screen.dart';
import 'offer_details_screen.dart';

// ─────────────────────────────────────────────
// الملف العام لمزوّد الطعام (مطعم أو جمعية) — يظهر للمستخدم العادي
// عند الضغط على اسم المزوّد ضمن تفاصيل عرض/باقة/تبرع.
// يعرض معلومات آمنة فقط، ولا يكشف أي وثائق أو بيانات إدارية خاصة.
// ─────────────────────────────────────────────
class ProviderPublicProfileScreen extends StatelessWidget {
  final String providerUserId;
  final String providerRole; // 'restaurant' | 'charity'

  const ProviderPublicProfileScreen({
    super.key,
    required this.providerUserId,
    required this.providerRole,
  });

  String get _roleCollection =>
      providerRole == 'charity' ? 'charities' : 'restaurants';
  String get _roleLabel => providerRole == 'charity' ? 'جمعية خيرية' : 'مطعم';
  bool get _isRestaurant => providerRole == 'restaurant';

  @override
  Widget build(BuildContext context) {
    // ── تبويبات مختلفة حسب نوع المزوّد: المطعم يفصل العروض عن الباقات ──
    final tabLabels = _isRestaurant
        ? const ['معلومات', 'العروض', 'الباقات', 'التقييمات / الإبلاغ']
        : const ['معلومات', 'منشورات الجمعية', 'التقييمات / الإبلاغ'];

    return DefaultTabController(
      length: tabLabels.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('الملف العام'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            isScrollable: _isRestaurant,
            tabs: tabLabels.map((t) => Tab(text: t)).toList(),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection(_roleCollection)
              .doc(providerUserId)
              .snapshots(),
          builder: (context, roleSnap) {
            final roleData =
                roleSnap.data?.data() as Map<String, dynamic>? ?? {};
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(providerUserId)
                  .snapshots(),
              builder: (context, userSnap) {
                final userData =
                    userSnap.data?.data() as Map<String, dynamic>? ?? {};
                final name = (roleData['name'] as String?) ??
                    (userData['name'] as String?) ??
                    _roleLabel;
                final usersPhotoUrl = userData['photoUrl'] as String?;
                final photoUrl =
                    (usersPhotoUrl != null && usersPhotoUrl.isNotEmpty)
                        ? usersPhotoUrl
                        : (roleData['logoUrl'] as String?);

                return Column(
                  children: [
                    _ProviderHeader(
                      name: name,
                      photoUrl: photoUrl,
                      roleLabel: _roleLabel,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: _isRestaurant
                            ? [
                                _InfoTab(
                                    roleData: roleData, roleLabel: _roleLabel),
                                _OffersTab(
                                  providerUserId: providerUserId,
                                  // ── العروض العادية فقط: تستثني أنواع الباقات ──
                                  filter: (d) => !_isPackageOfferType(
                                      d['offerType'] as String?),
                                  emptyMessage: 'لا توجد عروض متاحة حالياً',
                                ),
                                _OffersTab(
                                  providerUserId: providerUserId,
                                  // ── الباقات فقط ──
                                  filter: (d) => _isPackageOfferType(
                                      d['offerType'] as String?),
                                  emptyMessage: 'لا توجد باقات متاحة حالياً',
                                ),
                                _ReviewsReportTab(
                                  providerUserId: providerUserId,
                                  providerName: name,
                                ),
                              ]
                            : [
                                _InfoTab(
                                  roleData: roleData,
                                  roleLabel: _roleLabel,
                                  charityId: providerUserId,
                                  charityName: name,
                                ),
                                _CharityPostsTab(
                                    providerUserId: providerUserId),
                                _ReviewsReportTab(
                                  providerUserId: providerUserId,
                                  providerName: name,
                                ),
                              ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ── أنواع العروض التي تُعامَل كـ"باقة" لدى المطعم ──
bool _isPackageOfferType(String? offerType) =>
    offerType == 'mystery_package' || offerType == 'restaurant_package';

// ─────────────────────────────────────────────
// رأس الصفحة: الشعار والاسم ونوع الحساب
// ─────────────────────────────────────────────
class _ProviderHeader extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String roleLabel;

  const _ProviderHeader({
    required this.name,
    required this.photoUrl,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                ? NetworkImage(photoUrl!)
                : null,
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '؟',
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          Text(name,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(roleLabel,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// تبويب "معلومات" — بيانات عامة آمنة فقط
// ─────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  final Map<String, dynamic> roleData;
  final String roleLabel;
  // ── تُمرَّر فقط للجمعيات، لإظهار زر "تبرع الآن" ──
  final String? charityId;
  final String? charityName;

  const _InfoTab({
    required this.roleData,
    required this.roleLabel,
    this.charityId,
    this.charityName,
  });

  String? _formatWorkingHours() {
    final wh = roleData['workingHours'];
    if (wh is! Map) return null;
    final start = wh['start'] as String?;
    final end = wh['end'] as String?;
    if (start == null || end == null || start.isEmpty || end.isEmpty) {
      return null;
    }
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    final description = (roleData['description'] as String? ?? '').trim();
    final address = (roleData['address'] as String? ?? '').trim();
    final phone = (roleData['phone'] as String? ?? '').trim();
    final workingHours = _formatWorkingHours();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (charityId != null && charityId!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // ── التحقق من توثيق الهوية قبل فتح نموذج التبرع، وليس عند
                  // الضغط على "تبرع" داخل النموذج فقط؛ عبر نفس الدالة
                  // المشتركة ensureNationalIdSaved دون أي منطق توثيق منفصل ──
                  final identityReady = await ensureNationalIdSaved(context);
                  if (!context.mounted || !identityReady) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CharityDonationScreen(
                        initialCharityId: charityId,
                        initialCharityName: charityName,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.volunteer_activism_rounded),
                label: const Text('تبرع الآن',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        _InfoCard(
          children: [
            if (description.isNotEmpty)
              OfferInfoRow(
                icon: Icons.description_outlined,
                label: 'الوصف',
                value: description,
              ),
            if (address.isNotEmpty)
              OfferInfoRow(
                icon: Icons.location_on_outlined,
                label: 'العنوان',
                value: address,
              ),
            if (workingHours != null)
              OfferInfoRow(
                icon: Icons.access_time_rounded,
                label: 'ساعات العمل',
                value: workingHours,
              ),
            // ── رقم الهاتف: يُعرض هنا فقط لأنه معلومة تواصل عامة للمنشأة ──
            if (phone.isNotEmpty)
              OfferInfoRow(
                icon: Icons.phone_outlined,
                label: 'رقم الهاتف',
                value: phone,
                isPhone: true,
              ),
            if (description.isEmpty &&
                address.isEmpty &&
                workingHours == null &&
                phone.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('لا تتوفر معلومات إضافية بعد',
                      style: TextStyle(color: AppColors.textLight)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// تبويب "العروض" — عروض هذا المزوّد النشطة فقط، مُفلترة حسب المعرّف لا الاسم
// ─────────────────────────────────────────────
class _OffersTab extends StatelessWidget {
  final String providerUserId;
  final bool Function(Map<String, dynamic> data)? filter;
  final String emptyMessage;

  const _OffersTab({
    required this.providerUserId,
    this.filter,
    this.emptyMessage = 'لا توجد عروض متاحة حالياً',
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('providerUserId', isEqualTo: providerUserId)
          .where('status', isEqualTo: 'available')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notExpired = snap.data!.docs
            .where((d) => !isOfferExpired(d.data() as Map<String, dynamic>))
            .toList();
        final docs = filter == null
            ? notExpired
            : notExpired
                .where((d) => filter!(d.data() as Map<String, dynamic>))
                .toList();
        if (docs.isEmpty) {
          return Center(
            child: Text(emptyMessage,
                style: const TextStyle(color: AppColors.textLight)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'عرض طعام';
            final imageUrl = data['imageUrl'] ?? '';
            final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
            final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
            final isFree = data['isFree'] == true || discountPrice == 0;
            final pickupLocation = data['pickupLocation'] ?? 'غير محدد';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OfferDetailsScreen(docId: doc.id, data: data),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(16)),
                      child: imageUrl.isNotEmpty
                          ? Image.network(imageUrl,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  buildImagePlaceholder(
                                      icon: Icons.fastfood_rounded,
                                      height: 90))
                          : buildImagePlaceholder(
                              icon: Icons.fastfood_rounded, height: 90),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textDark)),
                            const SizedBox(height: 4),
                            Text(pickupLocation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight)),
                            const SizedBox(height: 6),
                            OfferPriceRow(
                              isFree: isFree,
                              originalPrice: originalPrice,
                              discountPrice: discountPrice,
                              currency: data['currency'] ?? 'ILS',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// تبويب "منشورات الجمعية" — منشورات هذه الجمعية فقط (وليس تبرعات الأفراد
// أو تبرعات موجَّهة إليها من مستخدمين آخرين أو منشورات جمعيات أخرى)، مُفلترة
// صراحةً بمعرّف الحساب ودوره معاً — لا بالاسم إطلاقاً.
// ─────────────────────────────────────────────
class _CharityPostsTab extends StatelessWidget {
  final String providerUserId;
  const _CharityPostsTab({required this.providerUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('providerUserId', isEqualTo: providerUserId)
          .where('providerRole', isEqualTo: 'charity')
          .where('status', isEqualTo: 'available')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs
            .where((d) => !isOfferExpired(d.data() as Map<String, dynamic>))
            .toList();
        if (docs.isEmpty) {
          return const Center(
            child: Text('لا توجد منشورات لهذه الجمعية حالياً',
                style: TextStyle(color: AppColors.textLight)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _CharityPostCard(docId: doc.id, data: data);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة منشور الجمعية — بنفس تصميم بطاقة شاشة التصفح (offers_tab.dart)
// كي يحصل المستخدم على تجربة متّسقة أينما شاهد المنشورات.
// ─────────────────────────────────────────────
class _CharityPostCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _CharityPostCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'منشور';
    final description = data['description'] ?? '';
    final pickupLocation = data['pickupLocation'] ?? 'غير محدد';
    final pickupTime = data['pickupTime'] ?? '';
    final remainingQuantity = data['remainingQuantity'] ?? 0;
    final currency = data['currency'] ?? 'ILS';
    final imageUrl = data['imageUrl'] ?? '';
    final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
    final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
    final isFree = data['isFree'] == true || discountPrice == 0;
    final discountPercent = calcDiscountPercent(originalPrice, discountPrice);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OfferDetailsScreen(docId: docId, data: data),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 170,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => buildImagePlaceholder(
                            icon: Icons.volunteer_activism_rounded),
                      )
                    : buildImagePlaceholder(
                        icon: Icons.volunteer_activism_rounded),
                Positioned(
                  top: 12,
                  right: 12,
                  child: buildPriceBadge(
                      isFree: isFree, discountPercent: discountPercent),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textLight,
                            height: 1.5,
                            fontSize: 13)),
                  ],
                  const SizedBox(height: 14),
                  OfferPriceRow(
                    isFree: isFree,
                    originalPrice: originalPrice,
                    discountPrice: discountPrice,
                    currency: currency,
                  ),
                  const SizedBox(height: 12),
                  OfferInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'مكان الاستلام',
                    value: pickupLocation,
                  ),
                  if (pickupTime.toString().isNotEmpty)
                    OfferInfoRow(
                      icon: Icons.access_time_outlined,
                      label: 'وقت الاستلام',
                      value: pickupTime.toString(),
                    ),
                  OfferInfoRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'الكمية المتاحة',
                    value: '$remainingQuantity',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// تبويب "التقييمات / الإبلاغ"
// ─────────────────────────────────────────────
class _ReviewsReportTab extends StatelessWidget {
  final String providerUserId;
  final String providerName;

  const _ReviewsReportTab({
    required this.providerUserId,
    required this.providerName,
  });

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        OutlinedButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => _ReportProviderDialog(
              providerUserId: providerUserId,
              providerName: providerName,
            ),
          ),
          icon: const Icon(Icons.flag_outlined, color: AppColors.danger),
          label: const Text('الإبلاغ عن المزوّد',
              style: TextStyle(color: AppColors.danger)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.danger),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),

        // ── يُسمح بالتقييم فقط بعد استلام طلب فعلي من هذا المزوّد ──
        if (_uid.isNotEmpty)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reservations')
                .where('userId', isEqualTo: _uid)
                .where('providerUserId', isEqualTo: providerUserId)
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              final pickedUp = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['status'] == 'picked_up';
              }).toList();
              final unrated = pickedUp.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['hasRated'] != true;
              }).toList();

              if (pickedUp.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'أكمل طلباً مع هذا المزوّد لتتمكن من تقييمه',
                    style: TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                );
              }

              if (unrated.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('⭐ لقد قيّمت هذا المزوّد بالفعل',
                      style:
                          TextStyle(color: AppColors.textLight, fontSize: 13)),
                );
              }

              final target = unrated.first;
              final targetData = target.data() as Map<String, dynamic>;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _RateProviderDialog(
                      reservationId: target.id,
                      offerId: (targetData['offerId'] as String?) ?? '',
                      offerTitle:
                          (targetData['offerTitle'] as String?) ?? '',
                      providerUserId: providerUserId,
                      providerName: providerName,
                    ),
                  ),
                  icon: const Icon(Icons.star_outline_rounded),
                  label: const Text('تقييم المزوّد'),
                ),
              );
            },
          ),

        const SizedBox(height: 20),
        const Text('آراء المستخدمين',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reviews')
              .where('providerUserId', isEqualTo: providerUserId)
              .limit(20)
              .snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Text('لا توجد تقييمات بعد',
                  style: TextStyle(color: AppColors.textLight, fontSize: 13));
            }
            return Column(
              children: docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                final rating = (data['rating'] as num?)?.toInt() ?? 0;
                final comment = (data['comment'] as String? ?? '').trim();
                final userName = (data['userName'] as String? ?? 'مستخدم');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'م',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(userName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const Spacer(),
                                Row(
                                  children: List.generate(
                                      5,
                                      (i) => Icon(
                                            i < rating
                                                ? Icons.star_rounded
                                                : Icons.star_outline_rounded,
                                            color: Colors.amber,
                                            size: 14,
                                          )),
                                ),
                              ],
                            ),
                            if (comment.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(comment,
                                  style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 12,
                                      height: 1.4)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// نافذة الإبلاغ عن المزوّد — نفس مجموعة complaints المستخدمة في باقي التطبيق
// ─────────────────────────────────────────────
class _ReportProviderDialog extends StatefulWidget {
  final String providerUserId;
  final String providerName;

  const _ReportProviderDialog({
    required this.providerUserId,
    required this.providerName,
  });

  @override
  State<_ReportProviderDialog> createState() => _ReportProviderDialogState();
}

class _ReportProviderDialogState extends State<_ReportProviderDialog> {
  final _descController = TextEditingController();
  String? _selectedType;
  bool _loading = false;

  final _types = [
    'طلب لم يُستلم',
    'معلومات خاطئة',
    'سلوك غير لائق',
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
      final complaintType = _selectedType ?? 'مشكلة أخرى';
      debugPrint('[ProviderReport] complainantUid=$reporterId');
      debugPrint('[ProviderReport] reportedUserId=${widget.providerUserId}');

      final docRef =
          await FirebaseFirestore.instance.collection('complaints').add({
        'userId': reporterId,
        'complainantId': reporterId,
        'reporterRole': 'user',
        'reportedUserId': widget.providerUserId,
        'reportedUserName': widget.providerName,
        'type': complaintType,
        'description': _descController.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[ProviderReport] complaintId=${docRef.id}');

      // Resolve reporter name for the notification (non-critical)
      String reporterName = 'مستخدم';
      String reporterEmail = '';
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(reporterId)
            .get();
        if (snap.exists) {
          final ud = snap.data()!;
          final n = ((ud['fullName'] as String? ?? '').trim().isNotEmpty
              ? ud['fullName'] as String
              : (ud['name'] as String? ?? '')).trim();
          if (n.isNotEmpty) reporterName = n;
          reporterEmail = (ud['email'] as String? ?? '').trim();
        }
      } catch (e) {
        debugPrint('[ProviderReport] nameResolution error=$e');
      }

      try {
        await NotificationService().notifyAdminsAboutComplaint(
          complaintId: docRef.id,
          complainantId: reporterId,
          complainantName: reporterName,
          complainantEmail: reporterEmail,
          complaintType: complaintType,
          reportedUserId: widget.providerUserId,
          reportedUserName: widget.providerName,
        );
      } catch (e, st) {
        debugPrint('[ProviderReport] notificationError=$e');
        debugPrintStack(stackTrace: st);
      }

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
      title: Text('الإبلاغ عن ${widget.providerName}',
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
// نافذة تقييم المزوّد — تكتب بنفس حقول تقييم المطعم/الجمعية الحالية
// (reservations.hasRated/rating/ratingComment + مجموعة reviews) دون أي تعديل
// على مخططها لتبقى متوافقة مع كل الشاشات التي تعتمد عليها.
// ─────────────────────────────────────────────
class _RateProviderDialog extends StatefulWidget {
  final String reservationId;
  final String offerId;
  final String offerTitle;
  final String providerUserId;
  final String providerName;

  const _RateProviderDialog({
    required this.reservationId,
    required this.offerId,
    required this.offerTitle,
    required this.providerUserId,
    required this.providerName,
  });

  @override
  State<_RateProviderDialog> createState() => _RateProviderDialogState();
}

class _RateProviderDialogState extends State<_RateProviderDialog> {
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
      final currentUser = FirebaseAuth.instance.currentUser!;
      final reservationRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId);
      final reservationDoc = await reservationRef.get();
      final reservationData = reservationDoc.data() ?? {};
      final reviewRef = FirebaseFirestore.instance.collection('reviews').doc();

      await reservationRef.update({
        'rating': _rating,
        'ratingComment': _commentController.text.trim(),
        'hasRated': true,
        'ratedAt': FieldValue.serverTimestamp(),
        'reviewId': reviewRef.id,
      });

      await reviewRef.set({
        'reviewId': reviewRef.id,
        'reservationId': widget.reservationId,
        'offerId': widget.offerId,
        'offerTitle': widget.offerTitle,
        'providerUserId': widget.providerUserId,
        'providerName': widget.providerName,
        'userId': currentUser.uid,
        'userName': reservationData['userName'] ?? '',
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شكراً على تقييمك! ⭐')),
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
      title: Text('تقييم ${widget.providerName}',
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
            'كيف كانت تجربتك مع هذا الطلب؟',
            style: TextStyle(color: AppColors.textLight, fontSize: 13),
          ),
          const SizedBox(height: 16),
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
                    size: 36,
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
