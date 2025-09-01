import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/bottom_nav.dart';
import 'home_page.dart';
import 'explore_page.dart';
import 'add_post_page.dart';
import 'events_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final pages = const [
    HomePage(),
    ExplorePage(),
    AddPostPage(),
    EventsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: BottomDockNav(
        index: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomDockItem(icon: Icons.home_filled, label: 'Home'),
          BottomDockItem(icon: Icons.search_rounded, label: 'Explore'),
          BottomDockItem(icon: Icons.add_box_rounded, label: 'Add'),
          BottomDockItem(icon: Icons.event_rounded, label: 'Events'),
        ],
      ),
    );
  }
}