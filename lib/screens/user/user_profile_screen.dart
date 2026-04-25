import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';

class UserProfileScreen extends StatelessWidget {
  final AppUser user;

  const UserProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 55),
            ),
            const SizedBox(height: 14),
            Text(user.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(user.role.toUpperCase()),
            const SizedBox(height: 24),

            _ProfileTile(icon: Icons.email, title: "Email", value: user.email),
            _ProfileTile(icon: Icons.phone, title: "Phone", value: user.phone),
            _ProfileTile(icon: Icons.location_on, title: "Address", value: user.address),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
              ),
            )
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