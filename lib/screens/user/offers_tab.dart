import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class OffersTab extends StatelessWidget {
  const OffersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('status', isEqualTo: 'available')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final offers = snapshot.data!.docs;

        if (offers.isEmpty) {
          return const Center(child: Text("No offers available"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final data = offers[index].data() as Map<String, dynamic>;

            final title = data['title'] ?? 'No Title';
            final description = data['description'] ?? '';
            final providerRole = data['providerRole'] ?? 'Provider';
            final pickupLocation = data['pickupLocation'] ?? 'Not specified';
            final price = data['price'] ?? 0;
            final isFree = data['isFree'] ?? price == 0;
            final remainingQuantity = data['remainingQuantity'] ?? 0;
            final currency = data['currency'] ?? 'ILS';

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

                    Text("Provider: $providerRole"),
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
                                content: Text("Reservation feature coming next"),
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