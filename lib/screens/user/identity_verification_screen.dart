import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/cloudinary_service.dart';
import '../../services/notification_service.dart';
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

  String? _existingStatus;
  String? _additionalInfoMessage;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data()!;
        final status = data['identityVerificationStatus'] as String?;
        final message = data['additionalInfoRequestMessage'] as String?;
        final existingId = (data['identityNumber'] as String? ??
                data['nationalId'] as String? ??
                '')
            .trim();
        setState(() {
          _existingStatus = status;
          _additionalInfoMessage = message;
          if (existingId.isNotEmpty && _identityController.text.isEmpty) {
            _identityController.text = existingId;
          }
        });
      }
    } catch (e) {
      debugPrint('[IdentityVerification] loadExistingData error: $e');
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

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
      final isResubmission = _existingStatus == 'pending_additional_info';

      debugPrint('[IdentityVerification] uid=$uid');
      debugPrint('[IdentityVerification] isResubmission=$isResubmission');

      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'identityNumber': idNumber,
          'identityDocumentUrl': docUrl,
          'identityVerificationStatus': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
          if (isResubmission) 'additionalInfoRequested': false,
          if (isResubmission)
            'additionalInfoResponseSubmittedAt': FieldValue.serverTimestamp(),
        },
      );
      batch.set(
        FirebaseFirestore.instance.collection('individuals').doc(uid),
        {
          'userId': uid,
          'identityCard': idNumber,
          'identityImageUrl': docUrl,
          'identityDocumentUrl': docUrl,
          'verificationStatus': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      // Notify admins — non-critical; failure must not block the user
      String notifName = 'مستخدم';
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final ud = snap.data() ?? {};
        final n =
            (ud['fullName'] as String? ?? ud['name'] as String? ?? '').trim();
        if (n.isNotEmpty) notifName = n;
      } catch (_) {}
      try {
        if (isResubmission) {
          await NotificationService().notifyAdminsAboutIdentityResubmission(
            userUid: uid,
            userName: notifName,
          );
        } else {
          await NotificationService().notifyAdminsAboutIdentityVerification(
            userUid: uid,
            userName: notifName,
          );
        }
      } catch (e) {
        debugPrint('[IdentityVerification] admin notification error: $e');
      }

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
            // ── بانر المعلومات الإضافية ──
            if (!_loadingStatus &&
                _existingStatus == 'pending_additional_info' &&
                (_additionalInfoMessage ?? '').isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.amber.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'يطلب المسؤول معلومات إضافية',
                            style: TextStyle(
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _additionalInfoMessage!,
                            style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 13,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
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
