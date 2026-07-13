import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CharityReservationsService {
  CharityReservationsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Stream<QuerySnapshot> watchReservations({
    String? status,
  }) {
    final userId = _auth.currentUser!.uid;

    Query query = _firestore
        .collection('reservations')
        .where('userId', isEqualTo: userId);

    if (status != null) {
      query = query.where(
        'status',
        isEqualTo: status,
      );
    }

    return query
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots();
  }

  // Cancels within the 10-minute window; restores quantity atomically.
  Future<void> cancelReservation({
    required String reservationId,
    required String offerId,
  }) async {
    final reservationReference =
        _firestore.collection('reservations').doc(reservationId);

    final offerReference = _firestore.collection('offers').doc(offerId);

    await _firestore.runTransaction(
      (transaction) async {
        final reservationSnapshot = await transaction.get(
          reservationReference,
        );

        final offerSnapshot = await transaction.get(
          offerReference,
        );

        if (!reservationSnapshot.exists) {
          throw Exception('الحجز غير موجود');
        }

        final reservationData =
            reservationSnapshot.data() as Map<String, dynamic>;

        if (reservationData['status'] != 'reserved') {
          throw Exception('لا يمكن إلغاء هذا الطلب');
        }

        final createdAt = reservationData['createdAt'] as Timestamp?;

        if (createdAt == null ||
            DateTime.now().difference(createdAt.toDate()).inMinutes > 10) {
          throw Exception(
            'لا يمكن إلغاء الحجز بعد مرور 10 دقائق.',
          );
        }

        final cancelledQuantity =
            (reservationData['quantity'] as num?)?.toInt() ?? 1;

        if (offerSnapshot.exists) {
          final offerData = offerSnapshot.data() as Map<String, dynamic>;

          final remainingQuantity =
              (offerData['remainingQuantity'] as num?)?.toInt() ?? 0;

          transaction.update(
            offerReference,
            {
              'remainingQuantity': remainingQuantity + cancelledQuantity,
              'status': 'available',
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }

        transaction.update(
          reservationReference,
          {
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  String cancelErrorMessage(Object error) {
    final rawMessage = error.toString();

    if (rawMessage.contains(
      'لا يمكن إلغاء الحجز بعد مرور 10 دقائق',
    )) {
      return 'لا يمكن إلغاء الحجز بعد مرور 10 دقائق.';
    }

    if (rawMessage.contains(
      'لا يمكن إلغاء هذا الطلب',
    )) {
      return 'لا يمكن إلغاء هذا الطلب.';
    }

    if (rawMessage.contains(
      'الحجز غير موجود',
    )) {
      return 'الحجز غير موجود.';
    }

    return rawMessage.replaceAll('Exception: ', '').trim();
  }
}
