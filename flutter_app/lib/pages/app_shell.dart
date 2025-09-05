import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/bottom_nav.dart';
import 'home_page.dart';
import 'explore_page.dart';
import 'add_post_page.dart';
import 'events_page.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;
  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int index;

  // เอา const ออก เว้นแต่ทุกหน้าเป็น const constructor จริง ๆ
  final pages = [
    HomePage(),
    ExplorePage(),
    AddPostPage(),
    EventsPage(),
  ];

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
  }

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
