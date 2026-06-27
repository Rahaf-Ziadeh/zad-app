import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'identity_verification_screen.dart';

class DonateTab extends StatefulWidget {
  const DonateTab({super.key});

  @override
  State<DonateTab> createState() => _DonateTabState();
}

class _DonateTabState extends State<DonateTab> {
  final _foodNameController = TextEditingController();
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

  // ← الجمعية المختارة
  String? _selectedCharityId;
  String? _selectedCharityName;

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
      // الأولوية لحقول spec الجديدة، ثم القيمة القديمة
      final idVerified =
          (data['identityVerificationStatus'] as String? ?? '') == 'approved';
      setState(() {
        _userNationalId = data['identityNumber'] as String? ?? nationalId.toString();
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
    _quantityController.dispose();
    _locationController.dispose();
    _notesController.dispose();
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

  // ── اختيار الجمعية ──
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
    if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً للتبرع'),
        ),
      );
      return;
    }
    if (_foodNameController.text.trim().isEmpty ||
        _quantityController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تعبئة جميع الحقول المطلوبة')),
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

    // ── التحقق من توثيق الهوية قبل قبول التبرع ──
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!mounted) return;
    final idStatus =
        (userSnap.data()?['identityVerificationStatus'] as String? ?? '');
    if (idStatus != 'approved') {
      if (idStatus == 'pending') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'طلب توثيق هويتك قيد المراجعة، يرجى الانتظار.'),
          ),
        );
        return;
      }
      // لم يتم التوثيق — فتح شاشة التوثيق
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const IdentityVerificationScreen()),
      );
      return; // المستخدم يعيد المحاولة بعد إرسال الطلب
    }

    setState(() => _isLoading = true);

    try {
      final userId = uid;

      await FirebaseFirestore.instance.collection('donations').add({
        'userId': userId,
        'userName': _userName ?? '',
        'nationalId': _userNationalId ?? '',
        'foodName': _foodNameController.text.trim(),
        'category': _selectedCategory,
        'quantity': _quantityController.text.trim(),
        'location': _locationController.text.trim(),
        'expiryDate': _expiryDate,
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'acceptedResponsibility': true,
        'responsibilityAcceptedAt': FieldValue.serverTimestamp(),
        // ← حفظ الجمعية المختارة
        'targetCharityId': _selectedCharityId ?? '',
        'targetCharityName': _selectedCharityName ?? '',
        'isDirectedToCharity': _selectedCharityId != null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _foodNameController.clear();
        _quantityController.clear();
        _locationController.clear();
        _notesController.clear();
        _expiryDate = null;
        _selectedCategory = 'وجبات';
        _acceptedResponsibility = false;
        _selectedCharityId = null;
        _selectedCharityName = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(_selectedCharityName != null
                  ? 'تم إرسال تبرعك إلى $_selectedCharityName ❤️'
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

  String _maskNationalId(String id) {
    if (id.length <= 4) return id;
    return '${'*' * (id.length - 4)}${id.substring(id.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasNationalId) {
      return _NoNationalIdView(onSaved: _loadUserData);
    }

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
            color: AppColors.success.withValues(alpha:0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.success.withValues(alpha:0.3)),
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
                  ? const Color(0xFFE11D48).withValues(alpha:0.06)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedCharityId != null
                    ? const Color(0xFFE11D48).withValues(alpha:0.4)
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
                        ? const Color(0xFFE11D48).withValues(alpha:0.12)
                        : AppColors.primary.withValues(alpha:0.08),
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
                _SectionLabel(label: 'اسم الطعام'),
                TextField(
                  controller: _foodNameController,
                  decoration: const InputDecoration(
                    hintText: 'مثال: أرز بالدجاج',
                    prefixIcon: Icon(Icons.fastfood_rounded),
                  ),
                ),

                const SizedBox(height: 14),
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
                              : AppColors.primary.withValues(alpha:0.07),
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
                _SectionLabel(label: 'الكمية'),
                TextField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    hintText: 'مثال: 3 وجبات',
                    prefixIcon: Icon(Icons.production_quantity_limits_rounded),
                  ),
                ),

                const SizedBox(height: 14),
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
                _SectionLabel(label: 'مكان الاستلام'),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    hintText: 'العنوان أو المنطقة',
                    prefixIcon: Icon(Icons.location_on_rounded),
                  ),
                ),

                const SizedBox(height: 14),
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
                          ? AppColors.danger.withValues(alpha:0.06)
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

        // ── تبرعاتي ──
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
                  color: AppColors.primary.withValues(alpha:0.05),
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
                final charityName = data['targetCharityName'] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withValues(alpha:0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          color: Color(0xFFE11D48), size: 20),
                    ),
                    title: Text(data['foodName'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${data['quantity']} • ${data['category']}',
                            style: const TextStyle(fontSize: 12)),
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
                    isThreeLine: charityName.isNotEmpty,
                    trailing: _StatusBadge(status: status),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
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
              // Handle
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

              // Title
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
                    color: AppColors.primary.withValues(alpha:0.07),
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

              // قائمة الجمعيات
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
                                color: AppColors.primary.withValues(alpha:0.3)),
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
                                  ? const Color(0xFFE11D48).withValues(alpha:0.07)
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
                                // أيقونة الجمعية
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFE11D48)
                                            .withValues(alpha:0.12)
                                        : AppColors.primary.withValues(alpha:0.08),
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
                                            Icon(Icons.location_on_outlined,
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
                                            Icon(Icons.phone_outlined,
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
                                // علامة الاختيار
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
                color: AppColors.secondary.withValues(alpha:0.12),
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
                color: AppColors.secondary.withValues(alpha:0.08),
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
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
