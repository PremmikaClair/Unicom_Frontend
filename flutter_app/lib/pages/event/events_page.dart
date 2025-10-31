// lib/pages/event/events_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/app_colors.dart';
import '../../models/event.dart';
import '../../components/filter_sheet.dart';
import '../../models/categories.dart';
import 'event_details_page.dart';
import 'create_event_page.dart';
import 'request_page.dart';
import 'manage_participants_page.dart';
import '../../services/database_service.dart';
import '../noti/notifications_page.dart'; 

/// แทนที่ด้วยแหล่งจริงของ roles ในแอปคุณ เช่น จาก Provider/Bloc/AuthService
class CurrentUser {
  /// สมมุติผู้ใช้ตอนนี้มี role 'head' (แก้ให้ดึงจริงในโปรเจกต์)
  static const Set<String> roles = {'student', 'head'};
}

/// roles ที่มีสิทธิ์เห็น/ใช้ FAB จัดการอีเวนต์
const Set<String> kEventManagerRoles = {'head', 'admin', 'organizer'};

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  late Future<List<_EventVM>> _future;
  final _searchCtrl = TextEditingController();
  int _activeFiltersCount = 0;
  FilterSheetResult _filters = const FilterSheetResult();
  int _pendingRequests = 1; // mock: ใส่จำนวนจริงจาก API ได้
  bool _canCreate = false;   // derived from /event/manageable-orgs
  bool _canManage = false;   // derived from /event/managed

  @override
  void initState() {
    super.initState();
    _future = _fetchEventsFiber();
    _loadPendingRequests();
    _loadEventAbilities();
    _loadUnreadNoti(); // << โหลดสถานะแจ้งเตือน
  }


  Future<List<_EventVM>> _fetchEventsFiber() async {
    final db = DatabaseService();
    // Fetch visible events
    final list = await db.getEventsFiberList();
    if (list.isEmpty) return const <_EventVM>[];

    // For each event, fetch detail to fill joined and confirm capacity
    final futures = list.map((e) async {
      int joined = 0;
      int capacity = e.capacity ?? 0;
      List<EventDayDetail> dayDetails = const [];
      try {
        final d = await db.getEventDetailFiber(e.id);
        final jp = d['current_participation'];
        final cp = d['max_participation'];
        if (jp is int) {
          joined = jp;
        } else if (jp != null) {
          joined = int.tryParse('$jp') ?? 0;
        }
        if (cp is int) {
          capacity = cp;
        } else if (cp != null) {
          capacity = int.tryParse('$cp') ?? capacity;
        }

        // Build multi-day details from schedules if available
        final raw = d['schedules'];
        if (raw is List && raw.isNotEmpty) {
          DateTime? _parse(dynamic v) {
            if (v == null) return null;
            if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
            final s = v.toString();
            return DateTime.tryParse(s);
          }

          String? _str(dynamic v) => v == null ? null : v.toString();

          final items = <EventDayDetail>[];
          for (final s in raw) {
            if (s is! Map) continue;
            final start =
                _parse(s['time_start']) ?? _parse(s['start']) ?? _parse(s['date']) ?? e.startTime;
            final end = _parse(s['time_end']) ?? _parse(s['end']) ?? (start.add(const Duration(hours: 1)));
            final date = _parse(s['date']) ?? start;
            final loc = _str(s['location']) ?? e.location;
            final desc = _str(s['description']) ?? e.description;
            items.add(EventDayDetail(
              date: DateTime(date.year, date.month, date.day),
              startTime: start,
              endTime: end,
              title: null,
              location: (loc == null || loc.isEmpty) ? e.location : loc,
              description: (desc == null || desc.isEmpty) ? e.description : desc,
              notes: null,
              mapUrl: null,
              isFree: e.isFree,
            ));
          }
          // Sort by startTime
          items.sort((a, b) => a.startTime.compareTo(b.startTime));
          dayDetails = items;
        }
      } catch (_) {}
      return _EventVM(e, joined: joined, capacity: capacity, dayDetails: dayDetails);
    }).toList();

    final vms = await Future.wait(futures);
    return vms;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetchEventsFiber();
    });
    await Future.wait([
      _future,
      _loadEventAbilities(),
      _loadUnreadNoti(), // << รีเช็กสถานะแจ้งเตือน
    ]);
  }


  bool _hasUnreadNoti = false; // << จุดแดง

  Future<void> _loadUnreadNoti() async {
    try {
      final db = DatabaseService();
      final list = await db.getUnreadNotificationsFiber();
      if (!mounted) return;
      setState(() => _hasUnreadNoti = list.isNotEmpty);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasUnreadNoti = false);
    }
  }


  Future<void> _loadPendingRequests() async {
    // TODO: เปลี่ยนเป็นเรียก API จริง เช่น GET /requests?status=pending&countOnly=true
    setState(() => _pendingRequests = 1); // mock
  }

  Future<void> _loadEventAbilities() async {
    try {
      final db = DatabaseService();
      final manageable = await db.getManageableOrgsFiber();
      final managed = await db.getManagedEventsFiber();
      if (!mounted) return;
      bool canCreate = manageable.isNotEmpty;
      bool canManage = managed.isNotEmpty;

      // Fallback: if manageable is empty, check policies by memberships
      if (!canCreate) {
        try {
          final mems = await db.getMyMembershipsFiber();
          for (final m in mems) {
            final org = (m['org_path'] ?? '').toString();
            final key = (m['position_key'] ?? '').toString();
            if (org.isEmpty || key.isEmpty) continue;
            final policies = await db.getPoliciesFiber(orgPrefix: org, positionKey: key);
            final hasCreate = policies.any((p) {
              final enabled = (p['enabled']?.toString() != 'false');
              final acts =
                  (p['actions'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
              return enabled && (acts.contains('event:create') || acts.contains('organize:create'));
            });
            if (hasCreate) {
              canCreate = true;
              break;
            }
          }
        } catch (_) {}
      }

      setState(() {
        _canCreate = canCreate;
        _canManage = canManage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canCreate = false;
        _canManage = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<FilterSheetResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const FilterBottomSheet(
              loadFilters: mockLoadFilters,
              initial: FilterSheetResult(facultyIds: {}, clubIds: {}, categoryIds: {}),
            ));
    if (!mounted || result == null) return;
    setState(() {
      _filters = result;
      _activeFiltersCount = result.facultyIds.length +
          result.departmentIds.length +
          result.clubIds.length +
          result.categoryIds.length +
          result.rolesIds.length;
    });
  }

  String _norm(String? s) => (s ?? '').toLowerCase().trim();

  // map ชื่อหมวดจากข้อมูลอีเวนต์ -> id ของฟิลเตอร์
  String _mapCategory(String? cat) {
    final k = _norm(cat);
    const alias = {
      'career': 'job',
      'social': 'life',
      'campus': 'event',
    };
    return alias[k] ?? k;
  }

  bool get _canManageEvents => CurrentUser.roles.any((r) => kEventManagerRoles.contains(r));

  void _goCreateEvent() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateEventPage()),
    );
  }

  void _goCheckIn() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('TODO: นำทางไปหน้าเช็คอิน/รายชื่อผู้ลงทะเบียน')),
    );
  }

  Future<void> _goRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManageParticipantsPage()),
    );
    if (mounted) _loadPendingRequests(); // refresh badge (optional)
  }

  // ✅ นำทางไปหน้า Notifications
  void _goNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
    if (mounted) {
      _loadUnreadNoti(); // << กลับมาแล้วรีเฟรชจุดแดง
    }
  }


  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    const headerG1 = Color(0xFF7E9766);
    const headerG2 = Color(0xFF7E9766);

    final w = MediaQuery.sizeOf(context).width;
    final subtitleSize = w < 360 ? 17.0 : 20.0;
    final illoHeight = w < 360 ? 128.0 : 140.0;

    // ===== control sizing
    const ctlHeight = 42.0;
    const ctlRadius = 24.0;

    final showFab = _canCreate || _canManage;
    return Scaffold(
      backgroundColor: headerG1,

      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              // ===== Green header =====
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [headerG1, headerG2],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: illoHeight,
                      // ✅ ครอบด้วย Stack เพื่อวางปุ่มกระดิ่งมุมขวาบน
                      child: Stack(
                        children: [
                          // เนื้อหาหลักเดิม
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10, right: 12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 22),
                                      Text(
                                        'EVENTS',
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                        style: t.displaySmall?.copyWith(
                                          fontSize: 52,
                                          color: const Color(0xFFF1F4EA),
                                          fontWeight: FontWeight.w900,
                                          height: 0.90,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'at Kasetsart University',
                                        maxLines: 1,
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                        style: t.titleLarge?.copyWith(
                                          fontSize: subtitleSize,
                                          color: const Color(0xFF283128).withOpacity(.78),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: Transform.translate( offset: const Offset(0, 10), 
                                  child: SizedBox(
                                    height: illoHeight + 10,
                                    width: illoHeight + 10,
                                    child: Image.asset(
                                      'assets/images/event_image.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              ),
                            ],
                          ),

                          // Notification มุมขวาบน
                            Positioned(
                              right: 0,
                              top: -8,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    tooltip: 'Notifications',
                                    onPressed: _goNotifications,
                                    icon: const Icon(Icons.notifications_rounded),
                                    color: const Color(0xFFF1F4EA),
                                    iconSize: 26,
                                    splashRadius: 22,
                                  ),
                                  if (_hasUnreadNoti)
                                    Positioned(
                                      right: 12,  // ปรับตำแหน่งได้ตามใจ
                                      top: 13,
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 0.8),
                                        ),
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
              ),

              // ===== Grey block (rounded top) + content =====
              SliverToBoxAdapter(
                child: Material(
                  color: const Color(0xFFEDEDED),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      const SizedBox(height: 18),

                      // --- Search + Filters ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: ctlHeight,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(ctlRadius),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.search, size: 20, color: Colors.black45),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchCtrl,
                                        decoration: const InputDecoration(
                                          hintText: 'Search events',
                                          hintStyle: TextStyle(color: Colors.black45),
                                          border: InputBorder.none,
                                          isCollapsed: true,
                                        ),
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: (_) => setState(() {}),
                                      ),
                                    ),
                                    if (_searchCtrl.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchCtrl.clear();
                                          setState(() {});
                                        },
                                        child: const Icon(Icons.close_rounded,
                                            size: 18, color: Colors.black38),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: _openFilterSheet,
                              borderRadius: BorderRadius.circular(ctlRadius),
                              child: Container(
                                height: ctlHeight,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(ctlRadius),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.filter_list, size: 20, color: Colors.black45),
                                    SizedBox(width: 6),
                                    Text(
                                      'filters',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // --- Event list ---
                      FutureBuilder<List<_EventVM>>(
                        future: _future,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 60),
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snap.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('Failed to load: ${snap.error}'),
                            );
                          }

                          var items = snap.data ?? const <_EventVM>[];
                          final q = _searchCtrl.text.trim().toLowerCase();
                          if (q.isNotEmpty) {
                            items = items
                                .where((vm) =>
                                    vm.event.title.toLowerCase().contains(q) ||
                                    (vm.event.location ?? '').toLowerCase().contains(q))
                                .toList();
                          }

                          final catSel = _filters.categoryIds;
                          final rolesSel = _filters.rolesIds;

                          if (catSel.isNotEmpty) {
                            items = items.where((vm) {
                              final mapped = _mapCategory(vm.event.category);
                              return catSel.contains(mapped);
                            }).toList();
                          }

                          if (rolesSel.isNotEmpty) {
                            items = items.where((vm) {
                              final r = _norm(vm.event.role);
                              return rolesSel.contains(r);
                            }).toList();
                          }

                          if (items.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No events'),
                            );
                          }

                          items.sort((a, b) => a.event.startTime.compareTo(b.event.startTime));
                          return _EventsList(items: items, onRefresh: _refresh);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              SliverFillRemaining(
                hasScrollBody: false,
                child: const ColoredBox(color: Color(0xFFEDEDED)),
              ),
            ],
          ),
        ),
      ),

      // ===== FAB — inline menu =====
      floatingActionButton: showFab
          ? _FabMenu(
              onCreate: _goCreateEvent,
              onCheckIn: _goCheckIn,
              onOpenRequests: _goRequests,
              pendingCount: _pendingRequests,
              mainColor: AppColors.sage,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _EventsList extends StatelessWidget {
  final List<_EventVM> items;
  final Future<void> Function()? onRefresh;
  const _EventsList({required this.items, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final entries = <_Entry>[];
    int? lastY, lastM;
    for (final vm in items) {
      final y = vm.event.startTime.year;
      final m = vm.event.startTime.month;
      if (lastY != y || lastM != m) {
        entries.add(_Entry.header(m, y));
        lastY = y;
        lastM = m;
      }
      entries.add(_Entry.item(vm));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 28),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final e = entries[i];
        return e.isHeader ? _MonthHeader(month: e.month!, year: e.year!) : _EventCard(vm: e.vm!, onRefresh: onRefresh);
      },
    );
  }
}

