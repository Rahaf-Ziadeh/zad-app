import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RestaurantDashboard extends StatefulWidget {
  const RestaurantDashboard({super.key});

  @override
  State<RestaurantDashboard> createState() => _RestaurantDashboardState();
}

class _RestaurantDashboardState extends State<RestaurantDashboard> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController pickupLocationController =
      TextEditingController();

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

  Future<void> _addOffer() async {
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

    setState(() {
      isLoading = true;
    });

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

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offer added successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding offer: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteOffer(String offerId) async {
    try {
      await firestore.collection('offers').doc(offerId).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offer deleted")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting offer: $e")),
      );
    }
  }

  Future<void> _closeOffer(String offerId) async {
    try {
      await firestore.collection('offers').doc(offerId).update({
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offer closed")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error closing offer: $e")),
      );
    }
  }

  Future<void> _logout() async {
    await auth.signOut();

    if (!mounted) return;

    Navigator.pop(context);
  }

  void _showAddOfferDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Add New Offer"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildTextField(
                  controller: titleController,
                  label: "Offer Title",
                  icon: Icons.fastfood,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: descriptionController,
                  label: "Description",
                  icon: Icons.description,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: quantityController,
                  label: "Quantity",
                  icon: Icons.numbers,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: priceController,
                  label: "Price",
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: pickupLocationController,
                  label: "Pickup Location",
                  icon: Icons.location_on,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : _addOffer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Stream<QuerySnapshot> _myOffersStream() {
    return firestore
        .collection('offers')
        .where('providerUserId', isEqualTo: currentUserId)
        .where('providerRole', isEqualTo: 'restaurant')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Restaurant Dashboard"),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        onPressed: _showAddOfferDialog,
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome Restaurant",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              user?.email ?? "",
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            StreamBuilder<QuerySnapshot>(
              stream: _myOffersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text("Error: ${snapshot.error}");
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final offers = snapshot.data!.docs;

                return _buildStatCard(
                  title: "My Offers",
                  value: offers.length.toString(),
                  icon: Icons.local_offer,
                );
              },
            ),

            const SizedBox(height: 20),

            const Text(
              "My Offers",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: _myOffersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text("Error loading offers: ${snapshot.error}");
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final offers = snapshot.data!.docs;

                if (offers.isEmpty) {
                  return const Text("No offers yet. Tap + to add one.");
                }

                return Column(
                  children: offers.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    final title = data['title'] ?? 'No Title';
                    final description = data['description'] ?? '';
                    final quantity = data['quantity'] ?? 0;
                    final remainingQuantity = data['remainingQuantity'] ?? 0;
                    final price = data['price'] ?? 0;
                    final status = data['status'] ?? 'unknown';
                    final pickupLocation = data['pickupLocation'] ?? '';

                    return Card(
                      elevation: 3,
                      child: ListTile(
                        leading: const Icon(
                          Icons.restaurant_menu,
                          color: Color(0xFF059669),
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
                              _closeOffer(doc.id);
                            } else if (value == 'delete') {
                              _deleteOffer(doc.id);
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
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      elevation: 3,
      child: ListTile(
        leading: Icon(icon, size: 32, color: const Color(0xFF059669)),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF059669)),
        border: const OutlineInputBorder(),
      ),
    );
  }
}