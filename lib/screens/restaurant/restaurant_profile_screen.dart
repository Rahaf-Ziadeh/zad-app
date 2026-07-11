import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zad_app/utils/phone_formatter.dart';

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
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  String? _updatedPhotoUrl;

  TimeOfDay? _workingHoursStart;
  TimeOfDay? _workingHoursEnd;
  TimeOfDay? _savedWorkingHoursStart;
  TimeOfDay? _savedWorkingHoursEnd;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _addressController = TextEditingController(text: widget.user.address);
    _updatedPhotoUrl = widget.user.photoUrl;
    _loadRestaurantAddress();
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

  // ── العنوان وساعات العمل أصبحا مخزّنين في مجموعة restaurants وليس users ──
  Future<void> _loadRestaurantAddress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(uid)
        .get();
    final data = doc.data();
    if (!mounted || data == null) return;

    final address = data['address'] as String?;
    if (address != null && address.isNotEmpty) {
      setState(() => _addressController.text = address);
    }

    final workingHours = data['workingHours'];
    if (workingHours is Map) {
      setState(() {
        _workingHoursStart = _parseTime(workingHours['start'] as String?);
        _workingHoursEnd = _parseTime(workingHours['end'] as String?);
        _savedWorkingHoursStart = _workingHoursStart;
        _savedWorkingHoursEnd = _workingHoursEnd;
      });
    }

    // ── users.photoUrl هو المصدر الأساسي، والرجوع إلى logoUrl عند غيابها ──
    if ((_updatedPhotoUrl == null || _updatedPhotoUrl!.isEmpty)) {
      final logoUrl = data['logoUrl'] as String?;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        setState(() => _updatedPhotoUrl = logoUrl);
      }
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

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاسم لا يمكن أن يكون فارغاً')),
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
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final name = _nameController.text.trim();
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'name': name,
          'fullName': name,
          'phone': _phoneController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      batch.set(
        FirebaseFirestore.instance.collection('restaurants').doc(uid),
        {
          'name': name,
          'restaurantName': name,
          'address': _addressController.text.trim(),
          'workingHours': {
            'start': _formatTimeOfDay(_workingHoursStart!),
            'end': _formatTimeOfDay(_workingHoursEnd!),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      _savedWorkingHoursStart = _workingHoursStart;
      _savedWorkingHoursEnd = _workingHoursEnd;
      setState(() => _isEditing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التغييرات'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _nameController.text = widget.user.name;
                  _phoneController.text = widget.user.phone;
                  _addressController.text = widget.user.address;
                  _workingHoursStart = _savedWorkingHoursStart;
                  _workingHoursEnd = _savedWorkingHoursEnd;
                });
              },
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

          const SizedBox(height: 24),

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
