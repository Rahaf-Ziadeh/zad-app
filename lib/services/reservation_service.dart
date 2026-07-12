import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/offer_utils.dart';
import 'notification_service.dart';

class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── الحد الأقصى (بالدقائق) المسموح به لإلغاء الحجز بعد إنشائه — المصدر
  // الوحيد لهذا الرقم في المشروع بأكمله (تم التحقق عبر بحث شامل) ──
  static const int cancellationWindowMinutes = 10;

  // ── القيمة القانونية الوحيدة لحالة "تم استرداد المبلغ" في كل المشروع ──
  static const String paymentStatusRefunded = 'refunded';

  // ── حارس بسيط على مستوى الخدمة (ذاكرة العملية الحالية فقط) ضد إرسال
  // طلبَي حجز متزامنَين لنفس العرض من نفس المستخدم عبر ضغطتين سريعتين على
  // نفس الزر؛ يكمّل تعطيل الزر في الواجهة (UI-level) دون الحاجة لمستند قفل
  // إضافي في Firestore قد يُترَك عالقاً لو فشل حذفه لاحقاً. الحارس الفعلي
  // ضد بيع نفس الوحدة أكثر من مرة (overselling) هو معاملة Firestore أدناه
  // التي تعيد قراءة remainingQuantity دائماً من المصدر، وليس هذا الحارس ──
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

  // ── يتحقق مسبقاً (قبل فتح صحيفة اختيار الكمية/الدفع) من وجود حجز نشط
  // للمستخدم الحالي على هذا العرض تحديداً. "نشط" يعني الحالة 'reserved' —
  // وهي نفسها حالة "بانتظار الاستلام" في هذا التطبيق؛ لا توجد حالة منفصلة
  // لذلك. تُستخدم في نقاط الدخول للحجز (OfferDetailsScreen وغيرها) لعرض
  // رسالة واضحة بدل ترك المستخدم يكتشف الحجز المسبق بعد فتح نافذة الدفع ──
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
    // ── اختياريان: يُكتَبان ذرّياً ضمن نفس معاملة إنشاء الحجز (بدل تحديث
    // منفصل لاحق) حتى لا توجد لحظة يكون فيها الحجز موجوداً بحالة دفع غير
    // معروفة. المسار النقدي يمرّرهما فوراً كما كان؛ مسار الدفع الإلكتروني
    // لا يستدعي reserveOffer إلا بعد نجاح الدفع (راجع payment_method_screen) ──
    String? paymentMethod,
    String? paymentStatus,
  }) async {
    if (selectedQuantity < 1) selectedQuantity = 1;

    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

    // ── منع حجز العرض الخاص بالمستخدم نفسه ──
    final selfProviderUid =
        (offerData['providerUserId'] as String? ?? '').trim();
    if (selfProviderUid.isNotEmpty && selfProviderUid == user.uid) {
      throw Exception('لا يمكن حجز عرضك الخاص.');
    }

    // ── حارس ضد الإرسال المتكرر (نفس المستخدم + نفس العرض) على مستوى
    // الخدمة، فوق تعطيل الزر في الواجهة؛ يُضبط قبل أي await ويُزال دائماً
    // في finally مهما كانت نتيجة العملية ──
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

    debugPrint('[ReservationService] reserveOffer TRANSACTION START '
        'offerId=$offerId requestedQuantity=$selectedQuantity userId=${user.uid}');

    await _firestore.runTransaction((transaction) async {
      // ── القراءة داخل المعاملة هي مصدر الحقيقة الوحيد؛ لا تُستخدَم أي قيمة
      // كمية حُمِّلت سابقاً في الواجهة (offerData) للتحقق أو للخصم ──
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

      // التحقق من أن الكمية المطلوبة لا تتجاوز المتاح (race-condition guard)
      if (selectedQuantity > remaining) {
        debugPrint('[ReservationService] reserveOffer REJECTED — '
            'insufficient quantity (offerId=$offerId requested=$selectedQuantity '
            'remaining=$remaining)');
        throw Exception('عذرًا، نفدت الكمية قبل إتمام الحجز.');
      }

      // ── حد أقصى للكمية لكل مستخدم، إن وُجد هذا الحقل على العرض ──
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

      // تحديث الكمية وحالة العرض
      transaction.update(offerRef, {
        'remainingQuantity': afterQty,
        'status': afterQty == 0 ? 'reserved' : 'available',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── لقطة ثابتة (immutable snapshot) من بيانات العرض وقت الحجز؛ تبقى
      // القراءة/التأكيد لاحقاً (شاشة تأكيد QR) تعمل حتى لو تم حذف العرض أو
      // انتهت صلاحيته بعد إنشاء هذا الحجز — الحجز لا يعتمد على وجود العرض ──
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

    // إشعار للمستخدم — غير حرج: لا يوقف الحجز عند الفشل
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

    // إشعار لمزوّد الطعام — غير حرج: لا يوقف الحجز عند الفشل
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

  // ── إلغاء الحجز وإرجاع الكمية — عملية ذرّية بالكامل ضمن معاملة واحدة:
  // قراءة الحجز، التحقق من حالته، قراءة العرض المرتبط، تحديث حالة الحجز
  // وإرجاع الكمية، أو لا شيء منها إطلاقاً عند أي خطأ. متكرِّرة الاستدعاء
  // بأمان (idempotent): إن كان الحجز ملغى مسبقاً فلن تُعاد الكمية مرة
  // أخرى — تكفي معاملة Firestore وحدها لضمان ذلك (retry تلقائي يعيد قراءة
  // الحالة الفعلية عند أي تعارض كتابة متزامن). أي خطأ غير معروف (بما في
  // ذلك أخطاء JS-interop الخاصة بويب فلاتر التي تظهر كنص "Dart exception
  // thrown from converted Future...") يُستبدَل هنا برسالة عربية واضحة قبل
  // أن تصل لأي واجهة مستخدم ──
  Future<void> cancelReservation({
    required String reservationId,
    required String offerId,
  }) async {
    debugPrint('[ReservationService] cancelReservation START '
        'reservationId=$reservationId offerId=$offerId');

    final reservationRef =
        _firestore.collection('reservations').doc(reservationId);
    // ── حجوزات قديمة قد لا تحمل offerId صالحاً؛ في هذه الحالة يُلغى الحجز
    // فقط دون محاولة إرجاع كمية على عرض غير معروف (تجنّباً لخطأ .doc('')) ──
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

        // ── لا تُعاد الكمية مرة أخرى إن كان الحجز ملغى مسبقاً بالفعل ──
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

        // ── قيد الإلغاء: مسموح فقط خلال cancellationWindowMinutes دقيقة من
        // وقت الحجز — تُطبع كل القيم المستخدمة في هذا القرار صراحة، سواء
        // نجح التحقق أو فشل، لتأكيد (أو نفي) أن هذا هو سبب الرفض الفعلي ──
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

        // ── quantity هو الحقل الفعلي المكتوب عبر reserveOffer، مع دعم
        // selectedQuantity كاسم بديل محتمل لسجلات قديمة ──
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
      // ── لا يُبتلع أي استثناء بصمت: يُطبع كاملاً مع نوعه الحقيقي وتتبّع
      // المكدّس الكامل قبل أي تحويل لرسالة صديقة للمستخدم ──
      debugPrint('[ReservationService] cancelReservation FAILED '
          'reservationId=$reservationId offerId=$offerId '
          'errorType=${e.runtimeType} error=$e');
      debugPrint(
          '[ReservationService] cancelReservation stackTrace:\n$stackTrace');
      debugPrint('[ReservationService] cancelReservation DIAGNOSIS: '
          '${_diagnoseCancelFailure(e)}');

      // ── لا يُسمح أبداً بتسريب نص خطأ خام (كأخطاء JS-interop على الويب) —
      // فقط رسائلنا العربية المعروفة تُمرَّر كما هي؛ أي شيء آخر يُستبدل
      // برسالة عامة واحدة آمنة. التشخيص الدقيق أعلاه هو ما يُستخدم لمعرفة
      // السبب الحقيقي، وليس النص المعروض للمستخدم ──
      throw Exception(_safeCancelErrorMessage(e));
    }
  }

  // ── يحدد بالضبط أي عملية فشلت، اعتماداً على نوع الاستثناء وخصائصه —
  // يُستخدَم فقط في سجلّات التصحيح (لا يُعرض للمستخدم) ──
  static String _diagnoseCancelFailure(Object e) {
    final raw = e.toString();

    // ── رسائلنا العربية المعروفة: السبب معروف فعلياً، وليس استثناءً غير
    // متوقع (حد الإلغاء الزمني، الحجز غير موجود، محاولة إلغاء مزدوجة...) ──
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

  // ── يعيد النص العربي كما هو فقط إن كان أحد الرسائل التي نرميها نحن
  // بأنفسنا (يُطابَق ببادئة ثابتة بدل نص كامل، حتى تبقى رسالة حد الإلغاء
  // الزمني متزامنة مع cancellationWindowMinutes دون تكرار الرقم هنا) —
  // أي شيء آخر (أخطاء منصّة/JS-interop خام) يُستبدل برسالة عامة آمنة ──
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

  // ── تسمية عربية واضحة لأي حالة حجز غير متوقعة، تُستخدم في رسالة الحظر
  // العامة عند محاولة تأكيد استلام حجز ليس بحالة 'reserved' ──
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

  // ── رسالة عربية واضحة حسب حالة الدفع الإلكتروني الحالية — تُستخدم لمنع
  // تأكيد الاستلام قبل اكتمال الدفع فعلياً ──
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

  // ═════════════════════════════════════════════════════════════════════
  // تأكيد الاستلام — نقطة الدخول الوحيدة المستخدمة من كل من شاشة مسح QR
  // وشاشة التأكيد اليدوي (Part 7/8). كل التحقق النهائي والملزم يتم هنا
  // داخل معاملة Firestore واحدة؛ أي فحص مسبق في الواجهة (لعرض نافذة
  // المعاينة) هو تحسين لتجربة المستخدم فقط وليس مصدر الحقيقة.
  //
  // idempotent بالكامل: إن كانت الحالة الحالية ليست 'reserved' وقت تنفيذ
  // المعاملة (سواء بسبب ضغطة مزدوجة سريعة أو مسح متكرر لنفس رمز QR بعد
  // تأكيد ناجح من محاولة سابقة) تُرمى رسالة واضحة ولا يُكتَب أو يُرسَل أي
  // شيء آخر — فلا يمكن تكرار التأكيد أو إرسال إشعار مكرر أبداً ──
  // ═════════════════════════════════════════════════════════════════════
  Future<void> confirmPickup({
    required String reservationId,
    required String confirmationMethod, // 'qr' | 'manual'
    // ── مطلوب صراحةً من واجهة المستخدم قبل استدعاء هذه الدالة لأي حجز
    // دفعه نقدي: تأكيد أن المطعم استلم المبلغ فعلياً. يُتجاهَل لأي طريقة
    // دفع أخرى (مجاني/إلكتروني) ──
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

        // ── ملكية الحجز: يجب أن يتبع الحجز هذا المطعم بالتحديد ──
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

        // ── أمان الدفع: إلكتروني يجب أن يكون paid فعلاً؛ نقدي يتطلب تأكيداً
        // صريحاً من المطعم بأنه استلم المبلغ؛ المجاني لا يحتاج أي تحقق ──
        final paymentMethod = (data['paymentMethod'] as String?) ?? '';
        final paymentStatus = data['paymentStatus'] as String?;
        if (paymentMethod == 'online' && paymentStatus != 'paid') {
          throw Exception(_electronicPaymentBlockMessage(paymentStatus));
        }
        if (paymentMethod == 'cash' && !paymentCollectedConfirmed) {
          throw Exception('يرجى تأكيد استلام المبلغ نقداً قبل تأكيد الاستلام.');
        }

        // ── لا داعي لحماية إضافية ضد الكتابة فوق pickedUpAt سابق: التحقق
        // أعلاه من status == 'reserved' يضمن عدم الوصول لهذه النقطة إطلاقاً
        // إن كان الحجز مؤكَّداً من قبل ──
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

    // ── الإشعار يُرسَل فقط بعد نجاح المعاملة، أي مرة واحدة بالضبط لكل حجز؛
    // فشله غير حرج ولا يُبطل تأكيد الاستلام الذي تم بالفعل ──
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

  // ═════════════════════════════════════════════════════════════════════
  // رفض/إلغاء الحجز من طرف المزوّد (Part 10) — على عكس cancelReservation
  // (التي يستخدمها المستخدم ولها قيد زمني cancellationWindowMinutes)، لا
  // يوجد أي قيد زمني هنا: يحق للمطعم رفض الطلب في أي وقت قبل الاستلام.
  // العملية بالكامل ذرّية: تحديث حالة الحجز + استرداد المبلغ منطقياً (لا
  // توجد بوابة دفع حقيقية في هذا المشروع) + إرجاع الكمية، كلها ضمن نفس
  // المعاملة أو لا شيء منها إطلاقاً ──
  // ═════════════════════════════════════════════════════════════════════
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

    // ── نتائج تُحدَّد داخل المعاملة وتُستخدَم بعدها لبناء رسالة الإشعار
    // الصحيحة (نجاح الاسترداد/قيد المعالجة/دفع نقدي) ──
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
        // ── idempotent: رفض مزدوج سريع لا يُعيد الكمية أو الاسترداد مرتين ──
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

        // ── استرداد منطقي فقط للحجوزات المدفوعة إلكترونياً وبحالة paid
        // فعلاً؛ لا شيء آخر (نقدي/مجاني/غير مدفوع بعد) يحتاج استرداداً ──
        refundApplied = paymentMethod == 'online' && paymentStatus == 'paid';

        // ── إرجاع الكمية للعرض المرتبط، إن وُجد ──
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
            // ── سجلّ تدقيق كامل: حالة الدفع الأصلية والنهائية معاً ──
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

    // ── إشعار المستخدم — غير حرج، بعد نجاح المعاملة فقط (مرة واحدة بالضبط) ──
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

  // ── يسجّل استرداداً منطقياً لدفعة إلكترونية محاكاة نجحت (لا يوجد بوابة
  // دفع حقيقية في هذا المشروع) لكن الحجز نفسه تعذّر إنشاؤه بعدها مباشرة
  // (مثلاً نفدت الكمية بين نجاح الدفع وبدء معاملة الحجز). لا يوجد مستند
  // حجز بعد في هذه الحالة (المعاملة رمت استثناءً قبل إنشائه)، لذا يُسجَّل
  // الاسترداد في مجموعة مستقلة بدل تحديث حجز غير موجود، فتبقى قابلة
  // للمراجعة والتسوية الإدارية لاحقاً (Part 10/11 — سجل تسوية قابل للاسترجاع) ──
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
      // ── لا يُسمح بالفشل الصامت: يُطبع بوضوح لبقاء الأثر قابلاً للتشخيص
      // حتى لو تعذّرت الكتابة نفسها (مثلاً بسبب صلاحيات) ──
      debugPrint('[ReservationService] recordSimulatedPaymentReversal '
          'FAILED to persist reconciliation record — offerId=$offerId '
          'amount=$amount $currency reason=$reason error=$e');
    }
  }
}
