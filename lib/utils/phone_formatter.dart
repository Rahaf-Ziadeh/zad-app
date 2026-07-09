import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// تنسيق أرقام الهاتف — يُستخدم في كل مكان يُعرض فيه رقم هاتف بالتطبيق.
// لا يُغيّر القيمة المخزّنة في Firestore، فقط طريقة عرضها.
// ─────────────────────────────────────────────

/// رموز الدول التي يدعمها التطبيق حالياً (الأطول أولاً لتفادي تطابق جزئي خاطئ).
const List<String> _knownCountryCodes = ['970', '962', '966', '20'];

/// يُحوّل رقماً مخزّناً مثل "+970599123456" إلى "+970 599 123 456".
/// إن كان الرقم منسّقاً بالفعل (يحتوي على مسافات) يُعاد كما هو دون تكرار التنسيق.
String formatPhoneNumber(String? phone) {
  if (phone == null) return '';
  final trimmed = phone.trim();
  if (trimmed.isEmpty) return '';

  // ── منسّق مسبقاً — لا تنسيق مكرر ──
  if (trimmed.contains(' ')) return trimmed;

  final hasPlus = trimmed.startsWith('+');
  final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return trimmed;

  String? countryCode;
  String rest = digitsOnly;
  if (hasPlus) {
    for (final code in _knownCountryCodes) {
      if (digitsOnly.startsWith(code)) {
        countryCode = code;
        rest = digitsOnly.substring(code.length);
        break;
      }
    }
  }

  // ── تجميع باقي الأرقام في مجموعات من 3 ──
  final groups = <String>[];
  for (var i = 0; i < rest.length; i += 3) {
    final end = (i + 3 > rest.length) ? rest.length : i + 3;
    groups.add(rest.substring(i, end));
  }
  final groupedRest = groups.join(' ');

  if (countryCode != null) {
    return groupedRest.isEmpty ? '+$countryCode' : '+$countryCode $groupedRest';
  }
  return (hasPlus ? '+' : '') + groupedRest;
}

/// نص رقم هاتف يُفرض عرضه من اليسار لليمين (LTR) دون التأثير على اتجاه
/// بقية الواجهة العربية المحيطة به — يُستخدم بدلاً من Text() العادي أينما
/// عُرض رقم هاتف.
class PhoneText extends StatelessWidget {
  final String phone;
  final TextStyle? style;
  final TextOverflow? overflow;
  final int? maxLines;

  const PhoneText(
    this.phone, {
    super.key,
    this.style,
    this.overflow,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        formatPhoneNumber(phone),
        style: style,
        overflow: overflow,
        maxLines: maxLines,
        // ── محاذاة لليمين كي يبقى الرقم في موضعه الطبيعي ضمن تخطيط عربي RTL ──
        textAlign: TextAlign.right,
      ),
    );
  }
}
