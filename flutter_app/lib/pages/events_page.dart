import 'dart:async';
import 'package:flutter/material.dart';

import '../components/header_section.dart';
import '../components/search_filter_bar.dart';
import '../components/event_card.dart';

import '../controllers/event.dart';
import '../controllers/base.dart';
import '../models/event.dart';
import '../services/database_service.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  // ใช้โดเมนล้วน ๆ แล้วให้ service ต่อ path เอง
  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-xe4h.onrender.com',
  );

  late final DatabaseService _db = DatabaseService(baseUrl: _defaultBaseUrl);
  late final EventsController _ctl = EventsController(db: _db);

  final _scroll = ScrollController();

  // --- Load guard กันค้างนานเกินไป ---
  static const _guard = Duration(seconds: 12);
  Timer? _loadGuardTimer;
  bool _stalled = false;
  String? _hardError; // เอาไว้แสดงข้อความถ้าค้าง/พัง

  @override
  void initState() {
    super.initState();
    _ctl.addListener(_onCtlChanged);
    _ctl.refresh(); // เริ่มโหลด
    _scroll.addListener(_maybeLoadMore);
  }

  void _onCtlChanged() {
    // ถ้าเริ่ม loading → ตั้ง timer เฝ้า
    if (_ctl.loading) {
      _hardError = null;
      _armLoadGuard();
    } else {
      _cancelLoadGuard();
      if (_stalled) setState(() => _stalled = false);
    }
    // ถ้า controller มี error property จะดีมาก;
    // ถ้าไม่มี เราใช้ load-guard ช่วยแสดงข้อความให้ผู้ใช้แทน
  }

  void _armLoadGuard() {
    _cancelLoadGuard();
    _loadGuardTimer = Timer(_guard, () {
      if (!mounted) return;
      if (_ctl.loading) {
        setState(() {
          _stalled = true;
          _hardError = 'โหลดข้อมูลนานผิดปกติ (>${_guard.inSeconds}s) — อาจมีปัญหาการเชื่อมต่อหรือเซิร์ฟเวอร์ช้า';
        });
      }
    });
  }

  void _cancelLoadGuard() {
    _loadGuardTimer?.cancel();
    _loadGuardTimer = null;
  }

  void _maybeLoadMore() {
    if (_ctl.loading || _ctl.fetchingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _ctl.loadMore();
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _stalled = false;
      _hardError = null;
    });
    try {
      await _ctl.refresh();
    } catch (e) {
      setState(() {
        _hardError = 'รีเฟรชไม่สำเร็จ: $e';
      });
    }
  }

  @override
  void dispose() {
    _cancelLoadGuard();
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    _ctl.removeListener(_onCtlChanged);
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header แอป
            SliverToBoxAdapter(
              child: HeaderSection(
                onAvatarTap: () {
                  // TODO: navigate to profile if needed
                },
              ),
            ),

            // แถบค้นหา + ฟิลเตอร์ แบบปักหัว
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedHeader(
                minExtentPx: 96,
                maxExtentPx: 170,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: AnimatedBuilder(
                    animation: _ctl,
                    builder: (_, __) {
                      return SearchFilterBar(
                        hintText: 'Search events…',
                        initialQuery: _ctl.state.query,
                        chipOptions: const [
                          FilterOption(id: 'upcoming', label: 'Upcoming', icon: Icons.schedule),
                          FilterOption(id: 'free', label: 'Free', icon: Icons.money_off),
                          FilterOption(id: 'popular', label: 'Popular', icon: Icons.trending_up),
                        ],
                        selectedChipIds: _ctl.state.chips,
                        dropdowns: [
                          DropdownSpec(
                            id: 'category',
                            label: 'Category',
                            items: const [
                              FilterOption(id: 'all', label: 'All'),
                              FilterOption(id: 'academic', label: 'Academic'),
                              FilterOption(id: 'social', label: 'Social'),
                              FilterOption(id: 'sports', label: 'Sports'),
                              FilterOption(id: 'career', label: 'Career'),
                            ],
                            selectedId: _ctl.state.dropdowns['category'] ?? 'all',
                          ),
                          DropdownSpec(
                            id: 'role',
                            label: 'Role',
                            items: const [
                              FilterOption(id: 'any', label: 'Any'),
                              FilterOption(id: 'student', label: 'Student'),
                              FilterOption(id: 'staff', label: 'Staff'),
                              FilterOption(id: 'admin', label: 'Admin'),
                            ],
                            selectedId: _ctl.state.dropdowns['role'] ?? 'any',
                          ),
                        ],
                        onQueryChanged: _ctl.updateQuery,
                        onQuerySubmitted: _ctl.updateQuery,
                        onChipsChanged: _ctl.updateChips,
                        onDropdownChanged: _ctl.updateDropdown,
                      );
                    },
                  ),
                ),
              ),
            ),

            // เนื้อหา
            AnimatedBuilder(
              animation: _ctl,
              builder: (context, _) {
                // กรณีโหลดค้างนานผิดปกติ
                if (_stalled) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _hardError ?? 'โหลดช้า กรุณาลองใหม่',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _onRefresh,
                            child: const Text('ลองใหม่'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (_ctl.loading) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final items = _ctl.items;
                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No events found'),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _onRefresh,
                            child: const Text('รีเฟรช'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // ใช้ SliverList + SliverChildBuilderDelegate (ถูกต้องตาม Flutter)
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i == items.length) {
                        return _ctl.fetchingMore
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : const SizedBox(height: 16);
                      }
                      final e = items[i] as AppEvent;
                      return EventCard(
                        event: e,
                        onTap: () {
                          // TODO: Navigator.push(... EventDetailPage(event: e))
                        },
                      );
                    },
                    childCount: items.length + 1,
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ---- Pinned header delegate (override getters ให้ถูกต้อง) ----
class _PinnedHeader extends SliverPersistentHeaderDelegate {
  final double _minExtent;
  final double _maxExtent;
  final Widget child;

  _PinnedHeader({
    required double minExtentPx,
    required double maxExtentPx,
    required this.child,
  })  : _minExtent = minExtentPx,
        _maxExtent = maxExtentPx;

  @override
  double get minExtent => _minExtent;

  @override
  double get maxExtent => _maxExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _PinnedHeader old) =>
      old.child != child || old._minExtent != _minExtent || old._maxExtent != _maxExtent;
}
