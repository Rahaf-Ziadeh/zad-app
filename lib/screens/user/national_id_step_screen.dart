import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/cloudinary_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';

// Checks that the current user has both a national ID and its image stored
// (users/{uid}.nationalId and users/{uid}.nationalIdImageUrl). Both fields are
// required — the ID number alone is never enough to pass this step.
//
// Returns true immediately if both are already saved — the user won't be asked again.
// Otherwise opens the identity step; the original action (donate or post an offer)
// only resumes automatically after a successful save.
//
// Error safety: any unexpected error (network, permissions…) cancels the original action
// by returning false instead of letting the exception leak and silently stall the flow.
Future<bool> ensureNationalIdSaved(BuildContext context) async {
  try {
    // Null-safe currentUser check — no ! operators used anywhere in this function.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('[ensureNationalIdSaved] currentUser is null — cancelling');
      return false;
    }
    final uid = currentUser.uid;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    // Missing user doc (brand-new account) — treat identity as absent and open the step screen.
    if (!userDoc.exists) {
      debugPrint(
          '[ensureNationalIdSaved] users/$uid does not exist — treating '
          'identity as missing');
      if (!context.mounted) return false;
      return _openIdentityStep(context, uid);
    }

    final userData = userDoc.data();
    if (userData == null) {
      debugPrint(
          '[ensureNationalIdSaved] users/$uid exists but data() is null — '
          'treating identity as missing');
      if (!context.mounted) return false;
      return _openIdentityStep(context, uid);
    }

    // is-check instead of 'as String?' — avoids a throw if the field type is unexpected.
    final nationalId = userData['nationalId'];
    final nationalIdImageUrl = userData['nationalIdImageUrl'];
    final hasNationalId =
        nationalId is String && nationalId.trim().isNotEmpty;
    final hasImage =
        nationalIdImageUrl is String && nationalIdImageUrl.trim().isNotEmpty;

    if (!hasNationalId) {
      debugPrint(
          '[ensureNationalIdSaved] uid=$uid nationalId missing/empty');
    }
    if (!hasImage) {
      debugPrint(
          '[ensureNationalIdSaved] uid=$uid nationalIdImageUrl missing/empty');
    }

    // Both fields required — having only one is not enough.
    if (hasNationalId && hasImage) {
      debugPrint(
          '[ensureNationalIdSaved] uid=$uid identity already verified — '
          'skipping NationalIdStepScreen');
      return true;
    }

    debugPrint(
        '[ensureNationalIdSaved] uid=$uid opening NationalIdStepScreen');
    if (!context.mounted) return false;
    return _openIdentityStep(context, uid);
  } catch (e, stack) {
    debugPrint('[ensureNationalIdSaved] unexpected error: $e\n$stack');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر التحقق من بيانات الهوية، يرجى المحاولة مجدداً'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    return false;
  }
}

Future<bool> _openIdentityStep(BuildContext context, String uid) async {
  if (!context.mounted) {
    debugPrint(
        '[ensureNationalIdSaved] uid=$uid context unmounted before opening '
        'identity step — cancelling');
    return false;
  }
  final saved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const NationalIdStepScreen()),
  );

  if (saved != true) {
    debugPrint(
        '[ensureNationalIdSaved] uid=$uid identity step cancelled/dismissed '
        '— cancelling original action');
    return false;
  }
  debugPrint(
      '[ensureNationalIdSaved] uid=$uid identity step completed successfully');
  return true;
}

// Identity step: saves nationalId + nationalIdImageUrl to both users/{uid} and
// individuals/{uid} in a single WriteBatch.
class NationalIdStepScreen extends StatefulWidget {
  const NationalIdStepScreen({super.key});

  @override
  State<NationalIdStepScreen> createState() => _NationalIdStepScreenState();
}

class _NationalIdStepScreenState extends State<NationalIdStepScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isPicking = false;
  bool _isSaving = false;

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
        final existingId = (data['nationalId'] as String? ?? '').trim();
        setState(() {
          _existingStatus = status;
          _additionalInfoMessage = message;
          if (existingId.isNotEmpty && _idController.text.isEmpty) {
            _idController.text = existingId;
          }
        });
      }
    } catch (e) {
      debugPrint('[NationalIdStep] loadExistingData error: $e');
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _isPicking = true);
    try {
      final file =
          await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إرفاق صورة الهوية'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final imageUrl = await CloudinaryService().uploadBytes(
        bytes: _imageBytes!,
        filename: _imageName ?? 'national_id_$uid.jpg',
      );
      if (!mounted) return;
      if (imageUrl == null || imageUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('فشل رفع صورة الهوية، يرجى المحاولة مجدداً')),
        );
        return;
      }

      final nationalId = _idController.text.trim();
      final isResubmission = _existingStatus == 'pending_additional_info';

      debugPrint('[Identity] authUid=$uid');
      debugPrint('[Identity] uploadUrl=$imageUrl');
      debugPrint('[Identity] writeDocId=$uid');
      debugPrint('[Identity] isResubmission=$isResubmission');

      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'nationalId': nationalId,
          'nationalIdImageUrl': imageUrl,
          'identityDocumentUrl': imageUrl,
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
          'nationalId': nationalId,
          'nationalIdImageUrl': imageUrl,
          'identityDocumentUrl': imageUrl,
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
        debugPrint('[Identity] admin notification error: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ بيانات الهوية ✅'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
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
    final picked = _imageBytes != null;
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
                      'قبل التبرع أو نشر عرض طعام، يرجى إدخال رقم هويتك الوطنية '
                      'وإرفاق صورتها للمساءلة القانونية. يُطلب هذا مرة واحدة فقط.',
                      style: TextStyle(
                          color: AppColors.textDark, fontSize: 13, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _idController,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'يرجى إدخال رقم الهوية الوطنية';
                }
                if (v.trim().length < 7 || !RegExp(r'^\d+$').hasMatch(v.trim())) {
                  return 'رقم الهوية غير صحيح';
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'رقم الهوية الوطنية *',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 18),

            // Same upload button pattern as offer and license image pickers.
            const Text('صورة الهوية *',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            Ink(
              decoration: BoxDecoration(
                color: picked
                    ? AppColors.success.withValues(alpha: 0.06)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: picked ? AppColors.success : AppColors.border,
                  width: picked ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                onTap: _isPicking ? null : _pickImage,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        picked
                            ? Icons.check_circle_rounded
                            : Icons.badge_outlined,
                        color: picked ? AppColors.success : AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          picked
                              ? (_imageName ?? 'تم إرفاق الصورة')
                              : 'إرفاق صورة الهوية',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                picked ? AppColors.success : AppColors.textDark,
                          ),
                        ),
                      ),
                      if (_isPicking)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _isSaving ? 'جاري الحفظ...' : 'حفظ ومتابعة',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
