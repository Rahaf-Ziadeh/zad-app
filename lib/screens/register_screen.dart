import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String selectedRole = 'individual';
  bool showPassword = false;
  bool isLoading = false;

  File? _image;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(String email) async {
    if (_image == null) return null;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${email.replaceAll('@', '_').replaceAll('.', '_')}.jpg');

      await ref.putFile(_image!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  Future<void> _handleRegister() async {
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (fullName.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() {
      isLoading = true;
    });

    String? imageUrl;
    if (_image != null) {
      imageUrl = await _uploadImage(email);
    }

    final auth = AuthService();
    final result = await auth.registerUser(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
      role: selectedRole,
      imageUrl: imageUrl,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (result["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Registered successfully")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Registration failed")),
      );
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _image != null ? FileImage(_image!) : null,
                    child: _image == null
                        ? const Icon(
                            Icons.camera_alt,
                            size: 30,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "Tap to add profile picture",
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 24),

                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Join ZAD and start saving food",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),

                const SizedBox(height: 30),

                _buildTextField(
                  label: "Full Name",
                  hint: "Enter your full name",
                  controller: _fullNameController,
                  icon: Icons.person_outline,
                ),

                const SizedBox(height: 20),

                _buildTextField(
                  label: "Phone Number",
                  hint: "Enter your phone number",
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                ),

                const SizedBox(height: 20),

                _buildTextField(
                  label: "Email Address",
                  hint: "Enter your email",
                  controller: _emailController,
                  icon: Icons.email_outlined,
                ),

                const SizedBox(height: 20),

                _buildTextField(
                  label: "Password",
                  hint: "Enter your password",
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  isPassword: true,
                  showPassword: showPassword,
                  onTogglePassword: () {
                    setState(() {
                      showPassword = !showPassword;
                    });
                  },
                ),

                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: Colors.green,
                        width: 1,
                      ),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'individual',
                      child: Text('Individual'),
                    ),
                    DropdownMenuItem(
                      value: 'restaurant',
                      child: Text('Restaurant'),
                    ),
                    DropdownMenuItem(value: 'charity', child: Text('Charity')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedRole = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 24),

                _buildPrimaryButton(
                  text: isLoading ? "Creating account..." : "Register",
                  onPressed: isLoading ? null : _handleRegister,
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    GestureDetector(
                      onTap: _goToLogin,
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onTogglePassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword && !showPassword,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.green),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.green, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
