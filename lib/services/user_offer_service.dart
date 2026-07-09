import 'package:cloud_firestore/cloud_firestore.dart';

class UserOfferService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> republishOffer({
    required String offerId,
    required int originalQuantity,
  }) async {
    await _firestore.collection('offers').doc(offerId).update({
      'status': 'available',
      'remainingQuantity': originalQuantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> publishIndividualOffer({
    required String uid,
    required String userName,
    required String title,
    required String description,
    required String category,
    required int quantity,
    required double price,
    required bool isFree,
    required String pickupLocation,
    required double? latitude,
    required double? longitude,
    required String pickupStartTime,
    required String pickupEndTime,
    // ── تاريخ الانتهاء اختياري: إن لم يُحدَّد يُعتمد انتهاء تلقائي بعد 24
    // ساعة من النشر بدل تكرار حقل "تاريخ انتهاء الصلاحية" في الواجهة ──
    DateTime? expiryDate,
    List<String>? allergyInfo,
    String? locationSource,
  }) async {
    final docRef = _firestore.collection('offers').doc();
    final expiresAt =
        expiryDate ?? DateTime.now().add(const Duration(hours: 24));
    final pickupTime = '$pickupStartTime - $pickupEndTime';

    await docRef.set({
      'offerId': docRef.id,
      'providerUserId': uid,
      'providerRole': 'individual',
      'providerName': userName,
      'offerType': 'individual_offer',
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': '',
      'quantity': quantity,
      'remainingQuantity': quantity,
      'originalPrice': price,
      'discountPrice': price,
      'price': price,
      'currency': 'ILS',
      'isFree': isFree,
      'status': 'available',
      'pickupLocation': pickupLocation,
      'latitude': latitude,
      'longitude': longitude,
      'hasLocation': latitude != null,
      'locationSource':
          latitude != null ? (locationSource ?? 'gps') : 'manual',
      'pickupStartTime': pickupStartTime,
      'pickupEndTime': pickupEndTime,
      'pickupTime': pickupTime,
      'allergyInfo': allergyInfo ?? const <String>[],
      'expiresAt': expiresAt,
      'isCash': true,
      'isOnline': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
