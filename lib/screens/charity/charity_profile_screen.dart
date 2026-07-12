import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/charity_data_service.dart';
import '../../services/charity_helper_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/charity_widgets.dart';
import '../../widgets/profile_widgets.dart';

class CharityProfileScreen extends StatefulWidget {
  final AppUser user;
  final ValueChanged<AppUser>? onUserUpdated;

  const CharityProfileScreen({
    super.key,
    required this.user,
    this.onUserUpdated,
  });

  @override
  State<CharityProfileScreen> createState() => _CharityProfileScreenState();
}

class _CharityProfileScreenState extends State<CharityProfileScreen> {
  final CharityDataService _dataService = CharityDataService();

  final CharityHelperService _helperService = const CharityHelperService();

  bool _isEditing = false;
  bool _isSaving = false;
  String? _updatedPhotoUrl;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

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

    _loadCharityProfile();
  }

  Future<void> _loadCharityProfile() async {
    final data = await _dataService.loadCharityProfile();

    if (!mounted || data == null) return;

    final address = data['address'] as String?;

    if (address != null && address.isNotEmpty) {
      setState(() {
        _addressController.text = address;
      });
    }

    final workingHours = data['workingHours'];

    if (workingHours is Map) {
      setState(() {
        _workingHoursStart = _helperService.parseTime(
          workingHours['start'] as String?,
        );

        _workingHoursEnd = _helperService.parseTime(
          workingHours['end'] as String?,
        );

        _savedWorkingHoursStart = _workingHoursStart;

        _savedWorkingHoursEnd = _workingHoursEnd;
      });
    }

    if (_updatedPhotoUrl == null || _updatedPhotoUrl!.isEmpty) {
      final logoUrl = data['logoUrl'] as String?;

      if (logoUrl != null && logoUrl.isNotEmpty) {
        setState(() {
          _updatedPhotoUrl = logoUrl;
        });
      }
    }
  }

  Future<void> _pickWorkingHours({
    required bool isStart,
  }) async {
    final initial =
        (isStart ? _workingHoursStart : _workingHoursEnd) ?? TimeOfDay.now();

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

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
        const SnackBar(
          content: Text(
            'الاسم لا يمكن أن يكون فارغاً',
          ),
        ),
      );

      return;
    }

    if (_workingHoursStart == null || _workingHoursEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى تحديد وقت بداية ونهاية العمل',
          ),
        ),
      );

      return;
    }

    final startMinutes =
        _workingHoursStart!.hour * 60 + _workingHoursStart!.minute;

    final endMinutes = _workingHoursEnd!.hour * 60 + _workingHoursEnd!.minute;

    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'وقت نهاية العمل يجب أن يكون بعد وقت البداية',
          ),
        ),
      );

      return;
    }

    setState(() => _isSaving = true);

    try {
      final newName = _nameController.text.trim();

      final newPhone = _phoneController.text.trim();

      final newAddress = _addressController.text.trim();

      await _dataService.saveCharityProfile(
        name: newName,
        phone: newPhone,
        address: newAddress,
        workingHoursStart: _helperService.formatTimeOfDay(
          _workingHoursStart!,
        ),
        workingHoursEnd: _helperService.formatTimeOfDay(
          _workingHoursEnd!,
        ),
      );

      _savedWorkingHoursStart = _workingHoursStart;

      _savedWorkingHoursEnd = _workingHoursEnd;

      widget.onUserUpdated?.call(
        widget.user.copyWith(
          name: newName,
          phone: newPhone,
          address: newAddress,
        ),
      );

      setState(() => _isEditing = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ التغييرات ✅',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;

      _nameController.text = widget.user.name;

      _phoneController.text = widget.user.phone;

      _addressController.text = widget.user.address;

      _workingHoursStart = _savedWorkingHoursStart;

      _workingHoursEnd = _savedWorkingHoursEnd;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text(
          'هل أنت متأكد من تسجيل الخروج؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              false,
            ),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(
              dialogContext,
              true,
            ),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final rootNavigator = Navigator.of(
      context,
      rootNavigator: true,
    );

    await _dataService.logout();

    rootNavigator.pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حساب الجمعية'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_isEditing)
            TextButton.icon(
              onPressed: () {
                setState(
                  () => _isEditing = true,
                );
              },
              icon: const Icon(
                Icons.edit_rounded,
                size: 18,
              ),
              label: const Text('تعديل'),
            )
          else ...[
            TextButton(
              onPressed: _cancelEdit,
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  color: AppColors.textLight,
                ),
              ),
            ),
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'حفظ',
                      style: TextStyle(
                        color: AppColors.primary,
                      ),
                    ),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
            child: Column(
              children: [
                ProfileAvatar(
                  name: widget.user.name,
                  photoUrl: _updatedPhotoUrl,
                  color: const Color(
                    0xFFE11D48,
                  ),
                  role: 'charity',
                  onPhotoUpdated: (url) {
                    setState(() {
                      _updatedPhotoUrl = url;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  _isEditing ? _nameController.text : widget.user.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFE11D48,
                    ).withValues(
                      alpha: 0.10,
                    ),
                    borderRadius: BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: const Text(
                    'جمعية خيرية',
                    style: TextStyle(
                      color: Color(0xFFE11D48),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(
                color: AppColors.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'معلومات الجمعية',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  EditableField(
                    icon: Icons.volunteer_activism_outlined,
                    label: 'اسم الجمعية',
                    controller: _nameController,
                    isEditing: _isEditing,
                  ),
                  const Divider(),
                  EditableField(
                    icon: Icons.email_outlined,
                    label: 'البريد الإلكتروني',
                    controller: TextEditingController(
                      text: widget.user.email,
                    ),
                    isEditing: false,
                    readOnly: true,
                  ),
                  const Divider(),
                  EditableField(
                    icon: Icons.phone_outlined,
                    label: 'رقم الهاتف',
                    controller: _phoneController,
                    isEditing: _isEditing,
                    keyboardType: TextInputType.phone,
                    isPhone: true,
                  ),
                  const Divider(),
                  EditableField(
                    icon: Icons.location_on_outlined,
                    label: 'العنوان',
                    controller: _addressController,
                    isEditing: _isEditing,
                  ),
                  const Divider(),
                  WorkingHoursField(
                    start: _workingHoursStart,
                    end: _workingHoursEnd,
                    isEditing: _isEditing,
                    onPickStart: () => _pickWorkingHours(
                      isStart: true,
                    ),
                    onPickEnd: () => _pickWorkingHours(
                      isStart: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(
                color: AppColors.border,
              ),
            ),
            child: const Column(
              children: [
                ChangePasswordTile(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.danger,
            ),
            label: const Text(
              'تسجيل الخروج',
              style: TextStyle(
                color: AppColors.danger,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                color: AppColors.danger,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
