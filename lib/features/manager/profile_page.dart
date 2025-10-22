// lib/features/manager/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← مهم ل Clipboard / ClipboardData

class ProfilePage extends StatelessWidget {
  final String name;
  final String role;
  final String phone;

  const ProfilePage({
    super.key,
    required this.name,
    required this.role,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('بياناتي')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 34,
                child: Icon(
                  role.contains('سائق') ? Icons.local_shipping : Icons.person,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                name.isEmpty ? '—' : name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            if (role.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(role, style: TextStyle(color: Colors.grey.shade700)),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('الاسم'),
                subtitle: Text(name.isEmpty ? '—' : name),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('الدور'),
                subtitle: Text(role.isEmpty ? '—' : role),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('رقم الجوال'),
                subtitle: Text(
                  phone.isEmpty ? '—' : phone,
                  textDirection: TextDirection.ltr,
                ),
                trailing: phone.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ الرقم')),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
