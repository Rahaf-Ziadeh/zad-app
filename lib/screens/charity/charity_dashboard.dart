import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../theme/app_colors.dart';

class CharityDashboard extends StatefulWidget {
  final AppUser user;

  const CharityDashboard({super.key, required this.user});

  @override
  State<CharityDashboard> createState() => _CharityDashboardState();
}

class _CharityDashboardState extends State<CharityDashboard> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      CharityHomeScreen(
        user: widget.user,
        onNavigate: (index) => setState(() => selectedIndex = index),
      ),
      const CharityDonationsScreen(),
      const CharityRequestsScreen(),
      const CharityHistoryScreen(),
      CharityProfileScreen(user: widget.user),
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
            icon: Icon(Icons.volunteer_activism_outlined),
            selectedIcon: Icon(Icons.volunteer_activism_rounded),
            label: "التبرعات",
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: "الطلبات",
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: "السجل",
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

class CharityHomeScreen extends StatelessWidget {
  final AppUser user;
  final ValueChanged<int> onNavigate;

  const CharityHomeScreen({
    super.key,
    required this.user,
    required this.onNavigate,
  });

  Stream<QuerySnapshot> _donationsStream() {
    return FirebaseFirestore.instance.collection('donations').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة الجمعية"),
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
                colors: [Color(0xFF10B981), Color(0xFF059669)],
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
                    Icons.volunteer_activism_rounded,
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
                        "راجعي التبرعات، وافقي عليها، وساعدي في إعادة توزيع الطعام بشكل منظم.",
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
            stream: _donationsStream(),
            builder: (context, snapshot) {
              final donations = snapshot.hasData ? snapshot.data!.docs : [];

              int pending = 0;
              int approved = 0;
              int redistributed = 0;

              for (final doc in donations) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'pending';

                if (status == 'pending') pending++;
                if (status == 'approved') approved++;
                if (status == 'redistributed') redistributed++;
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CharityStatCard(
                          title: "قيد المراجعة",
                          value: pending.toString(),
                          icon: Icons.pending_actions_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CharityStatCard(
                          title: "تم قبولها",
                          value: approved.toString(),
                          icon: Icons.check_circle_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _CharityStatCard(
                          title: "تم توزيعها",
                          value: redistributed.toString(),
                          icon: Icons.share_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: _CharityStatCard(
                          title: "عائلات مستفيدة",
                          value: "39",
                          icon: Icons.family_restroom_rounded,
                        ),
                      ),
                    ],
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
          _CharityActionTile(
            icon: Icons.assignment_rounded,
            title: "مراجعة التبرعات",
            subtitle: "قبول أو رفض التبرعات المقدمة من المستخدمين",
            onTap: () => onNavigate(1),
          ),
          _CharityActionTile(
            icon: Icons.schedule_rounded,
            title: "تنظيم الاستلام",
            subtitle: "تحديد موعد مناسب لاستلام التبرعات المقبولة",
            onTap: () => onNavigate(1),
          ),
          _CharityActionTile(
            icon: Icons.fastfood_rounded,
            title: "إعادة توزيع الفائض",
            subtitle: "نشر الطعام المتبقي ليستفيد منه المستحقون",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("ميزة إعادة التوزيع لاحقاً")),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CharityDonationsScreen extends StatelessWidget {
  const CharityDonationsScreen({super.key});

  Stream<QuerySnapshot> _donationsStream() {
    return FirebaseFirestore.instance
        .collection('donations')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _updateDonationStatus(
    BuildContext context,
    String donationId,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? "تم قبول التبرع"
                : status == 'rejected'
                    ? "تم رفض التبرع"
                    : "تم تحديث حالة التبرع",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ: $e")),
      );
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'redistributed':
        return 'تم توزيعه';
      default:
        return 'غير معروف';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.primary;
      case 'rejected':
        return Colors.red;
      case 'redistributed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("التبرعات الواردة"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _donationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("حدث خطأ أثناء تحميل التبرعات"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final donations = snapshot.data!.docs;

          if (donations.isEmpty) {
            return const Center(
              child: Text(
                "لا توجد تبرعات حالياً",
                style: TextStyle(color: AppColors.textLight),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: donations.length,
            itemBuilder: (context, index) {
              final doc = donations[index];
              final data = doc.data() as Map<String, dynamic>;

              final foodName = data['foodName'] ?? 'تبرع طعام';
              final quantity = data['quantity'] ?? 'غير محدد';
              final category = data['category'] ?? 'غير مصنف';
              final location = data['location'] ?? 'غير محدد';
              final notes = data['notes'] ?? '';
              final status = data['status'] ?? 'pending';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withOpacity(0.12),
                            child: const Icon(
                              Icons.volunteer_activism_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              foodName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              _statusLabel(status),
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: _statusColor(status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.category_outlined,
                        label: "النوع",
                        value: category,
                      ),
                      _InfoRow(
                        icon: Icons.inventory_2_outlined,
                        label: "الكمية",
                        value: quantity,
                      ),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: "الموقع",
                        value: location,
                      ),
                      if (notes.toString().isNotEmpty)
                        _InfoRow(
                          icon: Icons.notes_outlined,
                          label: "ملاحظات",
                          value: notes,
                        ),
                      const SizedBox(height: 14),
                      if (status == 'pending')
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateDonationStatus(
                                  context,
                                  doc.id,
                                  'approved',
                                ),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text("قبول"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _updateDonationStatus(
                                  context,
                                  doc.id,
                                  'rejected',
                                ),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text("رفض"),
                              ),
                            ),
                          ],
                        )
                      else if (status == 'approved')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _updateDonationStatus(
                              context,
                              doc.id,
                              'redistributed',
                            ),
                            icon: const Icon(Icons.share_rounded),
                            label: const Text("تأكيد إعادة التوزيع"),
                          ),
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

class CharityRequestsScreen extends StatelessWidget {
  const CharityRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = [
      "عائلة بحاجة إلى طرد غذائي",
      "مجموعة طلابية بحاجة لمساعدة",
      "طلب دعم غذائي طارئ",
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("طلبات المستفيدين")),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: const Icon(Icons.assignment_rounded,
                    color: AppColors.primary),
              ),
              title: Text(
                requests[index],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("الحالة: بانتظار المراجعة"),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          );
        },
      ),
    );
  }
}

class CharityHistoryScreen extends StatelessWidget {
  const CharityHistoryScreen({super.key});

