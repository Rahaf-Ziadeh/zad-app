import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/offer_utils.dart';
import 'notification_service.dart';

class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Maximum minutes a user has to cancel after booking — single source of truth across the entire project.
  static const int cancellationWindowMinutes = 10;

  // Single source of truth for the "refunded" payment status — keeps all comparisons in sync.
  static const String paymentStatusRefunded = 'refunded';

  // In-memory guard against double-tap: rejects a second reserveOffer call for the same
  // user+offer while the first is still in flight. Complements the UI button disable
  // without needing a Firestore lock doc that could get stuck on failure.
  // Actual overselling protection is the transaction below — it always re-reads remainingQuantity.
  static final Set<String> _inFlightReservationKeys = {};

  // ── ZAD-YYYYMMDD-XXXXXX from the first 6 chars of the Firestore doc ID ──
  static String _generateCode(String docId) {
    final now = DateTime.now();
    final date = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final suffix = docId.substring(0, 6).toUpperCase();
    return 'ZAD-$date-$suffix';
  }

  // Pre-checks for an active ('reserved') reservation before the quantity/payment sheet opens,
  // so the user sees a clear message instead of discovering the conflict inside the payment flow.
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> getActiveReservation(
    String offerId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final query = await _firestore
        .collection('reservations')
        .where('userId', isEqualTo: user.uid)
        .where('offerId', isEqualTo: offerId)
        .where('status', isEqualTo: 'reserved')
        .limit(1)
        .get();

    return query.docs.isEmpty ? null : query.docs.first;
  }

  Future<String> reserveOffer({
    required String offerId,
    required Map<String, dynamic> offerData,
    int selectedQuantity = 1,
    String reserverRole = 'individual',
    // Both optional; written atomically in the same transaction so there's never a
    // reservation with an unknown payment state. Cash passes them immediately;
    // online only calls reserveOffer after payment succeeds — see payment_method_screen.
    String? paymentMethod,
    String? paymentStatus,
  }) async {
    if (selectedQuantity < 1) selectedQuantity = 1;

    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

    // Prevent users from reserving their own offer.
    final selfProviderUid =
        (offerData['providerUserId'] as String? ?? '').trim();
    if (selfProviderUid.isNotEmpty && selfProviderUid == user.uid) {
      throw Exception('لا يمكن حجز عرضك الخاص.');
    }

    // Service-level in-flight guard — set before any await, always removed in finally.
    final inFlightKey = '${offerId}_${user.uid}';
    if (_inFlightReservationKeys.contains(inFlightKey)) {
      debugPrint('[ReservationService] reserveOffer REJECTED — duplicate '
          'in-flight request key=$inFlightKey');
      throw Exception('طلب الحجز قيد المعالجة بالفعل، يرجى الانتظار.');
    }
    _inFlightReservationKeys.add(inFlightKey);

    try {
      return await _reserveOfferInternal(
        offerId: offerId,
        offerData: offerData,
        selectedQuantity: selectedQuantity,
        user: user,
        reserverRole: reserverRole,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
      );
    } finally {
      _inFlightReservationKeys.remove(inFlightKey);
    }
  }

  Future<String> _reserveOfferInternal({
    required String offerId,
    required Map<String, dynamic> offerData,
    required int selectedQuantity,
    required User user,
    String reserverRole = 'individual',
    String? paymentMethod,
    String? paymentStatus,
  }) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.exists
        ? (userDoc.data()?['name'] ?? userDoc.data()?['fullName'] ?? 'مستخدم')
        : 'مستخدم';

    // Fetch the provider's display name from their role-specific collection.
    String providerName = '';
    final providerUid = (offerData['providerUserId'] as String? ?? '').trim();
    if (providerUid.isNotEmpty) {
      try {
        final providerRole = (offerData['providerRole'] as String? ?? '').trim();
        final roleCollection = providerRole == 'restaurant'
            ? 'restaurants'
            : providerRole == 'charity'
                ? 'charities'
                : null;

        if (roleCollection != null) {
          final roleDoc = await _firestore
              .collection(roleCollection)
              .doc(providerUid)
              .get();
          if (roleDoc.exists) {
            final rd = roleDoc.data()!;
            for (final key in ['restaurantName', 'charityName', 'name']) {
              final v = (rd[key] as String? ?? '').trim();
              if (v.isNotEmpty) {
                providerName = v;
                break;
              }
            }
          }
        }

        if (providerName.isEmpty) {
          final providerDoc =
              await _firestore.collection('users').doc(providerUid).get();
          if (providerDoc.exists) {
            final pd = providerDoc.data()!;
            for (final key in ['name', 'fullName']) {
              final v = (pd[key] as String? ?? '').trim();
              if (v.isNotEmpty) {
                providerName = v;
                break;
              }
            }
          }
        }
      } catch (_) {}
      if (providerName.isEmpty) {
        providerName = (offerData['providerRole'] as String? ?? '').trim();
      }
    }

    // Guard against double-booking the same offer.
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

    debugPrint('[ReservationService] reserveOffer TRANSACTION START '
        'offerId=$offerId requestedQuantity=$selectedQuantity userId=${user.uid}');

    await _firestore.runTransaction((transaction) async {
      // Transaction read is the only source of truth — never use offerData from the UI for quantity checks.
      final offerSnapshot = await transaction.get(offerRef);

      if (!offerSnapshot.exists) throw Exception('العرض غير موجود');

      final data = offerSnapshot.data() as Map<String, dynamic>;
      final rawQty = data['remainingQuantity'];
      final remaining = rawQty is num ? rawQty.toInt() : 0;
      final status = (data['status'] as String?) ?? '';

      debugPrint('[ReservationService] reserveOffer TRANSACTION READ '
          'offerId=$offerId remainingQuantity(fresh)=$remaining status=$status '
          'requestedQuantity=$selectedQuantity');

      if (status != 'available') {
        debugPrint('[ReservationService] reserveOffer REJECTED — status '
            'not available (offerId=$offerId status=$status)');
        throw Exception('العرض غير متاح حالياً');
      }
      if (remaining <= 0) {
        debugPrint('[ReservationService] reserveOffer REJECTED — sold out '
            '(offerId=$offerId remainingQuantity=$remaining)');
        throw Exception('نفدت الكمية المتاحة');
      }
      if (isOfferExpired(data)) {
        debugPrint('[ReservationService] reserveOffer REJECTED — expired '
            '(offerId=$offerId)');
        throw Exception('انتهت مدة هذا العرض ولم يعد متاحًا للحجز.');
      }

      // Requested quantity exceeds what's currently available — race-condition guard.
      if (selectedQuantity > remaining) {
        debugPrint('[ReservationService] reserveOffer REJECTED — '
            'insufficient quantity (offerId=$offerId requested=$selectedQuantity '
            'remaining=$remaining)');
        throw Exception('عذرًا، نفدت الكمية قبل إتمام الحجز.');
      }

      // Per-user quantity cap — only enforced if the offer defines this field.
      final rawMaxPerUser = data['maxQuantityPerUser'];
      final maxPerUser = rawMaxPerUser is num ? rawMaxPerUser.toInt() : null;
      if (maxPerUser != null && maxPerUser > 0 && selectedQuantity > maxPerUser) {
        throw Exception(
            'الحد الأقصى للكمية لكل مستخدم هو $maxPerUser');
      }

      final afterQty = remaining - selectedQuantity;
      debugPrint('[ReservationService] reserveOffer TRANSACTION SUCCESS '
          'offerId=$offerId remainingQuantity(after)=$afterQty '
          'requestedQuantity=$selectedQuantity');

      transaction.update(offerRef, {
        'remainingQuantity': afterQty,
        'status': afterQty == 0 ? 'reserved' : 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Immutable offer snapshot at reservation time — QR confirmation still works even if the offer is later deleted or expired.
      final unitPrice = (data['discountPrice'] ?? data['price'] ?? 0) as num;
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
        'pickupStartTime': data['pickupStartTime'] ?? '',
        'pickupEndTime': data['pickupEndTime'] ?? '',
        'allergyInfo': data['allergyInfo'] ?? const <String>[],
        'price': unitPrice,
        'totalAmount': unitPrice * selectedQuantity,
        'currency': data['currency'] ?? 'ILS',
        'quantity': selectedQuantity,
        'status': 'reserved',
        'hasRated': false,
        if (paymentMethod != null && paymentMethod.isNotEmpty)
          'paymentMethod': paymentMethod,
        if (paymentStatus != null && paymentStatus.isNotEmpty)
          'paymentStatus': paymentStatus,
        'createdAt': FieldValue.serverTimestamp(),
        'reserverRole': reserverRole,
      });
    });

    // User notification — non-critical, failure doesn't abort the reservation.
    try {
      await NotificationService().sendNotification(
        userId: user.uid,
        title: 'تم تأكيد الحجز ✅',
        message:
            'تم حجز "${offerData['title'] ?? 'العرض'}" بنجاح. استخدم رمز QR للاستلام.',
        type: 'reservation',
        relatedId: reservationRef.id,
      );
    } catch (e) {
      debugPrint('[ReservationService] user notification failed (non-critical): $e');
    }

    // Provider notification — non-critical, failure doesn't abort the reservation.
    try {
      final providerUserId = (offerData['providerUserId'] as String?) ?? '';
      if (providerUserId.isNotEmpty) {
        await NotificationService().sendNotification(
          userId: providerUserId,
          title: 'حجز جديد 🎉',
          message: selectedQuantity > 1
              ? 'قام $userName بحجز $selectedQuantity وحدات من "${offerData['title'] ?? 'عرضك'}".'
              : 'قام $userName بحجز "${offerData['title'] ?? 'عرضك'}".',
          type: 'reservation',
          relatedId: reservationRef.id,
        );
      }
    } catch (e) {
      debugPrint('[ReservationService] provider notification failed (non-critical): $e');
    }

    return reservationRef.id;
  }

  // Cancels a reservation and restores its quantity in a single atomic transaction.
  // Idempotent: already-cancelled reservations are rejected without restoring quantity again.
  // Unknown errors (including web JS-interop) are replaced with a safe user-facing message.
  Future<void> cancelReservation({
    required String reservationId,
    required String offerId,
  }) async {
    debugPrint('[ReservationService] cancelReservation START '
        'reservationId=$reservationId offerId=$offerId');

    final reservationRef =
        _firestore.collection('reservations').doc(reservationId);
    // Legacy reservations may lack a valid offerId — cancel without restoring quantity in that case.
    final offerRef =
        offerId.isEmpty ? null : _firestore.collection('offers').doc(offerId);

    try {
      await _firestore.runTransaction((transaction) async {
        final resSnap = await transaction.get(reservationRef);

        if (!resSnap.exists) {
          debugPrint('[ReservationService] cancelReservation: reservation '
              '$reservationId does not exist');
          throw Exception('الحجز غير موجود');
        }

        final resData = resSnap.data();
        if (resData == null) {
          debugPrint('[ReservationService] cancelReservation: reservation '
              '$reservationId has null data');
          throw Exception('تعذّر قراءة بيانات الحجز');
        }

        final currentStatus = (resData['status'] as String?) ?? '';
        debugPrint('[ReservationService] cancelReservation: current '
            'status="$currentStatus" for $reservationId');

        // Already cancelled — don't restore quantity again.
        if (currentStatus == 'cancelled') {
          debugPrint('[ReservationService] cancelReservation: already '
              'cancelled — skipping, quantity NOT restored again');
          throw Exception('تم إلغاء هذا الحجز مسبقاً');
        }
        if (currentStatus != 'reserved') {
          debugPrint('[ReservationService] cancelReservation: status '
              '"$currentStatus" is not cancellable');
          throw Exception('لا يمكن إلغاء هذا الطلب');
        }

        // Cancellation window check — all timing values are logged to confirm the actual rejection cause.
        final createdAt = resData['createdAt'] as Timestamp?;
        final now = DateTime.now();
        final elapsedMinutes =
            createdAt == null ? null : now.difference(createdAt.toDate()).inMinutes;
        debugPrint('[ReservationService] cancelReservation: TIME-LIMIT CHECK '
            'createdAt=${createdAt?.toDate()} now=$now '
            'elapsedMinutes=$elapsedMinutes '
            'configuredLimit=$cancellationWindowMinutes');

        if (createdAt == null ||
            elapsedMinutes == null ||
            elapsedMinutes > cancellationWindowMinutes) {
          debugPrint('[ReservationService] cancelReservation: REJECTED by '
              'time limit for $reservationId '
              '(elapsedMinutes=$elapsedMinutes > '
              'limit=$cancellationWindowMinutes, or createdAt missing)');
          throw Exception(
              'انتهت مهلة إلغاء الحجز. يمكن إلغاء الحجز خلال أول '
              '$cancellationWindowMinutes دقيقة.');
        }
        debugPrint('[ReservationService] cancelReservation: time-limit '
            'check PASSED for $reservationId '
            '(elapsedMinutes=$elapsedMinutes <= limit='
            '$cancellationWindowMinutes) — NOT the rejection cause');

        // 'quantity' is the canonical field; 'selectedQuantity' is a fallback for legacy records.
        final rawQty = resData['quantity'] ?? resData['selectedQuantity'];
        final reservedQty = rawQty is num ? rawQty.toInt() : 1;
        debugPrint('[ReservationService] cancelReservation: '
            'selectedQuantity=$reservedQty for $reservationId');

        if (offerRef != null) {
          final offerSnap = await transaction.get(offerRef);
          if (offerSnap.exists) {
            final offerData = offerSnap.data();
            final rawRemaining = offerData?['remainingQuantity'];
            final remaining = rawRemaining is num ? rawRemaining.toInt() : 0;
            debugPrint('[ReservationService] cancelReservation: offer '
                '$offerId remainingQuantity(before)=$remaining');

            final restored = remaining + reservedQty;
            transaction.update(offerRef, {
              'remainingQuantity': restored,
              'status': 'available',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            debugPrint('[ReservationService] cancelReservation: quantity '
                'restoration OK — offer $offerId remainingQuantity(after)='
                '$restored');
          } else {
            debugPrint('[ReservationService] cancelReservation: offer '
                '$offerId no longer exists — skipping quantity restoration');
          }
        } else {
          debugPrint('[ReservationService] cancelReservation: no offerId '
              'on reservation $reservationId — skipping quantity '
              'restoration (legacy record)');
        }

        transaction.update(reservationRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[ReservationService] cancelReservation: reservation '
            'update result OK — $reservationId status=cancelled');
      });

      debugPrint('[ReservationService] cancelReservation SUCCESS '
          'reservationId=$reservationId');
    } catch (e, stackTrace) {
      // Log the full exception type and stack before converting to a user-friendly message.
      debugPrint('[ReservationService] cancelReservation FAILED '
          'reservationId=$reservationId offerId=$offerId '
          'errorType=${e.runtimeType} error=$e');
      debugPrint(
          '[ReservationService] cancelReservation stackTrace:\n$stackTrace');
      debugPrint('[ReservationService] cancelReservation DIAGNOSIS: '
          '${_diagnoseCancelFailure(e)}');

      // Only our own known messages pass through; raw platform/JS-interop errors get a safe generic message.
      throw Exception(_safeCancelErrorMessage(e));
    }
  }

  // Maps the exception to the exact failure mode — used only in debug logs, never shown to the user.
  static String _diagnoseCancelFailure(Object e) {
    final raw = e.toString();

    // Our own messages mean the cause is known — not an unexpected exception.
    if (raw.contains('انتهت مهلة إلغاء الحجز')) {
      return 'CANCELLATION TIME LIMIT EXCEEDED (confirmed cause — see '
          'TIME-LIMIT CHECK log line above)';
    }
    if (raw.contains('الحجز غير موجود')) {
      return 'RESERVATION DOES NOT EXIST (reservationId lookup failed)';
    }
    if (raw.contains('تعذّر قراءة بيانات الحجز')) {
      return 'NULL VALUE — reservation document data() returned null';
    }
    if (raw.contains('تم إلغاء هذا الحجز مسبقاً')) {
      return 'ALREADY CANCELLED (idempotent no-op, not a real failure)';
    }
    if (raw.contains('لا يمكن إلغاء هذا الطلب')) {
      return 'RESERVATION STATUS IS NOT "reserved" (already picked_up or '
          'other terminal state)';
    }

    if (e is FirebaseException) {
      final where = e.code == 'permission-denied'
          ? 'FIRESTORE PERMISSION DENIED — security rules rejected either '
              'the reservations/{id} status update or the offers/{id} '
              'remainingQuantity update. Check that rules allow the '
              'reservation OWNER (not just the provider) to set '
              'status: "cancelled", and allow remainingQuantity to '
              'INCREASE (not just decrease) on the offer.'
          : 'FIRESTORE OPERATION FAILED — code=${e.code} plugin=${e.plugin} '
              'message=${e.message}';
      return where;
    }
    if (e is TypeError || e is NoSuchMethodError) {
      return 'NULL/TYPE ERROR — likely a missing or wrongly-typed field '
          '(offerId, quantity/selectedQuantity, remainingQuantity, or '
          'status) on the reservation or offer document. errorType='
          '${e.runtimeType} raw="$raw"';
    }

    return 'UNCLASSIFIED ERROR (errorType=${e.runtimeType}) — see raw '
        'message and stack trace above for details: "$raw"';
  }

  // Passes through only our own known error messages (matched by prefix so the
  // time-limit message stays in sync with cancellationWindowMinutes).
  // Anything else — raw platform/JS-interop errors — gets a safe generic fallback.
  static String _safeCancelErrorMessage(Object e) {
    final raw = e.toString().replaceAll('Exception: ', '').trim();
    const knownPrefixes = [
      'الحجز غير موجود',
      'تعذّر قراءة بيانات الحجز',
      'تم إلغاء هذا الحجز مسبقاً',
      'لا يمكن إلغاء هذا الطلب',
      'انتهت مهلة إلغاء الحجز',
    ];
    for (final prefix in knownPrefixes) {
      if (raw.startsWith(prefix)) return raw;
    }
    return 'تعذّر إلغاء الحجز، يرجى المحاولة مرة أخرى.';
  }

  // Human-readable label for unexpected reservation statuses — used in the pickup block message.
  static String _reservationStatusLabel(String status) {
    switch (status) {
      case 'reserved':
        return 'بانتظار الاستلام';
      case 'picked_up':
        return 'تم استلامه بالفعل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  // Block message for pickup confirmation when online payment hasn't completed.
  static String _electronicPaymentBlockMessage(String? paymentStatus) {
    switch (paymentStatus) {
      case 'pending_online':
        return 'الدفع الإلكتروني لهذا الطلب لم يكتمل بعد، لا يمكن تأكيد '
            'الاستلام حتى يتم الدفع.';
      case 'failed':
        return 'فشلت عملية الدفع الإلكتروني لهذا الطلب، لا يمكن تأكيد '
            'الاستلام.';
      case ReservationService.paymentStatusRefunded:
        return 'تم استرداد قيمة هذا الطلب، لا يمكن تأكيد الاستلام.';
      default:
        return 'حالة الدفع الإلكتروني لهذا الطلب غير مكتملة، لا يمكن تأكيد '
            'الاستلام.';
    }
  }

  // Single pickup confirmation entry point — used by both QR scan and manual confirmation.
  // All binding validation runs inside the transaction; UI pre-checks are UX only, not authoritative.
  // Idempotent: if status isn't 'reserved' when the transaction runs (double-tap or repeated QR
  // scan) nothing is written and no notification is sent.
  Future<void> confirmPickup({
    required String reservationId,
    required String confirmationMethod, // 'qr' | 'manual'
    // Must be true for cash reservations — confirms the restaurant physically collected the amount.
    bool paymentCollectedConfirmed = false,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) throw Exception('يجب تسجيل الدخول أولاً');

    debugPrint('[ReservationService] confirmPickup START '
        'reservationId=$reservationId method=$confirmationMethod uid=$uid');

    final reservationRef =
        _firestore.collection('reservations').doc(reservationId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(reservationRef);

        if (!snap.exists) {
          throw Exception('رمز QR غير صالح أو أن الحجز غير موجود.');
        }
        final data = snap.data();
        if (data == null) {
          throw Exception('رمز QR غير صالح أو أن الحجز غير موجود.');
        }

        // Reservation ownership check — must belong to the calling provider.
        final providerUserId = (data['providerUserId'] as String?) ?? '';
        if (providerUserId != uid) {
          debugPrint('[ReservationService] confirmPickup REJECTED — '
              'ownership mismatch reservationId=$reservationId '
              'reservationProvider=$providerUserId currentProvider=$uid');
          throw Exception('هذا الحجز لا يتبع مطعمك.');
        }

        final status = (data['status'] as String?) ?? '';
        debugPrint('[ReservationService] confirmPickup TRANSACTION READ '
            'reservationId=$reservationId status=$status');

        if (status == 'picked_up') {
          throw Exception(
              'تم استخدام رمز QR لهذا الطلب مسبقًا وتم تأكيد الاستلام.');
        }
        if (status == 'cancelled') {
          throw Exception('هذا الطلب ملغي ولا يمكن تأكيد استلامه.');
        }
        if (status != 'reserved') {
          throw Exception('لا يمكن تأكيد الاستلام — حالة الحجز الحالية: '
              '${_reservationStatusLabel(status)}.');
        }

        // Payment guard: online must be paid; cash requires explicit collection confirmation; free skips both.
        final paymentMethod = (data['paymentMethod'] as String?) ?? '';
        final paymentStatus = data['paymentStatus'] as String?;
        if (paymentMethod == 'online' && paymentStatus != 'paid') {
          throw Exception(_electronicPaymentBlockMessage(paymentStatus));
        }
        if (paymentMethod == 'cash' && !paymentCollectedConfirmed) {
          throw Exception('يرجى تأكيد استلام المبلغ نقداً قبل تأكيد الاستلام.');
        }

        transaction.update(reservationRef, {
          'status': 'picked_up',
          'pickedAt': FieldValue.serverTimestamp(),
          'pickedUpAt': FieldValue.serverTimestamp(),
          'confirmedBy': uid,
          'confirmationMethod': confirmationMethod,
          if (confirmationMethod == 'qr') ...{
            'qrValidatedAt': FieldValue.serverTimestamp(),
            'qrValidationMethod': 'firestore_transaction',
          },
          if (paymentMethod == 'cash' && paymentCollectedConfirmed) ...{
            'paymentStatus': 'paid',
            'paymentCollectedAt': FieldValue.serverTimestamp(),
            'paymentCollectedBy': uid,
          },
        });
        debugPrint('[ReservationService] confirmPickup TRANSACTION SUCCESS '
            'reservationId=$reservationId');
      });
    } catch (e) {
      debugPrint('[ReservationService] confirmPickup FAILED '
          'reservationId=$reservationId error=$e');
      final raw = e.toString().replaceAll('Exception: ', '').trim();
      throw Exception(raw);
    }

    // Notification sent only after the transaction succeeds — exactly once per reservation; failure is non-critical.
    try {
      final freshSnap = await reservationRef.get();
      final data = freshSnap.data();
      final userId = (data?['userId'] as String?) ?? '';
      final offerTitle = (data?['offerTitle'] as String?) ?? 'طلب طعام';
      if (userId.isNotEmpty) {
        await NotificationService().sendNotification(
          userId: userId,
          title: 'تم تأكيد الاستلام ✅',
          message: 'تم استلام طلبك "$offerTitle" بنجاح. نتمنى لك وجبة شهية ❤️',
          type: 'pickup',
          relatedId: reservationId,
        );
      }
    } catch (e) {
      debugPrint('[ReservationService] confirmPickup notification failed '
          '(non-critical): $e');
    }
  }

  // Provider-side rejection — no time limit (unlike user cancellation which has
  // cancellationWindowMinutes). Atomic: status update + logical refund + quantity
  // restore all in one transaction.
  Future<void> rejectReservationByProvider({
    required String reservationId,
    required String reason,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) throw Exception('يجب تسجيل الدخول أولاً');

    debugPrint('[ReservationService] rejectReservationByProvider START '
        'reservationId=$reservationId uid=$uid');

    final reservationRef =
        _firestore.collection('reservations').doc(reservationId);

    // Extracted inside the transaction; used after it completes to build the correct notification.
    bool refundApplied = false;
    num refundAmount = 0;
    String currency = 'ILS';
    String userId = '';
    String offerTitle = 'طلب طعام';
    String paymentMethod = '';

    try {
      await _firestore.runTransaction((transaction) async {
        final resSnap = await transaction.get(reservationRef);
        if (!resSnap.exists) throw Exception('الحجز غير موجود');

        final resData = resSnap.data();
        if (resData == null) throw Exception('تعذّر قراءة بيانات الحجز');

        final providerUserId = (resData['providerUserId'] as String?) ?? '';
        if (providerUserId != uid) {
          throw Exception('هذا الحجز لا يتبع مطعمك.');
        }

        final currentStatus = (resData['status'] as String?) ?? '';
        // Idempotent: fast double-reject doesn't restore quantity or issue a refund twice.
        if (currentStatus == 'cancelled') {
          throw Exception('تم إلغاء هذا الحجز مسبقاً');
        }
        if (currentStatus != 'reserved') {
          throw Exception('لا يمكن رفض هذا الطلب في حالته الحالية.');
        }

        userId = (resData['userId'] as String?) ?? '';
        offerTitle = (resData['offerTitle'] as String?) ?? 'طلب طعام';
        currency = (resData['currency'] as String? ?? 'ILS');
        paymentMethod = (resData['paymentMethod'] as String? ?? '');
        final paymentStatus = resData['paymentStatus'] as String?;
        final offerIdOnReservation = (resData['offerId'] as String?) ?? '';

        final rawTotal = resData['totalAmount'];
        final rawUnitPrice = resData['price'];
        final rawQty = resData['quantity'];
        final qty = rawQty is num ? rawQty.toInt() : 1;
        refundAmount = rawTotal is num
            ? rawTotal
            : (rawUnitPrice is num ? rawUnitPrice * qty : 0);

        // Logical refund only for online reservations that are actually paid; cash/free/pending are skipped.
        refundApplied = paymentMethod == 'online' && paymentStatus == 'paid';

        // Restore quantity on the linked offer, if it still exists.
        if (offerIdOnReservation.isNotEmpty) {
          final offerRef =
              _firestore.collection('offers').doc(offerIdOnReservation);
          final offerSnap = await transaction.get(offerRef);
          if (offerSnap.exists) {
            final offerData = offerSnap.data();
            final rawRemaining = offerData?['remainingQuantity'];
            final remaining = rawRemaining is num ? rawRemaining.toInt() : 0;
            transaction.update(offerRef, {
              'remainingQuantity': remaining + qty,
              'status': 'available',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        transaction.update(reservationRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'provider',
          'rejectedBy': uid,
          'rejectionReason': reason,
          if (refundApplied) ...{
            'paymentStatus': ReservationService.paymentStatusRefunded,
            'refundedAt': FieldValue.serverTimestamp(),
            'refundAmount': refundAmount,
            'refundReason': reason,
            'refundedBy': uid,
            // Full audit trail: both pre- and post-refund payment status.
            'paymentStatusBeforeRefund': paymentStatus,
          },
        });
        debugPrint('[ReservationService] rejectReservationByProvider '
            'TRANSACTION SUCCESS reservationId=$reservationId '
            'refundApplied=$refundApplied refundAmount=$refundAmount');
      });
    } catch (e) {
      debugPrint('[ReservationService] rejectReservationByProvider FAILED '
          'reservationId=$reservationId error=$e');
      final raw = e.toString().replaceAll('Exception: ', '').trim();
      const knownPrefixes = [
        'الحجز غير موجود',
        'تعذّر قراءة بيانات الحجز',
        'هذا الحجز لا يتبع مطعمك.',
        'تم إلغاء هذا الحجز مسبقاً',
        'لا يمكن رفض هذا الطلب في حالته الحالية.',
      ];
      for (final prefix in knownPrefixes) {
        if (raw.startsWith(prefix)) throw Exception(raw);
      }
      throw Exception('تعذّر رفض الطلب، يرجى المحاولة مرة أخرى.');
    }

    // User notification — non-critical; sent only after the transaction succeeds.
    if (userId.isEmpty) return;
    final message = paymentMethod == 'online'
        ? (refundApplied
            ? 'تم رفض طلبك وإعادة مبلغ $refundAmount $currency إلى وسيلة الدفع.'
            : 'تم رفض طلبك من المطعم ولم يتم خصم أي مبلغ.')
        : 'تم رفض طلبك من المطعم ولم يتم خصم أي مبلغ.';
    try {
      await NotificationService().sendNotification(
        userId: userId,
        title: 'تم رفض طلبك',
        message: 'تم رفض طلبك "$offerTitle" من المطعم. $message',
        type: 'reservation',
        relatedId: reservationId,
      );
    } catch (e) {
      debugPrint('[ReservationService] rejectReservationByProvider '
          'notification failed (non-critical): $e');
    }
  }

  // Records a logical refund when payment succeeded but the subsequent reservation
  // transaction failed (e.g. quantity ran out between payment and reservation start).
  // No reservation doc exists yet, so the record goes to a separate collection for later admin reconciliation.
  Future<void> recordSimulatedPaymentReversal({
    required String offerId,
    required String reason,
    required num amount,
    required String currency,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    try {
      await _firestore.collection('payment_reconciliation').add({
        'offerId': offerId,
        'userId': uid,
        'amount': amount,
        'currency': currency,
        'reason': reason,
        'refundedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[ReservationService] recordSimulatedPaymentReversal OK '
          'offerId=$offerId amount=$amount $currency reason=$reason');
    } catch (e) {
      // Log the failure explicitly so the reconciliation gap stays visible even if the write was denied.
      debugPrint('[ReservationService] recordSimulatedPaymentReversal '
          'FAILED to persist reconciliation record — offerId=$offerId '
          'amount=$amount $currency reason=$reason error=$e');
    }
  }
}
