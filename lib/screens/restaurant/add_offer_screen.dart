import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zad_app/screens/restaurant/restaurant_widgets.dart';
import 'package:zad_app/services/location_service.dart';
import 'package:zad_app/services/notification_service.dart';
import 'package:zad_app/theme/app_colors.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AddOfferScreen extends StatefulWidget {
  const AddOfferScreen({super.key});

  @override
  State<AddOfferScreen> createState() => _AddOfferScreenState();
}

class _AddOfferScreenState extends State<AddOfferScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _quantityController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountPriceController = TextEditingController();
  final _pickupController = TextEditingController();
  final _allergyController = TextEditingController();
  final _pickupStartTimeController = TextEditingController();
  final _pickupEndTimeController = TextEditingController();

  XFile? _selectedImage;
  bool _uploadingImage = false;
  bool _isLoading = false;
  bool _isMysteryPackage = false;

  // ── إحداثيات مكان الاستلام ──
  double? _latitude;
  double? _longitude;
  bool _fetchingLocation = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (pickedFile == null) return;
    setState(() => _selectedImage = pickedFile);
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;
    setState(() => _uploadingImage = true);
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/dsu1bewrx/image/upload',
      );
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = 'zad_upload';
      final bytes = await _selectedImage!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: _selectedImage!.name,
        ),
      );
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = jsonDecode(responseData);
        return data['secure_url'];
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل رفع الصورة: ${response.statusCode}')),
          );
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
      return null;
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  // ── جلب الموقع الحالي ──
  Future<void> _fetchLocation() async {
    setState(() => _fetchingLocation = true);
    final position = await LocationService().getCurrentLocation();
    if (position != null) {
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديد الموقع بنجاح ✅'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر الحصول على الموقع — تحقق من صلاحيات GPS'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
    setState(() => _fetchingLocation = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _quantityController.dispose();
    _originalPriceController.dispose();
    _discountPriceController.dispose();
    _pickupController.dispose();
    _allergyController.dispose();
    _pickupStartTimeController.dispose();
    _pickupEndTimeController.dispose();
    super.dispose();
  }

  Future<void> _addOffer() async {
    // ── جمع قيم الحقول وتحقق منها قبل أي await ──
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final quantityStr = _quantityController.text.trim();
    final originalStr = _originalPriceController.text.trim();
    final discountStr = _discountPriceController.text.trim();
    final pickup = _pickupController.text.trim();
    final pickupStartTime = _pickupStartTimeController.text.trim();
    final pickupEndTime = _pickupEndTimeController.text.trim();
    final allergyInfo = _allergyController.text.trim();

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة صورة للعرض')),
      );
      return;
    }

    if ([
          title,
          quantityStr,
          originalStr,
          discountStr,
          pickup,
          pickupStartTime,
          pickupEndTime,
        ].any((s) => s.isEmpty) ||
        (!_isMysteryPackage && desc.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تعبئة جميع الحقول المطلوبة')),
      );
      return;
    }

    final quantity = int.tryParse(quantityStr);
    final originalPrice = double.tryParse(originalStr);
    final discountPrice = double.tryParse(discountStr);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الكمية يجب أن تكون رقماً صحيحاً أكبر من صفر')),
      );
      return;
    }
    if (originalPrice == null || originalPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السعر الأصلي غير صحيح')),
      );
      return;
    }
    if (discountPrice == null || discountPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السعر بعد الخصم غير صحيح')),
      );
      return;
    }
    if (discountPrice > originalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('السعر بعد الخصم لا يجب أن يتجاوز السعر الأصلي')),
      );
      return;
    }

    // التحقق من تسجيل الدخول — قبل أي await
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
      // ── رفع الصورة — أول await في الدالة ──
      final imageUrl = await _uploadImage() ?? '';
      if (!mounted) return;
      if (imageUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم رفع الصورة، جرب مرة ثانية')),
        );
        return;
      }

      final docRef = FirebaseFirestore.instance.collection('offers').doc();
      await docRef.set({
        'offerId': docRef.id,
        'providerUserId': uid,
        'providerRole': 'restaurant',
        'offerType': _isMysteryPackage ? 'mystery_package' : 'clear_offer',
        'title': title,
        'description': _isMysteryPackage ? 'محتوى الباقة غير معلن' : desc,
        'isMysteryPackage': _isMysteryPackage,
        'packageType': _isMysteryPackage ? 'mystery' : 'clear',
        'imageUrl': imageUrl,
        'quantity': quantity,
        'remainingQuantity': quantity,
        'originalPrice': originalPrice,
        'discountPrice': discountPrice,
        'price': discountPrice,
        'currency': 'ILS',
        'isFree': discountPrice == 0,
        'status': 'available',
        'pickupLocation': pickup,
        'pickupStartTime': pickupStartTime,
        'pickupEndTime': pickupEndTime,
        'pickupTime': '$pickupStartTime - $pickupEndTime',
        'latitude': _latitude,
        'longitude': _longitude,
        'hasLocation': _latitude != null && _longitude != null,
        'allergyInfo': allergyInfo,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // الإشعار غير حرج — لا يوقف تدفق النشر عند الفشل
      try {
        await NotificationService().sendNotification(
          userId: uid,
          title: 'تم نشر العرض',
          message: 'تم نشر الباقة "$title" بنجاح',
          type: 'offer',
        );
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _titleController.clear();
        _descController.clear();
        _selectedImage = null;
        _quantityController.clear();
        _originalPriceController.clear();
        _discountPriceController.clear();
        _pickupController.clear();
        _allergyController.clear();
        _pickupStartTimeController.clear();
        _pickupEndTimeController.clear();
        _isMysteryPackage = false;
        _latitude = null;
        _longitude = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر الباقة بنجاح ✅'),
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
        title: const Text('إضافة باقة جديدة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.add_box_rounded, color: Colors.white, size: 32),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('باقة طعام فائض',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      SizedBox(height: 4),
                      Text('أضف تفاصيل الباقة والسعر ومكان الاستلام',
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
                  // 1 ── اسم الباقة ──
                  FormFieldWidget(
                    controller: _titleController,
                    label: 'اسم الباقة',
                    hint: 'مثال: باقة وجبات مشكّلة',
                    icon: Icons.fastfood_rounded,
                  ),
                  const SizedBox(height: 14),

                  // 2 ── صورة العرض ──
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
                                Text(
                                  'إضافة صورة للعرض',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold),
                                ),
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

                  // 3 ── السعر الأصلي / بعد الخصم ──
                  Row(
                    children: [
                      Expanded(
                        child: FormFieldWidget(
                          controller: _originalPriceController,
                          label: 'السعر الأصلي',
                          hint: '0.00',
                          icon: Icons.price_change_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FormFieldWidget(
                          controller: _discountPriceController,
                          label: 'بعد الخصم',
                          hint: '0.00',
                          icon: Icons.local_offer_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4 ── عدد الباقات ──
                  FormFieldWidget(
                    controller: _quantityController,
                    label: 'عدد الباقات',
                    hint: 'مثال: 10',
                    icon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),

                  // 5 ── مكان الاستلام (نص) ──
                  FormFieldWidget(
                    controller: _pickupController,
                    label: 'مكان الاستلام',
                    hint: 'العنوان أو المنطقة',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 10),

                  // 6 ── تحديد موقع الاستلام (GPS) ──
                  GestureDetector(
                    onTap: _fetchingLocation ? null : _fetchLocation,
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
                          _fetchingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary),
                                )
                              : Icon(
                                  _latitude != null
                                      ? Icons.my_location_rounded
                                      : Icons.location_searching_rounded,
                                  color: _latitude != null
                                      ? AppColors.success
                                      : AppColors.primary,
                                  size: 20,
                                ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _latitude != null
                                  ? 'تم تحديد الموقع ✓ (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})'
                                  : 'تحديد موقع الاستلام ',
                              style: TextStyle(
                                fontSize: 13,
                                color: _latitude != null
                                    ? AppColors.success
                                    : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_latitude != null)
                            GestureDetector(
                              onTap: () => setState(() {
                                _latitude = null;
                                _longitude = null;
                              }),
                              child: const Icon(Icons.close_rounded,
                                  size: 16, color: AppColors.textLight),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 7 ── بداية وقت الاستلام ──
                  TextField(
                    controller: _pickupStartTimeController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'بداية وقت الاستلام',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        _pickupStartTimeController.text =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // 8 ── نهاية وقت الاستلام ──
                  TextField(
                    controller: _pickupEndTimeController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'نهاية وقت الاستلام',
                      prefixIcon: Icon(Icons.access_time_filled),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        _pickupEndTimeController.text =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 9 ── نوع الباقة ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'نوع الباقة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        RadioGroup<bool>(
                          groupValue: _isMysteryPackage,
                          onChanged: (v) =>
                              setState(() => _isMysteryPackage = v ?? false),
                          child: Column(
                            children: [
                              RadioListTile<bool>(
                                value: false,
                                activeColor: AppColors.primary,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('عرض واضح المحتوى'),
                                subtitle: const Text(
                                    'سيظهر للمستخدم وصف محتوى الباقة'),
                              ),
                              RadioListTile<bool>(
                                value: true,
                                activeColor: AppColors.primary,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('باقة غامضة المحتوى 🎁'),
                                subtitle: const Text(
                                    'لن يظهر للمستخدم محتوى الباقة قبل الاستلام'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 10 ── محتوى العرض ──
                  if (!_isMysteryPackage)
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'محتوى العرض',
                        hintText: 'مثال: رز، دجاج، سلطة...',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 48),
                          child: Icon(Icons.description_outlined),
                        ),
                        alignLabelWithHint: true,
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              const Color(0xFF7C3AED).withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Text(
                        'سيتم نشرها كباقة غامضة، ولن يظهر محتواها للمستخدم قبل الاستلام.',
                        style: TextStyle(
                          color: Color(0xFF7C3AED),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),

                  // 11 ── معلومات الحساسية الغذائية ──
                  TextField(
                    controller: _allergyController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'معلومات الحساسية الغذائية',
                      hintText:
                          'مثال: يحتوي على مكسرات، لا يحتوي على جلوتين...',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 32),
                        child: Icon(Icons.warning_amber_outlined),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 12 ── نشر الباقة ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_isLoading || _uploadingImage) ? null : _addOffer,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.publish_rounded),
                      label: Text(
                        (_isLoading || _uploadingImage)
                            ? 'جاري النشر...'
                            : 'نشر الباقة',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
