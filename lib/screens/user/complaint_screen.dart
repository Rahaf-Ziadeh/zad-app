import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────
// شاشة الشكوى
// ─────────────────────────────────────────────
class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _offerIdController = TextEditingController();
  String? _selectedType;
  bool _isLoading = false;
  bool _submitted = false;

  final _types = [
    'طلب لم يُستلم',
    'معلومات خاطئة',
    'سلوك غير لائق',
    'مشكلة أخرى'
  ];

  @override
  void dispose() {
    _descController.dispose();
    _offerIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً لتقديم شكوى'),
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final userId    = currentUser.uid;
      final userEmail = (currentUser.email ?? '').trim();

      // Fetch user name + role for denormalization (avoids extra reads on admin side)
      String userName = '';
      String userRole = 'individual';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          final ud = userDoc.data()!;
          final fullName = (ud['fullName'] as String? ?? '').trim();
          final name    = (ud['name']     as String? ?? '').trim();
          userName = fullName.isNotEmpty ? fullName : name;
          userRole = (ud['role'] as String? ?? 'individual');
        }
      } catch (_) {
        // non-critical — complaint is still submitted without name
      }

      await FirebaseFirestore.instance.collection('complaints').add({
        'userId': userId,
        if (userName.isNotEmpty)  'userName':  userName,
        if (userRole.isNotEmpty)  'userRole':  userRole,
        if (userEmail.isNotEmpty) 'userEmail': userEmail,
        'type': _selectedType ?? 'مشكلة أخرى',
        'description': _descController.text.trim(),
        'relatedOfferId': _offerIdController.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() => _submitted = true);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تقديم شكوى')),
      body: _submitted ? _SuccessView() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // ── تنبيه ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.danger, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'سيتم مراجعة شكواك من قبل الإدارة والرد عليك في أقرب وقت.',
                    style: TextStyle(
                        color: AppColors.danger, fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // رقم العرض
                  TextFormField(
                    controller: _offerIdController,
                    decoration: const InputDecoration(
                      labelText: 'رقم العرض (اختياري)',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // نوع الشكوى
                  const Text('نوع الشكوى',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((type) {
                      final selected = _selectedType == type;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.danger.withValues(alpha: 0.10)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.danger
                                  : AppColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(type,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppColors.danger
                                      : AppColors.textLight)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // وصف الشكوى
                  TextFormField(
                    controller: _descController,
                    maxLines: 5,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'يرجى كتابة وصف الشكوى'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'وصف الشكوى *',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 80),
                        child: Icon(Icons.description_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      label:
                          Text(_isLoading ? 'جاري الإرسال...' : 'إرسال الشكوى'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// شاشة النجاح
class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 52),
            ),
            const SizedBox(height: 24),
            const Text('تم إرسال شكواك ✅',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 12),
            const Text(
              'سيتم مراجعة شكواك من قبل الإدارة والرد عليك في أقرب وقت ممكن.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textLight, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('العودة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
