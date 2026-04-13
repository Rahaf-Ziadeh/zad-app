import 'package:flutter/material.dart';
import '../services/offer_service.dart';
import '../models/offer_model.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<OfferModel> offers = OfferService().getOffers();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Offers"),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Provider: ${offer.provider}"),
                  Text("Type: ${offer.type}"),
                  Text("Price: ${offer.price}"),
                  Text("Pickup Time: ${offer.pickupTime}"),
                  Text("Location: ${offer.location}"),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Reserved: ${offer.title}"),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Reserve"),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}