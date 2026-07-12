import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:zad_app/screens/restaurant/restaurant_widgets.dart';
import 'package:zad_app/services/notification_service.dart';

import '../../constants/app_constants.dart';
import '../../theme/app_colors.dart';
import '../../utils/offer_utils.dart';
import '../../utils/verification_utils.dart';
import '../../widgets/allergy_checkbox_panel.dart';

class EditOfferScreen extends StatefulWidget {
  final String offerId;
  final Map<String, dynamic> offerData;

  const EditOfferScreen({
    super.key,
    required this.offerId,
    required this.offerData,
  });

  @override
  State<EditOfferScreen> createState() => _EditOfferScreenState();
}

class _EditOfferScreenState extends State<EditOfferScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _quantityController;
  late final TextEditingController _originalPriceController;
  late final TextEditingController _discountPriceController;
  late final TextEditingController _pickupController;
  Set<String> _selectedAllergens = {};

  XFile? _selectedImage;
  String _currentImageUrl = '';
  bool _uploadingImage = false;
  bool _isLoading = false;

  // ── تاريخ ووقت انتهاء العرض — يُحمَّل من القيمة الحالية (expiresAt، مع
  // الرجوع إلى الحقل القديم expiryDate للعروض السابقة) ويبقى كما هو إن لم
  // يُغيَّر ──
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    final d = widget.offerData;
    _titleController = TextEditingController(text: d['title'] ?? '');
    _descController = TextEditingController(text: d['description'] ?? '');
    _currentImageUrl = (d['imageUrl'] as String?) ?? '';
    _quantityController = TextEditingController(
        text: '${d['remainingQuantity'] ?? d['quantity'] ?? ''}');
    _originalPriceController =
        TextEditingController(text: '${d['originalPrice'] ?? ''}');
    _discountPriceController =
        TextEditingController(text: '${d['discountPrice'] ?? ''}');
    _pickupController = TextEditingController(text: d['pickupLocation'] ?? '');
    _selectedAllergens = AppConstants.parseAllergyCheckboxes(d['allergyInfo']);
    final rawExpiry = d['expiresAt'] ?? d['expiryDate'];
    if (rawExpiry is Timestamp) _expiresAt = rawExpiry.toDate();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _quantityController.dispose();
    _originalPriceController.dispose();
    _discountPriceController.dispose();
    _pickupController.dispose();
    super.dispose();
  }

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
        return data['secure_url'] as String?;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('فشل رفع الصورة: ${response.statusCode}')),
          );
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ في رفع الصورة: $e')));
      }
      return null;
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _saveChanges() async {
    // ── جمع قيم الحقول والتحقق منها قبل أي await ──
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final quantityStr = _quantityController.text.trim();
    final originalStr = _originalPriceController.text.trim();
    final discountStr = _discountPriceController.text.trim();
    final pickup = _pickupController.text.trim();
    final allergyInfo = _selectedAllergens.toList();

    if ([title, desc, quantityStr, originalStr, discountStr, pickup]
        .any((s) => s.isEmpty)) {
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

    if (_expiresAt != null && !_expiresAt!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('يجب أن يكون تاريخ ووقت انتهاء العرض في المستقبل.'),
        ),
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

    // ── يُحتفَظ بالقيمة الحالية إن لم تُغيَّر؛ إن حُذفت (null) يُطبَّق
    // الانتهاء التلقائي بعد 24 ساعة من هذا التعديل ──
    final expiresAt =
        _expiresAt ?? DateTime.now().add(const Duration(hours: 24));

    // ── يُمنع الحفظ إن كان سيعيد تفعيل عرض لم يكن نشطاً قبل التعديل (مغلق،
    // منتهي، أو نافد الكمية) بينما الحساب قيد إعادة المراجعة أو مرفوض؛
    // بما أن هذه الشاشة لا تُعدّل حقل status، فالتفعيل هنا يحدث فقط عبر رفع
    // الكمية المتبقية عن صفر و/أو تمديد تاريخ الانتهاء لعرض كان منتهياً —
    // ولأن expiresAt الجديد يُشترَط دائماً أن يكون بالمستقبل (تحقق أعلاه)،
    // فتعديل أي عرض منتهي يُعيد تفعيله تلقائياً إن بقيت حالته الخام 'available' ──
    final rawStatus = (widget.offerData['status'] as String?) ?? 'available';
    final wasActiveBefore = rawStatus == 'available' &&
        !isOfferExpired(widget.offerData) &&
        ((widget.offerData['remainingQuantity'] as num?)?.toInt() ?? 0) > 0;
    final willBeActiveAfter = rawStatus == 'available' && quantity > 0;

    if (!wasActiveBefore && willBeActiveAfter) {
      final uid = user.uid;
      final canReactivate = await canPublishOrReactivateOffers(uid);
      if (!mounted) return;
      if (!canReactivate) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (!mounted) return;
        final vs = doc.data()?['verificationStatus'] as String?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(publishBlockedMessage(vs)),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // ── تحديد رابط الصورة: رفع الجديدة أو الاحتفاظ بالحالية ──
      String imageUrl = _currentImageUrl;
      if (_selectedImage != null) {
        final uploaded = await _uploadImage();
        if (!mounted) return;
        if (uploaded == null || uploaded.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('لم يتم رفع الصورة، جرب مرة ثانية')),
          );
          return;
        }
        imageUrl = uploaded;
      }

      await FirebaseFirestore.instance
          .collection('offers')
          .doc(widget.offerId)
          .update({
        'title': title,
        'description': desc,
        'imageUrl': imageUrl,
        'remainingQuantity': quantity,
        'originalPrice': originalPrice,
        'discountPrice': discountPrice,
        'price': discountPrice,
        'isFree': discountPrice == 0,
        'pickupLocation': pickup,
        'allergyInfo': allergyInfo,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // الإشعار غير حرج — لا يوقف تدفق الحفظ عند الفشل
      try {
        await NotificationService().sendNotification(
          userId: user.uid,
          title: 'تم تعديل العرض',
          message: 'تم تحديث بيانات العرض "$title"',
          type: 'offer',
          relatedId: widget.offerId,
        );
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التعديلات بنجاح ✅'),
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
        title: const Text('تعديل العرض'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // ── تنبيه ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.secondary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'التعديل لن يؤثر على الحجوزات الموجودة حالياً.',
                    style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 13,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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

                  // 2 ── صورة ──
                  _ImagePickerSection(
                    selectedImage: _selectedImage,
                    currentImageUrl: _currentImageUrl,
                    uploading: _uploadingImage,
                    onPick: _pickImage,
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

                  // 4 ── الكمية ──
                  FormFieldWidget(
                    controller: _quantityController,
                    label: 'الكمية المتبقية',
                    hint: 'مثال: 10',
                    icon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),

                  // 5 ── مكان الاستلام ──
                  FormFieldWidget(
                    controller: _pickupController,
                    label: 'مكان الاستلام',
                    hint: 'العنوان أو المنطقة',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 14),

                  // 5.5 ── تاريخ ووقت انتهاء العرض ──
                  ExpiryDateTimeField(
                    value: _expiresAt,
                    onChanged: (v) => setState(() => _expiresAt = v),
                  ),
                  const SizedBox(height: 14),

                  // 6 ── وصف الباقة ──
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'وصف الباقة',
                      hintText: 'صف محتوى الباقة...',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 48),
                        child: Icon(Icons.description_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 7 ── معلومات الحساسية الغذائية ──
                  AllergyCheckboxPanel(
                    selected: _selectedAllergens,
                    onChanged: (v) => setState(() => _selectedAllergens = v),
                  ),
                  const SizedBox(height: 20),

                  // ── زر الحفظ ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveChanges,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_rounded),
                      label: Text(
                          _isLoading ? 'جاري الحفظ...' : 'حفظ التعديلات'),
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

class _ImagePickerSection extends StatelessWidget {
  final XFile? selectedImage;
  final String currentImageUrl;
  final bool uploading;
  final VoidCallback onPick;

  const _ImagePickerSection({
    required this.selectedImage,
    required this.currentImageUrl,
    required this.uploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final Widget preview;
    if (selectedImage != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          File(selectedImage!.path),
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else if (currentImageUrl.isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          currentImageUrl,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    } else {
      preview = _placeholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        preview,
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: uploading ? null : onPick,
            icon: uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library_outlined, size: 18),
            label: Text(
              selectedImage != null
                  ? 'تغيير الصورة'
                  : (currentImageUrl.isNotEmpty
                      ? 'تغيير الصورة الحالية'
                      : 'إضافة صورة'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Icon(Icons.restaurant_menu_rounded,
            size: 48, color: AppColors.textLight),
      ),
    );
  }
}
