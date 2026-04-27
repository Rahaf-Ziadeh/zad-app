import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  bool isPasswordVisible = false;
  bool isLoading = false;

  File? imageFile;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<String?> uploadImage(String email) async {
    if (imageFile == null) return null;

    try {
      final safeEmail = email.replaceAll('@', '_').replaceAll('.', '_');

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$safeEmail.jpg');

      await ref.putFile(imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  Future<void> handleSignup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        address.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final imageUrl = await uploadImage(email);

      await AuthService().registerUser(
        fullName: name,
        email: email,
        password: password,
        phone: phone,
        role: selectedRole,
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully")),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Create Account")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: pickImage,
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.grey[200],
                  backgroundImage:
                      imageFile != null ? FileImage(imageFile!) : null,
                  child: imageFile == null
                      ? const Icon(
                          Icons.camera_alt,
                          size: 34,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 10),

            const Center(
              child: Text(
                "Tap to add profile picture",
                style: TextStyle(color: AppColors.textLight),
              ),
            ),

            const SizedBox(height: 24),

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
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge),
              ),
              items: const [
                DropdownMenuItem(
                  value: "individual",
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
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedRole = value);
                }
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : handleSignup,
                child: Text(
                  isLoading ? "Creating account..." : "Create Account",
                ),
              ),
            ),

            const SizedBox(height: 16),

            Center(
              child: TextButton(
                onPressed: goToLogin,
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
      ),
    );
  }
}