import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../user/user_dashboard.dart';
import '../admin/admin_dashboard.dart';
import '../restaurant/restaurant_dashboard.dart';
import '../charity/charity_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void handleLogin() async {
    final user = await AuthService().login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login to ZAD"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: handleLogin,
                child: const Text("Login"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}