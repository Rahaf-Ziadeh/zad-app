import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/location_service.dart';
import '../../theme/app_colors.dart';

/// نتيجة اختيار الموقع — تُعاد عبر Navigator.pop عند التأكيد.
class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String address;
  final String locationSource; // 'gps' أو 'map'

  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.locationSource,
  });
}

/// شاشة اختيار الموقع على خريطة OpenStreetMap — قابلة لإعادة الاستخدام.
///
/// التدفق:
/// 1. عند الفتح: إن وُجدت إحداثيات أولية تُستخدم، وإلا تُجلب إحداثيات GPS تلقائياً.
/// 2. يمكن للمستخدم تحريك الخريطة (الدبوس ثابت في المنتصف) لضبط الموقع يدوياً.
/// 3. عند توقف الحركة يُعاد ترميز الإحداثيات إلى اسم عنوان عبر Nominatim.
/// 4. يمكن تعديل اسم العنوان يدوياً قبل التأكيد.
class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // مركز افتراضي عند تعذّر تحديد الموقع: رام الله، فلسطين
  static const _defaultCenter = LatLng(31.9038, 35.2034);

  final _mapController = MapController();
  final _addressController = TextEditingController();
  final _svc = LocationService();
  Timer? _debounce;

  late LatLng _center;
  String _locationSource = 'map';
  bool _loadingAddress = false;
  bool _loadingGps = false;
  bool _addressUnclear = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _center = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _addressController.text = widget.initialAddress ?? '';
      if (_addressController.text.trim().isEmpty) {
        _reverseGeocode(_center, showSnackOnFail: false);
      }
    } else {
      _center = _defaultCenter;
      // محاولة جلب GPS تلقائياً عند فتح الشاشة
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _useCurrentLocation());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  // ── استخدام موقعي الحالي ──────────────────────────────────────────────────
  Future<void> _useCurrentLocation() async {
    setState(() => _loadingGps = true);
    final position = await _svc.getCurrentLocation();
    if (!mounted) return;
    setState(() => _loadingGps = false);

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر الحصول على الموقع — تحقق من صلاحيات GPS'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final newCenter = LatLng(position.latitude, position.longitude);
    setState(() {
      _center = newCenter;
      _locationSource = 'gps';
    });
    _mapController.move(newCenter, 16);
    await _reverseGeocode(newCenter, showSnackOnFail: true);
  }

  // ── تتبّع تحريك الخريطة (الدبوس ثابت، الخريطة تتحرك تحته) ──────────────────
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return; // تجاهل التحركات البرمجية (move())
    _center = camera.center;
    _locationSource = 'map';
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _reverseGeocode(_center, showSnackOnFail: false);
    });
  }

  Future<void> _reverseGeocode(LatLng point,
      {required bool showSnackOnFail}) async {
    if (!mounted) return;
    setState(() {
      _loadingAddress = true;
      _addressUnclear = false;
    });
    final address =
        await _svc.getAddressFromCoordinates(point.latitude, point.longitude);
    if (!mounted) return;
    setState(() {
      _loadingAddress = false;
      if (address.isNotEmpty) {
        _addressController.text = address;
      } else {
        _addressUnclear = true;
      }
    });
    if (address.isEmpty && showSnackOnFail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد اسم الموقع، يرجى إدخال العنوان يدوياً.'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  void _confirm() {
    final text = _addressController.text.trim();
    Navigator.pop(
      context,
      LocationPickerResult(
        latitude: _center.latitude,
        longitude: _center.longitude,
        address: text.isNotEmpty ? text : 'موقع محدد على الخريطة',
        locationSource: _locationSource,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تحديد الموقع'),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    onPositionChanged: _onPositionChanged,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.zad.app',
                    ),
                  ],
                ),
                // ── دبوس ثابت في المنتصف — الخريطة تتحرك تحته ──
                IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_pin,
                      size: 48,
                      color: AppColors.danger.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'location_picker_gps_btn',
                    backgroundColor: Colors.white,
                    onPressed: _loadingGps ? null : _useCurrentLocation,
                    child: _loadingGps
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded,
                            color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.textLight, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _loadingAddress
                            ? 'جاري تحديد العنوان...'
                            : _addressUnclear
                                ? 'تعذر تحديد اسم الموقع، يرجى إدخال العنوان يدوياً.'
                                : 'حرّك الخريطة لضبط الموقع بدقة',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'اسم العنوان أو المنطقة',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loadingGps ? null : _useCurrentLocation,
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: const Text('استخدام موقعي الحالي'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _confirm,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('تأكيد الموقع'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
