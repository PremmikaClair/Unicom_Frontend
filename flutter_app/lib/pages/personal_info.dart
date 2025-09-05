import 'package:flutter/material.dart';
import '../components/bottom_nav.dart';
import 'app_shell.dart';

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
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _brandGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personal Information',
          style: TextStyle(
            color: _brandGreen,
            fontWeight: FontWeight.w600,
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
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),

            // Email
            const SizedBox(height: 4),
            Text(
              '$username@ku.th',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
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
              child: const Column(
                children: [
                  _InfoTile(icon: Icons.badge_outlined, title: 'USER ID'),
                  Divider(height: 0),
                  _InfoTile(icon: Icons.person_outline, title: 'FIRST NAME', chevron: true),
                  Divider(height: 0),
                  _InfoTile(icon: Icons.person_2_outlined, title: 'LAST NAME', chevron: true),
                  Divider(height: 0),
                  _InfoTile(icon: Icons.phone_rounded, title: 'PHONE', chevron: true),
                  Divider(height: 0),
                  _InfoTile(icon: Icons.info_outline, title: 'ALLERGIES', chevron: true),
                  Divider(height: 0),
                  _InfoTile(icon: Icons.group_outlined, title: 'ROLES', chevron: true),
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

  const _InfoTile({
    required this.icon,
    required this.title,
    this.chevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.black87),
      title: Text(title),
      trailing: chevron ? const Icon(Icons.chevron_right) : null,
      onTap: chevron
          ? () {
              // TODO: นำทางไปแก้ไข field นั้น ๆ
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title (mock)')),
              );
            }
          : null,
    );
  }
}