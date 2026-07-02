import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cloudinary_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_offer_service.dart';
import '../../theme/app_colors.dart';
import '../common/location_picker_screen.dart';
import 'identity_verification_screen.dart';

class DonateTab extends StatefulWidget {
  const DonateTab({super.key});

  @override
  State<DonateTab> createState() => _DonateTabState();
}

class _DonateTabState extends State<DonateTab> {
  final _foodNameController = TextEditingController();
  final _descController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'وجبات';
  DateTime? _expiryDate;
  bool _isLoading = false;
  bool _acceptedResponsibility = false;

  // بيانات المستخدم
  String? _userNationalId;
  String? _userName;
  bool _loadingUser = true;
  bool _hasNationalId = false;

  // الجمعية المختارة
  String? _selectedCharityId;
  String? _selectedCharityName;

  // موقع الاستلام
  double? _latitude;
  double? _longitude;
  String _locationSource = 'manual';

  // الصورة
  Uint8List? _imageBytes;
  bool _isPickingImage = false;

  // وقت الاستلام
  TimeOfDay? _pickupStartTime;
  TimeOfDay? _pickupEndTime;

  final _categories = ['وجبات', 'مخبوزات', 'خضار وفواكه', 'معلبات', 'حلويات'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      final nationalId = data['nationalId'] ?? '';
      final idVerified =
          (data['identityVerificationStatus'] as String? ?? '') == 'approved';
      setState(() {
        _userNationalId =
            data['identityNumber'] as String? ?? nationalId.toString();
        _userName = data['name'] ?? data['fullName'] ?? '';
        _hasNationalId = idVerified || nationalId.toString().isNotEmpty;
        _loadingUser = false;
      });
    } else {
      setState(() => _loadingUser = false);
    }
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _descController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_imageBytes != null)
              ListTile(
                leading:
                    const Icon(Icons.delete_rounded, color: AppColors.danger),
                title: const Text('إزالة الصورة',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  setState(() => _imageBytes = null);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _isPickingImage = true);
    try {
      final file =
          await ImagePicker().pickImage(source: source, imageQuality: 75);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _pickupStartTime : _pickupEndTime) ?? TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _pickupStartTime = picked;
      } else {
        _pickupEndTime = picked;
      }
    });
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _pickCharity() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CharityPickerSheet(
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

  Future<void> _donateFood() async {
    // ── التحقق من المصادقة ──
    if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً للتبرع')),
      );
      return;
    }

    // ── التحقق من الحقول المطلوبة (sync قبل أي await) ──
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة صورة للتبرع')),
      );
      return;
    }
    if (_foodNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم الطعام')),
      );
      return;
    }
    if (_locationController.text.trim().isEmpty && _latitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد مكان الاستلام')),
      );
      return;
    }
    if (_pickupStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد وقت بداية الاستلام')),
      );
      return;
    }
    if (_pickupEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد وقت نهاية الاستلام')),
      );
      return;
    }
    if (!_acceptedResponsibility) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى الموافقة على إقرار المسؤولية القانونية'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // ── التحقق من توثيق الهوية (يتطلب await) ──
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userSnap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    final idStatus =
        (userSnap.data()?['identityVerificationStatus'] as String? ?? '');
    if (idStatus != 'approved') {
      if (idStatus == 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('طلب توثيق هويتك قيد المراجعة، يرجى الانتظار.')),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const IdentityVerificationScreen()),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── رفع الصورة إلى Cloudinary ──
      final imageUrl = await CloudinaryService().uploadBytes(
        bytes: _imageBytes!,
        filename: 'donation_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (!mounted) return;
      if (imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('فشل رفع الصورة، يرجى المحاولة مرة أخرى')),
        );
        return;
      }

      final startStr = _formatTime(_pickupStartTime!);
      final endStr = _formatTime(_pickupEndTime!);
      final pickupTime = '$startStr - $endStr';
      final locationText = _locationController.text.trim();
      final title = _foodNameController.text.trim();
      final charityId = _selectedCharityId ?? '';
      final charityName = _selectedCharityName ?? '';

      final docRef =
          await FirebaseFirestore.instance.collection('donations').add({
        // ── حقول المواصفة الجديدة ──
        'donorUserId': uid,
        'donorName': _userName ?? '',
        'charityId': charityId,
        'charityName': charityName,
        'title': title,
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'imageUrl': imageUrl,
        'pickupLocation': locationText,
        'latitude': _latitude,
        'longitude': _longitude,
        'hasLocation': _latitude != null,
        'locationSource': _latitude != null ? _locationSource : 'manual',
        'pickupStartTime': startStr,
        'pickupEndTime': endStr,
        'pickupTime': pickupTime,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // ── حقول قديمة للتوافق مع السجلات السابقة ──
        'userId': uid,
        'userName': _userName ?? '',
        'nationalId': _userNationalId ?? '',
        'foodName': title,
        'quantity': _quantityController.text.trim().isEmpty
            ? '1'
            : _quantityController.text.trim(),
        'location': locationText,
        'notes': _notesController.text.trim(),
        'expiryDate': _expiryDate,
        'acceptedResponsibility': true,
        'responsibilityAcceptedAt': FieldValue.serverTimestamp(),
        'targetCharityId': charityId,
        'targetCharityName': charityName,
        'isDirectedToCharity': charityId.isNotEmpty,
      });

      await docRef.update({'donationId': docRef.id});
      if (!mounted) return;

      await _notifyCharity(title, charityId);
      if (!mounted) return;

      _resetForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(charityName.isNotEmpty
                  ? 'تم إرسال تبرعك إلى $charityName ❤️'
                  : 'تم إضافة تبرعك بنجاح، شكراً لك!'),
            ],
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

  Future<void> _notifyCharity(String title, String charityId) async {
    const notifTitle = 'تبرع طعام جديد';
    final msg = 'تبرع جديد بانتظار مراجعتك: "$title"';
    if (charityId.isNotEmpty) {
      await NotificationService().sendNotification(
        userId: charityId,
        title: notifTitle,
        message: msg,
        type: 'donation',
      );
    } else {
      final charities = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'charity')
          .where('isApproved', isEqualTo: true)
          .get();
      final ids = charities.docs.map((d) => d.id).toList();
      if (ids.isNotEmpty) {
        await NotificationService().sendBulkNotification(
          userIds: ids,
          title: notifTitle,
          message: msg,
          type: 'donation',
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _foodNameController.clear();
      _descController.clear();
      _quantityController.clear();
      _locationController.clear();
      _notesController.clear();
      _expiryDate = null;
      _selectedCategory = 'وجبات';
      _acceptedResponsibility = false;
      _selectedCharityId = null;
      _selectedCharityName = null;
      _latitude = null;
      _longitude = null;
      _locationSource = 'manual';
      _imageBytes = null;
      _pickupStartTime = null;
      _pickupEndTime = null;
    });
  }

  String _maskNationalId(String id) {
    if (id.length <= 4) return id;
    return '${'*' * (id.length - 4)}${id.substring(id.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) return const Center(child: CircularProgressIndicator());
    if (!_hasNationalId) return _NoNationalIdView(onSaved: _loadUserData);

    return ListView(
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
                  color: Colors.white, size: 36),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تبرع بالطعام ❤️',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('شارك طعامك الفائض وساهم في دعم المجتمع',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── هوية المتبرع ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('هويتك موثّقة ✓',
                        style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text(
                      'رقم الهوية: ${_maskNationalId(_userNationalId ?? '')}',
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── اختيار الجمعية ──
        GestureDetector(
          onTap: _pickCharity,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _selectedCharityId != null
                  ? const Color(0xFFE11D48).withValues(alpha: 0.06)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedCharityId != null
                    ? const Color(0xFFE11D48).withValues(alpha: 0.4)
                    : AppColors.border,
                width: _selectedCharityId != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _selectedCharityId != null
                        ? const Color(0xFFE11D48).withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedCharityId != null
                        ? Icons.favorite_rounded
                        : Icons.volunteer_activism_outlined,
                    color: _selectedCharityId != null
                        ? const Color(0xFFE11D48)
                        : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCharityId != null
                            ? 'الجمعية المختارة'
                            : 'اختر جمعية (اختياري)',
                        style: TextStyle(
                          fontSize: 11,
                          color: _selectedCharityId != null
                              ? const Color(0xFFE11D48)
                              : AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedCharityId != null
                            ? _selectedCharityName ?? ''
                            : 'سيذهب تبرعك لأي جمعية متاحة',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedCharityId != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedCharityId != null
                              ? const Color(0xFFBE123C)
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _selectedCharityId != null
                      ? Icons.change_circle_outlined
                      : Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.textLight,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── الفورم ──
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
                // ── صورة التبرع ──
                _SectionLabel(label: 'صورة التبرع *'),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _imageBytes != null
                          ? Colors.transparent
                          : AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _imageBytes != null
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: _isPickingImage
                        ? const Center(child: CircularProgressIndicator())
                        : _imageBytes != null
                            ? Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.memory(_imageBytes!,
                                        fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(Icons.edit_rounded,
                                          color: Colors.white, size: 18),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded,
                                      size: 42,
                                      color: AppColors.primary
                                          .withValues(alpha: 0.4)),
                                  const SizedBox(height: 8),
                                  const Text('اضغط لإضافة صورة',
                                      style: TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 13)),
                                ],
                              ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── اسم الطعام ──
                _SectionLabel(label: 'اسم الطعام *'),
                TextField(
                  controller: _foodNameController,
                  decoration: const InputDecoration(
                    hintText: 'مثال: أرز بالدجاج',
                    prefixIcon: Icon(Icons.fastfood_rounded),
                  ),
                ),

                const SizedBox(height: 14),

                // ── الوصف ──
                _SectionLabel(label: 'الوصف (اختياري)'),
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'وصف مختصر للطعام...',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 28),
                      child: Icon(Icons.description_outlined),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── الفئة ──
                _SectionLabel(label: 'الفئة'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
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
                              : AppColors.primary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.primary)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // ── الكمية ──
                _SectionLabel(label: 'الكمية'),
                TextField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    hintText: 'مثال: 3 وجبات',
                    prefixIcon: Icon(Icons.production_quantity_limits_rounded),
                  ),
                ),

                const SizedBox(height: 14),

                // ── تاريخ انتهاء الصلاحية ──
                _SectionLabel(label: 'تاريخ انتهاء الصلاحية'),
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
                              ? 'اختر تاريخ الانتهاء'
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

                // ── مكان الاستلام ──
                _SectionLabel(label: 'مكان الاستلام *'),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    hintText: 'العنوان أو المنطقة',
                    prefixIcon: Icon(Icons.location_on_rounded),
                  ),
                ),
                const SizedBox(height: 10),

                // زر خريطة الموقع
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
                        Expanded(
                          child: Text(
                            _latitude != null
                                ? 'تم تحديد الموقع ✓'
                                : 'تحديد الموقع على الخريطة',
                            style: TextStyle(
                              fontSize: 13,
                              color: _latitude != null
                                  ? AppColors.success
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── وقت الاستلام ──
                _SectionLabel(label: 'وقت الاستلام *'),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _pickupStartTime != null
                                  ? AppColors.success.withValues(alpha: 0.5)
                                  : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 18,
                                  color: _pickupStartTime != null
                                      ? AppColors.success
                                      : AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _pickupStartTime != null
                                      ? _formatTime(_pickupStartTime!)
                                      : 'وقت البداية',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _pickupStartTime != null
                                        ? AppColors.textDark
                                        : AppColors.textLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _pickupEndTime != null
                                  ? AppColors.success.withValues(alpha: 0.5)
                                  : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_filled_rounded,
                                  size: 18,
                                  color: _pickupEndTime != null
                                      ? AppColors.success
                                      : AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _pickupEndTime != null
                                      ? _formatTime(_pickupEndTime!)
                                      : 'وقت النهاية',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _pickupEndTime != null
                                        ? AppColors.textDark
                                        : AppColors.textLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── ملاحظات ──
                _SectionLabel(label: 'ملاحظات (اختياري)'),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'أي تفاصيل إضافية...',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 48),
                      child: Icon(Icons.notes_rounded),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ── إقرار المسؤولية ──
                GestureDetector(
                  onTap: () => setState(
                      () => _acceptedResponsibility = !_acceptedResponsibility),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _acceptedResponsibility
                          ? AppColors.danger.withValues(alpha: 0.06)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _acceptedResponsibility
                            ? AppColors.danger
                            : AppColors.border,
                        width: _acceptedResponsibility ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptedResponsibility,
                          onChanged: (v) => setState(
                              () => _acceptedResponsibility = v ?? false),
                          activeColor: AppColors.danger,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'أقرّ بأن الطعام المتبرع به آمن للاستهلاك البشري وغير منتهي الصلاحية، وأتحمل المسؤولية القانونية الكاملة عن سلامته.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textDark,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _donateFood,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.volunteer_activism_rounded),
                    label:
                        Text(_isLoading ? 'جاري الإرسال...' : 'إضافة التبرع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── تبرعاتي السابقة ──
        const Text('تبرعاتي السابقة',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('donations')
              .where('userId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final donations = snapshot.data!.docs;

            if (donations.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('لم تقم بأي تبرع بعد',
                      style: TextStyle(color: AppColors.textLight)),
                ),
              );
            }

            return Column(
              children: donations.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'pending';
                final charityName = data['targetCharityName'] ??
                    data['charityName'] ??
                    '';
                final imageUrl = data['imageUrl'] as String? ?? '';
                final displayTitle =
                    data['foodName'] ?? data['title'] ?? '';
                final pickupTime = data['pickupTime'] as String? ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: ListTile(
                    leading: imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _defaultLeadingIcon(),
                            ),
                          )
                        : _defaultLeadingIcon(),
                    title: Text(displayTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['quantity'] ?? ''} • ${data['category'] ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (pickupTime.isNotEmpty)
                          Text(
                            pickupTime,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight),
                          ),
                        if (charityName.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.volunteer_activism_rounded,
                                  size: 11, color: Color(0xFFE11D48)),
                              const SizedBox(width: 3),
                              Text(charityName,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFE11D48),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: _StatusBadge(status: status),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 24),

        // ── عروضي المنشورة ──
        const Text(
          'عروضي المنشورة',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark),
        ),
        const SizedBox(height: 10),

        const _MyPublishedOffers(),
      ],
    );
  }

  Widget _defaultLeadingIcon() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.favorite_rounded,
          color: Color(0xFFE11D48), size: 20),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom Sheet اختيار الجمعية
