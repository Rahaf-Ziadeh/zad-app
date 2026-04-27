import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';

class RestaurantDashboard extends StatefulWidget {
  final AppUser user;

  const RestaurantDashboard({super.key, required this.user});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  int selectedIndex = 0;

  late final List<Widget> pages = [
    RestaurantHomeScreen(user: widget.user),
    const RestaurantOffersScreen(),
    const RestaurantReservationsScreen(),
    const AddOfferScreen(),
    RestaurantProfileScreen(user: widget.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        indicatorColor: AppColors.secondary.withOpacity(0.2),
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: "Home"),
          NavigationDestination(icon: Icon(Icons.fastfood), label: "Offers"),
          NavigationDestination(
              icon: Icon(Icons.receipt_long), label: "Orders"),
          NavigationDestination(icon: Icon(Icons.add_circle), label: "Add"),
          NavigationDestination(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class RestaurantHomeScreen extends StatelessWidget {
  final AppUser user;

  const RestaurantHomeScreen({super.key, required this.user});

  Stream<QuerySnapshot> _myOffersStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance
        .collection('offers')
        .where('providerUserId', isEqualTo: uid)
        .where('providerRole', isEqualTo: 'restaurant')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Restaurant Dashboard"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "Welcome, ${user.name}",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            user.email,
            style: const TextStyle(color: AppColors.textLight),
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: _myOffersStream(),
            builder: (context, snapshot) {
              final offers = snapshot.hasData ? snapshot.data!.docs : [];
              final activeOffers = offers
                  .where((doc) =>
                      (doc.data() as Map<String, dynamic>)['status'] ==
                      'available')
                  .length;

              return Row(
                children: [
                  Expanded(
                    child: _RestaurantStatCard(
                      title: "My Offers",
                      value: offers.length.toString(),
                      icon: Icons.fastfood,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RestaurantStatCard(
                      title: "Active",
                      value: activeOffers.toString(),
                      icon: Icons.check_circle,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const _RestaurantActionTile(
            icon: Icons.add,
            title: "Create Surplus Package",
            subtitle: "Publish available food packages",
          ),
          const _RestaurantActionTile(
            icon: Icons.qr_code_scanner,
            title: "Confirm Pickup",
            subtitle: "Scan QR code to complete pickup",
          ),
          const _RestaurantActionTile(
            icon: Icons.volunteer_activism,
            title: "Donate to Charity",
            subtitle: "Submit donation request to a charity",
          ),
        ],
      ),
    );
  }
}

class RestaurantOffersScreen extends StatelessWidget {
  const RestaurantOffersScreen({super.key});

  Stream<QuerySnapshot> _myOffersStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return FirebaseFirestore.instance
        .collection('offers')
        .where('providerUserId', isEqualTo: uid)
        .where('providerRole', isEqualTo: 'restaurant')
        .snapshots();
  }

  Future<void> _deleteOffer(BuildContext context, String offerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offer deleted")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting offer: $e")),
      );
    }
  }

