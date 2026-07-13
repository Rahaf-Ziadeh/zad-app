import 'package:cloud_firestore/cloud_firestore.dart';

/// Returns true if the current verification status allows publishing new offers or
/// reactivating closed/expired ones. Only 'approved' is permitted; 'pending' (including
/// re-review after a license update) and 'rejected' are blocked. null is treated as a
/// legacy account (pre-field) and is allowed — same fallback as AuthService.login.
bool isVerificationApprovedForPublishing(String? verificationStatus) =>
    verificationStatus == 'approved' || verificationStatus == null;

/// Fetches the current verification status directly from Firestore (not from cached UI state)
/// before any write that creates or reactivates an offer. This is the actual enforcement layer
/// since the repo has no firestore.rules file; checking before every sensitive write prevents
/// bypassing the restriction by calling the save function directly, even when the UI button is disabled.
Future<bool> canPublishOrReactivateOffers(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  if (!doc.exists) return false;
  final vs = doc.data()?['verificationStatus'] as String?;
  return isVerificationApprovedForPublishing(vs);
}

const String pendingReviewBlockedMessage =
    'حسابك قيد إعادة المراجعة حالياً، ولا يمكن نشر عروض جديدة أو إعادة '
    'تفعيل عروض مغلقة/منتهية حتى تتم الموافقة.';

const String rejectedBlockedMessage =
    'تم رفض طلب التحقق الخاص بحسابك، ولا يمكن نشر عروض جديدة أو إعادة '
    'تفعيل عروض مغلقة/منتهية حتى تتم الموافقة على بيانات محدَّثة.';

/// Returns the appropriate blocked-publish message for the given verification status.
String publishBlockedMessage(String? verificationStatus) =>
    verificationStatus == 'rejected'
        ? rejectedBlockedMessage
        : pendingReviewBlockedMessage;
