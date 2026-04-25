import 'package:flutter/material.dart';
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
          NavigationDestination(icon: Icon(Icons.receipt_long), label: "Orders"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Restaurant Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              "Welcome, ${user.name}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("Manage surplus packages, reservations, and pickups."),
            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(child: _RestaurantStatCard(title: "Active Offers", value: "6", icon: Icons.fastfood)),
                SizedBox(width: 12),
                Expanded(child: _RestaurantStatCard(title: "Reserved", value: "12", icon: Icons.shopping_bag)),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(child: _RestaurantStatCard(title: "Picked Up", value: "30", icon: Icons.check_circle)),
                SizedBox(width: 12),
                Expanded(child: _RestaurantStatCard(title: "Revenue", value: "\$95", icon: Icons.payments)),
              ],
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
      ),
    );
  }
}

class RestaurantOffersScreen extends StatelessWidget {
  const RestaurantOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final offers = [
      {"title": "Pizza Mystery Package", "status": "Available", "price": "\$5"},
      {"title": "Bakery Box", "status": "Reserved", "price": "\$3"},
      {"title": "Lunch Meals", "status": "Available", "price": "\$7"},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("My Offers")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.fastfood, color: AppColors.primary),
              title: Text(offer["title"]!),
              subtitle: Text("Status: ${offer["status"]}"),
              trailing: Text(
                offer["price"]!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
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
              subtitle: Text("User: ${reservation["user"]} • ${reservation["status"]}"),
              trailing: IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: AppColors.secondary),
                onPressed: () {},
              ),
            ),
          );
        },
      ),
    );
  }
}

class AddOfferScreen extends StatelessWidget {
  const AddOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text("Add Offer")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: "Offer Title",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.fastfood),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: priceController,
            decoration: const InputDecoration(
              labelText: "Price",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payments),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: quantityController,
            decoration: const InputDecoration(
              labelText: "Quantity",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 14),
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Description",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.publish),
            label: const Text("Publish Offer"),
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

  @override
  Widget build(BuildContext context) {
    return _ProfileLayout(
      title: "Restaurant Profile",
      name: user.name,
      role: user.role,
      email: user.email,
      phone: user.phone,
      address: user.address,
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
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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

  const _ProfileLayout({
    required this.title,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.address,
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
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(role.toUpperCase()),
            const SizedBox(height: 24),
            _ProfileTile(icon: Icons.email, title: "Email", value: email),
            _ProfileTile(icon: Icons.phone, title: "Phone", value: phone),
            _ProfileTile(icon: Icons.location_on, title: "Address", value: address),
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