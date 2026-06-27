import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── ZAD-YYYYMMDD-XXXXXX from the first 6 chars of the Firestore doc ID ──
  static String _generateCode(String docId) {
    final now = DateTime.now();
    final date = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final suffix = docId.substring(0, 6).toUpperCase();
    return 'ZAD-$date-$suffix';
  }

  Future<String> reserveOffer({
    required String offerId,
    required Map<String, dynamic> offerData,
    int selectedQuantity = 1,
  }) async {
    if (selectedQuantity < 1) selectedQuantity = 1;

    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

    // ── جلب اسم المستخدم ──
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.exists
        ? (userDoc.data()?['name'] ?? userDoc.data()?['fullName'] ?? 'مستخدم')
        : 'مستخدم';

    // ── جلب الاسم الحقيقي للمزوّد ──
    String providerName = '';
    final providerUid = (offerData['providerUserId'] as String? ?? '').trim();
    if (providerUid.isNotEmpty) {
      try {
        final providerDoc =
            await _firestore.collection('users').doc(providerUid).get();
        if (providerDoc.exists) {
          final pd = providerDoc.data()!;
          for (final key in [
            'name',
            'fullName',
            'restaurantName',
            'charityName',
          ]) {
            final v = (pd[key] as String? ?? '').trim();
            if (v.isNotEmpty) {
              providerName = v;
              break;
            }
          }
        }
      } catch (_) {}
      if (providerName.isEmpty) {
        providerName = (offerData['providerRole'] as String? ?? '').trim();
      }
    }

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
    final reservationCode = _generateCode(reservationRef.id);

    await _firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(offerRef);

      if (!offerSnapshot.exists) throw Exception('العرض غير موجود');

      final data = offerSnapshot.data() as Map<String, dynamic>;
      final rawQty = data['remainingQuantity'];
      final remaining = rawQty is num ? rawQty.toInt() : 0;
      final status = (data['status'] as String?) ?? '';

      if (status != 'available') throw Exception('العرض غير متاح حالياً');
      if (remaining <= 0) throw Exception('نفدت الكمية المتاحة');

      // التحقق من أن الكمية المطلوبة لا تتجاوز المتاح (race-condition guard)
      if (selectedQuantity > remaining) {
        throw Exception(
            'الكمية المطلوبة ($selectedQuantity) تتجاوز المتاح ($remaining)');
      }

      final afterQty = remaining - selectedQuantity;

      // تحديث الكمية وحالة العرض
      transaction.update(offerRef, {
        'remainingQuantity': afterQty,
        'status': afterQty == 0 ? 'reserved' : 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // إنشاء الحجز
      transaction.set(reservationRef, {
        'reservationId': reservationRef.id,
        'reservationCode': reservationCode,
        'offerId': offerId,
        'offerTitle': data['title'] ?? '',
        'offerType': data['offerType'] ?? '',
        'imageUrl': data['imageUrl'] ?? '',
        'userId': user.uid,
        'userName': userName,
        'providerUserId': data['providerUserId'] ?? '',
        'providerRole': data['providerRole'] ?? '',
        'providerName': providerName,
        'pickupLocation': data['pickupLocation'] ?? '',
        'pickupTime': data['pickupTime'] ?? '',
        'price': data['discountPrice'] ?? data['price'] ?? 0,
        'currency': data['currency'] ?? 'ILS',
        'quantity': selectedQuantity,
        'status': 'reserved',
        'hasRated': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    // إشعار للمستخدم — غير حرج: لا يوقف الحجز عند الفشل
    try {
      await NotificationService().sendNotification(
        userId: user.uid,
        title: 'تم تأكيد الحجز ✅',
        message:
            'تم حجز "${offerData['title'] ?? 'العرض'}" بنجاح. استخدم رمز QR للاستلام.',
        type: 'reservation',
      );
    } catch (e) {
      debugPrint('[ReservationService] user notification failed (non-critical): $e');
    }

    // إشعار لمزوّد الطعام — غير حرج: لا يوقف الحجز عند الفشل
    try {
      final providerUserId = (offerData['providerUserId'] as String?) ?? '';
      if (providerUserId.isNotEmpty) {
        await NotificationService().sendNotification(
          userId: providerUserId,
          title: 'حجز جديد 🎉',
          message: 'قام $userName بحجز "${offerData['title'] ?? 'عرضك'}".',
          type: 'reservation',
        );
      }
    } catch (e) {
      debugPrint('[ReservationService] provider notification failed (non-critical): $e');
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

      // ── قيد الإلغاء: 10 دقائق فقط من وقت الحجز ──
      final createdAt = resData['createdAt'] as Timestamp?;
      if (createdAt == null ||
          DateTime.now().difference(createdAt.toDate()).inMinutes > 10) {
        throw Exception('لا يمكن إلغاء الحجز بعد مرور 10 دقائق.');
      }

      final reservedQty = (resData['quantity'] as num?)?.toInt() ?? 1;

      if (offerSnap.exists) {
        final offerData = offerSnap.data() as Map<String, dynamic>;
        final qty = (offerData['remainingQuantity'] as num?)?.toInt() ?? 0;
        transaction.update(offerRef, {
          'remainingQuantity': qty + reservedQty,
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
