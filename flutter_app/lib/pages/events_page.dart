import 'package:flutter/material.dart';

import '../components/header_section.dart';         // reuse your app header
import '../components/search_filter_bar.dart';      // the reusable bar you already have
import '../components/event_card.dart';            // the card above

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
  // Configure your backend baseUrl; or inject via an InheritedWidget/DI
  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-xe4h.onrender.com',
  );
  late final DatabaseService _db = DatabaseService(baseUrl: _defaultBaseUrl);
  late final EventsController _ctl = EventsController(db: _db);

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctl.refresh();
    _scroll.addListener(_maybeLoadMore);
  }

  void _maybeLoadMore() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _ctl.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _ctl.refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Your app header
            SliverToBoxAdapter(
              child: HeaderSection(
                onAvatarTap: () {
                  // TODO: navigate to profile if you want
                },
              ),
            ),

            // Pinned search + filters (text + dropdowns + chips)
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedHeader(
                minExtent: 96,
                maxExtent: 170,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: AnimatedBuilder(
                    animation: _ctl,
                    builder: (_, __) {
                      return SearchFilterBar(
                        hintText: 'Search events…',
                        initialQuery: _ctl.state.query,
                        // Quick chips → let backend decide semantics:
                        // 'upcoming' (only future events), 'free', 'popular' (sort/threshold)
                        chipOptions: const [
                          FilterOption(id: 'upcoming', label: 'Upcoming', icon: Icons.schedule),
                          FilterOption(id: 'free', label: 'Free', icon: Icons.money_off),
                          FilterOption(id: 'popular', label: 'Popular', icon: Icons.trending_up),
                        ],
                        selectedChipIds: _ctl.state.chips,
                        // Dropdowns → category & role
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

            // Body
            AnimatedBuilder(
              animation: _ctl,
              builder: (context, _) {
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
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No events found')),
                    ),
                  );
                }

                return SliverList.builder(
                  itemCount: items.length + 1, // +1 for load-more indicator
                  itemBuilder: (context, i) {
                    if (i == items.length) {
                      // Load-more indicator
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
                        // TODO: push EventDetailPage(event: e)
                      },
                    );
                  },
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

class _PinnedHeader extends SliverPersistentHeaderDelegate {
  final double minExtent;
  final double maxExtent;
  final Widget child;

  _PinnedHeader({required this.minExtent, required this.maxExtent, required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _PinnedHeader oldDelegate) =>
      oldDelegate.child != child || oldDelegate.minExtent != minExtent || oldDelegate.maxExtent != maxExtent;
}