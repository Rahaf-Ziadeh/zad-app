import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

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
  late final TextEditingController _imageUrlController;
  late final TextEditingController _quantityController;
  late final TextEditingController _originalPriceController;
  late final TextEditingController _discountPriceController;
  late final TextEditingController _pickupController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final d = widget.offerData;
    _titleController = TextEditingController(text: d['title'] ?? '');
    _descController = TextEditingController(text: d['description'] ?? '');
    _imageUrlController = TextEditingController(text: d['imageUrl'] ?? '');
    _quantityController = TextEditingController(
        text: '${d['remainingQuantity'] ?? d['quantity'] ?? ''}');
    _originalPriceController =
        TextEditingController(text: '${d['originalPrice'] ?? ''}');
    _discountPriceController =
        TextEditingController(text: '${d['discountPrice'] ?? ''}');
    _pickupController = TextEditingController(text: d['pickupLocation'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _imageUrlController.dispose();
    _quantityController.dispose();
    _originalPriceController.dispose();
    _discountPriceController.dispose();
    _pickupController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final imageUrl = _imageUrlController.text.trim();
    final quantityStr = _quantityController.text.trim();
    final originalStr = _originalPriceController.text.trim();
    final discountStr = _discountPriceController.text.trim();
    final pickup = _pickupController.text.trim();

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
            content: Text('السعر بعد الخصم لا يجب أن يتجاوز السعر الأصلي')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
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
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
                        color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
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
                        color: AppColors.secondary, fontSize: 13, height: 1.4),
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
                  _FormField(
                    controller: _titleController,
                    label: 'اسم الباقة',
                    hint: 'مثال: باقة وجبات مشكّلة',
                    icon: Icons.fastfood_rounded,
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _imageUrlController,
                    label: 'رابط الصورة (اختياري)',
                    hint: 'https://...',
                    icon: Icons.image_outlined,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _FormField(
                          controller: _originalPriceController,
                          label: 'السعر الأصلي',
                          hint: '0.00',
                          icon: Icons.price_change_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormField(
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
                  _FormField(
                    controller: _quantityController,
                    label: 'الكمية المتبقية',
                    hint: 'مثال: 10',
                    icon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: _pickupController,
                    label: 'مكان الاستلام',
                    hint: 'العنوان أو المنطقة',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 14),
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
                  const SizedBox(height: 20),
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
                      label:
                          Text(_isLoading ? 'جاري الحفظ...' : 'حفظ التعديلات'),
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

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
