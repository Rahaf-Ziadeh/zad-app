import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

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
  bool _acceptedResponsibility = false; // ← إقرار المسؤولية

  // بيانات المستخدم من Firestore
  String? _userNationalId;
  String? _userName;
  bool _loadingUser = true;
  bool _hasNationalId = false;

  final _categories = ['وجبات', 'مخبوزات', 'خضار وفواكه', 'معلبات', 'حلويات'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ── جلب بيانات المستخدم للتحقق من رقم الهوية ──
  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (doc.exists) {
      final data = doc.data()!;
      final nationalId = data['nationalId'] ?? '';
      setState(() {
        _userNationalId = nationalId;
        _userName = data['name'] ?? data['fullName'] ?? '';
        _hasNationalId = nationalId.toString().isNotEmpty;
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

  Future<void> _donateFood() async {
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

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('donations').add({
        'userId': userId,
        'userName': _userName ?? '',
        'nationalId': _userNationalId ?? '', // ← يُحفظ تلقائياً مع كل تبرع
        'foodName': _foodNameController.text.trim(),
        'category': _selectedCategory,
        'quantity': _quantityController.text.trim(),
        'location': _locationController.text.trim(),
        'expiryDate': _expiryDate,
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'acceptedResponsibility': true, // ← يُوثّق القبول
        'responsibilityAcceptedAt': FieldValue.serverTimestamp(),
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
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('تم إضافة تبرعك بنجاح، شكراً لك!'),
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

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Center(child: CircularProgressIndicator());
    }

    // ── لو ما عنده رقم هوية — اطلب منه يضيفه ──
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

        // ── بطاقة هوية المتبرع ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
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
                              : AppColors.primary.withOpacity(0.07),
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

                // ── إقرار المسؤولية ── جديد
                GestureDetector(
                  onTap: () => setState(
                      () => _acceptedResponsibility = !_acceptedResponsibility),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _acceptedResponsibility
                          ? AppColors.danger.withOpacity(0.06)
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
                  color: AppColors.primary.withOpacity(0.05),
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
                        color: const Color(0xFFE11D48).withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          color: Color(0xFFE11D48), size: 20),
                    ),
                    title: Text(data['foodName'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${data['quantity']} • ${data['category']}',
                        style: const TextStyle(fontSize: 12)),
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

  // إخفاء جزء من رقم الهوية للخصوصية
  String _maskNationalId(String id) {
    if (id.length <= 4) return id;
    return '${'*' * (id.length - 4)}${id.substring(id.length - 4)}';
  }
}

// ─────────────────────────────────────────────
// شاشة تطلب من المستخدم إضافة رقم الهوية أولاً
// ─────────────────────────────────────────────
class _NoNationalIdView extends StatefulWidget {
  final VoidCallback onSaved; // ← callback للـ parent عشان يعيد التحميل
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
      // استدعاء callback عشان DonateTab يعيد التحميل
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
                color: AppColors.secondary.withOpacity(0.12),
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
                color: AppColors.secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '🔒 رقم هويتك محمي ولن يُشارك مع أي طرف آخر. يُستخدم فقط في حالات سلامة الغذاء.',
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