class _Entry {
  final bool isHeader;
  final int? month, year;
  final _EventVM? vm;
  _Entry.header(this.month, this.year)
      : isHeader = true,
        vm = null;
  _Entry.item(this.vm)
      : isHeader = false,
        month = null,
        year = null;
}

/// ===== Month header =====
class _MonthHeader extends StatelessWidget {
  final int month;
  final int year;
  const _MonthHeader({required this.month, required this.year});

  @override
  Widget build(BuildContext context) {
    final label = '${_monthLongEn(month).toUpperCase()} $year';
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.sage,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
          ),
          child: Text(
            label,
            style: t.titleLarge?.copyWith(
              fontSize: 16,
              color: const Color(0xFFF1F4EA),
              fontWeight: FontWeight.w600,
              letterSpacing: .4,
            ),
          ),
        ),
      ),
    );
  }
}

/// ===== ViewModel =====
class _EventVM {
  final AppEvent event;
  final int joined;
  final int capacity;
  final List<EventDayDetail> dayDetails;
  const _EventVM(this.event, {this.joined = 0, this.capacity = 0, this.dayDetails = const []});
}

/// ===== Event Card =====
class _EventCard extends StatelessWidget {
  final _EventVM vm;
  final Future<void> Function()? onRefresh;
  const _EventCard({required this.vm, this.onRefresh});

