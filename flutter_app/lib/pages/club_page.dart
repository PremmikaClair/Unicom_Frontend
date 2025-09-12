import 'package:flutter/material.dart';
import 'home_page.dart';
import 'explore_page.dart';
import 'events_page.dart';
import 'personal_info.dart';
import 'role_page.dart';
import '../components/bottom_nav.dart';

class ClubPage extends StatefulWidget {
  const ClubPage({super.key});

  static const _brandGreen = Color(0xFF556B2F);
  static const _mintBg = Color(0xFFE6F0E6);

  @override
  State<ClubPage> createState() => _ClubPageState();
}

class _ClubPageState extends State<ClubPage> {
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
        // Add page (if any)
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
                          MaterialPageRoute(builder: (_) => const RolePage()),
                        );
                      },
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Personal Information',
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

                // Clubs card
                Container(
                  decoration: BoxDecoration(
                    color: ClubPage._mintBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'MY CLUBS',
                          style: TextStyle(
                            color: ClubPage._brandGreen,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _ClubItem(
                        role: 'สมาชิกชมรม',
                        clubName: 'สโมสรนิสิตคณะวิศวกรรมศาสตร์',
                        // Replace with your own AssetImage if available
                        avatar: const CircleAvatar(
                          radius: 22,
                          backgroundImage: NetworkImage('https://via.placeholder.com/100x100.png?text=EG'),
                          backgroundColor: Colors.white,
                        ),
                      ),

                      const Divider(height: 12),

                      _ClubItem(
                        role: 'รองหัวหน้าชมรม',
                        clubName: 'cpskclub',
                        avatar: const CircleAvatar(
                          radius: 22,
                          backgroundImage: NetworkImage('https://via.placeholder.com/100x100.png?text=CP'),
                          backgroundColor: Colors.white,
                        ),
                      ),

                      const Divider(height: 12),

                      _ClubItem(
                        role: 'หัวหน้าชมรม',
                        clubName: 'ชมรมรักษ์ช้างไทย',
                        avatar: const CircleAvatar(
                          radius: 22,
                          backgroundImage: NetworkImage('https://via.placeholder.com/100x100.png?text=EN'),
                          backgroundColor: Colors.white,
                        ),
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

class _ClubItem extends StatelessWidget {
  const _ClubItem({
    required this.role,
    required this.clubName,
    required this.avatar,
  });

  final String role;
  final String clubName;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      minLeadingWidth: 24,
      horizontalTitleGap: 12,
      leading: avatar,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            clubName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
