import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────
// ProfileAvatar — صورة قابلة للتغيير
// ─────────────────────────────────────────────
class ProfileAvatar extends StatefulWidget {
  final String name;
  final String? photoUrl;
  final Color color;
  final double radius;
  final String? role; // ← restaurant/charity: يُزامن الصورة مع logoUrl أيضاً
  final ValueChanged<String>? onPhotoUpdated; // يرجع الـ URL الجديد

  const ProfileAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.color = AppColors.primary,
    this.radius = 52,
    this.role,
    this.onPhotoUpdated,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _uploading = false;
  String? _localPhotoUrl; // الـ URL بعد الرفع

  String get _effectiveUrl => _localPhotoUrl ?? widget.photoUrl ?? '';

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();

    // اختيار المصدر
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
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
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
              ),
              title: const Text('الكاميرا'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: Color(0xFF7C3AED)),
              ),
              title: const Text('معرض الصور'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (picked == null) return;

    setState(() => _uploading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final file = File(picked.path);

      // رفع الصورة لـ Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // حفظ الـ URL في Firestore: users.photoUrl دائماً، ومرآة logoUrl لدور المطعم/الجمعية
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {'photoUrl': url},
      );
      final String? roleCollection = widget.role == 'restaurant'
          ? 'restaurants'
          : widget.role == 'charity'
              ? 'charities'
              : null;
      if (roleCollection != null) {
        batch.set(
          FirebaseFirestore.instance.collection(roleCollection).doc(uid),
          {
            'logoUrl': url,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();

      setState(() => _localPhotoUrl = url);
      widget.onPhotoUpdated?.call(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الصورة بنجاح ✅'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في رفع الصورة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── الصورة ──
        CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.color.withOpacity(0.15),
          backgroundImage:
              _effectiveUrl.isNotEmpty ? NetworkImage(_effectiveUrl) : null,
          child: _uploading
              ? CircularProgressIndicator(color: widget.color, strokeWidth: 2)
              : _effectiveUrl.isEmpty
                  ? Text(
                      widget.name.isNotEmpty
                          ? widget.name[0].toUpperCase()
                          : '؟',
                      style: TextStyle(
                        fontSize: widget.radius * 0.65,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    )
                  : null,
        ),

        // ── زر الكاميرا ──
        Positioned(
          bottom: 0,
          left: 0,
          child: GestureDetector(
            onTap: _uploading ? null : _pickAndUpload,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _uploading ? AppColors.textLight : widget.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _uploading
                    ? Icons.hourglass_top_rounded
                    : Icons.camera_alt_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ChangePasswordTile — سطر تغيير كلمة المرور
// ─────────────────────────────────────────────
class ChangePasswordTile extends StatelessWidget {
  const ChangePasswordTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => const _ChangePasswordSheet(),
      ),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.lock_outline_rounded,
            color: AppColors.secondary, size: 18),
      ),
      title: const Text('تغيير كلمة المرور',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: AppColors.textLight),
    );
  }
}

// ─────────────────────────────────────────────
// BottomSheet تغيير كلمة المرور
// ─────────────────────────────────────────────
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isLoading = false;

  double _strength = 0;
  String _strengthLabel = '';
  Color _strengthColor = AppColors.danger;

  @override
  void initState() {
    super.initState();
    _newController.addListener(_updateStrength);
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _updateStrength() {
    final p = _newController.text;
    double s = 0;
    if (p.length >= 6) s += 0.2;
    if (p.length >= 10) s += 0.2;
    if (p.contains(RegExp(r'[A-Z]'))) s += 0.2;
    if (p.contains(RegExp(r'[0-9]'))) s += 0.2;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) s += 0.2;

    String label;
    Color color;
    if (s <= 0.2) {
      label = 'ضعيفة جداً';
      color = AppColors.danger;
    } else if (s <= 0.4) {
      label = 'ضعيفة';
      color = Colors.orange;
    } else if (s <= 0.6) {
      label = 'متوسطة';
      color = AppColors.secondary;
    } else if (s <= 0.8) {
      label = 'جيدة';
      color = AppColors.primary;
    } else {
      label = 'قوية جداً ✓';
      color = AppColors.success;
    }

    setState(() {
      _strength = s;
      _strengthLabel = p.isEmpty ? '' : label;
      _strengthColor = color;
    });
  }

  Future<void> _changePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = user.email!;

      // إعادة المصادقة بالباسورد الحالي
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _currentController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newController.text.trim());

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تغيير كلمة المرور بنجاح ✅'),
          backgroundColor: AppColors.success,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'كلمة المرور الحالية غير صحيحة';
          break;
        case 'weak-password':
          msg = 'كلمة المرور الجديدة ضعيفة جداً';
          break;
        case 'requires-recent-login':
          msg = 'يرجى تسجيل الخروج والدخول مجدداً ثم المحاولة';
          break;
        default:
          msg = 'حدث خطأ: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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

              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: AppColors.secondary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('تغيير كلمة المرور',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                ],
              ),

              const SizedBox(height: 20),

              // كلمة المرور الحالية
              TextFormField(
                controller: _currentController,
                obscureText: !_showCurrent,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'أدخل كلمة المرور الحالية'
                    : null,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_showCurrent
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _showCurrent = !_showCurrent),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // كلمة المرور الجديدة
              TextFormField(
                controller: _newController,
                obscureText: !_showNew,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'أدخل كلمة المرور الجديدة';
                  }
                  if (v.length < 6) {
                    return 'يجب أن تكون 6 أحرف على الأقل';
                  }
                  if (v == _currentController.text) {
                    return 'كلمة المرور الجديدة مطابقة للحالية';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_showNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _showNew = !_showNew),
                  ),
                ),
              ),

              // مؤشر القوة
              if (_strengthLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _strength,
                    minHeight: 5,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('قوة كلمة المرور',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textLight)),
                    Text(_strengthLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _strengthColor)),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              // تأكيد كلمة المرور
              TextFormField(
                controller: _confirmController,
                obscureText: !_showConfirm,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'أعد إدخال كلمة المرور الجديدة';
                  }
                  if (v != _newController.text) {
                    return 'كلمتا المرور غير متطابقتين';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور الجديدة',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _changePassword,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_rounded),
                  label: Text(
                      _isLoading ? 'جاري التغيير...' : 'تغيير كلمة المرور'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileFieldWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final bool readOnly;
  final TextInputType? keyboardType;

  const ProfileFieldWidget({
    required this.icon,
    required this.label,
    required this.controller,
    required this.isEditing,
    this.readOnly = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    : Text(controller.text.isEmpty ? '—' : controller.text,
                        style: TextStyle(
                            fontSize: 14,
                            color: readOnly
                                ? AppColors.textLight
                                : AppColors.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MenuTileWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const MenuTileWidget({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: AppColors.textLight),
    );
  }
}
