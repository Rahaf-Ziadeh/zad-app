import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class DonateTab extends StatefulWidget {
  const DonateTab({super.key});

  @override
  State<DonateTab> createState() => _DonateTabState();
}

class _DonateTabState extends State<DonateTab> {
  final foodNameController = TextEditingController();
  final quantityController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();

  String selectedCategory = "وجبات";
  DateTime? expiryDate;

  bool isLoading = false;

  final categories = [
    "وجبات",
    "مخبوزات",
    "خضار وفواكه",
    "معلبات",
    "حلويات",
  ];

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => expiryDate = picked);
    }
  }

  Future<void> donateFood() async {
    if (foodNameController.text.isEmpty ||
        quantityController.text.isEmpty ||
        locationController.text.isEmpty ||
        expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى تعبئة جميع الحقول")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('donations').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'foodName': foodNameController.text.trim(),
        'category': selectedCategory,
        'quantity': quantityController.text.trim(),
        'location': locationController.text.trim(),
        'expiryDate': expiryDate,
        'notes': notesController.text.trim(),
        'status': 'pending', // 🔥 مهم جداً
        'createdAt': FieldValue.serverTimestamp(),
      });

      foodNameController.clear();
      quantityController.clear();
      locationController.clear();
      notesController.clear();
      expiryDate = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إضافة التبرع بنجاح ❤️")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    foodNameController.dispose();
    quantityController.dispose();
    locationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          "تبرع بالطعام ❤️",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 6),

        const Text(
          "شارك الطعام الفائض وساهم في دعم المجتمع.",
          style: TextStyle(color: AppColors.textLight),
        ),

        const SizedBox(height: 20),

        /// 🔥 الفورم
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: foodNameController,
                  decoration: const InputDecoration(
                    labelText: "اسم الطعام",
                    prefixIcon: Icon(Icons.fastfood),
                  ),
                ),

                const SizedBox(height: 12),

                /// 🔥 Categories
                Wrap(
                  spacing: 8,
                  children: categories.map((cat) {
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selectedCategory == cat,
                      onSelected: (_) {
                        setState(() => selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: "الكمية",
                    prefixIcon: Icon(Icons.production_quantity_limits),
                  ),
                ),

                const SizedBox(height: 12),

                /// 🔥 Expiry Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    expiryDate == null
                        ? "تاريخ انتهاء الصلاحية"
                        : "${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}",
                  ),
                  onTap: pickDate,
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: "الموقع / مكان الاستلام",
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: "ملاحظات (اختياري)",
                    prefixIcon: Icon(Icons.note),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : donateFood,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("إضافة التبرع"),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          "آخر التبرعات",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('donations')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final donations = snapshot.data!.docs;

            if (donations.isEmpty) {
              return const Text("لا يوجد تبرعات بعد");
            }

            return Column(
              children: donations.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.red),
                    title: Text(data['foodName'] ?? ''),
                    subtitle: Text("${data['quantity']} • ${data['category']}"),
                    trailing: Text(
                      data['status'] == 'pending' ? "قيد المراجعة" : "متاح",
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
