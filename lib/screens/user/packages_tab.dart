import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class PackagesTab extends StatelessWidget {
  const PackagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('offerType', isEqualTo: 'restaurant_package')
          .where('status', isEqualTo: 'available')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final packages = snapshot.data!.docs;

        if (packages.isEmpty) {
          return const Center(child: Text("No packages available"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: packages.length,
          itemBuilder: (context, index) {
            final data = packages[index].data() as Map<String, dynamic>;

            final title = data['title'] ?? 'No Title';
            final description = data['description'] ?? '';
            final price = data['price'] ?? 0;
            final currency = data['currency'] ?? 'ILS';
            final pickupLocation = data['pickupLocation'] ?? 'Not specified';
            final remainingQuantity = data['remainingQuantity'] ?? 0;
            final isFree = data['isFree'] ?? price == 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(description),
                    const SizedBox(height: 10),
                    Text("Location: $pickupLocation"),
                    Text("Available Quantity: $remainingQuantity"),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Chip(
                          label: Text(isFree ? "FREE" : "$price $currency"),
                          backgroundColor: isFree
                              ? AppColors.primary.withOpacity(0.15)
                              : AppColors.secondary.withOpacity(0.15),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Package reservation coming next"),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Reserve"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}