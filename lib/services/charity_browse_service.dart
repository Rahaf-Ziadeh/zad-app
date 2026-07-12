import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/offer_utils.dart';
import 'location_service.dart';
import 'reservation_service.dart';

/// Contains the data-access and business logic used by CharityBrowseScreen.
///
/// The screen remains responsible for UI-only work such as setState,
/// dialogs, snack bars, and navigation.
class CharityBrowseService {
  CharityBrowseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    LocationService? locationService,
    ReservationService? reservationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _locationService = locationService ?? LocationService(),
        _reservationService = reservationService ?? ReservationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final LocationService _locationService;
  final ReservationService _reservationService;

  static const Set<String> knownCategories = {
    'وجبات',
    'مخبوزات',
    'خضار وفواكه',
    'معلبات',
    'حلويات',
  };

  /// Reads all currently available offers from Firestore.
  Stream<QuerySnapshot> watchAvailableOffers() {
    return _firestore
        .collection('offers')
        .where('status', isEqualTo: 'available')
        .snapshots();
  }

  /// Returns the current latitude and longitude.
  ///
  /// Both values are null when the location could not be obtained.
  Future<({double? latitude, double? longitude})>
      loadCurrentCoordinates() async {
    final position = await _locationService.getCurrentLocation();
    return (
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
  }

  bool hasLocation({
    required double? userLat,
    required double? userLng,
  }) {
    return userLat != null && userLng != null;
  }

  double? calculateDistance({
    required Map<String, dynamic> offerData,
    required double? userLat,
    required double? userLng,
  }) {
    if (!hasLocation(userLat: userLat, userLng: userLng)) {
      return null;
    }

    final lat = offerData['latitude'];
    final lng = offerData['longitude'];

    if (lat is! num || lng is! num) {
      return null;
    }

    return _locationService.distanceKm(
      lat1: userLat!,
      lon1: userLng!,
      lat2: lat.toDouble(),
      lon2: lng.toDouble(),
    );
  }

  int activeFilterCount({
    required String priceFilter,
    required String providerTypeFilter,
    required String categoryFilter,
    required String sortOrder,
  }) {
    var count = 0;

    if (priceFilter != 'all') count++;
    if (providerTypeFilter != 'all') count++;
    if (categoryFilter != 'all') count++;
    if (sortOrder != 'newest') count++;

    return count;
  }

  List<QueryDocumentSnapshot> filterAndSortOffers({
    required List<QueryDocumentSnapshot> documents,
    required String priceFilter,
    required String providerTypeFilter,
    required String categoryFilter,
    required String sortOrder,
    required double radiusKm,
    required double? userLat,
    required double? userLng,
  }) {
    var filtered = List<QueryDocumentSnapshot>.from(documents);

    if (priceFilter != 'all') {
      filtered = filtered.where((document) {
        final data = document.data() as Map<String, dynamic>;
        return priceFilter == 'free'
            ? data['isFree'] == true
            : data['isFree'] != true;
      }).toList();
    }

    if (providerTypeFilter != 'all') {
      filtered = filtered.where((document) {
        final data = document.data() as Map<String, dynamic>;
        return data['providerRole'] == providerTypeFilter;
      }).toList();
    }

    if (categoryFilter != 'all') {
      filtered = filtered.where((document) {
        final data = document.data() as Map<String, dynamic>;
        final category = (data['category'] as String? ?? '').trim();

        if (categoryFilter == 'أخرى') {
          return category.isEmpty || !knownCategories.contains(category);
        }

        return category == categoryFilter;
      }).toList();
    }

    if (sortOrder == 'newest') {
      filtered.sort((a, b) {
        final aCreatedAt = (a.data() as Map<String, dynamic>)['createdAt'];
        final bCreatedAt = (b.data() as Map<String, dynamic>)['createdAt'];

        if (aCreatedAt is Timestamp && bCreatedAt is Timestamp) {
          return bCreatedAt.compareTo(aCreatedAt);
        }

        return 0;
      });
    } else if (sortOrder == 'nearest' &&
        hasLocation(userLat: userLat, userLng: userLng)) {
      filtered.sort((a, b) {
        final aDistance = calculateDistance(
          offerData: a.data() as Map<String, dynamic>,
          userLat: userLat,
          userLng: userLng,
        );
        final bDistance = calculateDistance(
          offerData: b.data() as Map<String, dynamic>,
          userLat: userLat,
          userLng: userLng,
        );

        if (aDistance == null && bDistance == null) return 0;
        if (aDistance == null) return 1;
        if (bDistance == null) return -1;

        return aDistance.compareTo(bDistance);
      });

      filtered = filtered.where((document) {
        final distance = calculateDistance(
          offerData: document.data() as Map<String, dynamic>,
          userLat: userLat,
          userLng: userLng,
        );

        // Keep the original behavior: offers without coordinates remain visible.
        return distance == null || distance <= radiusKm;
      }).toList();
    } else if (sortOrder == 'price_asc') {
      filtered.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;

        final aPrice = (aData['discountPrice'] ?? aData['price'] ?? 0) as num;
        final bPrice = (bData['discountPrice'] ?? bData['price'] ?? 0) as num;

        return aPrice.compareTo(bPrice);
      });
    }

    return filtered;
  }

  bool isExpired(Map<String, dynamic> offerData) {
    return isOfferExpired(offerData);
  }

  List<QueryDocumentSnapshot> removeExpiredOffers(
    List<QueryDocumentSnapshot> documents,
  ) {
    return documents.where((document) {
      final data = document.data() as Map<String, dynamic>;
      return !isOfferExpired(data);
    }).toList();
  }

  String providerLabel(String role) {
    switch (role) {
      case 'restaurant':
        return 'مطعم';
      case 'individual':
        return 'فرد';
      case 'charity':
        return 'جمعية';
      default:
        return 'مزوّد طعام';
    }
  }

  String formatDistance(double distanceKm) {
    return _locationService.formatDistance(distanceKm);
  }

  bool isOwnOffer(Map<String, dynamic> offerData) {
    final currentUid = _auth.currentUser?.uid ?? '';
    final providerUid = (offerData['providerUserId'] as String? ?? '').trim();

    return providerUid.isNotEmpty && providerUid == currentUid;
  }

  Future<void> reserveOfferForCharity({
    required String offerId,
    required Map<String, dynamic> offerData,
    required int selectedQuantity,
  }) {
    return _reservationService.reserveOffer(
      offerId: offerId,
      offerData: offerData,
      selectedQuantity: selectedQuantity,
      reserverRole: 'charity',
    );
  }
}
