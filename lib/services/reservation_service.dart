import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> reserveOffer({
    required String offerId,
    required Map<String, dynamic> offerData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

    // ── جلب اسم المستخدم ──
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.exists
        ? (userDoc.data()?['name'] ?? userDoc.data()?['fullName'] ?? 'مستخدم')
        : 'مستخدم';

    // ── التحقق من عدم وجود حجز مسبق لنفس العرض ──
    final existing = await _firestore
        .collection('reservations')
        .where('userId', isEqualTo: user.uid)
        .where('offerId', isEqualTo: offerId)
        .where('status', isEqualTo: 'reserved')
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('لديك حجز مسبق لهذا العرض');
    }

    final offerRef = _firestore.collection('offers').doc(offerId);
    final reservationRef = _firestore.collection('reservations').doc();

    await _firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(offerRef);

      if (!offerSnapshot.exists) throw Exception('العرض غير موجود');

      final data = offerSnapshot.data() as Map<String, dynamic>;
      final remaining = data['remainingQuantity'] ?? 0;
      final status = data['status'] ?? '';

      if (status != 'available') throw Exception('العرض غير متاح حالياً');
      if (remaining <= 0) throw Exception('نفدت الكمية المتاحة');

      // تحديث الكمية وحالة العرض
      transaction.update(offerRef, {
        'remainingQuantity': remaining - 1,
        'status': remaining - 1 == 0 ? 'reserved' : 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // إنشاء الحجز
      transaction.set(reservationRef, {
        'reservationId': reservationRef.id,
        'offerId': offerId,
        'offerTitle': data['title'] ?? '',
        'offerType': data['offerType'] ?? '',
        'imageUrl': data['imageUrl'] ?? '',
        'userId': user.uid,
        'userName': userName,
        'providerUserId': data['providerUserId'] ?? '',
        'providerRole': data['providerRole'] ?? '',
        'pickupLocation': data['pickupLocation'] ?? '',
        'price': data['discountPrice'] ?? data['price'] ?? 0,
        'currency': data['currency'] ?? 'ILS',
        'status': 'reserved',
        'hasRated': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    // إشعار للمستخدم
    await NotificationService().sendNotification(
      userId: user.uid,
      title: 'تم تأكيد الحجز ✅',
      message:
          'تم حجز "${offerData['title'] ?? 'العرض'}" بنجاح. استخدم رمز QR للاستلام.',
      type: 'reservation',
    );

    // إشعار لمزوّد الطعام
    final providerUserId = offerData['providerUserId'] ?? '';
    if (providerUserId.isNotEmpty) {
      await NotificationService().sendNotification(
        userId: providerUserId,
        title: 'حجز جديد 🎉',
        message: 'قام $userName بحجز "${offerData['title'] ?? 'عرضك'}".',
        type: 'reservation',
      );
    }

    return reservationRef.id;
  }

  // ── إلغاء الحجز وإرجاع الكمية ──
  Future<void> cancelReservation({
    required String reservationId,
    required String offerId,
  }) async {
    final reservationRef =
        _firestore.collection('reservations').doc(reservationId);
    final offerRef = _firestore.collection('offers').doc(offerId);

    await _firestore.runTransaction((transaction) async {
      final resSnap = await transaction.get(reservationRef);
      final offerSnap = await transaction.get(offerRef);

      if (!resSnap.exists) throw Exception('الحجز غير موجود');

      final resData = resSnap.data() as Map<String, dynamic>;
      if (resData['status'] != 'reserved') {
        throw Exception('لا يمكن إلغاء هذا الطلب');
      }

      if (offerSnap.exists) {
        final offerData = offerSnap.data() as Map<String, dynamic>;
        final qty = offerData['remainingQuantity'] ?? 0;
        transaction.update(offerRef, {
          'remainingQuantity': qty + 1,
          'status': 'available',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.update(reservationRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
