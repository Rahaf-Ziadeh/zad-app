import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/reservation_service.dart';
import '../../theme/app_colors.dart';
import 'qr_code_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final int selectedQuantity;

  const PaymentMethodScreen({
    super.key,
    required this.docId,
    required this.data,
    this.selectedQuantity = 1,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String _selectedMethod = 'cash'; // cash | online
  bool _isLoading = false;

  double get _price =>
      ((widget.data['discountPrice'] ?? widget.data['price'] ?? 0) as num)
          .toDouble();
  String get _currency => widget.data['currency'] ?? 'ILS';
  String get _title => widget.data['title'] ?? 'عرض طعام';

  Future<void> _confirm() async {
    // Extra guard against rapid double-tap, on top of button-disable during loading.
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (_selectedMethod == 'online') {
        // No reservation is created here: we open the card-entry form directly.
        // reserveOffer is only called inside _OnlinePaymentScreen after a successful payment.
        // If the user goes back, cancels, or payment fails — nothing is written to Firestore.
        debugPrint(
            '[Payment] opening card-entry screen, no reservation yet offerId=${widget.docId}');
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _OnlinePaymentScreen(
              docId: widget.docId,
              data: widget.data,
              selectedQuantity: widget.selectedQuantity,
              amount: _price,
              currency: _currency,
              offerTitle: _title,
            ),
          ),
        );
        // _OnlinePaymentScreen handles both the reservation and QR navigation; nothing more needed here.
        return;
      }

      // Cash path: reservation is created immediately — payment method/status
      // are written inside the same transaction instead of a separate update.
      debugPrint(
          '[Payment] cash flow — creating reservation immediately offerId=${widget.docId}');
      final reservationId = await ReservationService().reserveOffer(
        offerId: widget.docId,
        offerData: widget.data,
        selectedQuantity: widget.selectedQuantity,
        paymentMethod: 'cash',
        paymentStatus: 'pending_cash',
      );
      debugPrint('[Payment] cash reservation created: $reservationId');

      if (!mounted) return;
      final userId = FirebaseAuth.instance.currentUser!.uid;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QrCodeScreen(
            reservationId: reservationId,
            offerId: widget.docId,
            userId: userId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[Payment] cash reservation FAILED: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('طريقة الدفع'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('المبلغ: $_price $_currency',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text('اختر طريقة الدفع',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 14),

          _PaymentOption(
            icon: Icons.payments_outlined,
            title: 'كاش عند الاستلام',
            subtitle: 'ادفع نقداً لمزوّد الطعام عند استلام الطلب',
            color: AppColors.success,
            selected: _selectedMethod == 'cash',
            onTap: () => setState(() => _selectedMethod = 'cash'),
            badge: 'الأكثر شيوعاً',
          ),

          const SizedBox(height: 12),

          _PaymentOption(
            icon: Icons.credit_card_rounded,
            title: 'دفع إلكتروني',
            subtitle: 'ادفع الآن بالبطاقة أو المحفظة الإلكترونية',
            color: const Color(0xFF7C3AED),
            selected: _selectedMethod == 'online',
            onTap: () => setState(() => _selectedMethod = 'online'),
          ),

          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha:0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha:0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_rounded, color: AppColors.primary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'معاملاتك محمية ومشفّرة. لن يتم تأكيد الحجز إلا بعد اكتمال الدفع.',
                    style: TextStyle(
                        color: AppColors.primary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _confirm,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(
                _isLoading
                    ? 'جاري التأكيد...'
                    : _selectedMethod == 'cash'
                        ? 'تأكيد الحجز — كاش'
                        : 'متابعة للدفع الإلكتروني',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha:0.07) : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha:0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: selected ? color : AppColors.textDark)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha:0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(badge!,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                          height: 1.4)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected ? color : AppColors.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlinePaymentScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final int selectedQuantity;
  final double amount;
  final String currency;
  final String offerTitle;

  const _OnlinePaymentScreen({
    required this.docId,
    required this.data,
    required this.selectedQuantity,
    required this.amount,
    required this.currency,
    required this.offerTitle,
  });

  @override
  State<_OnlinePaymentScreen> createState() => _OnlinePaymentScreenState();
}

class _OnlinePaymentScreenState extends State<_OnlinePaymentScreen> {
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _isProcessing = false;

  // True only after the reservation is created — distinguishes "user left before
  // completion" (real abandonment, logged) from "screen closed as part of QR navigation".
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[Payment] flow started (online) offerId=${widget.docId} '
        'amount=${widget.amount} ${widget.currency}');
  }

  @override
  void dispose() {
    // Covers all exit paths (back button, swipe, programmatic close) without intercepting close.
    if (!_paymentCompleted) {
      debugPrint('[Payment] cancelled — user left the payment screen before '
          'completion offerId=${widget.docId}');
    }
    _cardController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    // Set before any await — prevents concurrent processing even on rapid double-tap.
    if (_isProcessing) {
      debugPrint('[Payment] tap ignored — already processing');
      return;
    }

    if (_cardController.text.length < 16 ||
        _expiryController.text.isEmpty ||
        _cvvController.text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال بيانات البطاقة كاملة')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    // Simulates payment gateway processing; no reservation or charge happens during this delay.
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('[Payment] succeeded (simulated) offerId=${widget.docId}');

    if (!mounted) return;

    // Extra pre-check right after simulated success; reserveOffer's internal transaction remains the final safety net.
    final existing =
        await ReservationService().getActiveReservation(widget.docId);
    if (!mounted) return;
    if (existing != null) {
      debugPrint('[Payment] reservation creation ABORTED — active '
          'reservation already exists offerId=${widget.docId}');
      setState(() => _isProcessing = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('لديك حجز نشط'),
          content: const Text(
              'لديك حجز نشط لهذا العرض بالفعل. لم يتم إنشاء حجز جديد ولم '
              'يُخصم أي مبلغ.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      debugPrint(
          '[Payment] creating reservation after successful payment offerId=${widget.docId}');
      final reservationId = await ReservationService().reserveOffer(
        offerId: widget.docId,
        offerData: widget.data,
        selectedQuantity: widget.selectedQuantity,
        paymentMethod: 'online',
        paymentStatus: 'paid',
      );
      debugPrint('[Payment] reservation created after payment: $reservationId');
      _paymentCompleted = true;

      if (!mounted) return;

      final userId = FirebaseAuth.instance.currentUser!.uid;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => QrCodeScreen(
            reservationId: reservationId,
            offerId: widget.docId,
            userId: userId,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      // Simulated payment succeeded but reservation creation failed (e.g. quantity ran out).
      // No reservation or quantity change persists in Firestore, but since the user saw a
      // "charged" state, a logical reversal is recorded in the reconciliation collection
      // for admin review — there's no real gateway to refund from.
      debugPrint(
          '[Payment] reservation creation FAILED after payment: $e');
      try {
        await ReservationService().recordSimulatedPaymentReversal(
          offerId: widget.docId,
          reason: e.toString().replaceAll('Exception: ', ''),
          amount: widget.amount * widget.selectedQuantity,
          currency: widget.currency,
        );
      } catch (_) {}
      if (!mounted) return;
      final reason = e.toString().replaceAll('Exception: ', '');
      final isSoldOut =
          reason.contains('نفدت الكمية') || reason.contains('تتجاوز المتاح');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تعذّر إتمام الحجز'),
          content: Text(
            isSoldOut
                ? 'نفدت الكمية قبل تثبيت الحجز، وتمت إعادة المبلغ.'
                : 'تم الدفع لكن تعذّر إتمام الحجز ($reason). تمت إعادة '
                    'المبلغ ولن يبقى أي مبلغ مخصوماً.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الدفع الإلكتروني'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha:0.08),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFF7C3AED).withValues(alpha:0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.credit_card_rounded,
                    color: Color(0xFF7C3AED), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.offerTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text('${widget.amount} ${widget.currency}',
                          style: const TextStyle(
                              color: Color(0xFF7C3AED),
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('بيانات البطاقة',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textDark)),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _cardController,
                    keyboardType: TextInputType.number,
                    maxLength: 16,
                    decoration: const InputDecoration(
                      labelText: 'رقم البطاقة',
                      hintText: '1234 5678 9012 3456',
                      prefixIcon: Icon(Icons.credit_card_rounded),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _expiryController,
                          keyboardType: TextInputType.number,
                          maxLength: 5,
                          decoration: const InputDecoration(
                            labelText: 'تاريخ الانتهاء',
                            hintText: 'MM/YY',
                            prefixIcon: Icon(Icons.calendar_today_rounded),
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _cvvController,
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'CVV',
                            hintText: '123',
                            prefixIcon: Icon(Icons.lock_rounded),
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('نقبل: ',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              ...[
                Icons.credit_card_rounded,
                Icons.account_balance_wallet_rounded,
                Icons.payment_rounded,
              ].map((icon) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(icon, color: AppColors.textLight, size: 22),
                  )),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED)),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.lock_rounded),
              label: Text(
                _isProcessing
                    ? 'جاري المعالجة...'
                    : 'ادفع ${widget.amount} ${widget.currency}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
