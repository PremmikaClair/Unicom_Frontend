import 'package:flutter/material.dart';
import '../components/bottom_nav.dart';
import 'app_shell.dart';
import 'allergies.dart';
import 'profile_page.dart';
import 'role_page.dart';
import 'phone_page.dart';

class PersonalInfoPage extends StatelessWidget {
  final String? userId;
  final String name;
  final String username;       // ใช้โชว์เป็น name@ku.th
  final String avatarUrl;

  const PersonalInfoPage({
    super.key,
    this.userId,
    this.name = '—',
    this.username = '—',
    this.avatarUrl = '',
  });

  static const _brandGreen = Color(0xFF556B2F);
  static const _mintBg = Color(0xFFE6F0E6);

  void _onDockTap(BuildContext context, int i) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AppShell(initialIndex: i)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PersonalInfoPage._brandGreen),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
        ),
        title: const Text(
          'Personal Information',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF006400),
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Avatar with border (ตามภาพ)
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Color(0xFF5AA7FF), width: 2),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 50, color: Color(0xFF3E3A66))
                    : null,
              ),
            ),

            const SizedBox(height: 12),

            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            // Email
            const SizedBox(height: 4),
            Text(
              '$username@ku.th',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            // Mint card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: _mintBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const _InfoTile(icon: Icons.badge_outlined, title: 'User id'),
                  const Divider(height: 0),
                  const _InfoTile(icon: Icons.person_outline, title: 'First name', chevron: true),
                  const Divider(height: 0),
                  const _InfoTile(icon: Icons.person_2_outlined, title: 'Last name', chevron: true),
                  const Divider(height: 0),
                  _InfoTile(
                    icon: Icons.phone_rounded,
                    title: 'Phone',
                    chevron: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PhonePage()),
                      );
                    },
                  ),
                  const Divider(height: 0),
                  _InfoTile(
                    icon: Icons.info_outline,
                    title: 'Allergies',
                    chevron: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AllergiesPage()),
                      );
                    },
                  ),
                  const Divider(height: 0),
                  _InfoTile(
                    icon: Icons.group_outlined,
                    title: 'Roles',
                    chevron: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RolePage()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),

      // bottom dock ตามภาพ (ถ้าไม่ต้องการ เอาออกได้)
      bottomNavigationBar: BottomDockNav(
        index: -1, // ไม่ไฮไลต์แท็บใด
        onTap: (i) => _onDockTap(context, i),
        items: const [
          BottomDockItem(icon: Icons.home_filled, label: 'Home'),
          BottomDockItem(icon: Icons.search_rounded, label: 'Explore'),
          BottomDockItem(icon: Icons.add_rounded, label: 'Add'),
          BottomDockItem(icon: Icons.event_rounded, label: 'Events'),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool chevron;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    this.chevron = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: PersonalInfoPage._brandGreen),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.black,
        ),
      ),
      trailing: chevron ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: onTap ??
          (chevron
              ? () {
                  // TODO: นำทางไปแก้ไข field นั้น ๆ
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$title (mock)')),
                  );
                }
              : null),
    );
  }
}
