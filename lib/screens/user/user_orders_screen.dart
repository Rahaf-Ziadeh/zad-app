import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class UserOrdersScreen extends StatelessWidget {
  const UserOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentOrders = ["Pizza Package", "Bread Donation"];
    final previousOrders = ["Vegetables Box", "Bakery Package"];

    return Scaffold(
      appBar: AppBar(title: const Text("My Orders")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Current Orders",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...currentOrders.map((order) => _OrderCard(title: order, status: "Reserved")),

          const SizedBox(height: 24),

          const Text("Previous Orders",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...previousOrders.map((order) => _OrderCard(title: order, status: "Picked Up")),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String title;
  final String status;

  const _OrderCard({
    required this.title,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fastfood, color: AppColors.primary),
        title: Text(title),
        subtitle: Text("Status: $status"),
        trailing: status == "Reserved"
            ? const Icon(Icons.qr_code, color: AppColors.secondary)
            : const Icon(Icons.check_circle, color: AppColors.primary),
      ),
    );
  }
}