import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/cloudinary_service.dart';
import '../../theme/app_colors.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();

  PlatformFile? _pickedFile;
  bool _loading = false;

  @override
  void dispose() {
    _identityController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _pickedFile = result.files.first);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_pickedFile == null || _pickedFile!.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى رفع صورة أو ملف الهوية'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final docUrl = await CloudinaryService().uploadBytes(
        bytes: _pickedFile!.bytes!,
        filename: _pickedFile!.name,
      );

      if (!mounted) return;

      if (docUrl == null || docUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل رفع المستند، يرجى المحاولة مجدداً'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final idNumber = _identityController.text.trim();

      // ── حقول spec في مجموعة users ──
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'identityNumber': idNumber,
        'identityDocumentUrl': docUrl,
        'identityVerificationStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── توافق مع الشاشات القديمة التي تقرأ من individuals ──
      await FirebaseFirestore.instance
          .collection('individuals')
          .doc(uid)
          .set({
        'userId': uid,
        'identityCard': idNumber,
        'identityImageUrl': docUrl,
        'identityDocumentUrl': docUrl,
        'verificationStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب التوثيق — بانتظار موافقة الإدارة ✅'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('توثيق الهوية'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // ── تعليمات ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_rounded,
                      color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'قبل نشر التبرع، يرجى توثيق هويتك. '
                      'سيتم مراجعة الطلب من الإدارة قبل الموافقة.',
                      style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 13,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── رقم الهوية ──
            TextFormField(
              controller: _identityController,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'يرجى إدخال رقم الهوية';
                }
                if (v.trim().length < 7) return 'رقم الهوية غير صحيح';
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'رقم الهوية *',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // ── رفع المستند ──
            GestureDetector(
              onTap: _pickDocument,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _pickedFile != null
                        ? AppColors.success
                        : AppColors.border,
                    width: _pickedFile != null ? 1.5 : 1,
                  ),
                ),
                child: _pickedFile == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file_rounded,
                              size: 36, color: AppColors.primary),
                          SizedBox(height: 8),
                          Text(
                            'اضغط لرفع صورة أو ملف الهوية',
                            style: TextStyle(
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'jpg  •  png  •  pdf',
                            style: TextStyle(
                                color: AppColors.textLight, fontSize: 12),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              _pickedFile!.name.endsWith('.pdf')
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.image_rounded,
                              color: AppColors.success,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _pickedFile!.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Text('تم اختيار الملف ✓',
                                      style: TextStyle(
                                          color: AppColors.success,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 18, color: AppColors.textLight),
                              onPressed: () =>
                                  setState(() => _pickedFile = null),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── زر الإرسال ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_loading ? 'جاري الإرسال...' : 'إرسال الطلب'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
