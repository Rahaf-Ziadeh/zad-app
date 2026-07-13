import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../theme/app_colors.dart';
import 'pickup_confirmation_sheet.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  bool _scanned = false;
  bool _isLoading = false;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Decodes the QR payload only — no Firestore writes here. Preserves both
  // QR formats (new JSON and legacy pipe-delimited) so previously issued
  // codes stay valid.
  ({String reservationId, String offerId, String userId})? _decodeQr(
      String code) {
    try {
      final json = jsonDecode(code) as Map<String, dynamic>;
      return (
        reservationId: (json['reservationId'] ?? '').toString(),
        offerId: (json['offerId'] ?? '').toString(),
        userId: (json['userId'] ?? '').toString(),
      );
    } catch (_) {
      final parts = code.split('|');
      if (parts.length != 3) return null;
      return (reservationId: parts[0], offerId: parts[1], userId: parts[2]);
    }
  }

  Future<void> _handleScan(String code) async {
    if (_scanned || _isLoading) return;
    setState(() {
      _scanned = true;
      _isLoading = true;
    });

    final decoded = _decodeQr(code);
    if (decoded == null) {
      _showResult(
        title: 'رمز غير صالح',
        message: 'رمز QR غير صحيح أو لا يتبع صيغة زاد.',
      );
      return;
    }
    final reservationId = decoded.reservationId;
    final offerId = decoded.offerId;
    final userId = decoded.userId;

    if (reservationId.isEmpty || offerId.isEmpty || userId.isEmpty) {
      _showResult(
        title: 'رمز غير مكتمل',
        message: 'البيانات في رمز QR غير مكتملة.',
      );
      return;
    }

    // Read-only fetch to populate the preview sheet — no transaction here.
    // Authoritative validation and write happen inside
    // ReservationService.confirmPickup, not at scan time.
    Map<String, dynamic>? data;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .get();
      data = doc.exists ? doc.data() : null;
    } catch (e) {
      _showResult(
        title: 'حدث خطأ',
        message: 'تعذر قراءة بيانات الحجز: $e',
      );
      return;
    }

    if (data == null) {
      _showResult(
        title: 'رمز QR غير صالح',
        message: 'رمز QR غير صالح أو أن الحجز غير موجود.',
      );
      return;
    }

    // Extra check: QR payload (offerId/userId) must match the stored
    // reservation, on top of the standard ownership/status validation.
    final storedOfferId = (data['offerId'] as String?) ?? '';
    final storedUserId = (data['userId'] as String?) ?? '';
    if (storedOfferId != offerId || storedUserId != userId) {
      _showResult(
        title: 'بيانات غير متطابقة',
        message: 'بيانات رمز QR لا تتطابق مع بيانات الحجز.',
      );
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final validationError =
        validateReservationForPickupPreview(data, currentUid);
    if (validationError != null) {
      _showResult(
        title: 'لا يمكن المتابعة',
        message: validationError,
      );
      return;
    }

    // Stop loading before opening the sheet — the sheet has its own
    // loading/confirm indicators.
    setState(() => _isLoading = false);

    if (!mounted) return;
    final confirmed = await showPickupConfirmationSheet(
      context,
      reservationId: reservationId,
      data: data,
      confirmationMethod: 'qr',
    );

    if (!mounted) return;
    if (confirmed) {
      _controller.stop();
      if (Navigator.canPop(context)) Navigator.pop(context);
    } else {
      // Sheet dismissed without confirming — allow scanning another code.
      setState(() => _scanned = false);
    }
  }

  // Only for pre-sheet errors (invalid QR, reservation not found, wrong restaurant).
  // Successful pickup confirmation is reported by the preview sheet via SnackBar after closing.
  void _showResult({
    required String title,
    required String message,
  }) {
    if (!mounted) return;
    setState(() => _isLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        title: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textLight, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _scanned = false);
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'مسح رمز الاستلام',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
            tooltip: 'الفلاش',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final value = capture.barcodes.first.rawValue;
                    if (value != null) _handleScan(value);
                  },
                ),

                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QrFrame(scanned: _scanned),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'وجّه الكاميرا نحو رمز QR',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Loading overlay ──
                if (_isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'جاري التحقق...',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: AppColors.primary,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'اطلب من المستخدم إظهار رمز QR من شاشة طلباته',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrFrame extends StatefulWidget {
  final bool scanned;
  const _QrFrame({required this.scanned});

  @override
  State<_QrFrame> createState() => _QrFrameState();
}

class _QrFrameState extends State<_QrFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scanLine;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLine = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 240.0;
    const cornerSize = 28.0;
    const cornerWidth = 4.0;
    final color = widget.scanned ? AppColors.success : Colors.white;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ..._corners(size, cornerSize, cornerWidth, color),

          if (!widget.scanned)
            AnimatedBuilder(
              animation: _scanLine,
              builder: (_, __) => Positioned(
                top: _scanLine.value * (size - 4),
                left: 20,
                right: 20,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.primary.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _corners(double size, double cs, double cw, Color color) {
    return [
      // top-right
      Positioned(
        top: 0,
        right: 0,
        child: _Corner(
            size: cs, strokeWidth: cw, color: color, top: true, right: true),
      ),
      // top-left
      Positioned(
        top: 0,
        left: 0,
        child: _Corner(
            size: cs, strokeWidth: cw, color: color, top: true, right: false),
      ),
      // bottom-right
      Positioned(
        bottom: 0,
        right: 0,
        child: _Corner(
            size: cs, strokeWidth: cw, color: color, top: false, right: true),
      ),
      // bottom-left
      Positioned(
        bottom: 0,
        left: 0,
        child: _Corner(
            size: cs, strokeWidth: cw, color: color, top: false, right: false),
      ),
    ];
  }
}

class _Corner extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color color;
  final bool top;
  final bool right;

  const _Corner({
    required this.size,
    required this.strokeWidth,
    required this.color,
    required this.top,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          strokeWidth: strokeWidth,
          top: top,
          right: right,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool top;
  final bool right;

  _CornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.top,
    required this.right,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    if (top && right) {
      canvas.drawLine(Offset(w, 0), Offset(0, 0), paint);
      canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
    } else if (top && !right) {
      canvas.drawLine(Offset(0, 0), Offset(w, 0), paint);
      canvas.drawLine(Offset(0, 0), Offset(0, h), paint);
    } else if (!top && right) {
      canvas.drawLine(Offset(w, h), Offset(0, h), paint);
      canvas.drawLine(Offset(w, h), Offset(w, 0), paint);
    } else {
      canvas.drawLine(Offset(0, h), Offset(w, h), paint);
      canvas.drawLine(Offset(0, h), Offset(0, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}
