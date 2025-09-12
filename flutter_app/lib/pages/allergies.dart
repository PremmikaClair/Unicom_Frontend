import 'package:flutter/material.dart';
import 'food_allergies_page.dart';
import 'health_allergies.dart';
import 'home_page.dart';
import 'explore_page.dart';
import 'events_page.dart';
import 'personal_info.dart';
import '../components/bottom_nav.dart';
import 'app_shell.dart';


class AllergiesPage extends StatefulWidget {
  const AllergiesPage({super.key});

  @override
  State<AllergiesPage> createState() => _AllergiesPageState();

  static const _brandGreen = Color(0xFF556B2F);
  static const _mintBg = Color(0xFFE6F0E6);
}

class _AllergiesPageState extends State<AllergiesPage> {
  int _selectedIndex = 2;

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
    });

    switch(index) {
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
        // Current page: AllergiesPage
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EventsPage()),
        );
        break;
    }
  }

  void _onDockTap(BuildContext context, int index) {
    if (index == _selectedIndex) return;
    switch(index) {
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
        // Current page: AllergiesPage
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PersonalInfoPage()),
            );
          },
        ),
        title: const Text(
          "Personal Information",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AllergiesPage._brandGreen,
                  child: const Icon(Icons.person, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Text(
                      "Username",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "user@example.com",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Container(
                  decoration: BoxDecoration(
                    color: AllergiesPage._mintBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          "Allergies",
                          style: TextStyle(
                            color: AllergiesPage._brandGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        minLeadingWidth: 24,
                        horizontalTitleGap: 8,
                        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                        leading: const Icon(Icons.lunch_dining, color: Color(0xFF006400), size: 24),
                        title: const Text(
                          "Food",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FoodAllergiesPage()),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 12,
                        child: const Divider(height: 0),
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        minLeadingWidth: 24,
                        horizontalTitleGap: 8,
                        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                        leading: const Icon(Icons.favorite_border, color: Color(0xFF006400), size: 24),
                        title: const Text(
                          "Health",
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const HealthAllergiesPage()),
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