// ─────────────────────────────────────────────
class _CharityPickerSheet extends StatelessWidget {
  final String? selectedId;
  final void Function(String id, String name) onSelected;
  final VoidCallback onClear;

  const _CharityPickerSheet({
    required this.selectedId,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.volunteer_activism_rounded,
                        color: Color(0xFFE11D48), size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('اختر جمعية خيرية',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark)),
                    ),
                    if (selectedId != null)
                      TextButton(
                        onPressed: onClear,
                        child: const Text('إلغاء الاختيار',
                            style: TextStyle(
                                color: AppColors.danger, fontSize: 12)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'يمكنك اختيار جمعية محددة أو ترك الاختيار فارغاً وستتولى أي جمعية متاحة استلام تبرعك.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'charity')
                      .where('status', isEqualTo: 'active')
                      .where('isApproved', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final charities = snap.data!.docs;

                    if (charities.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volunteer_activism_outlined,
                                size: 48,
                                color:
                                    AppColors.primary.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            const Text(
                              'لا توجد جمعيات مسجّلة حالياً',
                              style: TextStyle(color: AppColors.textLight),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: charities.length,
                      itemBuilder: (context, i) {
                        final doc = charities[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final name =
                            data['name'] ?? data['fullName'] ?? 'جمعية';
                        final address = data['address'] ?? '';
                        final phone = data['phone'] ?? '';
                        final isSelected = selectedId == doc.id;

                        return GestureDetector(
                          onTap: () => onSelected(doc.id, name),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE11D48)
                                      .withValues(alpha: 0.07)
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFE11D48)
                                    : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFE11D48)
                                            .withValues(alpha: 0.12)
                                        : AppColors.primary
                                            .withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.volunteer_activism_rounded,
                                    color: isSelected
                                        ? const Color(0xFFE11D48)
                                        : AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: isSelected
                                                  ? const Color(0xFFBE123C)
                                                  : AppColors.textDark)),
                                      if (address.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.location_on_outlined,
                                                size: 12,
                                                color: AppColors.textLight),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(address,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.textLight),
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (phone.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone_outlined,
                                                size: 12,
                                                color: AppColors.textLight),
                                            const SizedBox(width: 3),
                                            Text(phone,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textLight)),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? const Color(0xFFE11D48)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFE11D48)
                                          : AppColors.border,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 14)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// شاشة إضافة رقم الهوية
// ─────────────────────────────────────────────
class _NoNationalIdView extends StatefulWidget {
  final VoidCallback onSaved;
  const _NoNationalIdView({required this.onSaved});

