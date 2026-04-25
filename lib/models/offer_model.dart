class Offer {
  final String id;
  final String title;
  final String providerName;
  final String description;
  final double price;
  final String location;
  final String pickupTime;
  final bool isFree;

  Offer({
    required this.id,
    required this.title,
    required this.providerName,
    required this.description,
    required this.price,
    required this.location,
    required this.pickupTime,
    required this.isFree,
  });
}