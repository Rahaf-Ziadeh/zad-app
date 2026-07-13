import 'package:cloud_firestore/cloud_firestore.dart';

/// Returns true if the offer is past its expiry. Checks expiresAt first (restaurants/individuals),
/// then falls back to the legacy expiryDate field (charity surplus). No expiry field → not expired.
bool isOfferExpired(Map<String, dynamic> data) {
  final raw = data['expiresAt'] ?? data['expiryDate'];
  if (raw is! Timestamp) return false;
  return raw.toDate().isBefore(DateTime.now());
}

/// Effective offer status after accounting for expiry — the raw stored status field can
/// remain "available" even after an offer expires, so always use this instead of reading status directly.
String effectiveOfferStatus(Map<String, dynamic> data) {
  if (isOfferExpired(data)) return 'expired';
  return (data['status'] as String?) ?? 'available';
}

/// Returns the offer's expiry Timestamp if present (expiresAt, or expiryDate as fallback).
Timestamp? offerExpiryTimestamp(Map<String, dynamic> data) {
  final raw = data['expiresAt'] ?? data['expiryDate'];
  return raw is Timestamp ? raw : null;
}

/// Formats the offer expiry for display, e.g. "12/07/2026 - 18:30".
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
