import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_widgets.dart';
import 'national_id_step_screen.dart';
import 'user_extra_screens.dart';
import 'user_publish_offer_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final AppUser user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  String? _updatedPhotoUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _addressController = TextEditingController(text: widget.user.address);
    _updatedPhotoUrl = widget.user.photoUrl;
    _loadIndividualAddress();
  }

  // ── العنوان أصبح مخزّناً في مجموعة individuals وليس users ──
  Future<void> _loadIndividualAddress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('individuals')
        .doc(uid)
        .get();
    final address = doc.data()?['address'] as String?;
    if (!mounted || address == null || address.isEmpty) return;
    setState(() => _addressController.text = address);
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
        FirebaseFirestore.instance.collection('individuals').doc(uid),
        {
          'name': name,
          'address': _addressController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      setState(() => _isEditing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('تم حفظ التغييرات بنجاح'),
          ]),
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
      // ── نستخدم سياق النافذة الخاص بها (dialogContext) لإغلاقها، وليس سياق
      // الشاشة الخارجية، تفادياً لأي التباس مع Navigator غير الجذري ──
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

  String _roleLabel(String role) {
    switch (role) {
      case 'restaurant':
        return 'مطعم';
      case 'charity':
        return 'جمعية خيرية';
      case 'individual':
        return 'مستخدم';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isGuest = user.role == 'guest' ||
        (FirebaseAuth.instance.currentUser?.isAnonymous ?? false);

    if (isGuest) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('حسابي'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha:0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 58,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'أنت تتصفح كزائر',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'سجّل الدخول أو أنشئ حساباً للوصول إلى الطلبات، التبرعات، الشكاوى، وتعديل الملف الشخصي.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textLight,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('تسجيل الدخول'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('إنهاء التصفح كزائر'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }


    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حسابي'),
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
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.textLight)),
            ),
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
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
                  name: user.name,
                  photoUrl: _updatedPhotoUrl,
                  color: AppColors.primary,
                  onPhotoUpdated: (url) =>
                      setState(() => _updatedPhotoUrl = url),
                ),
                const SizedBox(height: 12),
                Text(user.name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha:0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_roleLabel(user.role),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── معلومات الحساب ──
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
                  const Text('معلومات الحساب',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  const SizedBox(height: 14),
                  ProfileFieldWidget(
                      icon: Icons.person_outline_rounded,
                      label: 'الاسم الكامل',
                      controller: _nameController,
                      isEditing: _isEditing),
                  const Divider(),
                  ProfileFieldWidget(
                      icon: Icons.email_outlined,
                      label: 'البريد الإلكتروني',
                      controller: TextEditingController(text: user.email),
                      isEditing: false,
                      readOnly: true),
                  const Divider(),
                  ProfileFieldWidget(
                      icon: Icons.phone_outlined,
                      label: 'رقم الهاتف',
                      controller: _phoneController,
                      isEditing: _isEditing,
                      keyboardType: TextInputType.phone,
                      isPhone: true),
                  const Divider(),
                  ProfileFieldWidget(
                      icon: Icons.location_on_outlined,
                      label: 'العنوان',
                      controller: _addressController,
                      isEditing: _isEditing),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── إجراءات إضافية ──
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Column(
              children: [
                MenuTileWidget(
                  icon: Icons.add_box_rounded,
                  title: 'نشر عرض طعام',
                  color: AppColors.primary,
                  onTap: () async {
                    // ── يفتح مباشرة شاشة نشر الطعام للكل، دون المرور بصفحة
                    // الدخول المحايدة، بعد التحقق من توثيق الهوية ──
                    final identityReady = await ensureNationalIdSaved(context);
                    if (!context.mounted || !identityReady) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserPublishOfferScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                MenuTileWidget(
                    icon: Icons.history_rounded,
                    title: 'سجل التبرعات',
                    color: const Color(0xFFE11D48),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const UserDonationsHistoryScreen()))),
                const Divider(height: 1, indent: 56),
                MenuTileWidget(
                    icon: Icons.star_outline_rounded,
                    title: 'تقييماتي',
                    color: Colors.amber,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const UserRatingsScreen()))),
                const Divider(height: 1, indent: 56),
                MenuTileWidget(
                    icon: Icons.report_problem_outlined,
                    title: 'شكاواي',
                    color: AppColors.secondary,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const UserComplaintsScreen()))),
                const Divider(height: 1, indent: 56),
                const ChangePasswordTile(),
              ],
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
