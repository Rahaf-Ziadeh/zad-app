import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../user/user_dashboard.dart';
import '../admin/admin_dashboard.dart';
import '../restaurant/restaurant_dashboard.dart';
import '../charity/charity_dashboard.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool showPassword = false;
  bool isLoading = false;
  bool rememberMe = true;

  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return emailRegex.hasMatch(email);
  }

  Future<void> handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() {
      errorMessage = null;
    });

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = "يرجى إدخال البريد الإلكتروني وكلمة المرور";
      });
      return;
    }

    if (!isValidEmail(email)) {
      setState(() {
        errorMessage = "صيغة البريد الإلكتروني غير صحيحة";
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        errorMessage = "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await AuthService().login(email, password);

      if (!mounted) return;

      Widget dashboard;

      if (user.role == "admin") {
        dashboard = AdminDashboard(user: user);
      } else if (user.role == "restaurant") {
        dashboard = RestaurantDashboard(user: user);
      } else if (user.role == "charity") {
        dashboard = CharityDashboard(user: user);
      } else {
        dashboard = UserDashboard(user: user);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => dashboard),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void goToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  void forgotPassword() {
    setState(() {
      errorMessage = "ميزة استعادة كلمة المرور غير مفعّلة حالياً";
    });
  }

  void continueAsGuest() {
    setState(() {
      errorMessage = "وضع الزائر غير مفعّل حالياً";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            children: [
              const SizedBox(height: 55),
              Hero(
                tag: 'zad_logo',
                child: Image.asset(
                  'assets/images/zad_logo.png',
                  height: 90,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.eco_rounded, size: 90),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "مرحباً بعودتك",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "سجّل دخولك للمتابعة في زاد",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 34),
              _buildField(
                controller: emailController,
                hint: "البريد الإلكتروني",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: passwordController,
                hint: "كلمة المرور",
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: (value) {
                      setState(() {
                        rememberMe = value ?? false;
                      });
                    },
                  ),
                  const Text("تذكرني"),
                  const Spacer(),
                  TextButton(
                    onPressed: forgotPassword,
                    child: const Text("نسيت كلمة المرور؟"),
                  ),
                ],
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                _buildErrorBox(errorMessage!),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : handleLogin,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text("تسجيل الدخول"),
                ),
              ),
              const SizedBox(height: 25),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("أو"),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: continueAsGuest,
                  child: const Text("المتابعة كزائر"),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("ليس لديك حساب؟ "),
                  GestureDetector(
                    onTap: goToSignUp,
                    child: const Text(
                      "إنشاء حساب",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword && !showPassword,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  showPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => showPassword = !showPassword);
                },
              )
            : null,
      ),
    );
  }
}
