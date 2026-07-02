import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/offer_widgets.dart';
import '../common/location_picker_screen.dart';

// ─────────────────────────────────────────────
// شاشة إعادة نشر الفائض — FR-36
// ─────────────────────────────────────────────
class CharityPublishSurplusScreen extends StatelessWidget {
  const CharityPublishSurplusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('إعادة توزيع الفائض'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'فائض متاح للنشر'),
              Tab(text: 'تم نشره'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AvailableSurplusTab(),
            _PublishedSurplusTab(),
          ],
        ),
        // زر نشر عرض جديد من الفائض
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const _PublishNewSurplusScreen()),
          ),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('نشر عرض جديد',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 1 — التبرعات المقبولة الجاهزة للنشر
// ─────────────────────────────────────────────
class _AvailableSurplusTab extends StatelessWidget {
  const _AvailableSurplusTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('status', isEqualTo: 'approved')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 64, color: AppColors.primary.withValues(alpha:0.3)),
                const SizedBox(height: 14),
                const Text('لا يوجد فائض جاهز للنشر',
                    style: TextStyle(color: AppColors.textLight, fontSize: 14)),
                const SizedBox(height: 8),
                const Text(
                  'اقبلي التبرعات أولاً لتظهر هنا',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _SurplusCard(
              donationId: doc.id,
              data: data,
              isPublished: false,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Tab 2 — العروض التي تم نشرها
// ─────────────────────────────────────────────
class _PublishedSurplusTab extends StatelessWidget {
  const _PublishedSurplusTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('providerUserId', isEqualTo: uid)
          .where('providerRole', isEqualTo: 'charity')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_outlined,
                    size: 64, color: AppColors.primary.withValues(alpha:0.3)),
                const SizedBox(height: 14),
                const Text('لم تنشري أي عرض بعد',
                    style: TextStyle(color: AppColors.textLight, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _PublishedOfferCard(offerId: doc.id, data: data);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة التبرع الجاهز للنشر
// ─────────────────────────────────────────────
class _SurplusCard extends StatelessWidget {
  final String donationId;
  final Map<String, dynamic> data;
  final bool isPublished;

  const _SurplusCard({
    required this.donationId,
    required this.data,
    required this.isPublished,
  });

  @override
  Widget build(BuildContext context) {
    final foodName = data['foodName'] ?? 'طعام';
    final quantity = data['quantity'] ?? '—';
    final category = data['category'] ?? '—';
    final location = data['location'] ?? 'غير محدد';
    final notes = data['notes'] ?? '';
    final donorName = data['userName'] ?? 'متبرع';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.success.withValues(alpha:0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.volunteer_activism_rounded,
                      color: AppColors.success, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(foodName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textDark)),
                      Text('من: $donorName',
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('جاهز للنشر',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── تفاصيل ──
            OfferInfoRow(
                icon: Icons.category_outlined, label: 'الفئة', value: category),
            OfferInfoRow(
                icon: Icons.inventory_2_outlined,
                label: 'الكمية',
                value: '$quantity'),
            OfferInfoRow(
                icon: Icons.location_on_outlined,
                label: 'الموقع',
                value: location),
            if (notes.toString().isNotEmpty)
              OfferInfoRow(
                  icon: Icons.notes_outlined, label: 'ملاحظات', value: notes),

            const SizedBox(height: 14),

            // ── زرّ النشر ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PublishNewSurplusScreen(
                      prefillDonationId: donationId,
                      prefillData: data,
                    ),
                  ),
                ),
                icon: const Icon(Icons.publish_rounded),
                label: const Text('نشر كعرض للمستفيدين'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة العرض المنشور
// ─────────────────────────────────────────────
class _PublishedOfferCard extends StatelessWidget {
  final String offerId;
  final Map<String, dynamic> data;

  const _PublishedOfferCard({
    required this.offerId,
    required this.data,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'available':
        return AppColors.success;
      case 'closed':
        return AppColors.textLight;
      case 'reserved':
        return Colors.orange;
      default:
        return AppColors.textLight;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'available':
        return 'متاح';
      case 'closed':
        return 'مغلق';
      case 'reserved':
        return 'محجوز';
      default:
        return s;
    }
  }

  Future<void> _closeOffer(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .update({
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إغلاق العرض')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'عرض طعام';
    final status = data['status'] ?? 'available';
    final remaining = data['remainingQuantity'] ?? 0;
    final total = data['quantity'] ?? 0;
    final location = data['pickupLocation'] ?? 'غير محدد';
    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color.withValues(alpha:0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha:0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fastfood_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(location,
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel(status),
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // شريط تقدم الكمية
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الكمية المتبقية',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                    Text('$remaining / $total',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? remaining / total : 0,
                    minHeight: 7,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),

            if (status == 'available') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _closeOffer(context),
                  icon: const Icon(Icons.close_rounded,
                      size: 16, color: AppColors.danger),
                  label: const Text('إغلاق العرض',
                      style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// شاشة نشر عرض جديد من الفائض
// ─────────────────────────────────────────────
class _PublishNewSurplusScreen extends StatefulWidget {
  final String? prefillDonationId;
  final Map<String, dynamic>? prefillData;

  const _PublishNewSurplusScreen({
    this.prefillDonationId,
    this.prefillData,
  });

  @override
  State<_PublishNewSurplusScreen> createState() =>
      _PublishNewSurplusScreenState();
}

class _PublishNewSurplusScreenState extends State<_PublishNewSurplusScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _quantityController;
  late final TextEditingController _locationController;

  bool _isFree = true;
  bool _isLoading = false;
  DateTime? _expiryDate;
  double? _latitude;
  double? _longitude;
  String _locationSource = 'manual'; // 'gps' أو 'map' أو 'manual'

  @override
  void initState() {
    super.initState();
    final d = widget.prefillData;
    // ملء البيانات تلقائياً من التبرع لو موجود
    _titleController = TextEditingController(
        text: d != null ? 'فائض: ${d['foodName'] ?? ''}' : '');
    _descController = TextEditingController(
        text: d != null
            ? 'طعام متبرع به من ${d['userName'] ?? 'متبرع'}. الفئة: ${d['category'] ?? ''}'
            : '');
    _quantityController =
        TextEditingController(text: d != null ? '${d['quantity'] ?? ''}' : '');
    _locationController =
        TextEditingController(text: d != null ? '${d['location'] ?? ''}' : '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  // ── فتح شاشة اختيار الموقع على خريطة OpenStreetMap ──
  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialAddress: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      _locationController.text = result.address;
      _locationSource = result.locationSource;
    });
  }

  Future<void> _publish() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد تاريخ الانتهاء')),
      );
      return;
    }

    // ── تحقق من موقع الاستلام ──
    final locationText = _locationController.text.trim();
    if (locationText.isEmpty && _latitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'يرجى إدخال اسم موقع الاستلام أو تحديد الموقع الحالي.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── حل موقع الاستلام إذا كان فارغاً مع وجود إحداثيات ──
      var resolvedLocation = locationText;
      if (resolvedLocation.isEmpty && _latitude != null) {
        final address = await LocationService().getAddressFromCoordinates(
          _latitude!, _longitude!,
        );
        if (!mounted) return;
        if (address.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'يرجى إدخال اسم موقع الاستلام أو تحديد الموقع الحالي.'),
            ),
          );
          return;
        }
        resolvedLocation = address;
        setState(() => _locationController.text = address);
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final charityName = userDoc.data()?['name'] ?? 'جمعية خيرية';

      final qty = int.tryParse(_quantityController.text.trim()) ?? 1;

      // ── 1. نشر العرض ──
      final docRef = FirebaseFirestore.instance.collection('offers').doc();
      await docRef.set({
        'offerId': docRef.id,
        'providerUserId': uid,
        'providerRole': 'charity',
        'providerName': charityName,
        'offerType': 'charity_surplus',
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'imageUrl': '',
        'quantity': qty,
        'remainingQuantity': qty,
        'originalPrice': 0,
        'discountPrice': 0,
        'price': 0,
        'currency': 'ILS',
        'isFree': _isFree,
        'status': 'available',
        'pickupLocation': resolvedLocation,
        'latitude': _latitude,
        'longitude': _longitude,
        'hasLocation': _latitude != null,
        'locationSource': _latitude != null ? _locationSource : 'manual',
        'expiryDate': _expiryDate,
        'sourceDonationId': widget.prefillDonationId ?? '',
        'isCash': false,
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── 2. تحديث حالة التبرع إلى redistributed ──
      if (widget.prefillDonationId != null) {
        await FirebaseFirestore.instance
            .collection('donations')
            .doc(widget.prefillDonationId)
            .update({
          'status': 'redistributed',
          'publishedOfferId': docRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // ── 3. إشعار المتبرع الأصلي ──
        final donationData = widget.prefillData;
        if (donationData != null) {
          final donorId = donationData['userId'] ?? '';
          final foodName = donationData['foodName'] ?? 'تبرعك';
          if (donorId.isNotEmpty) {
            await NotificationService().sendNotification(
              userId: donorId,
              title: 'تم نشر تبرعك للمستفيدين ❤️',
              message:
                  'قامت الجمعية بنشر "$foodName" وإتاحته للمستفيدين. جزاك الله خيراً!',
              type: 'donation',
            );
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر العرض بنجاح ✅'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFromDonation = widget.prefillDonationId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isFromDonation ? 'نشر فائض التبرع' : 'نشر عرض جديد'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.share_rounded,
                      color: Colors.white, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFromDonation
                              ? 'نشر الطعام المتبرع به'
                              : 'نشر عرض من الفائض',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFromDonation
                              ? 'سيُحوَّل التبرع لعرض متاح للمستفيدين'
                              : 'نشر طعام فائض لمن يحتاجه',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // لو من تبرع — عرض معلومات التبرع الأصلي
            if (isFromDonation && widget.prefillData != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha:0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.success.withValues(alpha:0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'البيانات مملوءة تلقائياً من التبرع. يمكنك تعديلها قبل النشر.',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── مجاني أو رمزي ──
            Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'مجاني',
                    subtitle: 'للمستفيدين مجاناً',
                    selected: _isFree,
                    color: AppColors.success,
                    onTap: () => setState(() => _isFree = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeButton(
                    icon: Icons.local_offer_rounded,
                    label: 'بسعر رمزي',
                    subtitle: 'بأقل من التكلفة',
                    selected: !_isFree,
                    color: AppColors.primary,
                    onTap: () => setState(() => _isFree = false),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // عنوان العرض
                    TextFormField(
                      controller: _titleController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'يرجى إدخال عنوان العرض'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'عنوان العرض *',
                        prefixIcon: Icon(Icons.fastfood_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // الكمية
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'يرجى إدخال الكمية';
                        }
                        if (int.tryParse(v.trim()) == null ||
                            int.parse(v.trim()) <= 0) {
                          return 'الكمية يجب أن تكون أكبر من صفر';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'الكمية المتاحة *',
                        prefixIcon:
                            Icon(Icons.production_quantity_limits_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // تاريخ الانتهاء
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 20, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Text(
                              _expiryDate == null
                                  ? 'تاريخ انتهاء الصلاحية *'
                                  : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                              style: TextStyle(
                                color: _expiryDate == null
                                    ? AppColors.textLight
                                    : AppColors.textDark,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // مكان الاستلام
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'مكان الاستلام *',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // زر تحديد الموقع على الخريطة
                    GestureDetector(
                      onTap: _openLocationPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _latitude != null
                              ? AppColors.success.withValues(alpha:0.08)
                              : AppColors.primary.withValues(alpha:0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _latitude != null
                                ? AppColors.success.withValues(alpha:0.4)
                                : AppColors.primary.withValues(alpha:0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _latitude != null
                                  ? Icons.my_location_rounded
                                  : Icons.map_outlined,
                              color: _latitude != null
                                  ? AppColors.success
                                  : AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _latitude != null
                                  ? 'تم تحديد الموقع ✓'
                                  : 'تحديد الموقع على الخريطة',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _latitude != null
                                      ? AppColors.success
                                      : AppColors.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // الوصف
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'وصف العرض (اختياري)',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 48),
                          child: Icon(Icons.description_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _publish,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.publish_rounded),
                label: Text(
                  _isLoading
                      ? 'جاري النشر...'
                      : isFromDonation
                          ? 'نشر الفائض للمستفيدين'
                          : 'نشر العرض',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// زر اختيار النوع
// ─────────────────────────────────────────────
class _TypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha:0.10) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : AppColors.textLight, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: selected ? color : AppColors.textDark)),
            const SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}
