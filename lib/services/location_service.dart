import 'package:geolocator/geolocator.dart';

class LocationService {
  // ── جلب موقع المستخدم الحالي ──
  Future<Position?> getCurrentLocation() async {
    // تحقق من تفعيل الـ GPS
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    // تحقق من الصلاحيات
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

  // ── حساب المسافة بين نقطتين بالكيلومتر ──
  double distanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final meters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return meters / 1000;
  }

  // ── تنسيق المسافة للعرض ──
  String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} م';
    if (km < 10) return '${km.toStringAsFixed(1)} كم';
    return '${km.round()} كم';
  }
}
