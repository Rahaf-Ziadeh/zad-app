import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/services/cloudinary_service.dart';
import 'package:zad_app/services/notification_service.dart';
import 'package:zad_app/utils/phone_formatter.dart';
import 'package:zad_app/widgets/fullscreen_image_viewer.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_widgets.dart';

class RestaurantProfileScreen extends StatefulWidget {
  final AppUser user;
  const RestaurantProfileScreen({super.key, required this.user});

  @override
  State<RestaurantProfileScreen> createState() =>
      _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  late final TextEditingController _nameController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _licenseNumberController;
  String? _updatedPhotoUrl;

  TimeOfDay? _workingHoursStart;
  TimeOfDay? _workingHoursEnd;
  TimeOfDay? _savedWorkingHoursStart;
  TimeOfDay? _savedWorkingHoursEnd;

  // ── قيم آخر حفظ ناجح — تُستخدم لاستعادة الحقول كاملةً عند إلغاء التعديل ──
  String _savedOwnerName = '';
  String _savedDescription = '';
  String _savedLicenseNumber = '';

  // ── وثيقة الرخصة الحالية (بعد الرفع)، ووثيقة جديدة مُختارة لم تُرفَع بعد.
  // لا يُكتَب أي شيء في Firestore إلا بعد نجاح الرفع عند الحفظ، فيبقى الرابط
  // القديم سليماً تلقائياً في حال إلغاء التعديل أو فشل الرفع ──
  String _businessLicenseUrl = '';
  PlatformFile? _pickedLicenseFile;
  bool _uploadingLicense = false;

  // ── حالة التحقق الحالية للحساب — تُقرأ من users/{uid} (المصدر الوحيد
  // المستخدم في AuthService.login وشاشات الإدارة) ──
  String? _verificationStatus;
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _ownerNameController = TextEditingController();
    _phoneController = TextEditingController(text: widget.user.phone);
    _addressController = TextEditingController(text: widget.user.address);
    _descriptionController = TextEditingController();
    _licenseNumberController = TextEditingController();
    _updatedPhotoUrl = widget.user.photoUrl;
    _loadRestaurantDetails();
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── يجلب بيانات المطعم من restaurants/{uid} وحالة التحقق من users/{uid}؛
  // الحقول المستخدمة هي بالضبط نفس أسماء الحقول التي يكتبها AuthService عند
  // التسجيل (ownerName, licenseNumber, businessLicenseUrl, description) حتى
  // لا يتكرر نفس الحقل باسمين مختلفين ──
  Future<void> _loadRestaurantDetails() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final results = await Future.wait([
      FirebaseFirestore.instance.collection('restaurants').doc(uid).get(),
      FirebaseFirestore.instance.collection('users').doc(uid).get(),
    ]);
    if (!mounted) return;

    final data = results[0].data();
    if (data != null) {
      final address = (data['address'] as String? ?? '').trim();
      final ownerName = (data['ownerName'] as String? ?? '').trim();
      final description = (data['description'] as String? ?? '').trim();
      final licenseNumber = (data['licenseNumber'] as String? ?? '').trim();
      final businessLicenseUrl =
          (data['businessLicenseUrl'] as String? ?? '').trim();

      TimeOfDay? start;
      TimeOfDay? end;
      final workingHours = data['workingHours'];
      if (workingHours is Map) {
        start = _parseTime(workingHours['start'] as String?);
        end = _parseTime(workingHours['end'] as String?);
      }

      setState(() {
        if (address.isNotEmpty) _addressController.text = address;
        _ownerNameController.text = ownerName;
        _descriptionController.text = description;
        _licenseNumberController.text = licenseNumber;
        _businessLicenseUrl = businessLicenseUrl;
        _savedOwnerName = ownerName;
        _savedDescription = description;
        _savedLicenseNumber = licenseNumber;
        if (start != null) _workingHoursStart = start;
        if (end != null) _workingHoursEnd = end;
        _savedWorkingHoursStart = _workingHoursStart;
        _savedWorkingHoursEnd = _workingHoursEnd;
      });

      // ── users.photoUrl هو المصدر الأساسي، والرجوع إلى logoUrl عند غيابها ──
      if (_updatedPhotoUrl == null || _updatedPhotoUrl!.isEmpty) {
        final logoUrl = data['logoUrl'] as String?;
        if (logoUrl != null && logoUrl.isNotEmpty) {
          setState(() => _updatedPhotoUrl = logoUrl);
        }
      }
    }