  @override
  State<_NoNationalIdView> createState() => _NoNationalIdViewState();
}

class _NoNationalIdViewState extends State<_NoNationalIdView> {
  final _idController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _saveNationalId() async {
    final id = _idController.text.trim();
    if (id.isEmpty || id.length < 7 || !RegExp(r'^\d+$').hasMatch(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رقم هوية صحيح (7 أرقام على الأقل)'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'nationalId': id});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ رقم هويتك ✅'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.badge_outlined,
                  color: AppColors.secondary, size: 46),
            ),
            const SizedBox(height: 20),
            const Text('رقم الهوية مطلوب للتبرع',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 12),
            const Text(
              'لضمان سلامة الغذاء والمساءلة القانونية، يجب تسجيل رقم هويتك قبل التبرع بالطعام.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textLight, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _idController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'رقم الهوية الوطنية',
                hintText: 'مثال: 123456789',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '🔒 رقم هويتك محمي ولن يُشارك مع أي طرف آخر.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.secondary, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveNationalId,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ رقم الهوية'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'قيد المراجعة';
        break;
      case 'approved':
        color = AppColors.success;
        label = 'مقبول';
        break;
      case 'redistributed':
        color = AppColors.primary;
        label = 'موزّع';
        break;
      case 'rejected':
        color = AppColors.danger;
        label = 'مرفوض';
        break;
      default:
        color = AppColors.textLight;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// ─────────────────────────────────────────────
// عروضي المنشورة — قائمة عروض الفرد القابلة لإعادة المشاركة
// ─────────────────────────────────────────────
class _MyPublishedOffers extends StatelessWidget {
  const _MyPublishedOffers();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('providerUserId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final docs = snap.data!.docs
            .where((d) =>
                (d.data() as Map<String, dynamic>)['offerType'] ==
                'individual_offer')
            .toList()
          ..sort((a, b) {
            final aRaw = (a.data() as Map<String, dynamic>)['updatedAt'];
            final bRaw = (b.data() as Map<String, dynamic>)['updatedAt'];
            final aTs = aRaw is Timestamp ? aRaw : null;
            final bTs = bRaw is Timestamp ? bRaw : null;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'لم تنشر أي عرض طعام بعد',
                style: TextStyle(color: AppColors.textLight),
              ),
            ),
          );
        }

        return Column(
          children: docs
              .map((doc) => _MyOfferCard(
                    docId: doc.id,
                    data: doc.data() as Map<String, dynamic>,
                  ))
              .toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// بطاقة العرض المنشور مع زر "إعادة مشاركة"
// ─────────────────────────────────────────────
class _MyOfferCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _MyOfferCard({required this.docId, required this.data});

  @override
  State<_MyOfferCard> createState() => _MyOfferCardState();
}

class _MyOfferCardState extends State<_MyOfferCard> {
  bool _loading = false;

  Future<void> _republish() async {
    setState(() => _loading = true);
    try {
      final originalQty = (widget.data['quantity'] as num?)?.toInt() ?? 1;
      await UserOfferService().republishOffer(
        offerId: widget.docId,
        originalQuantity: originalQty,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إعادة نشر العرض بنجاح ✅'),
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
    final title = widget.data['title'] ?? 'عرض طعام';
    final status = widget.data['status'] ?? 'available';
    final remainingQty =
        (widget.data['remainingQuantity'] as num?)?.toInt() ?? 0;
    final originalQty = (widget.data['quantity'] as num?)?.toInt() ?? 1;
    final isActive = status == 'available' && remainingQty > 0;

    final Color statusColor;
    final String statusLabel;
    if (isActive) {
      statusColor = AppColors.success;
      statusLabel = 'نشط';
    } else if (status == 'expired') {
      statusColor = AppColors.danger;
      statusLabel = 'منتهي';
    } else if (remainingQty == 0) {
      statusColor = AppColors.secondary;
      statusLabel = 'نفذ';
    } else {
      statusColor = AppColors.textLight;
      statusLabel = status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
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
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    'متبقي: $remainingQty / $originalQty',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                if (!isActive) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _loading ? null : _republish,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _loading
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded,
                                    color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'إعادة مشاركة',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
