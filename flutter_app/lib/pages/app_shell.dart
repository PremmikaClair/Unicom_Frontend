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

  // บันทึกว่าหน้าไหนถูกสร้างแล้วบ้าง (เริ่มที่หน้าแรก)
  final _built = <bool>[true, false, false, false];

  // เก็บ instance ของแต่ละหน้า (สร้างเมื่อถูกใช้งานครั้งแรก)
  final List<Widget?> _pages = [const HomePage(), null, null, null];

  Widget _createPage(int i) {
    switch (i) {
      case 1:
        return const ExplorePage();
      case 2:
        return const AddPostPage();
      case 3:
        return EventsPage(); // ไม่ใส่ const ถ้าหน้านี้มี state/fetch
      default:
        return const HomePage();
    }
  }

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    _built[index] = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: index,
        // ถ้ายังไม่ถูกเลือก ให้ใส่ SizedBox() แทน เพื่อลดการสร้าง/เรียก API
        children: List.generate(4, (i) {
          if (!_built[i]) return const SizedBox.shrink();
          return _pages[i] ??= _createPage(i);
        }),
      ),
      bottomNavigationBar: BottomDockNav(
        index: index,
        onTap: (i) => setState(() {
          index = i;
          _built[i] = true; // สร้างหน้านี้ครั้งแรกตอนถูกเลือก
        }),
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