  static const double _imageW = 128;
  static const double _imageH = 104;

  @override
  Widget build(BuildContext context) {
    final e = vm.event;
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () async {
          final res = await Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => EventDetailPage.fromListItem(
                event: vm.event,
                // Derive join behavior from backend flag
                overrideMode:
                    (vm.event.haveForm == true) ? EventRegMode.requestToJoin : EventRegMode.registerNow,
                dayDetails: vm.dayDetails,
              ),
            ),
          );
          if (res == true) {
            await onRefresh?.call();
          }
        },
        child: Card(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: _imageW,
                    height: _imageH,
                    child: (e.imageUrl == null || e.imageUrl!.isEmpty)
                        ? Container(color: const Color(0xFFEFEFEF))
                        : Image.network(
                            e.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFEFEFEF)),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.sage,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.event_outlined, size: 16, color: AppColors.sage),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _formatDateRangeDateOnlyEn(e.startTime, e.endTime),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyMedium?.copyWith(color: Colors.black54, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if ((e.location ?? '').isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 16, color: AppColors.sage),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  e.location!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodyMedium?.copyWith(color: Colors.black54, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.people_outline, size: 16, color: AppColors.sage),
                            const SizedBox(width: 6),
                            Text(
                              '${vm.joined}/${vm.capacity}',
                              style: t.bodyMedium?.copyWith(color: Colors.black54, fontSize: 14),
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
    );
  }
}