  Stream<QuerySnapshot> _historyStream() {
    return FirebaseFirestore.instance.collection('donations').where('status',
        whereIn: ['approved', 'redistributed', 'rejected']).snapshots();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'redistributed':
        return 'تم توزيعه';
      default:
        return 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("سجل التبرعات"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _historyStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("حدث خطأ أثناء تحميل السجل"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final history = snapshot.data!.docs;

          if (history.isEmpty) {
            return const Center(
              child: Text(
                "لا يوجد سجل حتى الآن",
                style: TextStyle(color: AppColors.textLight),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final data = history[index].data() as Map<String, dynamic>;

              final foodName = data['foodName'] ?? 'تبرع طعام';
              final quantity = data['quantity'] ?? 'غير محدد';
              final status = data['status'] ?? '';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: const Icon(Icons.history_rounded,
                        color: AppColors.primary),
                  ),
                  title: Text(
                    foodName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      "الكمية: $quantity • الحالة: ${_statusLabel(status)}"),
                  trailing: const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CharityProfileScreen extends StatelessWidget {
  final AppUser user;

  const CharityProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return _ProfileLayout(
      title: "حساب الجمعية",
      name: user.name,
      role: "جمعية",
      email: user.email,
      phone: user.phone,
      address: user.address,
    );
  }
}

class _CharityStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _CharityStatCard({
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

class _CharityActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CharityActionTile({
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
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 10),
          const CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primary,
            child: Icon(
              Icons.volunteer_activism_rounded,
              color: Colors.white,
              size: 52,
            ),
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
