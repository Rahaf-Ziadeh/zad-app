import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../user/user_dashboard.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../admin/admin_dashboard.dart';
import '../charity/charity_dashboard.dart';
import '../restaurant/restaurant_dashboard.dart';
import 'signup_screen.dart';

enum _BlockType { none, pending, rejected }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  bool _rememberMe = true;
  String? _errorMessage;
  _BlockType _blockType = _BlockType.none;

  bool _resendLoading = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── validation ──
  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!regex.hasMatch(v.trim())) return 'صيغة البريد الإلكتروني غير صحيحة';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.trim().isEmpty) return 'يرجى إدخال كلمة المرور';
    if (v.trim().length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    return null;
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
      _blockType = _BlockType.none;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthService().login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      Widget dashboard;
      switch (user.role) {
        case 'admin':
          dashboard = AdminDashboard(user: user);
          break;
        case 'restaurant':
          dashboard = RestaurantDashboard(user: user);
          break;
        case 'charity':
          dashboard = CharityDashboard(user: user);
          break;
        default:
          dashboard = UserDashboard(user: user);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => dashboard),
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceAll('Exception: ', '');
      if (raw.startsWith('PENDING:')) {
        setState(() {
          _blockType = _BlockType.pending;
          _errorMessage = raw.substring(8);
        });
      } else if (raw.startsWith('REJECTED:')) {
        setState(() {
          _blockType = _BlockType.rejected;
          _errorMessage = raw.substring(9);
        });
      } else {
        setState(() {
          _blockType = _BlockType.none;
          _errorMessage = raw;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage =
          'أدخل بريدك الإلكتروني أولاً ثم اضغط "نسيت كلمة المرور"');
      return;
    }

    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!regex.hasMatch(email)) {
      setState(() => _errorMessage = 'صيغة البريد الإلكتروني غير صحيحة');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _errorMessage = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال رابط إعادة التعيين إلى $email'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'تعذر إرسال البريد. تحقق من العنوان.');
    }
  }

  Future<void> _resendVerification() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage =
          'أدخل البريد الإلكتروني وكلمة المرور لإعادة إرسال رابط التحقق');
      return;
    }

    setState(() {
      _resendLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) throw Exception('تعذر تسجيل الدخول');

      await user.reload();

      if (user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() =>
            _errorMessage = 'بريدك الإلكتروني مُحقق بالفعل. أعد تسجيل الدخول.');
        return;
      }

      await user.sendEmailVerification();
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      setState(() => _resendCooldown = 60);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال رابط التحقق ✅ تحقق من بريدك الإلكتروني'),
          backgroundColor: AppColors.primary,
        ),
      );

      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _resendCooldown--;
          if (_resendCooldown <= 0) t.cancel();
        });
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _resendAuthError(e.code));
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _resendLoading = false);
    }
  }

  String _resendAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني';
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور غير صحيحة';
      case 'too-many-requests':
        return 'محاولات كثيرة، انتظر قليلاً وأعد المحاولة';
      case 'network-request-failed':
        return 'تحقق من اتصال الإنترنت';
      default:
        return 'حدث خطأ، يرجى المحاولة مرة أخرى';
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInAnonymously();

      if (!mounted) return;

      final guestUser = AppUser(
        uid: credential.user!.uid,
        name: 'زائر',
        email: '',
        role: 'guest',
        phone: '',
        address: '',
        status: 'active',
        isApproved: true,
        isSuspended: false,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserDashboard(user: guestUser),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 48),

                    Hero(
                      tag: 'zad_logo',
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.eco_rounded,
                            size: 44, color: AppColors.primary),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'مرحباً بعودتك 👋',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'سجّل دخولك للمتابعة في زاد',
                      style:
                          TextStyle(color: AppColors.textLight, fontSize: 14),
                    ),

                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      validator: _validatePassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.9,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) =>
                                setState(() => _rememberMe = v ?? false),
                            activeColor: AppColors.primary,
                          ),
                        ),
                        const Text('تذكرني',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textLight)),
                        const Spacer(),
                        TextButton(
                          onPressed: _forgotPassword,
                          child: const Text(
                            'نسيت كلمة المرور؟',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      if (_blockType == _BlockType.pending)
                        _PendingBox(message: _errorMessage!)
                      else if (_blockType == _BlockType.rejected)
                        _RejectedBox(message: _errorMessage!)
                      else
                        _ErrorBox(message: _errorMessage!),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('تسجيل الدخول',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 12),

                    _resendCooldown > 0
                        ? Text(
                            'إعادة الإرسال بعد $_resendCooldown ثانية',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : TextButton.icon(
                            onPressed:
                                _resendLoading ? null : _resendVerification,
                            icon: _resendLoading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.mark_email_unread_outlined,
                                    size: 16),
                            label: const Text(
                              'إعادة إرسال رابط التحقق',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),

                    const SizedBox(height: 16),

                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('أو',
                              style: TextStyle(
                                  color: AppColors.textLight, fontSize: 13)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _continueAsGuest,
                        icon:
                            const Icon(Icons.person_outline_rounded, size: 20),
                        label: const Text('المتابعة كزائر',
                            style: TextStyle(fontSize: 15)),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('ليس لديك حساب؟ ',
                            style: TextStyle(
                                color: AppColors.textLight, fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignupScreen()),
                          ),
                          child: const Text(
                            'إنشاء حساب',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBox extends StatelessWidget {
  final String message;
  const _PendingBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              const Text(
                'بانتظار الموافقة',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF78350F),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ستصلك إشعاراً فور مراجعة طلبك من قِبَل الإدارة.',
            style: TextStyle(
              color: Color(0xFF92400E),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectedBox extends StatelessWidget {
  final String message;
  const _RejectedBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_rounded,
                  color: Color(0xFFDC2626), size: 20),
              const SizedBox(width: 8),
              const Text(
                'تم رفض الطلب',
                style: TextStyle(
                  color: Color(0xFF991B1B),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF7F1D1D),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'يمكنك التواصل مع الإدارة أو إنشاء حساب جديد بمعلومات صحيحة.',
            style: TextStyle(
              color: Color(0xFF991B1B),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
