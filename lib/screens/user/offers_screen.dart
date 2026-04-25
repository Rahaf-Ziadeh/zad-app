import 'package:flutter/material.dart';
import '../../services/offer_service.dart';
import '../../theme/app_colors.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final offers = OfferService().getOffers();

    return Scaffold(
      appBar: AppBar(title: const Text("Browse Offers")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(offer.description),
                  const SizedBox(height: 10),
                  Text("Provider: ${offer.providerName}"),
                  Text("Location: ${offer.location}"),
                  Text("Pickup: ${offer.pickupTime}"),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Chip(
                        label: Text(offer.isFree ? "FREE" : "\$${offer.price}"),
                        backgroundColor: offer.isFree
                            ? AppColors.primary.withOpacity(0.15)
                            : AppColors.secondary.withOpacity(0.15),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Reserve"),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}