import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'charity_notification_service.dart';
import 'notification_service.dart';
import 'reservation_service.dart';

class CharityDataService {
  CharityDataService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ReservationService? reservationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _reservationService = reservationService ?? ReservationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // موجودة لخدمات الحجز الأخرى داخل هذا السيرفس.
  // ignore: unused_field
  final ReservationService _reservationService;

  // ─────────────────────────────────────────────
  // التبرعات قيد الانتظار
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> watchPendingDonations() {
    return _firestore
        .collection('donations')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // التبرعات المقبولة (الحالة القديمة: approved فقط)
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> watchApprovedDonations() {
    return _firestore
        .collection('donations')
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // التبرعات المقبولة — جميع مراحل دورة الحياة بعد pending/rejected
  // (approved → received → redistributed/published)
  // بدون orderBy لتجنّب فهرس مركّب — الترتيب يتم client-side
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> watchAcceptedDonations() {
    return _firestore
        .collection('donations')
        .where('status', whereIn: [
          'approved',
          'received',
          'redistributed',
          'published',
        ])
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // التبرعات التي تم استلامها وجاهزة للنشر
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> watchReceivedDonations() {
    return _firestore
        .collection('donations')
        .where('status', isEqualTo: 'received')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // التبرعات المرفوضة
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> watchRejectedDonations() {
    return _firestore
        .collection('donations')
        .where('status', isEqualTo: 'rejected')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // تحديث حالة التبرع (قبول / رفض)
  // ─────────────────────────────────────────────
  Future<void> updateDonationStatus({
    required String donationId,
    required String newStatus,
    required String userId,
    required String foodName,
  }) async {
    final currentCharityId = _auth.currentUser?.uid ?? '';

    await _firestore.collection('donations').doc(donationId).update({
      'status': newStatus,
      'donationStatus': newStatus,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': currentCharityId,
      'updatedAt': FieldValue.serverTimestamp(),
      if (newStatus == 'approved') ...{
        'charityUserId': currentCharityId,
        'acceptedAt': FieldValue.serverTimestamp(),
      },
    });

    await CharityNotificationService().sendDonationStatusNotification(
      userId: userId,
      status: newStatus,
      foodName: foodName,
      donationId: donationId,
    );
  }

  // ─────────────────────────────────────────────
  // تأكيد استلام التبرع — يغيّر الحالة إلى received
  // وينبّه المتبرع أن الجمعية استلمت التبرع
  // ─────────────────────────────────────────────
  Future<void> confirmDonationReceipt({
    required String donationId,
    required String donorUserId,
    required String foodName,
  }) async {
    final uid = _auth.currentUser!.uid;

    // جلب اسم الجمعية من مستند المستخدم لإدراجه في الإشعار
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final charityName =
        userDoc.data()?['name'] as String? ?? 'الجمعية الخيرية';

    await _firestore.collection('donations').doc(donationId).update({
      'status': 'received',
      'donationStatus': 'received',
      'receivedAt': FieldValue.serverTimestamp(),
      'receivedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (donorUserId.isNotEmpty) {
      await NotificationService().sendNotification(
        userId: donorUserId,
        title: 'تم استلام التبرع',
        message: '$charityName أكدت استلام تبرعك "$foodName".',
        type: 'donation_received',
        relatedId: donationId,
      );
    }
  }

  // ─────────────────────────────────────────────
  // سجل التبرعات — يشمل جميع حالات ما بعد pending
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> watchDonationHistory() {
    return _firestore.collection('donations').where(
      'status',
      whereIn: [
        'approved',
        'received',
        'rejected',
        'redistributed',
        'published',
      ],
    ).snapshots();
  }

  List<QueryDocumentSnapshot> filterDonationHistoryForCurrentCharity(
    List<QueryDocumentSnapshot> documents,
  ) {
    final currentCharityId = _auth.currentUser?.uid ?? '';

    final history = documents.where((document) {
      final data = document.data() as Map<String, dynamic>;

      final charityUserId = data['charityUserId']?.toString().trim() ?? '';

      final reviewedBy = data['reviewedBy']?.toString().trim() ?? '';

      final charityId = data['charityId']?.toString().trim() ?? '';

      final targetCharityId = data['targetCharityId']?.toString().trim() ?? '';

      return charityUserId == currentCharityId ||
          reviewedBy == currentCharityId ||
          charityId == currentCharityId ||
          targetCharityId == currentCharityId;
    }).toList();

    history.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final aTime = aData['createdAt'];
      final bTime = bData['createdAt'];

      final aMilliseconds =
          aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;

      final bMilliseconds =
          bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;

      return bMilliseconds.compareTo(aMilliseconds);
    });

    return history;
  }

  // ─────────────────────────────────────────────
  // الإشعارات غير المقروءة
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> watchUnreadNotifications() {
    final currentCharityId = _auth.currentUser?.uid ?? '';

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentCharityId)
        .where('isRead', isEqualTo: false)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // جميع التبرعات
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> watchAllDonations() {
    return _firestore.collection('donations').snapshots();
  }

  // ─────────────────────────────────────────────
  // إحصائيات الصفحة الرئيسية
  // ─────────────────────────────────────────────
  ({
    int pending,
    int approved,
    int redistributed,
  }) calculateHomeStatistics(
    List<QueryDocumentSnapshot> donations,
  ) {
    final currentCharityId = _auth.currentUser?.uid ?? '';

    int pending = 0;
    int approved = 0;
    int redistributed = 0;

    for (final document in donations) {
      final data = document.data() as Map<String, dynamic>;

      final status = data['status']?.toString().trim() ?? 'pending';

      final charityUserId = data['charityUserId']?.toString().trim() ?? '';

      final reviewedBy = data['reviewedBy']?.toString().trim() ?? '';

      final charityId = data['charityId']?.toString().trim() ?? '';

      final targetCharityId = data['targetCharityId']?.toString().trim() ?? '';

      if (status == 'pending') {
        if (targetCharityId == currentCharityId ||
            charityId == currentCharityId) {
          pending++;
        }

        continue;
      }

      final belongsToCurrentCharity = charityUserId == currentCharityId ||
          reviewedBy == currentCharityId ||
          charityId == currentCharityId ||
          targetCharityId == currentCharityId;

      if (!belongsToCurrentCharity) {
        continue;
      }

      if (status == 'approved') {
        approved++;
      }

      if (status == 'redistributed') {
        redistributed++;
      }
    }

    return (
      pending: pending,
      approved: approved,
      redistributed: redistributed,
    );
  }

  // ─────────────────────────────────────────────
  // جميع إشعارات الجمعية
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> watchNotifications() {
    final uid = _auth.currentUser?.uid ?? '';

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // تعليم جميع الإشعارات كمقروءة
  // ─────────────────────────────────────────────
  Future<void> markAllNotificationsAsRead(
    List<QueryDocumentSnapshot> documents,
  ) async {
    final batch = _firestore.batch();

    for (final document in documents) {
      final data = document.data() as Map<String, dynamic>;

      if (data['isRead'] != true) {
        batch.update(
          document.reference,
          {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          },
        );
      }
    }

    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // تعليم إشعار واحد كمقروء
  // ─────────────────────────────────────────────
  Future<void> markNotificationAsRead(
    String notificationId,
  ) {
    return NotificationService().markAsRead(notificationId);
  }

  // ─────────────────────────────────────────────
  // تحميل ملف الجمعية
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>?> loadCharityProfile() async {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      return null;
    }

    final document = await _firestore.collection('charities').doc(uid).get();

    return document.data();
  }

  // ─────────────────────────────────────────────
  // حفظ ملف الجمعية
  // ─────────────────────────────────────────────
  Future<void> saveCharityProfile({
    required String name,
    required String phone,
    required String address,
    required String workingHoursStart,
    required String workingHoursEnd,
  }) async {
    final uid = _auth.currentUser!.uid;

    final batch = _firestore.batch();

    batch.update(
      _firestore.collection('users').doc(uid),
      {
        'name': name,
        'fullName': name,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.set(
      _firestore.collection('charities').doc(uid),
      {
        'name': name,
        'charityName': name,
        'address': address,
        'workingHours': {
          'start': workingHoursStart,
          'end': workingHoursEnd,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // تسجيل الخروج
  // ─────────────────────────────────────────────
  Future<void> logout() {
    return _auth.signOut();
  }

  // ─────────────────────────────────────────────
  // العروض التي نشرتها الجمعية
  // مطابق للاستعلام الموجود في الكلاس الأصلي
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> watchPublishedCharityOffers() {
    final uid = _auth.currentUser?.uid ?? '';

    return _firestore
        .collection('offers')
        .where('providerUserId', isEqualTo: uid)
        .where('providerRole', isEqualTo: 'charity')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─────────────────────────────────────────────
  // إغلاق العرض
  // مطابق للكلاس الأصلي
  // ─────────────────────────────────────────────
  Future<void> closeOffer(String offerId) async {
    await _firestore.collection('offers').doc(offerId).update({
      'status': 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────
  // نشر عرض جديد من الفائض
  // هذا المنطق مطابق للكلاس الأصلي
  // ─────────────────────────────────────────────
  Future<void> publishSurplusOffer({
    required String title,
    required String description,
    required int quantity,
    required String pickupLocation,
    required double? latitude,
    required double? longitude,
    required String locationSource,
    required DateTime expiryDate,
    required String? prefillDonationId,
    required Map<String, dynamic>? prefillData,
    String imageUrl = '',
  }) async {
    final uid = _auth.currentUser!.uid;

    final userDocument = await _firestore.collection('users').doc(uid).get();

    final charityName = userDocument.data()?['name'] ?? 'جمعية خيرية';

    // ── 1. إنشاء العرض ──
    final offerReference = _firestore.collection('offers').doc();

    // صورة التبرع الأصلية — تُحفظ للمراجعة حتى لو استُبدلت
    final originalDonationImageUrl = prefillData != null
        ? (prefillData['imageUrl'] as String? ??
            prefillData['donationImageUrl'] as String? ??
            prefillData['foodImageUrl'] as String? ??
            '')
        : '';

    await offerReference.set({
      'offerId': offerReference.id,
      'providerUserId': uid,
      'providerRole': 'charity',
      'providerName': charityName,
      'offerType': 'charity_surplus',
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'remainingQuantity': quantity,
      'originalPrice': 0,
      'discountPrice': 0,
      'price': 0,
      'currency': 'ILS',
      'isFree': true,
      'status': 'available',
      'pickupLocation': pickupLocation,
      'latitude': latitude,
      'longitude': longitude,
      'hasLocation': latitude != null,
      'locationSource': latitude != null ? locationSource : 'manual',
      'expiryDate': expiryDate,
      'sourceDonationId': prefillDonationId ?? '',
      if (originalDonationImageUrl.isNotEmpty)
        'originalDonationImageUrl': originalDonationImageUrl,
      'isCash': false,
      'isOnline': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // ── 2. تحديث التبرع إذا كان العرض منشورًا من تبرع ──
    if (prefillDonationId != null) {
      await _firestore.collection('donations').doc(prefillDonationId).update({
        'status': 'redistributed',
        'donationStatus': 'redistributed',
        'isPublished': true,
        'publishedOfferId': offerReference.id,
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ── 3. إشعار المتبرع بأن تبرعه أُعيد توزيعه ──
      final donationData = prefillData;

      if (donationData != null) {
        final donorId = (donationData['userId'] as String? ??
                donationData['donorUserId'] as String? ??
                '')
            .trim();
        final foodName =
            donationData['foodName'] as String? ?? donationData['title'] as String? ?? 'تبرعك';

        if (donorId.isNotEmpty) {
          await NotificationService().sendNotification(
            userId: donorId,
            title: 'تم نشر تبرعك للمستفيدين ❤️',
            message:
                'قامت $charityName بنشر "$foodName" وإتاحته للمستفيدين. جزاك الله خيراً!',
            type: 'donation_redistributed',
            relatedId: prefillDonationId,
          );
        }
      }
    }
  }

  // ─────────────────────────────────────────────
  // فلترة التبرعات المقبولة للجمعية الحالية
  // مطابق للكلاس الأصلي
  // ─────────────────────────────────────────────
  List<QueryDocumentSnapshot> filterDonationsForCurrentCharity(
    List<QueryDocumentSnapshot> documents,
  ) {
    final currentCharityId = _auth.currentUser?.uid ?? '';

    return documents.where((document) {
      final data = document.data() as Map<String, dynamic>;

      final targetCharityId = data['targetCharityId']?.toString().trim() ?? '';

      final charityId = data['charityId']?.toString().trim() ?? '';

      final charityUserId = data['charityUserId']?.toString().trim() ?? '';

      final reviewedBy = data['reviewedBy']?.toString().trim() ?? '';

      return targetCharityId == currentCharityId ||
          charityId == currentCharityId ||
          charityUserId == currentCharityId ||
          reviewedBy == currentCharityId;
    }).toList();
  }
}