    final userData = results[1].data();
    if (userData != null) {
      setState(() {
        _verificationStatus = userData['verificationStatus'] as String?;
        final reason = (userData['rejectionReason'] as String? ?? '').trim();
        _rejectionReason = reason.isEmpty ? null : reason;
      });
    }
  }

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

  Future<void> _pickLicenseDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() => _pickedLicenseFile = file);
  }

  void _openLicenseDocument(String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد وثيقة رخصة مرفوعة بعد')),
      );
      return;
    }
    if (url.toLowerCase().contains('.pdf')) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('وثيقة PDF'),
          content: const Text(
            'معاينة ملفات PDF داخل التطبيق غير مدعومة حالياً.',
            style: TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }
    openFullScreenImage(context, url, title: 'وثيقة الرخصة');
  }

  Future<bool> _isLicenseNumberTaken(String licenseNumber, String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('restaurants')
        .where('licenseNumber', isEqualTo: licenseNumber)
        .limit(2)
        .get();
    return snap.docs.any((d) => d.id != uid);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاسم لا يمكن أن يكون فارغاً')),
      );
      return;
    }
    if (_ownerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم المالك لا يمكن أن يكون فارغاً')),
      );
      return;
    }
    final licenseNumber = _licenseNumberController.text.trim();
    if (licenseNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم الرخصة التجارية لا يمكن أن يكون فارغاً')),
      );
      return;
    }
    if (_workingHoursStart == null || _workingHoursEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد وقت بداية ونهاية العمل')),
      );
      return;
    }
    final startMinutes =
        _workingHoursStart!.hour * 60 + _workingHoursStart!.minute;
    final endMinutes = _workingHoursEnd!.hour * 60 + _workingHoursEnd!.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('وقت نهاية العمل يجب أن يكون بعد وقت البداية')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    setState(() => _isSaving = true);
    try {
      // ── تفرّد رقم الرخصة: فقط عند تغييره فعلياً، مستثنياً مستند هذا
      // المطعم نفسه من فحص التكرار ──
      final licenseNumberChanged = licenseNumber != _savedLicenseNumber;
      if (licenseNumberChanged) {
        final taken = await _isLicenseNumberTaken(licenseNumber, uid);
        if (!mounted) return;
        if (taken) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('رقم الرخصة مستخدم من قبل مطعم آخر.')),
          );
          setState(() => _isSaving = false);
          return;
        }
      }

      // ── رفع وثيقة الرخصة الجديدة (إن وُجدت) قبل أي كتابة على Firestore؛
      // فشل الرفع يوقف الحفظ بالكامل فيبقى الرابط القديم كما هو دون أي تغيير ──
      String newBusinessLicenseUrl = _businessLicenseUrl;
      if (_pickedLicenseFile != null) {
        setState(() => _uploadingLicense = true);
        final uploadedUrl = await CloudinaryService().uploadBytes(
          bytes: _pickedLicenseFile!.bytes!,
          filename: _pickedLicenseFile!.name,
        );
        if (!mounted) return;
        setState(() => _uploadingLicense = false);
        if (uploadedUrl == null || uploadedUrl.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل رفع وثيقة الرخصة، يرجى المحاولة مرة أخرى.'),
              backgroundColor: AppColors.danger,
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
        newBusinessLicenseUrl = uploadedUrl;
      }

      final licenseDataChanged = licenseNumberChanged ||
          newBusinessLicenseUrl != _businessLicenseUrl;

      final name = _nameController.text.trim();
      final ownerName = _ownerNameController.text.trim();
      final description = _descriptionController.text.trim();

      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'name': name,
          'fullName': name,
          'phone': _phoneController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
          // ── تعديل بيانات الرخصة يُعيد الحساب لقائمة المراجعة الإدارية؛
          // isApproved يبقى دون تغيير عمداً — هو ما يسمح بدخول محدود أثناء
          // إعادة المراجعة (راجع AuthService.login وmain.dart) ──
          if (licenseDataChanged) ...{
            'verificationStatus': 'pending',
            'rejectionReason': null,
            'wasEverApproved': true,
          },
        },
      );
      batch.set(
        FirebaseFirestore.instance.collection('restaurants').doc(uid),
        {
          'name': name,
          'restaurantName': name,
          'ownerName': ownerName,
          'description': description,
          'address': _addressController.text.trim(),
          'licenseNumber': licenseNumber,
          'businessLicenseUrl': newBusinessLicenseUrl,
          'workingHours': {
            'start': _formatTimeOfDay(_workingHoursStart!),
            'end': _formatTimeOfDay(_workingHoursEnd!),
          },
          'updatedAt': FieldValue.serverTimestamp(),
          if (licenseDataChanged) ...{
            'verificationStatus': 'pending',
            'rejectionReason': null,
          },
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      // ── إشعار الإدارة بطلب إعادة مراجعة، بنفس نمط التسجيل الأول ──
      if (licenseDataChanged) {
        try {
          await NotificationService().notifyAdmins(
            title: 'طلب إعادة مراجعة رخصة مطعم',
            message: 'قام مطعم "$name" بتحديث بيانات رخصته ويحتاج مراجعة.',
            type: 'account',
          );
        } catch (_) {}
      }

      _savedWorkingHoursStart = _workingHoursStart;
      _savedWorkingHoursEnd = _workingHoursEnd;
      _savedOwnerName = ownerName;
      _savedDescription = description;
      _savedLicenseNumber = licenseNumber;
      _businessLicenseUrl = newBusinessLicenseUrl;
      _pickedLicenseFile = null;
      if (licenseDataChanged) {
        _verificationStatus = 'pending';
        _rejectionReason = null;
      }
      setState(() => _isEditing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(licenseDataChanged
              ? 'تم تحديث بيانات الرخصة وسيعاد إرسال الحساب للمراجعة.'
              : 'تم حفظ التغييرات'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadingLicense = false;
        });
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _nameController.text = widget.user.name;
      _phoneController.text = widget.user.phone;
      _addressController.text = widget.user.address;
      _ownerNameController.text = _savedOwnerName;
      _descriptionController.text = _savedDescription;
      _licenseNumberController.text = _savedLicenseNumber;
      _workingHoursStart = _savedWorkingHoursStart;
      _workingHoursEnd = _savedWorkingHoursEnd;
      _pickedLicenseFile = null;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      // ── نستخدم سياق النافذة الخاص بها (dialogContext) لإغلاقها، وليس سياق
      // الشاشة الخارجية: الشاشة متداخلة ضمن Navigator خاص بتبويب "حسابي"،
      // بينما showDialog يفتح النافذة على الـ Navigator الجذري افتراضياً —
      // استخدام السياق الخاطئ يحاول إغلاق الـ Navigator الداخلي بدل النافذة ──
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    // ── نلتقط الـ Navigator الجذري صراحةً قبل await تسجيل الخروج: تغيّر حالة
    // المصادقة قد يُعيد بناء الشجرة فوق هذه الشاشة بمجرد اكتمال signOut،
    // فنفقد إمكانية استخدام context بأمان بعد ذلك ──
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    await FirebaseAuth.instance.signOut();

    rootNavigator.pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حساب المطعم'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_isEditing)
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('تعديل'),
            )
          else ...[
            TextButton(
              onPressed: _isSaving ? null : _cancelEdit,
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.textLight)),
            ),
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ',
                      style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // ── الصورة والاسم ──
          Center(
            child: Column(
              children: [
                ProfileAvatar(
                  name: widget.user.name,
                  photoUrl: _updatedPhotoUrl,
                  color: AppColors.primary,
                  role: 'restaurant',
                  onPhotoUpdated: (url) =>
                      setState(() => _updatedPhotoUrl = url),
                ),
                const SizedBox(height: 12),
                Text(widget.user.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('مطعم',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_verificationStatus case final vs?
              when vs != 'approved')
            _VerificationStatusBanner(
              status: vs,
              rejectionReason: _rejectionReason,
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
                children: [
                  _EditableField(
                      icon: Icons.storefront_outlined,
                      label: 'اسم المطعم',
                      controller: _nameController,
                      isEditing: _isEditing),
                  const Divider(),
                  _EditableField(
                      icon: Icons.badge_outlined,
                      label: 'اسم المالك',
                      controller: _ownerNameController,
                      isEditing: _isEditing),
                  const Divider(),
                  _EditableField(
                      icon: Icons.email_outlined,
                      label: 'البريد الإلكتروني',
                      controller:
                          TextEditingController(text: widget.user.email),
                      isEditing: false,
                      readOnly: true),
                  const Divider(),
                  _EditableField(
                      icon: Icons.phone_outlined,
                      label: 'رقم الهاتف',
                      controller: _phoneController,
                      isEditing: _isEditing,
                      keyboardType: TextInputType.phone,
                      isPhone: true),
                  const Divider(),
                  _EditableField(
                      icon: Icons.location_on_outlined,
                      label: 'عنوان المطعم',
                      controller: _addressController,
                      isEditing: _isEditing),
                  const Divider(),
                  _EditableField(
                      icon: Icons.description_outlined,
                      label: 'وصف المطعم',
                      controller: _descriptionController,
                      isEditing: _isEditing),
                  const Divider(),
                  _WorkingHoursField(
                    start: _workingHoursStart,
                    end: _workingHoursEnd,
                    isEditing: _isEditing,
                    onPickStart: () => _pickWorkingHours(isStart: true),
                    onPickEnd: () => _pickWorkingHours(isStart: false),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── بيانات الرخصة التجارية — حسّاسة ولا تظهر في الملف العام ──
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
                  const Text('بيانات الرخصة التجارية',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  _EditableField(
                      icon: Icons.numbers_rounded,
                      label: 'رقم الرخصة التجارية',
                      controller: _licenseNumberController,
                      isEditing: _isEditing),
                  const Divider(),
                  _LicenseDocumentRow(
                    currentUrl: _businessLicenseUrl,
                    pickedFile: _pickedLicenseFile,
                    isEditing: _isEditing,
                    uploading: _uploadingLicense,
                    onView: () => _openLicenseDocument(_businessLicenseUrl),
                    onPick: _pickLicenseDocument,
                    onClearPick: () =>
                        setState(() => _pickedLicenseFile = null),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── تغيير كلمة المرور ──
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Column(
              children: [ChangePasswordTile()],
            ),
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            label: const Text('تسجيل الخروج',
                style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// شريط حالة التحقق — يظهر فقط عند عدم الاعتماد (قيد المراجعة أو مرفوض)
// ─────────────────────────────────────────────
class _VerificationStatusBanner extends StatelessWidget {
  final String status; // 'pending' | 'rejected'
  final String? rejectionReason;

  const _VerificationStatusBanner({
    required this.status,
    required this.rejectionReason,
  });

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    final color = isRejected ? AppColors.danger : Colors.orange;
    final title = isRejected
        ? 'تم رفض طلب التحقق'
        : 'حسابك قيد إعادة المراجعة';
    final message = isRejected
        ? (rejectionReason?.isNotEmpty == true
            ? 'السبب: $rejectionReason\nيمكنك تعديل بيانات الرخصة وإعادة الإرسال للمراجعة.'
            : 'يمكنك تعديل بيانات الرخصة وإعادة الإرسال للمراجعة.')
        : 'يمكنك إكمال حجوزاتك الحالية، لكن لا يمكنك نشر عروض جديدة أو '
            'إعادة تفعيل عروض مغلقة/منتهية حتى تتم الموافقة.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(message,
                    style: const TextStyle(
                        color: AppColors.textDark, fontSize: 12, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final bool readOnly;
  final TextInputType? keyboardType;
  final bool isPhone;

  const _EditableField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.isEditing,
    this.readOnly = false,
    this.keyboardType,
    this.isPhone = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
        fontSize: 14,
        color: readOnly ? AppColors.textLight : AppColors.textDark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                isEditing && !readOnly
                    ? TextField(
                        controller: controller,
                        keyboardType: keyboardType,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textDark),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                          border: UnderlineInputBorder(),
                        ),
                      )
                    : controller.text.isEmpty
                        ? Text('—', style: valueStyle)
                        : isPhone
                            ? PhoneText(controller.text, style: valueStyle)
                            : Text(controller.text, style: valueStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── حقل ساعات العمل: عرض نصي، وأثناء التعديل منتقيان لوقت البداية والنهاية فقط ──
class _WorkingHoursField extends StatelessWidget {
  final TimeOfDay? start;
  final TimeOfDay? end;
  final bool isEditing;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _WorkingHoursField({
    required this.start,
    required this.end,
    required this.isEditing,
    required this.onPickStart,
    required this.onPickEnd,
  });

  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.access_time_rounded,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ساعات العمل',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                if (!isEditing)
                  Text(
                    (start != null && end != null)
                        ? '${_format(start!)} - ${_format(end!)}'
                        : '—',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textDark),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onPickStart,
                          child:
                              Text(start != null ? _format(start!) : 'البداية'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onPickEnd,
                          child: Text(end != null ? _format(end!) : 'النهاية'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// صف وثيقة الرخصة — عرض الوثيقة الحالية (قابلة للنقر)، وأثناء التعديل زر
// استبدال + معاينة الملف المُختار حديثاً قبل رفعه ──
// ─────────────────────────────────────────────
class _LicenseDocumentRow extends StatelessWidget {
  final String currentUrl;
  final PlatformFile? pickedFile;
  final bool isEditing;
  final bool uploading;
  final VoidCallback onView;
  final VoidCallback onPick;
  final VoidCallback onClearPick;

  const _LicenseDocumentRow({
    required this.currentUrl,
    required this.pickedFile,
    required this.isEditing,
    required this.uploading,
    required this.onView,
    required this.onPick,
    required this.onClearPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onView,
            child: Row(
              children: [
                const Icon(Icons.folder_shared_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('عرض وثيقة الرخصة',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        currentUrl.isEmpty ? 'لا توجد وثيقة مرفوعة' : 'عرض المستند',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded,
                    size: 18, color: AppColors.textLight),
              ],
            ),
          ),
          if (isEditing) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: uploading ? null : onPick,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(currentUrl.isEmpty
                  ? 'رفع وثيقة الرخصة'
                  : 'استبدال وثيقة الرخصة'),
            ),
            if (pickedFile != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      pickedFile!.name.toLowerCase().endsWith('.pdf')
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(pickedFile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textDark)),
                    ),
                    if (!uploading)
                      GestureDetector(
                        onTap: onClearPick,
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.textLight),
                      ),
                  ],
                ),
              ),
            ],
            if (uploading) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('جاري رفع الوثيقة...',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
