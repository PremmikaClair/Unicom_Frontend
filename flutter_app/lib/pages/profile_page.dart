// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import '../components/bottom_nav.dart';
import 'app_shell.dart';
import 'personal_info.dart';
import 'home_page.dart';
import 'change_username_page.dart';

class ProfilePage extends StatefulWidget {
  /// null = my profile (editable)
  final String? userId;

  /// Optional initial values (used when navigating from other pages)
  final String? initialUsername;
  final String? initialName;
  final String? initialAvatarUrl;
  final String? initialBio;

  const ProfilePage({
    super.key,
    this.userId,
    this.initialUsername,
    this.initialName,
    this.initialAvatarUrl,
    this.initialBio,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = false;
  String? _error;

  // Fake profile data placeholders
  String _username = '';
  String _name = '';
  String _avatarUrl = '';
  String _bio = '';

  void _onDockTap(BuildContext context, int index) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AppShell(initialIndex: index)),
    );
  }

  @override
  void initState() {
    super.initState();
    _username = widget.initialUsername ?? _username;
    _name = widget.initialName ?? _name;
    _avatarUrl = widget.initialAvatarUrl ?? _avatarUrl;
    _bio = widget.initialBio ?? _bio;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF006400),
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // กลับไป route เดิมที่อยู่ใต้ AppShell
          } else {
            // เผื่อกรณีเปิดมาจาก deep link หรือไม่มีอะไรให้ pop
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => AppShell(initialIndex: 0)),
            );
          }
        },
      ),

      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $_error'),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage:
                            _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                        child:
                            _avatarUrl.isEmpty ? const Icon(Icons.person, size: 48) : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _name.isNotEmpty ? _name : '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _username.isNotEmpty ? '@$_username' : '@—',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading:
                                  const Icon(Icons.edit, color: Color(0xFF006400)),
                              title: const Text('Change username'),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => ChangeUsernamePage()),
                                );
                              },
                            ),
                            const Divider(height: 1, thickness: 1),
                            ListTile(
                              leading:
                                  const Icon(Icons.person, color: Color(0xFF006400)),
                              title: const Text('Personal information'),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => PersonalInfoPage()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: BottomDockNav(
        index: -1,
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
