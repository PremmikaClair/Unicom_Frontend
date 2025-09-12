import 'package:flutter/material.dart';
import 'home_page.dart';
import 'explore_page.dart';
import 'events_page.dart';
import 'personal_info.dart';
import 'club_page.dart';
import '../components/bottom_nav.dart';

class RolePage extends StatefulWidget {
  const RolePage({super.key});

  static const _brandGreen = Color(0xFF556B2F);
  static const _mintBg = Color(0xFFE6F0E6);

  @override
  State<RolePage> createState() => _RolePageState();
}

class _RoleTextStyles {
  static const header = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 24,
    color: Colors.black87,
  );
  static const name = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 24,
    color: Colors.black87,
  );
  static const email = TextStyle(
    fontSize: 16,
    color: Colors.grey,
  );
  static const sectionTitle = TextStyle(
    color: RolePage._brandGreen,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );
  static const listTitle = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: Colors.black,
  );
}

class _RolePageState extends State<RolePage> {
  int _selectedIndex = -1; // not highlighting any tab

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
        // Add page
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
                // Header with back button and title
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PersonalInfoPage()),
                        );
                      },
                    ),
                    const Expanded(
                      child: Center(
                        child: Text('Personal Information', style: _RoleTextStyles.header),
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
                  style: _RoleTextStyles.name,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tumtim@ku.th',
                  textAlign: TextAlign.center,
                  style: _RoleTextStyles.email,
                ),

                const SizedBox(height: 28),

                // Roles card
                Container(
                  decoration: BoxDecoration(
                    color: RolePage._mintBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: const Text('My role', style: _RoleTextStyles.sectionTitle),
                      ),
                      const SizedBox(height: 12),

                      // STUDENT
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        minLeadingWidth: 24,
                        horizontalTitleGap: 10,
                        leading: const Icon(Icons.person_outline, size: 28, color: Colors.black),
                        title: const Text('Student', style: _RoleTextStyles.listTitle),
                        // no trailing chevron for current role
                        onTap: () {},
                      ),

                      const Divider(height: 8),

                      // CLUBS
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        minLeadingWidth: 24,
                        horizontalTitleGap: 10,
                        leading: const Icon(Icons.groups_outlined, size: 28, color: Colors.black),
                        title: const Text('Clubs', style: _RoleTextStyles.listTitle),
                        trailing: const Icon(Icons.chevron_right, color: Colors.black),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ClubPage()),
                          );
                        },
                      ),
                    ],
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