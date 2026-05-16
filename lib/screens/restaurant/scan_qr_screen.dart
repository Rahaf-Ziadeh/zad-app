import 'dart:convert';
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
  bool _scanned = false;
  bool _isLoading = false;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String code) async {
    if (_scanned || _isLoading) return;
    setState(() {
      _scanned = true;
      _isLoading = true;
    });

    String reservationId, offerId, userId;

    // ── تحليل JSON (الصيغة الجديدة) أو pipe (الصيغة القديمة) ──
    try {
      final json = jsonDecode(code) as Map<String, dynamic>;
      reservationId = json['reservationId'] ?? '';
      offerId = json['offerId'] ?? '';
      userId = json['userId'] ?? '';
    } catch (_) {
      // fallback للصيغة القديمة reservationId|offerId|userId
      final parts = code.split('|');
      if (parts.length != 3) {
        _showResult(
          title: 'رمز غير صالح',
          message: 'رمز QR غير صحيح أو لا يتبع صيغة زاد.',
          isSuccess: false,
        );
        return;
      }
      reservationId = parts[0];
      offerId = parts[1];
      userId = parts[2];
    }

    if (reservationId.isEmpty || offerId.isEmpty || userId.isEmpty) {
      _showResult(
        title: 'رمز غير مكتمل',
        message: 'البيانات في رمز QR غير مكتملة.',
        isSuccess: false,
      );
      return;
    }

    try {
      final reservationRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId);

      final reservationDoc = await reservationRef.get();

      if (!reservationDoc.exists) {
        _showResult(
          title: 'الحجز غير موجود',
          message: 'لم يتم العثور على هذا الحجز في النظام.',
          isSuccess: false,
        );
        return;
      }

      final data = reservationDoc.data() as Map<String, dynamic>;
      final storedOfferId = data['offerId'] ?? '';
      final storedUserId = data['userId'] ?? '';
      final status = data['status'] ?? '';
      final offerTitle = data['offerTitle'] ?? 'طلب طعام';
      final userName = data['userName'] ?? 'مستخدم';

      if (storedOfferId != offerId || storedUserId != userId) {
        _showResult(
          title: 'بيانات غير متطابقة',
          message: 'بيانات رمز QR لا تتطابق مع بيانات الحجز.',
          isSuccess: false,
        );
        return;
      }

      if (status == 'picked_up') {
        _showResult(
          title: 'تم الاستلام مسبقاً',
          message: 'هذا الطلب تم تأكيد استلامه من قبل.',
          isSuccess: false,
        );
        return;
      }

      if (status != 'reserved') {
        _showResult(
          title: 'لا يمكن تأكيد الاستلام',
          message: 'حالة الحجز الحالية لا تسمح بتأكيد الاستلام.',
          isSuccess: false,
        );
        return;
      }

      // ── تأكيد الاستلام ──
      await reservationRef.update({
        'status': 'picked_up',
        'pickedAt': FieldValue.serverTimestamp(),
      });

      // ── إشعار للمستخدم ──
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': 'تم تأكيد الاستلام ✅',
        'message': 'تم استلام طلبك "$offerTitle" بنجاح. نتمنى لك وجبة شهية ❤️',
        'type': 'pickup',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showResult(
        title: 'تم تأكيد الاستلام',
        message: 'تم استلام "$offerTitle" للمستخدم $userName بنجاح.',
        isSuccess: true,
      );
    } catch (e) {
      _showResult(
        title: 'حدث خطأ',
        message: 'تعذر تأكيد الاستلام: $e',
        isSuccess: false,
      );
    }
  }

  void _showResult({
    required String title,
    required String message,
    required bool isSuccess,
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
                color: isSuccess
                    ? AppColors.success.withOpacity(0.12)
                    : AppColors.danger.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: isSuccess ? AppColors.success : AppColors.danger,
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
                if (isSuccess) {
                  Navigator.pop(context);
                } else {
                  setState(() => _scanned = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isSuccess ? AppColors.primary : AppColors.danger,
              ),
              child: Text(isSuccess ? 'تم' : 'إعادة المحاولة'),
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
          // ── الكاميرا ──
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

                // ── إطار QR ──
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
                          color: Colors.black.withOpacity(0.55),
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
                    color: Colors.black.withOpacity(0.5),
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

          // ── شريط سفلي ──
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

// ─────────────────────────────────────────────
// إطار الـ QR المتحرك
// ─────────────────────────────────────────────
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
          // ── زوايا الإطار ──
          ..._corners(size, cornerSize, cornerWidth, color),

          // ── خط المسح المتحرك ──
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
                        AppColors.primary.withOpacity(0.8),
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
      // أعلى يمين
      Positioned(
        top: 0,
        right: 0,
        child: _Corner(
            size: cs, strokeWidth: cw, color: color, top: true, right: true),
      ),
      // أعلى يسار
      Positioned(
        top: 0,
        left: 0,
        child: _Corner(
            size: cs, strokeWidth: cw, color: color, top: true, right: false),
      ),
      // أسفل يمين
      Positioned(
        bottom: 0,
        right: 0,
        child: _Corner(
            size: cs, strokeWidth: cw, color: color, top: false, right: true),
      ),
      // أسفل يسار
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
