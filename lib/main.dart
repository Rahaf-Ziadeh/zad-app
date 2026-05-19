import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/user.dart';
import 'screens/auth/WelcomeScreen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/user_dashboard.dart';
import 'screens/restaurant/restaurant_dashboard.dart';
import 'screens/charity/charity_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'theme/app_theme.dart';

// ─────────────────────────────────────────────
// ⚠️ نقل هاي القيم لـ .env أو firebase_options.dart
// لا تحطها على GitHub
// ─────────────────────────────────────────────
const _firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyAvMajBi4k8xnckT0IoTkiZac0YCWfNn_k",
  appId: "1:1043940728580:android:b57764c4a71726cfe5fa51",
  messagingSenderId: "1043940728580",
  projectId: "zad-def41",
  storageBucket: "zad-def41.firebasestorage.app",
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── اتجاه الشريط العلوي ──
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // ── تأمين الاتجاه العمودي فقط ──
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: _firebaseOptions);

  runApp(const ZadApp());
}

// ─────────────────────────────────────────────
// التطبيق الرئيسي
// ─────────────────────────────────────────────
class ZadApp extends StatelessWidget {
  const ZadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'زاد',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
      home: const _AppEntry(),
    );
  }
}

// ─────────────────────────────────────────────
// نقطة الدخول — تقرر أين يذهب المستخدم
// ─────────────────────────────────────────────
class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // ── جاري التحقق ──
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // ── مش مسجّل دخول ──
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const WelcomeScreen();
        }

        final user = authSnapshot.data!;

        // ── مسجّل دخول — جلب بياناته من Firestore ──
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            // لو ما في بيانات أو حصل خطأ → Login
            if (!userSnapshot.hasData ||
                !userSnapshot.data!.exists ||
                userSnapshot.hasError) {
              return const LoginScreen();
            }

            final data = userSnapshot.data!.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'active';
            final role = data['role'] ?? 'individual';
            final isApproved = data['isApproved'] ?? false;

            // ── حساب معلّق أو مرفوض → Login مع رسالة ──
            if (status == 'suspended' || status == 'rejected') {
              return const LoginScreen();
            }

            // ── بانتظار موافقة الأدمن ──
            if ((role == 'restaurant' || role == 'charity') && !isApproved) {
              return const _PendingApprovalScreen();
            }

            final appUser = AppUser.fromMap(user.uid, data);

            // ── توجيه حسب الدور ──
            switch (role) {
              case 'admin':
                return AdminDashboard(user: appUser);
              case 'restaurant':
                return RestaurantDashboard(user: appUser);
              case 'charity':
                return CharityDashboard(user: appUser);
              default:
                return UserDashboard(user: appUser);
            }
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Splash Screen
// ─────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.eco_rounded,
                      size: 52,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'زاد',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'وفّر الطعام… وشارك الخير',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// شاشة انتظار الموافقة
// ─────────────────────────────────────────────
class _PendingApprovalScreen extends StatelessWidget {
  const _PendingApprovalScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pending_actions_rounded,
                  size: 52,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'حسابك قيد المراجعة',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'تم إنشاء حسابك بنجاح وهو الآن بانتظار مراجعة وموافقة الإدارة.\n\nستصلك إشعار فور الموافقة على حسابك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('تسجيل الخروج'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
