import 'package:cloud_firestore/cloud_firestore.dart';

class UserOfferService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    required DateTime expiryDate,
  }) async {
    final docRef = _firestore.collection('offers').doc();

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
      'expiryDate': expiryDate,
      'isCash': true,
      'isOnline': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
