import 'package:zad_app/services/location_service.dart';

class CharityLocationService {
  CharityLocationService({
    LocationService? locationService,
  }) : _locationService = locationService ?? LocationService();

  final LocationService _locationService;
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) {
    return _locationService.getAddressFromCoordinates(
      latitude,
      longitude,
    );
  }
}
