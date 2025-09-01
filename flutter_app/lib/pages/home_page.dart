// lib/pages/home_page.dart
import 'package:flutter/material.dart';

import '../components/app_colors.dart';
import '../components/header_section.dart';
import '../components/post_card.dart';
import 'profile_page.dart';
import 'post_page.dart';

import '../models/post.dart';
import '../services/database_service.dart';

// Reusable search/filter UI (advanced version with dropdowns)
import '../components/search_filter_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Point to your backend; override with --dart-define if needed.
  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-xe4h.onrender.com/post',
  );
  // If your DatabaseService previously required postsPath, you can keep it internally;
  // here we assume it builds URIs itself (e.g., '/Post').
  late final DatabaseService _db = DatabaseService(baseUrl: _defaultBaseUrl);

  // --- Paging state (backend-driven) ---
  bool _loading = true;
  bool _fetchingMore = false;
  String? _nextCursor;

  // Data
  List<Post> _posts = [];

  // --- Search & filters (frontend state passed to backend) ---
  String _query = '';
  final Set<String> _chipIds = <String>{}; // e.g., {'liked'}
  String? _categoryId = 'all';             // null or 'all' means no filter
  String? _roleId = 'any';                 // null or 'any' means no filter

  // Scroll for infinite load
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ---------- Backend calls ----------
  Future<void> _loadFirstPage() async {
    setState(() => _loading = true);

    // Derive sort from chips (example: 'liked' chip → liked sort, else recent)
    final sort = _chipIds.contains('liked') ? 'liked' : 'recent';

    try {
      final page = await _db.getPosts(
        q: _query,
        filters: _chipIds.toList(),
        category: _categoryId == 'all' ? null : _categoryId,
        role: _roleId == 'any' ? null : _roleId,
        sort: sort,
        limit: 20,
        cursor: null,
      );
      setState(() {
        _posts = page.items;
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _posts = [];
        _nextCursor = null;
        _loading = false;
      });
      _showSnack('Failed to load posts');
    }
  }

  Future<void> _loadMore() async {
    if (_fetchingMore || _nextCursor == null) return;
    setState(() => _fetchingMore = true);

    final sort = _chipIds.contains('liked') ? 'liked' : 'recent';

    try {
      final page = await _db.getPosts(
        q: _query,
        filters: _chipIds.toList(),
        category: _categoryId == 'all' ? null : _categoryId,
        role: _roleId == 'any' ? null : _roleId,
        sort: sort,
        limit: 20,
        cursor: _nextCursor,
      );
      setState(() {
        _posts.addAll(page.items);
        _nextCursor = page.nextCursor;
        _fetchingMore = false;
      });
    } catch (e) {
      setState(() => _fetchingMore = false);
      _showSnack('Failed to load more');
    }
  }

  // Pull-to-refresh just reloads first page with current filters
  Future<void> _onRefresh() => _loadFirstPage();

  void _maybeLoadMore() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  // ---------- SearchFilterBar handlers ----------
  void _onQueryChanged(String q) {
    _query = q;
    _loadFirstPage(); // debounced by SearchFilterBar
  }

  void _onQuerySubmitted(String q) {
    _query = q;
    _loadFirstPage();
  }

  void _onChipsChanged(Set<String> ids) {
    _chipIds
      ..clear()
      ..addAll(ids);
    _loadFirstPage();
  }

  void _onDropdownChanged(String groupId, String? valueId) {
    if (groupId == 'category') _categoryId = valueId;
    if (groupId == 'role') _roleId = valueId;
    _loadFirstPage();
  }

  // ---------- UI ----------
  void _showSnack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header (unchanged)
            SliverToBoxAdapter(
              child: HeaderSection(
                onAvatarTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
              ),
            ),

            // 🔎 Pinned Search + Filter bar using your advanced SearchFilterBar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchFilterHeaderDelegate(
                minExtent: 96,
                maxExtent: 170,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: SearchFilterBar(
                    hintText: 'Search posts…',
                    initialQuery: _query,

                    // Quick chips (multi-select). Add/remove as you like.
                    chipOptions: const [
                      FilterOption(id: 'liked', label: 'Most liked', icon: Icons.star),
                      // FilterOption(id: 'media', label: 'With media', icon: Icons.image),
                      // FilterOption(id: 'mine', label: 'My posts', icon: Icons.person),
                    ],
                    selectedChipIds: _chipIds,

                    // Dropdowns for Category and Role (single select)
                    dropdowns: [
                      DropdownSpec(
                        id: 'category',
                        label: 'Category',
                        items: const [
                          FilterOption(id: 'all', label: 'All'),
                          FilterOption(id: 'announcement', label: 'Announcement'),
                          FilterOption(id: 'market', label: 'Market'),
                          FilterOption(id: 'qa', label: 'Q&A'),
                          // add your real categories…
                        ],
                        selectedId: _categoryId ?? 'all',
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
                        selectedId: _roleId ?? 'any',
                      ),
                    ],

                    // Events
                    onQueryChanged: _onQueryChanged,       // debounced
                    onQuerySubmitted: _onQuerySubmitted,   // enter
                    onChipsChanged: _onChipsChanged,
                    onDropdownChanged: _onDropdownChanged,
                  ),
                ),
              ),
            ),

            // Loading
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            // Posts list (kept exactly like your card)
            if (!_loading)
              SliverList.builder(
                itemCount: _posts.length + 1, // +1 for load-more indicator
                itemBuilder: (context, i) {
                  if (i == _posts.length) {
                    // Load-more indicator slot
                    if (_fetchingMore) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    // Spacer at the end
                    return const SizedBox(height: 16);
                  }

                  final p = _posts[i];
                  return PostCard(
                    avatarUrl: p.profilePic,
                    username: p.username,
                    text: p.message,
                    onAvatarTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfilePage(
                            initialUsername: p.username,
                            initialName: p.username,
                            initialAvatarUrl: p.profilePic,
                          ),
                        ),
                      );
                    },
                    onCardTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PostPage(post: p)),
                      );
                    },
                  );
                },
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// Pinned header delegate for the search/filter bar
class _SearchFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtent;
  final double maxExtent;
  final Widget child;

  _SearchFilterHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _SearchFilterHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.minExtent != minExtent ||
        oldDelegate.maxExtent != maxExtent;
  }
}