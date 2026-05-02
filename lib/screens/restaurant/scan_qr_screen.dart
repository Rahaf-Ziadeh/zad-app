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

  void handleScan(String code) {
    if (scanned) return;
    scanned = true;

    final parts = code.split('|');

    if (parts.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid QR Code")),
      );
      scanned = false;
      return;
    }

    final reservationId = parts[0];
    final offerId = parts[1];
    final userId = parts[2];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Pickup Confirmed"),
        content: Text(
          "Reservation: $reservationId\nOffer: $offerId\nUser: $userId",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Pickup QR"),
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                final barcode = capture.barcodes.first;
                final value = barcode.rawValue;

                if (value != null) {
                  handleScan(value);
                }
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.primary,
            child: const Text(
              "Point the camera at the user's QR code",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
