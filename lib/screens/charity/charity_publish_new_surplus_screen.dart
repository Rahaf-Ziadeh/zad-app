import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/charity_data_service.dart';
import '../../services/charity_location_service.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_colors.dart';
import '../common/location_picker_screen.dart';

// ─────────────────────────────────────────────
// شاشة نشر عرض جديد من الفائض
// ─────────────────────────────────────────────
class PublishNewSurplusScreen extends StatefulWidget {
  final String? prefillDonationId;
  final Map<String, dynamic>? prefillData;

  const PublishNewSurplusScreen({
    this.prefillDonationId,
    this.prefillData,
  });

  @override
  State<PublishNewSurplusScreen> createState() =>
      _PublishNewSurplusScreenState();
}

class _PublishNewSurplusScreenState extends State<PublishNewSurplusScreen> {
  final CharityDataService _dataService = CharityDataService();
  final CharityLocationService _locationService = CharityLocationService();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _quantityController;
  late final TextEditingController _locationController;

  bool _isLoading = false;
  DateTime? _expiryDate;
  double? _latitude;
  double? _longitude;
  String _locationSource = 'manual'; // 'gps' أو 'map' أو 'manual'

  // ── صورة التبرع ──
  // صورة التبرع الأصلية (من Firestore) — تُستخدم ما لم تختر الجمعية بديلاً
  String _existingImageUrl = '';
  XFile? _newImageFile;
  Uint8List? _newImageBytes;

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

    // تحميل صورة التبرع الأصلية بأولوية الحقول المتاحة
    if (d != null) {
      _existingImageUrl = (d['imageUrl'] as String? ??
              d['donationImageUrl'] as String? ??
              d['foodImageUrl'] as String? ??
              '')
          .trim();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _newImageFile = picked;
      _newImageBytes = bytes;
    });
  }

  void _removeNewImage() => setState(() {
        _newImageFile = null;
        _newImageBytes = null;
      });

  Widget _buildImageSection() {
    // إذا اختارت الجمعية صورة جديدة → عرضها مع زر إزالة
    if (_newImageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _newImageBytes!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: GestureDetector(
              onTap: _removeNewImage,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('صورة جديدة',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
        ],
      );
    }

    // إذا كان التبرع الأصلي يحتوي على صورة → عرضها مع زر الاستبدال
    if (_existingImageUrl.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  _existingImageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('صورة التبرع الأصلية',
                      style:
                          TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz_rounded,
                      size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('استبدال الصورة (اختياري)',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // لا توجد صورة أصلية → زر رفع صورة جديدة
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 32, color: AppColors.primary),
            SizedBox(height: 6),
            Text('إضافة صورة (اختياري)',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
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
          content: Text('يرجى إدخال اسم موقع الاستلام أو تحديد الموقع الحالي.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── حل موقع الاستلام إذا كان فارغاً مع وجود إحداثيات ──
      var resolvedLocation = locationText;
      if (resolvedLocation.isEmpty && _latitude != null) {
        final address = await _locationService.getAddressFromCoordinates(
          _latitude!,
          _longitude!,
        );
        if (!mounted) return;
        if (address.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('يرجى إدخال اسم موقع الاستلام أو تحديد الموقع الحالي.'),
            ),
          );
          return;
        }
        resolvedLocation = address;
        setState(() => _locationController.text = address);
      }

      // ── حل URL الصورة النهائي ──
      // إذا اختارت الجمعية صورة جديدة → رفعها إلى Cloudinary
      // وإلا → إعادة استخدام الصورة الأصلية من التبرع
      String finalImageUrl = _existingImageUrl;
      if (_newImageBytes != null && _newImageFile != null) {
        final uploaded = await CloudinaryService().uploadBytes(
          bytes: _newImageBytes!,
          filename: _newImageFile!.name,
        );
        if (uploaded != null) finalImageUrl = uploaded;
      }

      final qty = int.tryParse(_quantityController.text.trim()) ?? 1;

      await _dataService.publishSurplusOffer(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        quantity: qty,
        pickupLocation: resolvedLocation,
        latitude: _latitude,
        longitude: _longitude,
        locationSource: _latitude != null ? _locationSource : 'manual',
        expiryDate: _expiryDate!,
        prefillDonationId: widget.prefillDonationId,
        prefillData: widget.prefillData,
        imageUrl: finalImageUrl,
      );

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
                  color: AppColors.success.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
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

            // ── قسم الصورة ──
            _buildImageSection(),
            const SizedBox(height: 16),

            // ── نوع التوزيع (ثابت للجمعيات) ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التوزيع مجاني',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.success,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'يتم توزيع هذا الطعام مجانًا على المستفيدين.',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                              ? AppColors.success.withValues(alpha: 0.08)
                              : AppColors.primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _latitude != null
                                ? AppColors.success.withValues(alpha: 0.4)
                                : AppColors.primary.withValues(alpha: 0.3),
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
