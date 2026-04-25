import '../models/offer_model.dart';

class OfferService {
  List<Offer> getOffers() {
    return [
      Offer(
        id: "1",
        title: "Surplus Pizza Package",
        providerName: "Pizza House",
        description: "Fresh pizza slices available for pickup.",
        price: 5,
        location: "Ramallah - Al Tireh",
        pickupTime: "6:00 PM - 8:00 PM",
        isFree: false,
      ),
      Offer(
        id: "2",
        title: "Free Bread Donation",
        providerName: "Local Bakery",
        description: "Fresh bread donated for families in need.",
        price: 0,
        location: "Ramallah Center",
        pickupTime: "4:00 PM - 6:00 PM",
        isFree: true,
      ),
    ];
  }
}