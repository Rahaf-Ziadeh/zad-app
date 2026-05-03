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

  @override
  Widget build(BuildContext context) {
    final pages = [
      RestaurantHomeScreen(
        user: widget.user,
        onNavigate: (index) => setState(() => selectedIndex = index),
      ),
      const RestaurantOffersScreen(),
      const RestaurantReservationsScreen(),
      const AddOfferScreen(),
      RestaurantProfileScreen(user: widget.user),
    ];

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        indicatorColor: AppColors.primaryLight.withOpacity(0.25),
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: "الرئيسية",
          ),
          NavigationDestination(
            icon: Icon(Icons.fastfood_outlined),
            selectedIcon: Icon(Icons.fastfood_rounded),
            label: "عروضي",
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: "الطلبات",
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: "إضافة",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: "حسابي",
          ),
        ],
      ),
    );
  }
}

class RestaurantHomeScreen extends StatelessWidget {
  final AppUser user;
  final ValueChanged<int> onNavigate;

  const RestaurantHomeScreen({
    super.key,
    required this.user,
    required this.onNavigate,
  });

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
        title: const Text("لوحة المطعم"),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF10B981),
                  Color(0xFF059669),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.restaurant_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "مرحباً بعودتك",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "أنشئ باقات الطعام الفائض وتابع الحجوزات وعمليات الاستلام بسهولة.",
                        style: TextStyle(
                          color: Colors.white,
                          height: 1.5,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          StreamBuilder<QuerySnapshot>(
            stream: _myOffersStream(),
            builder: (context, snapshot) {
              final offers = snapshot.hasData ? snapshot.data!.docs : [];

              final activeOffers = offers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'available';
              }).length;

              return Row(
                children: [
                  Expanded(
                    child: _RestaurantStatCard(
                      title: "كل العروض",
                      value: offers.length.toString(),
                      icon: Icons.fastfood_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RestaurantStatCard(
                      title: "العروض النشطة",
                      value: activeOffers.toString(),
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "إجراءات سريعة",
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          _RestaurantActionTile(
            icon: Icons.add_rounded,
            title: "إنشاء باقة فائض",
            subtitle: "أضف باقة طعام بسعر مخفّض للمستخدمين",
            onTap: () => onNavigate(3),
          ),
          _RestaurantActionTile(
            icon: Icons.qr_code_scanner_rounded,
            title: "تأكيد الاستلام",
            subtitle: "تابع الطلبات وافحص رمز QR عند الاستلام",
            onTap: () => onNavigate(2),
          ),
          _RestaurantActionTile(
            icon: Icons.volunteer_activism_rounded,
            title: "التبرع لجمعية",
            subtitle: "يمكنك لاحقاً إرسال فائض الطعام للجمعيات",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("ميزة التبرع للجمعيات لاحقاً")),
              );
            },
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
        const SnackBar(content: Text("تم حذف العرض")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء حذف العرض: $e")),
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
        const SnackBar(content: Text("تم إغلاق العرض")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء إغلاق العرض: $e")),
      );
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'available':
        return 'متاح';
      case 'closed':
        return 'مغلق';
      case 'reserved':
        return 'محجوز';
      case 'picked_up':
        return 'تم الاستلام';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("عروضي"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _myOffersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("حدث خطأ أثناء تحميل العروض"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final offers = snapshot.data!.docs;

          if (offers.isEmpty) {
            return const Center(
              child: Text(
                "لا توجد عروض بعد. أضف أول باقة فائض.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final doc = offers[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'باقة طعام';
              final description = data['description'] ?? '';
              final imageUrl = data['imageUrl'] ?? '';
              final quantity = data['quantity'] ?? 0;
              final remainingQuantity = data['remainingQuantity'] ?? 0;
              final originalPrice = data['originalPrice'] ?? data['price'] ?? 0;
              final discountPrice = data['discountPrice'] ?? data['price'] ?? 0;
              final currency = data['currency'] ?? 'ILS';
              final status = data['status'] ?? 'unknown';
              final pickupLocation = data['pickupLocation'] ?? 'غير محدد';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.toString().isNotEmpty)
                      Image.network(
                        imageUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _offerPlaceholder(),
                      )
                    else
                      _offerPlaceholder(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
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
                                    child: Text("إغلاق العرض"),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text("حذف العرض"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                "$discountPrice $currency",
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "$originalPrice $currency",
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const Spacer(),
                              Chip(
                                label: Text(_statusLabel(status)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.inventory_2_outlined,
                            label: "الكمية",
                            value: "$remainingQuantity / $quantity",
                          ),
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: "مكان الاستلام",
                            value: pickupLocation,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _offerPlaceholder() {
    return Container(
      height: 150,
      width: double.infinity,
      color: AppColors.primary.withOpacity(0.08),
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 52,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class RestaurantReservationsScreen extends StatelessWidget {
  const RestaurantReservationsScreen({super.key});

  Stream<QuerySnapshot> _reservationsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return FirebaseFirestore.instance
        .collection('reservations')
        .where('providerUserId', isEqualTo: uid)
        .snapshots();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'reserved':
        return 'محجوز';
      case 'picked_up':
        return 'تم الاستلام';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Future<void> _markPickedUp(BuildContext context, String reservationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .update({
        'status': 'picked_up',
        'pickedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تأكيد الاستلام")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء تأكيد الاستلام: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الطلبات والحجوزات"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _reservationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("حدث خطأ أثناء تحميل الطلبات"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reservations = snapshot.data!.docs;

          if (reservations.isEmpty) {
            return const Center(
              child: Text(
                "لا توجد حجوزات حالياً",
                style: TextStyle(color: AppColors.textLight),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final doc = reservations[index];
              final data = doc.data() as Map<String, dynamic>;

              final offerTitle = data['offerTitle'] ?? 'طلب طعام';
              final userName = data['userName'] ?? 'مستخدم';
              final status = data['status'] ?? 'reserved';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    offerTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle:
                      Text("المستخدم: $userName • ${_statusLabel(status)}"),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.secondary,
                    ),
                    onPressed: status == 'picked_up'
                        ? null
                        : () => _markPickedUp(context, doc.id),
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
  final imageUrlController = TextEditingController();
  final quantityController = TextEditingController();
  final originalPriceController = TextEditingController();
  final discountPriceController = TextEditingController();
  final pickupLocationController = TextEditingController();

  bool isLoading = false;

  String get currentUserId => auth.currentUser!.uid;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    imageUrlController.dispose();
    quantityController.dispose();
    originalPriceController.dispose();
    discountPriceController.dispose();
    pickupLocationController.dispose();
    super.dispose();
  }

  Future<void> addOffer() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final imageUrl = imageUrlController.text.trim();
    final quantityText = quantityController.text.trim();
    final originalPriceText = originalPriceController.text.trim();
    final discountPriceText = discountPriceController.text.trim();
    final pickupLocation = pickupLocationController.text.trim();

    if (title.isEmpty ||
        description.isEmpty ||
        quantityText.isEmpty ||
        originalPriceText.isEmpty ||
        discountPriceText.isEmpty ||
        pickupLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى تعبئة جميع الحقول المطلوبة")),
      );
      return;
    }

    final quantity = int.tryParse(quantityText);
    final originalPrice = double.tryParse(originalPriceText);
    final discountPrice = double.tryParse(discountPriceText);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الكمية يجب أن تكون رقماً صحيحاً")),
      );
      return;
    }

    if (originalPrice == null || originalPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("السعر الأصلي غير صحيح")),
      );
      return;
    }

    if (discountPrice == null || discountPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("السعر بعد الخصم غير صحيح")),
      );
      return;
    }

    if (discountPrice > originalPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("السعر بعد الخصم لا يجب أن يكون أكبر من السعر الأصلي"),
        ),
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
        'imageUrl': imageUrl,
        'quantity': quantity,
        'remainingQuantity': quantity,
        'originalPrice': originalPrice,
        'discountPrice': discountPrice,
        'price': discountPrice,
        'currency': 'ILS',
        'isFree': discountPrice == 0,
        'status': 'available',
        'pickupLocation': pickupLocation,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      titleController.clear();
      descriptionController.clear();
      imageUrlController.clear();
      quantityController.clear();
      originalPriceController.clear();
      discountPriceController.clear();
      pickupLocationController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم نشر الباقة بنجاح")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء إضافة الباقة: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إضافة باقة"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            "أنشئ باقة طعام فائض",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "أضف تفاصيل الطعام، السعر قبل وبعد الخصم، ومكان الاستلام.",
            style: TextStyle(color: AppColors.textLight),
          ),
          const SizedBox(height: 22),
          _Field(
            controller: titleController,
            label: "اسم الباقة",
            icon: Icons.fastfood_rounded,
          ),
          const SizedBox(height: 14),
          _Field(
            controller: imageUrlController,
            label: "رابط صورة الباقة (اختياري)",
            icon: Icons.image_outlined,
          ),
          const SizedBox(height: 14),
          _Field(
            controller: originalPriceController,
            label: "السعر الأصلي",
            icon: Icons.price_change_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          _Field(
            controller: discountPriceController,
            label: "السعر بعد الخصم",
            icon: Icons.local_offer_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          _Field(
            controller: quantityController,
            label: "عدد الباقات المتاحة",
            icon: Icons.numbers_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          _Field(
            controller: pickupLocationController,
            label: "مكان الاستلام",
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "وصف مختصر",
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: 22),
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
                : const Icon(Icons.publish_rounded),
            label: Text(isLoading ? "جاري النشر..." : "نشر الباقة"),
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
      title: "حساب المطعم",
      name: user.name,
      role: "مطعم",
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
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

class _RestaurantActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RestaurantActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textLight),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 10),
          const CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.restaurant, color: Colors.white, size: 52),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            role,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          _ProfileTile(
              icon: Icons.email_outlined, title: "البريد", value: email),
          _ProfileTile(
              icon: Icons.phone_outlined, title: "الهاتف", value: phone),
          _ProfileTile(
            icon: Icons.location_on_outlined,
            title: "العنوان",
            value: address,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text("تسجيل الخروج"),
          ),
        ],
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
        subtitle: Text(value.isEmpty ? "غير محدد" : value),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
