import '../models/offer_model.dart';

class OfferService {
  List<OfferModel> getOffers() {
    return [
      OfferModel(
        title: "Surplus Meal Package",
        provider: "Al Quds Restaurant",
        price: "5 ILS",
        pickupTime: "6:00 PM - 8:00 PM",
        location: "Ramallah",
        type: "Low-price",
      ),
      OfferModel(
        title: "Fresh Bread Donation",
        provider: "Local Bakery",
        price: "Free",
        pickupTime: "4:00 PM - 6:00 PM",
        location: "Al-Bireh",
        type: "Donation",
      ),
      OfferModel(
        title: "Family Meal Box",
        provider: "Home Donor",
        price: "3 ILS",
        pickupTime: "2:00 PM - 4:00 PM",
        location: "Nablus",
        type: "Low-price",
      ),
    ];
  }
}