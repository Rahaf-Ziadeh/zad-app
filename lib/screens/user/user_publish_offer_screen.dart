import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/location_service.dart';
import '../../theme/app_colors.dart';

class UserPublishOfferScreen extends StatefulWidget {
  const UserPublishOfferScreen({super.key});

  @override
  State<UserPublishOfferScreen> createState() => _UserPublishOfferScreenState();
}

class _UserPublishOfferScreenState extends State<UserPublishOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();

  String _selectedCategory = 'وجبات';
  bool _isFree = true;
  bool _isLoading = false;
  bool _fetchingLocation = false;
  DateTime? _expiryDate;
  double? _latitude;
  double? _longitude;

  final _categories = [
    'وجبات',
    'مخبوزات',
    'خضار وفواكه',
    'معلبات',
    'حلويات',
    'أخرى',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _priceController.dispose();
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
            content: Text('تم تحديد الموقع ✅'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّر الحصول على الموقع'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
    setState(() => _fetchingLocation = false);
  }

  Future<void> _publish() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد تاريخ الانتهاء')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userName = userDoc.data()?['name'] ?? 'فرد';

      final price =
          _isFree ? 0.0 : (double.tryParse(_priceController.text.trim()) ?? 0);

      final docRef = FirebaseFirestore.instance.collection('offers').doc();
      await docRef.set({
        'offerId': docRef.id,
        'providerUserId': uid,
        'providerRole': 'individual',
        'providerName': userName,
        'offerType': 'individual_offer',
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'imageUrl': '',
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 1,
        'remainingQuantity': int.tryParse(_quantityController.text.trim()) ?? 1,
        'originalPrice': price,
        'discountPrice': price,
        'price': price,
        'currency': 'ILS',
        'isFree': _isFree,
        'status': 'available',
        'pickupLocation': _locationController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'hasLocation': _latitude != null,
        'expiryDate': _expiryDate,
        'isCash': true,
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر عرضك بنجاح ✅'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('نشر عرض طعام'),
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
                  colors: [Color(0xFF059669), Color(0xFF047857)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.eco_rounded, color: Colors.white, size: 32),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('شارك طعامك الفائض',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        SizedBox(height: 4),
                        Text('أضف عرضاً مجانياً أو برمزي لمن يحتاجه في منطقتك',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── مجاني أو بسعر رمزي ──
            Row(
              children: [
                Expanded(
                  child: _TypeCard(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'مجاني',
                    subtitle: 'هدية لمن يحتاج',
                    selected: _isFree,
                    color: AppColors.success,
                    onTap: () => setState(() => _isFree = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeCard(
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
                    // اسم الطعام
                    TextFormField(
                      controller: _titleController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'يرجى إدخال اسم الطعام'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطعام *',
                        hintText: 'مثال: أرز بالدجاج',
                        prefixIcon: Icon(Icons.fastfood_rounded),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // الفئة
                    const _SectionLabel(text: 'الفئة'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
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
                                  ? AppColors.primary
                                  : AppColors.primary.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(cat,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.primary)),
                          ),
                        );
                      }).toList(),
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
                        labelText: 'الكمية *',
                        hintText: 'مثال: 3',
                        prefixIcon:
                            Icon(Icons.production_quantity_limits_rounded),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // السعر — يظهر فقط لو مش مجاني
                    if (!_isFree) ...[
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (!_isFree) {
                            if (v == null || v.trim().isEmpty) {
                              return 'يرجى إدخال السعر';
                            }
                            if (double.tryParse(v.trim()) == null ||
                                double.parse(v.trim()) <= 0) {
                              return 'السعر يجب أن يكون أكبر من صفر';
                            }
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'السعر الرمزي (ILS) *',
                          hintText: 'مثال: 5',
                          prefixIcon: Icon(Icons.attach_money_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

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

                    // موقع الاستلام
                    TextFormField(
                      controller: _locationController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'يرجى إدخال مكان الاستلام'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'مكان الاستلام *',
                        hintText: 'العنوان أو المنطقة',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // زر الموقع GPS
                    GestureDetector(
                      onTap: _fetchingLocation ? null : _fetchLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _latitude != null
                              ? AppColors.success.withOpacity(0.08)
                              : AppColors.primary.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _latitude != null
                                ? AppColors.success.withOpacity(0.4)
                                : AppColors.primary.withOpacity(0.3),
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
                                        color: AppColors.primary))
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
                                    ? 'تم تحديد الموقع ✓'
                                    : 'تحديد موقعي تلقائياً',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: _latitude != null
                                        ? AppColors.success
                                        : AppColors.primary,
                                    fontWeight: FontWeight.w600),
                              ),
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
                        labelText: 'وصف مختصر (اختياري)',
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
                label: Text(_isLoading ? 'جاري النشر...' : 'نشر العرض',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeCard({
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : AppColors.textLight, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: selected ? color : AppColors.textDark)),
            const SizedBox(height: 3),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark));
  }
}
