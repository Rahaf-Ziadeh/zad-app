import 'package:flutter/material.dart';
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

  String selectedRole = "user";
  bool isPasswordVisible = false;

  void handleSignup() {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        phoneController.text.isEmpty ||
        addressController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Account created successfully")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Create Account"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Join ZAD",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Create your account and start reducing food waste.",
              style: TextStyle(color: AppColors.textLight),
            ),
            const SizedBox(height: 24),

            _InputField(
              controller: nameController,
              label: "Full Name / Organization Name",
              icon: Icons.person,
            ),
            const SizedBox(height: 14),

            _InputField(
              controller: emailController,
              label: "Email",
              icon: Icons.email,
            ),
            const SizedBox(height: 14),

            _InputField(
              controller: phoneController,
              label: "Phone Number",
              icon: Icons.phone,
            ),
            const SizedBox(height: 14),

            _InputField(
              controller: addressController,
              label: "Address / Location",
              icon: Icons.location_on,
            ),
            const SizedBox(height: 14),

            TextField(
              controller: passwordController,
              obscureText: !isPasswordVisible,
              decoration: InputDecoration(
                labelText: "Password",
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              "Select Account Type",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.badge),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: "user",
                  child: Text("Individual User"),
                ),
                DropdownMenuItem(
                  value: "restaurant",
                  child: Text("Restaurant"),
                ),
                DropdownMenuItem(
                  value: "charity",
                  child: Text("Charitable Organization"),
                ),
                DropdownMenuItem(
                  value: "admin",
                  child: Text("Admin"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedRole = value!;
                });
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: handleSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Create Account",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text("Already have an account? Login"),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}