/// ===== FAB Menu (กด + แล้วเด้งปุ่มย่อย) =====
class _FabMenu extends StatefulWidget {
  final VoidCallback onCreate;
  final VoidCallback onCheckIn;
  final VoidCallback onOpenRequests;
  final int pendingCount;
  final Color mainColor;

  const _FabMenu({
    required this.onCreate,
    required this.onCheckIn,
    required this.onOpenRequests,
    required this.pendingCount,
    this.mainColor = AppColors.sage,
  });

  @override
  State<_FabMenu> createState() => _FabMenuState();
}

class _FabMenuState extends State<_FabMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _curve;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      _open ? _ctrl.forward() : _ctrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // พื้นที่ปล่อยปุ่มย่อย
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 16),
          child: SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                // >> Requests (ปรับให้เยื้องขึ้นซ้าย 225°)
                AnimatedBuilder(
                  animation: _curve,
                  builder: (_, __) {
                    final rad = 225 * 3.1415926535 / 180.0;
                    final offset = Offset.fromDirection(rad, 72 * _curve.value);
                    return Transform.translate(
                      offset: offset,
                      child: Opacity(
                        opacity: _curve.value.clamp(0.0, 1.0),
                        child: Material(
                          color: widget.mainColor,
                          elevation: 3,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () {
                              _toggle();
                              widget.onOpenRequests();
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const SizedBox(width: 50, height: 50),
                                const Positioned.fill(
                                  child: Center(
                                    child: Icon(Icons.inbox_outlined, size: 22, color: Colors.white),
                                  ),
                                ),
                                if (widget.pendingCount > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                      child: Text(
                                        widget.pendingCount > 99 ? '99+' : '${widget.pendingCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // (Check-in button removed as requested)

                // >> Create (ประมาณ 270° ตรงขึ้นบน)
                AnimatedBuilder(
                  animation: _curve,
                  builder: (_, __) {
                    final rad = 270 * 3.1415926535 / 180.0;
                    final offset = Offset.fromDirection(rad, 72 * _curve.value);
                    return Transform.translate(
                      offset: offset,
                      child: Opacity(
                        opacity: _curve.value.clamp(0.0, 1.0),
                        child: Material(
                          color: widget.mainColor,
                          elevation: 3,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () {
                              _toggle();
                              widget.onCreate();
                            },
                            child: const SizedBox(
                              width: 50,
                              height: 50,
                              child:
                                  Icon(Icons.event_available_rounded, size: 22, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // ปุ่มหลัก (+)
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 16),
          child: FloatingActionButton(
            backgroundColor: widget.mainColor,
            shape: const CircleBorder(),
            onPressed: _toggle,
            child: AnimatedRotation(
              turns: _open ? 0.125 : 0, // หมุน 45°
              duration: const Duration(milliseconds: 160),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ===== Utilities =====
String _monthLongEn(int m) {
  const names = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return (m >= 1 && m <= 12) ? names[m] : '';
}

String _monthShortEn(int m) {
  const names = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return (m >= 1 && m <= 12) ? names[m] : '';
}

String _formatDateRangeDateOnlyEn(DateTime start, DateTime? end) {
  if (end == null ||
      (start.year == end.year && start.month == end.month && start.day == end.day)) {
    return '${start.day} ${_monthShortEn(start.month)} ${start.year}';
  }
  if (start.year == end.year && start.month == end.month) {
    return '${start.day}–${end.day} ${_monthShortEn(start.month)} ${start.year}';
  }
  if (start.year == end.year) {
    return '${start.day} ${_monthShortEn(start.month)} ${start.year} – '
        '${end.day} ${_monthShortEn(end.month)} ${end.year}';
  }
  return '${start.day} ${_monthShortEn(start.month)} ${start.year} – '
      '${end.day} ${_monthShortEn(end.month)} ${end.year}';
}
