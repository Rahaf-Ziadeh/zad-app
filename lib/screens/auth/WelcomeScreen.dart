import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class _OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const _pages = [
  _OnboardingPage(
    title: 'مرحباً بك في زاد',
    subtitle:
        'اكتشف الطعام الفائض من المطاعم والأفراد القريبين منك وساهم في تقليل الهدر.',
    icon: Icons.eco_rounded,
    color: Color(0xFF059669),
  ),
  _OnboardingPage(
    title: 'وفّر وشارك',
    subtitle:
        'احجز وجبات مجانية أو بأسعار رمزية، أو تبرع بطعامك الفائض لمن يحتاجه.',
    icon: Icons.volunteer_activism_rounded,
    color: Color(0xFFE11D48),
  ),
  _OnboardingPage(
    title: 'معاً نقلل الهدر',
    subtitle:
        'انضم لآلاف المستخدمين والمطاعم والجمعيات في رحلة بناء مجتمع أكثر استدامة.',
    icon: Icons.people_rounded,
    color: Color(0xFF7C3AED),
  ),
];

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Each page has its own AnimationController.
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _pages.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      ),
    );

    _fades = _controllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: c, curve: Curves.easeIn),
            ))
        .toList();

    _slides = _controllers
        .map((c) => Tween<Offset>(
              begin: const Offset(0, 0.18),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutBack)))
        .toList();

    // Kick off the first page's animation immediately.
    _controllers[0].forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _controllers[index].forward(from: 0);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToLogin() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );

  void _goToSignup() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SignupScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                child: TextButton(
                  onPressed: _goToLogin,
                  child: const Text(
                    'تخطي',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return FadeTransition(
                    opacity: _fades[index],
                    child: SlideTransition(
                      position: _slides[index],
                      child: _OnboardingPageWidget(page: page),
                    ),
                  );
                },
              ),
            ),

            // ── Dots ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? _pages[i].color
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  if (isLast) ...[
                    _PrimaryButton(
                      text: 'إنشاء حساب',
                      color: const Color(0xFF059669),
                      onPressed: _goToSignup,
                    ),
                    const SizedBox(height: 12),
                    _OutlineButton(
                      text: 'تسجيل الدخول',
                      onPressed: _goToLogin,
                    ),
                  ] else ...[
                    _PrimaryButton(
                      text: 'التالي',
                      color: _pages[_currentPage].color,
                      onPressed: _nextPage,
                      icon: Icons.arrow_back_ios_rounded,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _goToLogin,
                      child: const Text(
                        'لديك حساب؟ تسجيل الدخول',
                        style:
                            TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: page.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: _pages.indexOf(page) == 0
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/zad_logo.png',
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(
                        page.icon,
                        size: 52,
                        color: page.color,
                      ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 10),
              Text(
                'زاد',
                style: TextStyle(
                  color: page.color,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
              height: 1.3,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;
  final IconData? icon;

  const _PrimaryButton({
    required this.text,
    required this.color,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.85), color],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, color: Colors.white, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _OutlineButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF059669), width: 1.6),
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF059669),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
