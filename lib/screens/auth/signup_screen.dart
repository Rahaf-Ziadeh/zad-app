import 'package:flutter/material.dart';

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_colors.dart';
import '../common/location_picker_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nationalIdController = TextEditingController(); // ← جديد

  String _selectedRole = 'individual';
  String _selectedCountryCode = '+970';
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  bool _acceptedTerms = false;

  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = AppColors.danger;

  // ── الموقع المسجَّل ──
  double? _registrationLat;
  double? _registrationLon;
  String _registrationLocationSource = 'manual'; // 'gps' أو 'map' أو 'manual'

  // ── حقول إضافية للمطعم ──
  final _ownerNameController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  // ── ساعات العمل: مشتركة بين المطعم والجمعية ──
  TimeOfDay? _workingHoursStart;
  TimeOfDay? _workingHoursEnd;

  // ── حقول إضافية للجمعية ──
  final _responsiblePersonController = TextEditingController();
  final _regNumberController = TextEditingController();

  // ── مشتركة بين المطعم والجمعية ──
  final _orgDescController = TextEditingController();
  _PickedDoc? _logoFile;
  _PickedDoc? _orgDocFile;
  bool _uploadingOrgDocs = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nationalIdController.dispose();
    _ownerNameController.dispose();
    _licenseNumberController.dispose();
    _responsiblePersonController.dispose();
    _regNumberController.dispose();
    _orgDescController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final p = _passwordController.text;
    double strength = 0;
    if (p.length >= 6) strength += 0.2;
    if (p.length >= 10) strength += 0.2;
    if (p.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (p.contains(RegExp(r'[0-9]'))) strength += 0.2;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength += 0.2;

    String label;
    Color color;
    if (strength <= 0.2) {
      label = 'ضعيفة جداً';
      color = AppColors.danger;
    } else if (strength <= 0.4) {
      label = 'ضعيفة';
      color = Colors.orange;
    } else if (strength <= 0.6) {
      label = 'متوسطة';
      color = AppColors.secondary;
    } else if (strength <= 0.8) {
      label = 'جيدة';
      color = AppColors.primary;
    } else {
      label = 'قوية جداً ✓';
      color = AppColors.success;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = p.isEmpty ? '' : label;
      _passwordStrengthColor = color;
    });
  }

  // ── Validators ──
  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'يرجى إدخال الاسم';
    if (v.trim().length < 3) return 'الاسم يجب أن يكون 3 أحرف على الأقل';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v.trim())) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'يرجى إدخال رقم الهاتف';
    if (v.trim().length < 7) return 'رقم الهاتف غير صحيح';
    return null;
  }

  String? _validateAddress(String? v) {
    if (v == null || v.trim().isEmpty) return 'يرجى إدخال العنوان';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.trim().isEmpty) return 'يرجى إدخال كلمة المرور';
    if (v.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (v == null || v.trim().isEmpty) return 'يرجى تأكيد كلمة المرور';
    if (v != _passwordController.text) return 'كلمتا المرور غير متطابقتين';
    return null;
  }

  Future<void> _pickLogo() async {
    // اختيار المصدر: الكاميرا أو المعرض
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('اختر مصدر الصورة',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primary),
              title: const Text('الكاميرا'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primary),
              title: const Text('معرض الصور'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (!mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _logoFile = _PickedDoc(bytes: bytes, name: picked.name));
  }

  Future<void> _pickOrgDoc() async {
    // نستخدم ImagePicker (مُهيَّأ مسبقاً) بدلاً من FilePicker
    // لأن FilePicker يحتاج إعداداً إضافياً في AndroidManifest
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('اختر مصدر المستند',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primary),
              title: const Text('التقاط صورة للمستند'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primary),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (!mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
      );
      if (!mounted) return;
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _orgDocFile = _PickedDoc(bytes: bytes, name: picked.name));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في اختيار المستند: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // ── فتح شاشة اختيار الموقع على خريطة OpenStreetMap ──
  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _registrationLat,
          initialLongitude: _registrationLon,
          initialAddress: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _registrationLat = result.latitude;
      _registrationLon = result.longitude;
      _addressController.text = result.address;
      _registrationLocationSource = result.locationSource;
    });
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickWorkingHours({required bool isStart}) async {
    final initial =
        (isStart ? _workingHoursStart : _workingHoursEnd) ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _workingHoursStart = picked;
      } else {
        _workingHoursEnd = picked;
      }
    });
  }

  Future<void> _handleSignup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى الموافقة على الشروط والأحكام للمتابعة'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── رفع وثائق المطعم / الجمعية ──
      String? logoUrl;
      String? orgDocUrl;
      if (_selectedRole == 'restaurant' || _selectedRole == 'charity') {
        final isRestaurant = _selectedRole == 'restaurant';
        if (isRestaurant &&
            (_ownerNameController.text.trim().isEmpty ||
                _licenseNumberController.text.trim().isEmpty ||
                _orgDescController.text.trim().isEmpty)) {
          throw Exception('يرجى تعبئة جميع حقول المطعم المطلوبة');
        }
        if (!isRestaurant &&
            (_responsiblePersonController.text.trim().isEmpty ||
                _regNumberController.text.trim().isEmpty ||
                _orgDescController.text.trim().isEmpty)) {
          throw Exception('يرجى تعبئة جميع حقول الجمعية المطلوبة');
        }
        // ── ساعات العمل: مطلوبة لكل من المطعم والجمعية ──
        if (_workingHoursStart == null || _workingHoursEnd == null) {
          throw Exception('يرجى تحديد وقت بداية ونهاية العمل');
        }

        final startMinutes =
            _workingHoursStart!.hour * 60 + _workingHoursStart!.minute;

        var endMinutes = _workingHoursEnd!.hour * 60 + _workingHoursEnd!.minute;

// إذا كان وقت الإغلاق بعد منتصف الليل، اعتبره في اليوم التالي.
// مثال: 8:00 صباحًا → 1:00 بعد منتصف الليل.
        if (endMinutes <= startMinutes) {
          endMinutes += 24 * 60;
        }

        final workingDuration = endMinutes - startMinutes;

// منع اختيار نفس وقت البداية والنهاية كدوام 24 ساعة.
        if (workingDuration == 24 * 60) {
          throw Exception('وقت بداية ونهاية العمل لا يمكن أن يكونا متطابقين');
        }
        if (_orgDocFile == null) {
          throw Exception(isRestaurant
              ? 'يرجى رفع الرخصة التجارية'
              : 'يرجى رفع وثيقة تسجيل الجمعية');
        }
        setState(() => _uploadingOrgDocs = true);
        if (_logoFile != null) {
          logoUrl = await CloudinaryService()
              .uploadBytes(bytes: _logoFile!.bytes, filename: _logoFile!.name);
          if (!mounted) return;
        }
        orgDocUrl = await CloudinaryService().uploadBytes(
            bytes: _orgDocFile!.bytes, filename: _orgDocFile!.name);
        if (!mounted) return;
        if (orgDocUrl == null || orgDocUrl.isEmpty) {
          throw Exception('فشل رفع المستند، يرجى المحاولة مجدداً');
        }
        setState(() => _uploadingOrgDocs = false);
      }

      await AuthService().registerUser(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: '$_selectedCountryCode${_phoneController.text.trim()}',
        role: _selectedRole,
        address: _addressController.text.trim(),
        nationalId: _nationalIdController.text.trim(),
        latitude: _registrationLat,
        longitude: _registrationLon,
        locationSource: _registrationLocationSource,
        ownerName: _selectedRole == 'restaurant'
            ? _ownerNameController.text.trim()
            : null,
        workingHours:
            (_selectedRole == 'restaurant' || _selectedRole == 'charity')
                ? {
                    'start': _formatTimeOfDay(_workingHoursStart!),
                    'end': _formatTimeOfDay(_workingHoursEnd!),
                  }
                : null,
        licenseNumber: _selectedRole == 'restaurant'
            ? _licenseNumberController.text.trim()
            : null,
        description: _orgDescController.text.trim().isNotEmpty
            ? _orgDescController.text.trim()
            : null,
        logoUrl: logoUrl,
        businessLicenseUrl: _selectedRole == 'restaurant' ? orgDocUrl : null,
        responsiblePerson: _selectedRole == 'charity'
            ? _responsiblePersonController.text.trim()
            : null,
        registrationNumber: _selectedRole == 'charity'
            ? _regNumberController.text.trim()
            : null,
        charityDocumentUrl: _selectedRole == 'charity' ? orgDocUrl : null,
      );

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(
            Icons.mark_email_read_rounded,
            color: AppColors.primary,
            size: 44,
          ),
          title: const Text(
            'تحقق من بريدك الإلكتروني',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'تم إرسال رابط التحقق إلى بريدك الإلكتروني.\n'
            'يرجى التحقق من البريد قبل تسجيل الدخول.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.6),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'individual':
        return 'مستخدم عادي';
      case 'restaurant':
        return 'مطعم';
      case 'charity':
        return 'جمعية خيرية';
      default:
        return role;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'individual':
        return Icons.person_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'charity':
        return Icons.volunteer_activism_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إنشاء حساب'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('انضم إلى زاد 🌱',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              const SizedBox(height: 6),
              const Text('أنشئ حسابك وابدأ بالمساهمة في تقليل هدر الطعام',
                  style: TextStyle(color: AppColors.textLight, fontSize: 14)),

              const SizedBox(height: 24),

              // ── نوع الحساب ──
              const _Label(text: 'نوع الحساب'),
              const SizedBox(height: 10),
              Row(
                children: ['individual', 'restaurant', 'charity'].map((role) {
                  final selected = _selectedRole == role;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRole = role),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.10)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                selected ? AppColors.primary : AppColors.border,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(_roleIcon(role),
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textLight,
                                size: 22),
                            const SizedBox(height: 4),
                            Text(_roleLabel(role),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.textLight)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                    children: [
                      // الاسم
                      TextFormField(
                        controller: _nameController,
                        validator: _validateName,
                        decoration: InputDecoration(
                          labelText: _selectedRole == 'individual'
                              ? 'الاسم الكامل'
                              : _selectedRole == 'restaurant'
                                  ? 'اسم المطعم'
                                  : 'اسم الجمعية',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // البريد
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // الهاتف
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone,
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف',
                          hintText: 'مثال: 599123456',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCountryCode,
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(
                                      value: '+970',
                                      child: Text('🇵🇸 +970',
                                          style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(
                                      value: '+962',
                                      child: Text('🇯🇴 +962',
                                          style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(
                                      value: '+966',
                                      child: Text('🇸🇦 +966',
                                          style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(
                                      value: '+20',
                                      child: Text('🇪🇬 +20',
                                          style: TextStyle(fontSize: 13))),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedCountryCode = v!),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // العنوان
                      TextFormField(
                        controller: _addressController,
                        validator: _validateAddress,
                        decoration: InputDecoration(
                          labelText: 'العنوان / الموقع',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _registrationLat != null
                                  ? Icons.my_location_rounded
                                  : Icons.map_outlined,
                              color: _registrationLat != null
                                  ? AppColors.success
                                  : AppColors.primary,
                              size: 20,
                            ),
                            tooltip: 'تحديد الموقع على الخريطة',
                            onPressed: _openLocationPicker,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── حقول إضافية حسب نوع الحساب ──
                      if (_selectedRole == 'restaurant') ...[
                        const SizedBox(height: 6),
                        const Divider(),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _ownerNameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم المالك / صاحب العمل *',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _orgDescController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'وصف المطعم *',
                            prefixIcon: Icon(Icons.description_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _WorkingHoursPicker(
                          start: _workingHoursStart,
                          end: _workingHoursEnd,
                          formatTime: _formatTimeOfDay,
                          onPickStart: () => _pickWorkingHours(isStart: true),
                          onPickEnd: () => _pickWorkingHours(isStart: false),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _licenseNumberController,
                          decoration: const InputDecoration(
                            labelText: 'رقم الرخصة التجارية *',
                            prefixIcon: Icon(Icons.numbers_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FilePickButton(
                          label: 'شعار المطعم (اختياري)',
                          file: _logoFile,
                          icon: Icons.image_rounded,
                          onPick: _pickLogo,
                          onClear: () => setState(() => _logoFile = null),
                        ),
                        const SizedBox(height: 10),
                        _FilePickButton(
                          label: 'الرخصة التجارية *',
                          file: _orgDocFile,
                          icon: Icons.folder_rounded,
                          onPick: _pickOrgDoc,
                          onClear: () => setState(() => _orgDocFile = null),
                        ),
                        const SizedBox(height: 6),
                        const Divider(),
                      ],
                      if (_selectedRole == 'charity') ...[
                        const SizedBox(height: 6),
                        const Divider(),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _responsiblePersonController,
                          decoration: const InputDecoration(
                            labelText: 'اسم المسؤول *',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _orgDescController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'وصف الجمعية *',
                            prefixIcon: Icon(Icons.description_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _regNumberController,
                          decoration: const InputDecoration(
                            labelText: 'رقم التسجيل الرسمي *',
                            prefixIcon: Icon(Icons.numbers_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _WorkingHoursPicker(
                          start: _workingHoursStart,
                          end: _workingHoursEnd,
                          formatTime: _formatTimeOfDay,
                          onPickStart: () => _pickWorkingHours(isStart: true),
                          onPickEnd: () => _pickWorkingHours(isStart: false),
                        ),
                        const SizedBox(height: 14),
                        _FilePickButton(
                          label: 'شعار الجمعية (اختياري)',
                          file: _logoFile,
                          icon: Icons.image_rounded,
                          onPick: _pickLogo,
                          onClear: () => setState(() => _logoFile = null),
                        ),
                        const SizedBox(height: 10),
                        _FilePickButton(
                          label: 'وثيقة تسجيل الجمعية *',
                          file: _orgDocFile,
                          icon: Icons.folder_rounded,
                          onPick: _pickOrgDoc,
                          onClear: () => setState(() => _orgDocFile = null),
                        ),
                        const SizedBox(height: 6),
                        const Divider(),
                      ],

                      const SizedBox(height: 14),

                      // كلمة المرور
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        validator: _validatePassword,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                      ),

                      // مؤشر قوة الباسورد
                      if (_passwordStrengthLabel.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _passwordStrength,
                            minHeight: 5,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                _passwordStrengthColor),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('قوة كلمة المرور',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textLight)),
                            Text(_passwordStrengthLabel,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _passwordStrengthColor)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),

                      // تأكيد كلمة المرور
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_showConfirmPassword,
                        validator: _validateConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_showConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(() =>
                                _showConfirmPassword = !_showConfirmPassword),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── إقرار قانوني — جديد ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.gavel_rounded,
                        color: AppColors.danger, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'إقرار قانوني: بالتسجيل في تطبيق زاد، أقرّ بأنني أتحمل المسؤولية الكاملة عن سلامة أي طعام أتبرع به أو أشاركه عبر التطبيق، وأن هويتي موثّقة لدى الجهة المشغّلة.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.danger, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── الشروط والأحكام ──
              GestureDetector(
                onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _acceptedTerms
                        ? AppColors.primary.withValues(alpha: 0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          _acceptedTerms ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        onChanged: (v) =>
                            setState(() => _acceptedTerms = v ?? false),
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textLight,
                                height: 1.5),
                            children: [
                              TextSpan(text: 'أوافق على '),
                              TextSpan(
                                text: 'شروط الاستخدام',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' و'),
                              TextSpan(
                                text: 'سياسة الخصوصية',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                  text:
                                      ' لتطبيق زاد، وأتحمل المسؤولية القانونية عن دقة بياناتي.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── زر التسجيل ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  child: _isLoading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _uploadingOrgDocs
                                  ? 'جاري رفع الوثائق...'
                                  : 'جاري إنشاء الحساب...',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white),
                            ),
                          ],
                        )
                      : const Text('إنشاء الحساب',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text(
                    'لديك حساب بالفعل؟ تسجيل الدخول',
                    style: TextStyle(color: AppColors.textLight, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── نموذج بيانات الملف المختار ─────────────────────────────────────────────────
class _PickedDoc {
  final Uint8List bytes;
  final String name;
  const _PickedDoc({required this.bytes, required this.name});
  bool get isImage =>
      name.toLowerCase().endsWith('.jpg') ||
      name.toLowerCase().endsWith('.jpeg') ||
      name.toLowerCase().endsWith('.png');
}

// ── منتقي ساعات العمل: بداية ونهاية عبر Material Time Picker فقط (بدون كتابة يدوية) ──
class _WorkingHoursPicker extends StatelessWidget {
  final TimeOfDay? start;
  final TimeOfDay? end;
  final String Function(TimeOfDay) formatTime;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _WorkingHoursPicker({
    required this.start,
    required this.end,
    required this.formatTime,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            readOnly: true,
            controller: TextEditingController(
                text: start != null ? formatTime(start!) : ''),
            decoration: const InputDecoration(
              labelText: 'بداية العمل *',
              prefixIcon: Icon(Icons.access_time_rounded),
            ),
            onTap: onPickStart,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            readOnly: true,
            controller: TextEditingController(
                text: end != null ? formatTime(end!) : ''),
            decoration: const InputDecoration(
              labelText: 'نهاية العمل *',
              prefixIcon: Icon(Icons.access_time_filled_rounded),
            ),
            onTap: onPickEnd,
          ),
        ),
      ],
    );
  }
}

// ── زر اختيار الملف (شعار أو وثيقة) ──────────────────────────────────────────
class _FilePickButton extends StatelessWidget {
  final String label;
  final _PickedDoc? file;
  final IconData icon;
  final VoidCallback onPick;
  final VoidCallback onClear;
  const _FilePickButton({
    required this.label,
    required this.file,
    required this.icon,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final picked = file != null;
    final showPreview = picked && file!.isImage;
    // ── Ink+InkWell بدلاً من GestureDetector لضمان تسجيل النقر ──
    // GestureDetector يتعارض مع SingleChildScrollView على بعض أجهزة Android.
    // InkWell (Material) يفوز دائماً على منافسة الإيماءات ويُظهر تموّج اللمس.
    return Ink(
      decoration: BoxDecoration(
        color: picked
            ? AppColors.success.withValues(alpha: 0.06)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: picked ? AppColors.success : AppColors.border,
          width: picked ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    picked ? Icons.check_circle_rounded : icon,
                    color: picked ? AppColors.success : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                picked ? AppColors.success : AppColors.textDark,
                          ),
                        ),
                        if (picked)
                          Text(
                            '✔ ${file!.name}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textLight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            'jpg  •  png — الكاميرا أو المعرض',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textLight),
                          ),
                      ],
                    ),
                  ),
                  if (picked)
                    // زر الحذف لا يحتاج InkWell — GestureDetector يكفي لأيقونة صغيرة
                    GestureDetector(
                      onTap: onClear,
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.textLight),
                    ),
                ],
              ),
            ),
            // معاينة الصورة للشعار
            if (showPreview)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
                child: Image.memory(
                  file!.bytes,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark));
  }
}
