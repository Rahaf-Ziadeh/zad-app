import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReservationService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<String> reserveOffer({
    required String offerId,
    required Map<String, dynamic> offerData,
  }) async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception("يجب تسجيل الدخول أولاً");
    }

    final offerRef = firestore.collection('offers').doc(offerId);
    final reservationRef = firestore.collection('reservations').doc();

    await firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(offerRef);

      if (!offerSnapshot.exists) {
        throw Exception("العرض غير موجود");
      }

      final data = offerSnapshot.data() as Map<String, dynamic>;
      final remaining = data['remainingQuantity'] ?? 0;
      final status = data['status'] ?? '';

      if (status != 'available') {
        throw Exception("العرض غير متاح حالياً");
      }

      if (remaining <= 0) {
        throw Exception("نفدت الكمية المتاحة");
      }

      transaction.update(offerRef, {
        'remainingQuantity': remaining - 1,
        'status': remaining - 1 == 0 ? 'reserved' : 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(reservationRef, {
        'reservationId': reservationRef.id,
        'offerId': offerId,
        'offerTitle': data['title'] ?? '',
        'userId': user.uid,
        'providerUserId': data['providerUserId'] ?? '',
        'providerRole': data['providerRole'] ?? '',
        'status': 'reserved',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return reservationRef.id;
  }
}