import 'package:flutter/material.dart';
import 'home_page.dart';
import 'explore_page.dart';
import 'events_page.dart';
import 'personal_info.dart';
import 'profile_page.dart';
import '../components/bottom_nav.dart';

class ChangeUsernamePage extends StatefulWidget {
  const ChangeUsernamePage({super.key});

  static const _brandGreen = Color(0xFF556B2F);
  static const _mintBg = Color(0xFFE6F0E6);

  @override
  State<ChangeUsernamePage> createState() => _ChangeUsernamePageState();
}

class _ChangeUsernamePageState extends State<ChangeUsernamePage> {
  final TextEditingController _controller = TextEditingController();
  int _selectedIndex = -1;

  void _goBackToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }

  void _onDockTap(BuildContext context, int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ExplorePage()),
        );
        break;
      case 2:
        // Add action if needed
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EventsPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: _goBackToProfile,
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'setting',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 28),

                // Profile avatar
                const CircleAvatar(
                  radius: 64,
                  backgroundImage: NetworkImage(
                    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=800&auto=format&fit=crop',
                  ),
                ),
                const SizedBox(height: 16),

                // Name & email
                const Text(
                  'Dekyingtumtim naunicom',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tumtim@ku.th',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 28),

                // Card with input
                Container(
                  decoration: BoxDecoration(
                    color: ChangeUsernamePage._mintBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black26, width: 1.0),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text(
                            'Enter your new username',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'your username here',
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.black26),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: Colors.black87, width: 1.2),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF6F6F6),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Confirm button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black87,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _goBackToProfile,
                              child: const Text('Confirm'),
                            ),
                            const SizedBox(width: 16),
                            // Cancel button
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.black54),
                                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                foregroundColor: Colors.black87,
                              ),
                              onPressed: _goBackToProfile,
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
