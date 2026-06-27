import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  // ── جلب موقع المستخدم الحالي ──────────────────────────────────────────────

  Future<Position?> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  // ── عكس الترميز الجغرافي عبر OpenStreetMap Nominatim ─────────────────────
  //
  // يُرجع اسم المكان بالعربية إن أمكن.
  // أسباب اختيار Nominatim:
  //   • مجاني — لا يتطلب مفتاح API
  //   • يدعم accept-language=ar → نتائج عربية للمدن الفلسطينية
  //   • تغطية OSM ممتازة للضفة الغربية وغزة
  //   • حزمة http موجودة بالفعل في pubspec.yaml

  Future<String> getAddressFromCoordinates(double lat, double lon) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'format': 'json',
          'accept-language': 'ar',
          'addressdetails': '1',
          'zoom': '16', // مستوى الحي/المنطقة
        },
      );

      final response = await http
          .get(uri, headers: {'User-Agent': 'ZAD-GradApp/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return '';

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      debugPrint('[LocationService] Nominatim response:\n'
          '  raw = ${response.body}\n');

      final addr = (data['address'] as Map<String, dynamic>?) ?? {};

      // حقول مرتبة حسب الأولوية
      final suburb = _pick(addr, ['suburb', 'neighbourhood', 'quarter', 'residential']) ?? '';
      final city = _pick(addr, ['city', 'town', 'village', 'municipality', 'hamlet']) ?? '';
      final state = _pick(addr, ['state', 'county', 'region', 'governorate']) ?? '';

      // 1. حي + مدينة  →  "حي الطيرة، رام الله"
      if (_isMeaningful(suburb) && _isMeaningful(city)) return '$suburb، $city';

      // 2. مدينة + محافظة  →  "رام الله، محافظة رام الله والبيرة"
      if (_isMeaningful(city) && _isMeaningful(state)) return '$city، $state';

      // 3. مدينة فقط  →  "نابلس"
      if (_isMeaningful(city)) return city;

      // 4. محافظة فقط
      if (_isMeaningful(state)) return state;

      // 5. display_name — أخذ أول جزأين من القيمة المركبة
      final display = (data['display_name'] as String? ?? '').trim();
      if (display.isNotEmpty) {
        final parts = display
            .split(',')
            .map((s) => s.trim())
            .where(_isMeaningful)
            .take(2)
            .toList();
        if (parts.isNotEmpty) return parts.join('، ');
      }

      // 6. نص احتياطي — الإحداثيات محفوظة، المستخدم يكمل يدوياً
      return 'موقع محدد على الخريطة';
    } catch (e) {
      debugPrint('[LocationService] Nominatim error: $e');
      return '';
    }
  }

  // ── حساب المسافة بين نقطتين بالكيلومتر ────────────────────────────────────

  double distanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final meters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return meters / 1000;
  }

  // ── تنسيق المسافة للعرض ────────────────────────────────────────────────────

  String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} م';
    if (km < 10) return '${km.toStringAsFixed(1)} كم';
    return '${km.round()} كم';
  }

  // ── مساعدات خاصة ──────────────────────────────────────────────────────────

  /// يختار أول قيمة غير فارغة من قائمة مفاتيح.
  String? _pick(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = (map[k] as String? ?? '').trim();
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  /// يعيد true إذا كانت القيمة اسم مكان مفيداً.
  bool _isMeaningful(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final v = s.trim();
    if (v.length < 3) return false;
    if (v.toLowerCase().contains('unnamed')) return false;
    // ارفض القيم التي تبدأ برقم (أرقام المباني/الشوارع مثل "1600 Amphit")
    if (RegExp(r'^\d').hasMatch(v)) return false;
    return true;
  }
}
