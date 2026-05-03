import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/app_colors.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  bool scanned = false;
  bool isLoading = false;

  Future<void> handleScan(String code) async {
    if (scanned || isLoading) return;

    setState(() {
      scanned = true;
      isLoading = true;
    });

    final parts = code.split('|');

    if (parts.length != 3) {
      _showResultDialog(
        title: "رمز غير صالح",
        message: "رمز QR غير صحيح أو لا يتبع صيغة زاد.",
        isSuccess: false,
      );
      return;
    }

    final reservationId = parts[0];
    final offerId = parts[1];
    final userId = parts[2];

    try {
      final reservationRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId);

      final reservationDoc = await reservationRef.get();

      if (!reservationDoc.exists) {
        _showResultDialog(
          title: "الحجز غير موجود",
          message: "لم يتم العثور على هذا الحجز في النظام.",
          isSuccess: false,
        );
        return;
      }

      final data = reservationDoc.data() as Map<String, dynamic>;
      final storedOfferId = data['offerId'] ?? '';
      final storedUserId = data['userId'] ?? '';
      final status = data['status'] ?? '';

      if (storedOfferId != offerId || storedUserId != userId) {
        _showResultDialog(
          title: "بيانات غير متطابقة",
          message: "بيانات رمز QR لا تتطابق مع بيانات الحجز.",
          isSuccess: false,
        );
        return;
      }

      if (status == 'picked_up') {
        _showResultDialog(
          title: "تم الاستلام مسبقاً",
          message: "هذا الطلب تم تأكيد استلامه من قبل.",
          isSuccess: false,
        );
        return;
      }

      if (status != 'reserved') {
        _showResultDialog(
          title: "لا يمكن تأكيد الاستلام",
          message: "حالة الحجز الحالية لا تسمح بتأكيد الاستلام.",
          isSuccess: false,
        );
        return;
      }

      await reservationRef.update({
        'status': 'picked_up',
        'pickedAt': FieldValue.serverTimestamp(),
      });

      _showResultDialog(
        title: "تم تأكيد الاستلام",
        message: "تم تأكيد استلام الطلب بنجاح.",
        isSuccess: true,
      );
    } catch (e) {
      _showResultDialog(
        title: "حدث خطأ",
        message: "تعذر تأكيد الاستلام: $e",
        isSuccess: false,
      );
    }
  }

  void _showResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    if (!mounted) return;

    setState(() => isLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_outline,
              color: isSuccess ? AppColors.primary : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              if (isSuccess) {
                Navigator.pop(context);
              } else {
                setState(() {
                  scanned = false;
                });
              }
            },
            child: Text(isSuccess ? "تم" : "إعادة المحاولة"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مسح رمز الاستلام"),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    final barcode = capture.barcodes.first;
                    final value = barcode.rawValue;

                    if (value != null) {
                      handleScan(value);
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                if (isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.35),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            color: AppColors.primary,
            child: const Text(
              "وجّه الكاميرا نحو رمز QR الخاص بالمستخدم لتأكيد الاستلام",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
