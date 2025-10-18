import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/bottom_nav.dart';
import 'home_page.dart';
import 'explore/explore_page.dart';
import 'createpost/make_post.dart';      // ใช้กับปุ่มกลาง (updated)
import 'event/events_page.dart';
import 'explore/explore_tab_shell.dart';
import 'profile/profile_page.dart';         // << เพิ่มโปรไฟล์

class AppShell extends StatefulWidget {
  final int initialIndex;
  const AppShell({super.key, this.initialIndex = 0});

  // 🔑 แยก navigator ต่อแท็บ
  static final homeNavKey = GlobalKey<NavigatorState>();
  static final exploreNavKey = GlobalKey<NavigatorState>();
  static final profileNavKey = GlobalKey<NavigatorState>(); // << เพิ่ม
  static final eventsNavKey = GlobalKey<NavigatorState>();

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int index;

  // เริ่มต้นสร้างเฉพาะแท็บแรก
  final _built = <bool>[true, false, false, false];
  final List<Widget?> _pages = [null, null, null, null];

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    _built[index] = true;
  }

  // ====== Navigator ต่อแท็บ ======
  Widget _homeTab() {
    return Navigator(
      key: AppShell.homeNavKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: const RouteSettings(name: '/home/root'),
        builder: (_) => const HomePage(),
      ),
    );
  }

  Widget _exploreTab() => ExploreTabShell(navKey: AppShell.exploreNavKey);

  Widget _profileTab() { // << ใหม่ แทนตำแหน่งเดิมของ Add
    return Navigator(
      key: AppShell.profileNavKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: const RouteSettings(name: '/profile/root'),
        builder: (_) => const ProfilePage(),
      ),
    );
  }

  Widget _eventsTab() {
    return Navigator(
      key: AppShell.eventsNavKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: const RouteSettings(name: '/events/root'),
        builder: (_) => EventsPage(),
      ),
    );
  }

  Widget _createPage(int i) {
    switch (i) {
      case 0:
        return _homeTab();
      case 1:
        return _exploreTab();
      case 2: 
        return _eventsTab();
      case 3:
        return _profileTab();
      default:
        return _homeTab();
    }
  }

  void _popToRootOfTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        AppShell.homeNavKey.currentState?.popUntil(
          (r) => r.settings.name == '/home/root' || r.isFirst,
        );
        break;
      case 1:
        AppShell.exploreNavKey.currentState?.popUntil(
          (r) => r.settings.name == '/explore/root' || r.isFirst,
        );
        break;
      case 2: // << โปรไฟล์
        AppShell.eventsNavKey.currentState?.popUntil(
          (r) => r.settings.name == '/events/root' || r.isFirst,
        );
        break;
      case 3:
        AppShell.profileNavKey.currentState?.popUntil(
          (r) => r.settings.name == '/profile/root' || r.isFirst,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: index,
        children: List.generate(4, (i) {
          if (!_built[i]) return const SizedBox.shrink();
          return _pages[i] ??= _createPage(i);
        }),
      ),
      bottomNavigationBar: BottomDockNav(
        key: UniqueKey(),                 // กันค้างค่าเดิมตอน hot reload
        index: index,
        // รายการแท็บ: ซ้าย = Home, Explore | ขวา = Profile, Events
        items: const [
          BottomDockItem(icon: Icons.home_filled,      label: 'Home'),
          BottomDockItem(icon: Icons.search_rounded,   label: 'Explore'),
          BottomDockItem(icon: Icons.event_rounded,    label: 'Events'),  
          BottomDockItem(icon: Icons.person_outline,   label: 'Profile'), 
        ],
        // ให้ปุ่มกลางเป็น Add Post
        onCenterTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MakePostPage()),
          );
        },
        centerLabel: 'Add Post',
        centerIcon: Icons.add,
        // ดัน Explore/Events ให้เข้าใกล้ปุ่มกลาง
        centerGap: 40,     // ลดได้อีกเป็น 40 ถ้าอยากชิดขึ้น
        itemSpacing: 15,
        // ถ้าใช้ธีมเดิมโทนเขียว ให้ปลดคอมเมนต์ 3 บรรทัดนี้
        // barColor: AppColors.sage,
        // activeColor: Colors.white,
        // inactiveColor: Colors.white70,
        onTap: (i) {
          if (i == index) {
            _popToRootOfTab(i);
            return;
          }
          setState(() {
            index = i;
            _built[i] = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _popToRootOfTab(i);
          });
        },
      ),
    );
  }
}
