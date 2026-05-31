import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../auth/WelcomeScreen.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_widgets.dart';

class AdminProfileScreen extends StatefulWidget {
  final AppUser user;

  const AdminProfileScreen({super.key, required this.user});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  String? _updatedPhotoUrl;
  bool _isEditing = false;
  bool _isSaving = false;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _addressController = TextEditingController(text: widget.user.address);
    _updatedPhotoUrl = widget.user.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاسم لا يمكن أن يكون فارغاً')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _nameController.text.trim(),
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isEditing = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التغييرات بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _nameController.text = widget.user.name;
      _phoneController.text = widget.user.phone;
      _addressController.text = widget.user.address;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حساب المدير'),
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
              onPressed: _cancelEdit,
              child: const Text(
                'إلغاء',
                style: TextStyle(color: AppColors.textLight),
              ),
            ),
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'حفظ',
                      style: TextStyle(color: AppColors.primary),
                    ),
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
                  name: user.name,
                  photoUrl: _updatedPhotoUrl,
                  color: AppColors.primary,
                  onPhotoUpdated: (url) =>
                      setState(() => _updatedPhotoUrl = url),
                ),
                const SizedBox(height: 12),
                Text(user.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('مدير النظام',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── معلومات ──
          _ProfileField(
            icon: Icons.person_outline_rounded,
            label: 'الاسم الكامل',
            controller: _nameController,
            isEditing: _isEditing,
          ),
          const Divider(),
          _ProfileField(
            icon: Icons.email_outlined,
            label: 'البريد الإلكتروني',
            controller: TextEditingController(text: user.email),
            isEditing: false,
            readOnly: true,
          ),
          const Divider(),
          _ProfileField(
            icon: Icons.phone_outlined,
            label: 'الهاتف',
            controller: _phoneController,
            isEditing: _isEditing,
            keyboardType: TextInputType.phone,
          ),
          const Divider(),
          _ProfileField(
            icon: Icons.location_on_outlined,
            label: 'العنوان',
            controller: _addressController,
            isEditing: _isEditing,
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

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool isEditing;
  final bool readOnly;
  final TextInputType? keyboardType;

  const _ProfileField({
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