  Future<void> _closeOffer(BuildContext context, String offerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .update({
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offer closed")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error closing offer: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Offers"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _myOffersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text("Error loading offers: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final offers = snapshot.data!.docs;

          if (offers.isEmpty) {
            return const Center(
              child: Text("No offers yet. Add your first surplus package."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final doc = offers[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'No Title';
              final description = data['description'] ?? '';
              final quantity = data['quantity'] ?? 0;
              final remainingQuantity = data['remainingQuantity'] ?? 0;
              final price = data['price'] ?? 0;
              final status = data['status'] ?? 'unknown';
              final pickupLocation = data['pickupLocation'] ?? '';

              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.restaurant_menu,
                    color: AppColors.primary,
                  ),
                  title: Text(title),
                  subtitle: Text(
                    "$description\n"
                    "Quantity: $remainingQuantity / $quantity\n"
                    "Price: $price ILS\n"
                    "Pickup: $pickupLocation\n"
                    "Status: $status",
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'close') {
                        _closeOffer(context, doc.id);
                      } else if (value == 'delete') {
                        _deleteOffer(context, doc.id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'close',
                        child: Text("Close Offer"),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text("Delete Offer"),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RestaurantReservationsScreen extends StatelessWidget {
  const RestaurantReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reservations = [
      {"order": "Pizza Mystery Package", "status": "Reserved", "user": "Ahmad"},
      {"order": "Bakery Box", "status": "Picked Up", "user": "Sara"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Reservations")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reservations.length,
        itemBuilder: (context, index) {
          final reservation = reservations[index];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: AppColors.primary),
              title: Text(reservation["order"]!),
              subtitle: Text(
                  "User: ${reservation["user"]} • ${reservation["status"]}"),
              trailing: IconButton(
                icon: const Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.secondary,
                ),
                onPressed: () {},
              ),
            ),
          );
        },
      ),
    );
  }
}

class AddOfferScreen extends StatefulWidget {
  const AddOfferScreen({super.key});

  @override
  State<AddOfferScreen> createState() => _AddOfferScreenState();
}

class _AddOfferScreenState extends State<AddOfferScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final quantityController = TextEditingController();
  final priceController = TextEditingController();
  final pickupLocationController = TextEditingController();

  bool isLoading = false;

  String get currentUserId => auth.currentUser!.uid;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    priceController.dispose();
    pickupLocationController.dispose();
    super.dispose();
  }

  Future<void> addOffer() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final quantityText = quantityController.text.trim();
    final priceText = priceController.text.trim();
    final pickupLocation = pickupLocationController.text.trim();

    if (title.isEmpty ||
        description.isEmpty ||
        quantityText.isEmpty ||
        priceText.isEmpty ||
        pickupLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    final quantity = int.tryParse(quantityText);
    final price = double.tryParse(priceText);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Quantity must be a valid number")),
      );
      return;
    }

    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Price must be a valid number")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final docRef = firestore.collection('offers').doc();

      await docRef.set({
        'offerId': docRef.id,
        'providerUserId': currentUserId,
        'providerRole': 'restaurant',
        'offerType': 'restaurant_package',
        'title': title,
        'description': description,
        'quantity': quantity,
        'remainingQuantity': quantity,
        'price': price,
        'currency': 'ILS',
        'isFree': price == 0,
        'status': 'available',
        'pickupLocation': pickupLocation,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      titleController.clear();
      descriptionController.clear();
      quantityController.clear();
      priceController.clear();
      pickupLocationController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offer added successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding offer: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Offer"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: "Offer Title",
              prefixIcon: Icon(Icons.fastfood),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Price",
              prefixIcon: Icon(Icons.payments),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Quantity",
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: pickupLocationController,
            decoration: const InputDecoration(
              labelText: "Pickup Location",
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Description",
              prefixIcon: Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: isLoading ? null : addOffer,
            icon: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.publish),
            label: Text(isLoading ? "Publishing..." : "Publish Offer"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}

class RestaurantProfileScreen extends StatelessWidget {
  final AppUser user;

  const RestaurantProfileScreen({super.key, required this.user});

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileLayout(
      title: "Restaurant Profile",
      name: user.name,
      role: user.role,
      email: user.email,
      phone: user.phone,
      address: user.address,
      onLogout: () => logout(context),
    );
  }
}

class _RestaurantStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _RestaurantStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _RestaurantActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _RestaurantActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}

class _ProfileLayout extends StatelessWidget {
  final String title;
  final String name;
  final String role;
  final String email;
  final String phone;
  final String address;
  final VoidCallback onLogout;

  const _ProfileLayout({
    required this.title,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.address,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.restaurant, color: Colors.white, size: 55),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(role.toUpperCase()),
            const SizedBox(height: 24),
            _ProfileTile(icon: Icons.email, title: "Email", value: email),
            _ProfileTile(icon: Icons.phone, title: "Phone", value: phone),
            _ProfileTile(
              icon: Icons.location_on,
              title: "Address",
              value: address,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}
