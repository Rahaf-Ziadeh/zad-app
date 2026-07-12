import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cloudinary_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../common/location_picker_screen.dart';
import '../user/donate_tab.dart' show CharityPickerSheet;
import 'restaurant_widgets.dart';

// ─────────────────────────────────────────────
// شاشة تبرّع المطعم لجمعية خيرية بفائض طعام — واضح المحتوى دائماً (لا يوجد
// خيار باقة غامضة هنا إطلاقاً). تكتب في نفس مجموعة donations وبنفس عقد
// الحقول المستخدم في تبرع المستخدم العادي (CharityDonationScreen في
// donate_tab.dart) حتى تبقى متوافقة مع كل شاشات الجمعية التي تعرض التبرعات
// (مراجعة التبرعات، إعادة توزيع الفائض)، مع إضافة donorRole/restaurantId
// لتمييز مصدر التبرع دون كسر أي قارئ قديم لا يعرف هذين الحقلين ──
// ─────────────────────────────────────────────
class RestaurantDonateToCharityScreen extends StatefulWidget {
  const RestaurantDonateToCharityScreen({super.key});

  @override
  State<RestaurantDonateToCharityScreen> createState() =>
      _RestaurantDonateToCharityScreenState();
}

class _RestaurantDonateToCharityScreenState
    extends State<RestaurantDonateToCharityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _quantityController = TextEditingController();
  final _pickupController = TextEditingController();

  String _selectedCategory = 'وجبات';
  final _categories = const ['وجبات', 'مخبوزات', 'خضار وفواكه', 'معلبات', 'حلويات'];

  String? _selectedCharityId;
  String? _selectedCharityName;

  XFile? _selectedImage;
  bool _uploadingImage = false;
  bool _isLoading = false;

  double? _latitude;
  double? _longitude;
  String _locationSource = 'manual';

  TimeOfDay? _pickupStartTime;
  TimeOfDay? _pickupEndTime;
  DateTime? _expiryDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _quantityController.dispose();
    _pickupController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (pickedFile == null) return;
    setState(() => _selectedImage = pickedFile);
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;
    setState(() => _uploadingImage = true);
    try {
      final bytes = await _selectedImage!.readAsBytes();
      return await CloudinaryService()
          .uploadBytes(bytes: bytes, filename: _selectedImage!.name);
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _pickCharity() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CharityPickerSheet(
        selectedId: _selectedCharityId,
        onSelected: (id, name) {
          setState(() {
            _selectedCharityId = id;
            _selectedCharityName = name;
          });
          Navigator.pop(context);
        },
        onClear: () {
          setState(() {
            _selectedCharityId = null;
            _selectedCharityName = null;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _pickupStartTime : _pickupEndTime) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _pickupStartTime = picked;
      } else {
        _pickupEndTime = picked;
      }
    });
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialAddress: _pickupController.text.trim().isNotEmpty
              ? _pickupController.text.trim()
              : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      _pickupController.text = result.address;
      _locationSource = result.locationSource;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedCharityId == null || _selectedCharityId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الجمعية المستفيدة')),
      );
      return;
    }
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة صورة للطعام المتبرَّع به')),
      );
      return;
    }
    if (_pickupController.text.trim().isEmpty && _latitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد مكان الاستلام')),
      );
      return;
    }
    if (_pickupStartTime == null || _pickupEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد وقت بداية ونهاية الاستلام')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
      );
      return;
    }
    final uid = user.uid;

    setState(() => _isLoading = true);
    try {
      final restaurantDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(uid)
          .get();
      final donorName = (restaurantDoc.data()?['name'] as String?) ??
          (restaurantDoc.data()?['restaurantName'] as String?) ??
          'مطعم';

      final uploadedUrl = await _uploadImage();
      if (!mounted) return;
      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم رفع الصورة، جرب مرة ثانية')),
        );
        return;
      }

      final title = _titleController.text.trim();
      final description = _descController.text.trim();
      final quantity = _quantityController.text.trim().isEmpty
          ? '1'
          : _quantityController.text.trim();
      final pickupLocation = _pickupController.text.trim();
      final startStr = _formatTime(_pickupStartTime!);
      final endStr = _formatTime(_pickupEndTime!);
      final expiresAt =
          _expiryDate ?? DateTime.now().add(const Duration(hours: 24));

      final docRef =
          await FirebaseFirestore.instance.collection('donations').add({
        // ── حقول العقد الحالي لمجموعة donations (نفس تبرع المستخدم العادي) ──
        'donorUserId': uid,
        'donorName': donorName,
        'donorRole': 'restaurant',
        'restaurantId': uid,
        'charityId': _selectedCharityId,
        'charityName': _selectedCharityName ?? '',
        'title': title,
        'description': description,
        'category': _selectedCategory,
        'quantity': quantity,
        'imageUrl': uploadedUrl,
        'pickupLocation': pickupLocation,
        'latitude': _latitude,
        'longitude': _longitude,
        'hasLocation': _latitude != null,
        'locationSource': _latitude != null ? _locationSource : 'manual',
        'pickupStartTime': startStr,
        'pickupEndTime': endStr,
        'pickupTime': '$startStr - $endStr',
        'expiryDate': _expiryDate,
        'expiresAt': expiresAt,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // ── حقول قديمة للتوافق مع الشاشات التي لا تزال تقرأها مباشرة
        // (مثل بطاقة الفائض الجاهز للنشر لدى الجمعية) ──
        'userId': uid,
        'userName': donorName,
        'foodName': title,
        'location': pickupLocation,
        'notes': description,
        'targetCharityId': _selectedCharityId,
        'targetCharityName': _selectedCharityName ?? '',
        'isDirectedToCharity': true,
      });

      await docRef.update({'donationId': docRef.id});
      if (!mounted) return;

      // ── إشعار الجمعية المختارة — غير حرج، لا يوقف تدفق التبرع ──
      try {
        await NotificationService().sendNotification(
          userId: _selectedCharityId!,
          title: 'تبرع طعام جديد من مطعم',
          message: 'تبرع جديد من "$donorName" بانتظار مراجعتك: "$title"',
          type: 'donation',
          relatedId: docRef.id,
        );
      } catch (e) {
        debugPrint('[RestaurantDonation] notify charity error: $e');
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            (_selectedCharityName ?? '').isNotEmpty
                ? 'تم إرسال تبرعك إلى ${_selectedCharityName!} ❤️'
                : 'تم إرسال التبرع بنجاح',
          ),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تبرع لجمعية'),
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
                  colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.volunteer_activism_rounded,
                      color: Colors.white, size: 32),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تبرّع بفائض الطعام لجمعية',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        SizedBox(height: 4),
                        Text('طعام واضح المحتوى دائماً — بلا باقات غامضة',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                    // ── اختيار الجمعية ──
                    const Text('الجمعية المستفيدة *',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickCharity,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedCharityId != null
                              ? AppColors.success.withValues(alpha: 0.08)
                              : AppColors.primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedCharityId != null
                                ? AppColors.success.withValues(alpha: 0.4)
                                : AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.volunteer_activism_rounded,
                              color: _selectedCharityId != null
                                  ? AppColors.success
                                  : AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedCharityName ?? 'اختيار جمعية خيرية',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedCharityId != null
                                      ? AppColors.success
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_left_rounded,
                                size: 18, color: AppColors.textLight),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── صورة الطعام ──
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: kIsWeb
                                      ? NetworkImage(_selectedImage!.path)
                                      : FileImage(File(_selectedImage!.path))
                                          as ImageProvider,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      size: 34, color: AppColors.primary),
                                  SizedBox(height: 10),
                                  Text('إضافة صورة للطعام',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold)),
                                ],
                              )
                            : Align(
                                alignment: Alignment.topLeft,
                                child: IconButton(
                                  onPressed: () =>
                                      setState(() => _selectedImage = null),
                                  icon: const Icon(Icons.close,
                                      color: Colors.white),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── عنوان الطعام ──
                    TextFormField(
                      controller: _titleController,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'يرجى إدخال اسم الطعام'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطعام *',
                        prefixIcon: Icon(Icons.fastfood_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── الفئة ──
                    const Text('الفئة',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final selected = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.10)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(cat,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.textLight)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // ── الكمية ──
                    FormFieldWidget(
                      controller: _quantityController,
                      label: 'الكمية',
                      hint: 'مثال: 10 وجبات',
                      icon: Icons.numbers_rounded,
                    ),
                    const SizedBox(height: 14),

                    // ── مكان الاستلام ──
                    FormFieldWidget(
                      controller: _pickupController,
                      label: 'مكان الاستلام',
                      hint: 'العنوان أو المنطقة',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 10),
                    LocationPickerRow(
                      hasLocation: _latitude != null,
                      latitude: _latitude,
                      longitude: _longitude,
                      onTap: _openLocationPicker,
                      onClear: () => setState(() {
                        _latitude = null;
                        _longitude = null;
                        _locationSource = 'manual';
                      }),
                    ),
                    const SizedBox(height: 14),

                    // ── وقت الاستلام ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(isStart: true),
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(_pickupStartTime == null
                                ? 'بداية الاستلام'
                                : _formatTime(_pickupStartTime!)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(isStart: false),
                            icon:
                                const Icon(Icons.access_time_filled, size: 18),
                            label: Text(_pickupEndTime == null
                                ? 'نهاية الاستلام'
                                : _formatTime(_pickupEndTime!)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── تاريخ الانتهاء (اختياري) ──
                    ExpiryDateTimeField(
                      value: _expiryDate,
                      onChanged: (v) => setState(() => _expiryDate = v),
                    ),
                    const SizedBox(height: 14),

                    // ── الوصف ──
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'وصف الطعام (اختياري)',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 48),
                          child: Icon(Icons.description_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isLoading || _uploadingImage) ? null : _submit,
                        icon: (_isLoading || _uploadingImage)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.volunteer_activism_rounded),
                        label: Text((_isLoading || _uploadingImage)
                            ? 'جاري الإرسال...'
                            : 'إرسال التبرع'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
