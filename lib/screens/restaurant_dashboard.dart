import 'package:flutter/material.dart';

class RestaurantDashboard extends StatelessWidget {
  const RestaurantDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Restaurant Dashboard"),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          "Welcome Restaurant",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
