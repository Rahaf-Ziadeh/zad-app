import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../../widgets/user_publish_widgets.dart';
import '../../services/user_offer_service.dart';
import '../../services/location_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../constants/app_constants.dart';

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

    try {
      final position = await LocationService().getCurrentLocation();

      if (position == null) {
        throw Exception('تعذّر الحصول على الإحداثيات');
      }

      String locationText = '';

      // ── محاولة جلب اسم المنطقة ──
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 8));

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          final city = place.locality ?? '';
          final area = place.subLocality ?? '';
          final street = place.street ?? '';

          locationText = [
            if (city.isNotEmpty) city,
            if (area.isNotEmpty) area,
            if (street.isNotEmpty) street,
          ].join(' - ');
        }
      } catch (_) {
        // إذا فشل geocoding
        locationText = 'يرجى كتابة اسم المنطقة يدوياً';
      }

      // إذا رجع فاضي
      if (locationText.trim().isEmpty) {
        locationText = 'يرجى كتابة اسم المنطقة يدوياً';
      }

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationController.text = locationText;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد الموقع ✅'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحديد الموقع: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _fetchingLocation = false);
      }
    }
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
      final userName = await UserService().getUserName(uid);

      final price =
          _isFree ? 0.0 : (double.tryParse(_priceController.text.trim()) ?? 0);
      await UserOfferService().publishIndividualOffer(
        uid: uid,
        userName: userName,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory,
        quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
        price: price,
        isFree: _isFree,
        pickupLocation: resolvedLocation,
        latitude: _latitude,
        longitude: _longitude,
        expiryDate: _expiryDate!,
      );

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
                  child: TypeCard(
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
                  child: TypeCard(
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
                    const SectionLabel(text: 'الفئة'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: AppConstants.foodCategories.map((cat) {
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
                                  : AppColors.primary.withValues(alpha:0.07),
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
