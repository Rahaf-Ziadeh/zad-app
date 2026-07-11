import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Resolved user info returned by [resolveComplaintUser].
// ─────────────────────────────────────────────────────────────────────────────
class ComplaintUserInfo {
  final String  name;
  final String? photoUrl;
  final String? role;
  final String? email;
  final String? phone;

  const ComplaintUserInfo({
    required this.name,
    this.photoUrl,
    this.role,
    this.email,
    this.phone,
  });

  static const unknown = ComplaintUserInfo(name: 'مستخدم غير معروف');

  bool get isKnown => name != 'مستخدم غير معروف';
}

// ─────────────────────────────────────────────────────────────────────────────
// Extract UID from complaint data — exposed so callers can key caches by UID.
// ─────────────────────────────────────────────────────────────────────────────
String extractComplaintUid(Map<String, dynamic> data) {
  for (final key in [
    'userId', 'complainantId', 'reporterId', 'submittedBy', 'createdBy', 'uid'
  ]) {
    final v = (data[key] as String? ?? '').trim();
    if (v.isNotEmpty) return v;
  }
  return '';
}

// ─────────────────────────────────────────────────────────────────────────────
// Full user resolution with structured fallback chain and debug logs.
//
// Resolution order:
//   1. Name stored directly in complaint doc (userName / complainantName / reporterName)
//   2. users/{uid}  direct document lookup
//   3. users.where('uid', == uid).limit(1)  (mismatched doc-IDs)
//   4. Role-specific collection: individuals / restaurants / charities
//
// Temporary debug logs prefixed [Complaint] — remove before release.
// ─────────────────────────────────────────────────────────────────────────────
Future<ComplaintUserInfo> resolveComplaintUser(
  String complaintId,
  Map<String, dynamic> data,
) async {
  debugPrint('[Complaint] complaintId=$complaintId');
  debugPrint('[Complaint] rawData=$data');

  // ── Step 1: name already stored in complaint document ──────────────────────
  for (final key in ['userName', 'complainantName', 'reporterName']) {
    final v = (data[key] as String? ?? '').trim();
    if (v.isNotEmpty) {
      debugPrint('[Complaint] resolvedUid=n/a (name from complaint field "$key")');
      debugPrint('[Complaint] finalName=$v');
      return ComplaintUserInfo(
        name: v,
        role:  _nonEmpty(data['userRole']  as String?),
        email: _nonEmpty(data['userEmail'] as String?),
      );
    }
  }

  // ── Step 2: extract UID ────────────────────────────────────────────────────
  String resolvedUid   = '';
  String resolvedField = '';
  for (final key in [
    'userId', 'complainantId', 'reporterId', 'submittedBy', 'createdBy', 'uid'
  ]) {
    final v = (data[key] as String? ?? '').trim();
    if (v.isNotEmpty) {
      resolvedUid   = v;
      resolvedField = key;
      break;
    }
  }
  debugPrint('[Complaint] resolvedUid="$resolvedUid" (field=$resolvedField)');

  if (resolvedUid.isEmpty) {
    debugPrint('[Complaint] finalName=مستخدم غير معروف (no UID field in complaint doc)');
    return ComplaintUserInfo.unknown;
  }

  final storedRole = (data['userRole'] as String? ?? '').trim();

  // ── Step 3: users/{uid} direct lookup ─────────────────────────────────────
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(resolvedUid)
        .get();
    debugPrint('[Complaint] direct users doc exists=${doc.exists}');
    if (doc.exists) {
      final info = _extractInfo(doc.data()!);
      if (info != null) {
        debugPrint('[Complaint] finalName=${info.name} (users/{uid})');
        return info;
      }
    }
  } catch (e) {
    // Log the actual error — swallowing it hides permission failures.
    debugPrint('[Complaint] users.doc($resolvedUid) error: $e');
  }

  // ── Step 4: users.where('uid', == uid) fallback ───────────────────────────
  try {
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: resolvedUid)
        .limit(1)
        .get();
    debugPrint('[Complaint] uid-query result=${q.docs.length} docs');
    if (q.docs.isNotEmpty) {
      final info = _extractInfo(q.docs.first.data());
      if (info != null) {
        debugPrint('[Complaint] finalName=${info.name} (users uid-query)');
        return info;
      }
    }
  } catch (e) {
    debugPrint('[Complaint] users uid-query error: $e');
  }

  // ── Step 5: role-specific collections ────────────────────────────────────
  for (final col in _roleCollections(storedRole)) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(col)
          .doc(resolvedUid)
          .get();
      debugPrint('[Complaint] role collection result=$col exists=${doc.exists}');
      if (doc.exists) {
        final info = _extractInfo(doc.data()!);
        if (info != null) {
          debugPrint('[Complaint] finalName=${info.name} ($col)');
          return info;
        }
      }
    } catch (e) {
      debugPrint('[Complaint] $col lookup error: $e');
    }
  }

  debugPrint('[Complaint] finalName=مستخدم غير معروف (all lookups failed, uid=$resolvedUid)');
  return ComplaintUserInfo.unknown;
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

List<String> _roleCollections(String role) {
  switch (role) {
    case 'restaurant':
      return ['restaurants'];
    case 'charity':
      return ['charities'];
    case 'individual':
      return ['individuals'];
    default:
      return ['individuals', 'restaurants', 'charities'];
  }
}

ComplaintUserInfo? _extractInfo(Map<String, dynamic> d) {
  String name = '';
  for (final key in [
    'fullName', 'name', 'restaurantName', 'charityName', 'username', 'email'
  ]) {
    final v = (d[key] as String? ?? '').trim();
    if (v.isNotEmpty) { name = v; break; }
  }
  if (name.isEmpty) return null;

  String? photo;
  for (final key in ['photoUrl', 'logoUrl', 'profileImage', 'photo']) {
    final v = (d[key] as String? ?? '').trim();
    if (v.isNotEmpty) { photo = v; break; }
  }

  return ComplaintUserInfo(
    name:     name,
    photoUrl: photo,
    role:     _nonEmpty(d['role']  as String?),
    email:    _nonEmpty(d['email'] as String?),
    phone:    _nonEmpty(d['phone'] as String?),
  );
}

String? _nonEmpty(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}
