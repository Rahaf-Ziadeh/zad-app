import 'package:cloud_firestore/cloud_firestore.dart';

/// يتحقق مما إذا كانت الحالة الفعلية تسمح بنشر عروض/باقات جديدة أو إعادة
/// تفعيل عرض مغلق أو منتهي. 'approved' فقط مسموحة؛ 'pending' (بما فيها
/// إعادة المراجعة بعد تعديل بيانات الرخصة) و'rejected' ممنوعتان. القيمة
/// null تُعامَل كحساب قديم (سابق لإضافة هذا الحقل) وتُعتبر مسموحة، بنفس
/// منطق fallback المستخدم في AuthService.login عند غياب الحقل.
bool isVerificationApprovedForPublishing(String? verificationStatus) =>
    verificationStatus == 'approved' || verificationStatus == null;

/// يجلب حالة التحقق الحالية مباشرة من Firestore (وليس من بيانات مخزَّنة
/// محلياً في الواجهة) قبل أي كتابة تُنشئ عرضاً جديداً أو تُعيد تفعيل عرض.
/// هذا هو خط الدفاع الفعلي المتاح على مستوى "طبقة الخدمة/الكتابة" بما أن
/// هذا المستودع لا يتضمن ملف قواعد أمان Firestore (firestore.rules) يمكن
/// تعديله هنا؛ التحقق قبل كل كتابة حسّاسة يمنع تجاوز القيد عبر استدعاء
/// دالة الحفظ مباشرة من أي مكان آخر في الكود، حتى لو كان زر الواجهة معطّلاً.
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

/// رسالة الحظر المناسبة حسب الحالة، لعرضها للمستخدم عند منع النشر/التفعيل.
String publishBlockedMessage(String? verificationStatus) =>
    verificationStatus == 'rejected'
        ? rejectedBlockedMessage
        : pendingReviewBlockedMessage;
