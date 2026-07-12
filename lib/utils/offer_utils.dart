import 'package:cloud_firestore/cloud_firestore.dart';

/// يُحدّد ما إذا كان العرض منتهي الصلاحية.
/// يدعم الحقل الجديد expiresAt (يُستخدم لعروض المطاعم والأفراد) والحقل
/// القديم expiryDate (فائض الجمعيات)؛ أي عرض بلا أي منهما يُعتبر غير منتهٍ.
bool isOfferExpired(Map<String, dynamic> data) {
  final raw = data['expiresAt'] ?? data['expiryDate'];
  if (raw is! Timestamp) return false;
  return raw.toDate().isBefore(DateTime.now());
}

/// الحالة الفعلية للعرض بعد اعتبار انتهاء الصلاحية، بصرف النظر عن حقل
/// status الخام المخزَّن (الذي قد يبقى "available" حتى بعد الانتهاء).
String effectiveOfferStatus(Map<String, dynamic> data) {
  if (isOfferExpired(data)) return 'expired';
  return (data['status'] as String?) ?? 'available';
}

/// يستخرج Timestamp انتهاء العرض إن وُجد (expiresAt أو expiryDate كحقل بديل).
Timestamp? offerExpiryTimestamp(Map<String, dynamic> data) {
  final raw = data['expiresAt'] ?? data['expiryDate'];
  return raw is Timestamp ? raw : null;
}

/// تنسيق تاريخ ووقت انتهاء العرض للعرض في الواجهة، مثل: 12/07/2026 - 18:30
String formatOfferExpiry(Timestamp? ts) {
  if (ts == null) return '—';
  final dt = ts.toDate().toLocal();
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year.toString();
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$d/$m/$y - $h:$min';
}
