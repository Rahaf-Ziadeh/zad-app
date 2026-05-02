import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final passwordController = TextEditingController();

  String selectedRole = "individual";
  String selectedCountryCode = "+970";

  bool isPasswordVisible = false;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleSignup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone =
        "$selectedCountryCode${phoneController.text.trim()}";
    final address = addressController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        address.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى تعبئة جميع الحقول")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await AuthService().registerUser(
        fullName: name,
        email: email,
        password: password,
        phone: phone,
        role: selectedRole,
        imageUrl: null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إنشاء الحساب بنجاح")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll("Exception: ", "")),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  String getRoleLabel(String role) {
    switch (role) {
      case "individual":
        return "مستخدم";
      case "restaurant":
        return "مطعم";
      case "charity":
        return "جمعية";
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("إنشاء حساب")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "انضم إلى زاد",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              "أنشئ حسابك وابدأ بالمساهمة في تقليل هدر الطعام",
              style: TextStyle(color: AppColors.textLight),
            ),

            const SizedBox(height: 25),

            _InputField(
              controller: nameController,
              label: "الاسم الكامل / اسم الجهة",
              icon: Icons.person,
            ),

            const SizedBox(height: 14),

            _InputField(
              controller: emailController,
              label: "البريد الإلكتروني",
              icon: Icons.email,
            ),

            const SizedBox(height: 14),

            /// 📞 رقم الهاتف
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "رقم الهاتف",
                hintText: "مثال: 599123456",
                prefixIcon: const Icon(Icons.phone),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCountryCode,
                      items: const [
                        DropdownMenuItem(
                            value: "+970", child: Text("🇵🇸 +970")),
                        DropdownMenuItem(
                            value: "+962", child: Text("🇯🇴 +962")),
                        DropdownMenuItem(
                            value: "+966", child: Text("🇸🇦 +966")),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedCountryCode = value!;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            _InputField(
              controller: addressController,
              label: "العنوان / الموقع",
              icon: Icons.location_on,
            ),

            const SizedBox(height: 14),

            TextField(
              controller: passwordController,
              obscureText: !isPasswordVisible,
              decoration: InputDecoration(
                labelText: "كلمة المرور",
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              "نوع الحساب",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge),
              ),
              items: [
                DropdownMenuItem(
                  value: "individual",
                  child: Text(getRoleLabel("individual")),
                ),
                DropdownMenuItem(
                  value: "restaurant",
                  child: Text(getRoleLabel("restaurant")),
                ),
                DropdownMenuItem(
                  value: "charity",
                  child: Text(getRoleLabel("charity")),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedRole = value);
                }
              },
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : handleSignup,
                child: Text(
                  isLoading ? "جاري إنشاء الحساب..." : "إنشاء حساب",
                ),
              ),
            ),

            const SizedBox(height: 16),

            Center(
              child: TextButton(
                onPressed: goToLogin,
                child: const Text("لديك حساب بالفعل؟ تسجيل الدخول"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}