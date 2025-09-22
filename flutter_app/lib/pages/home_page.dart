import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../components/app_colors.dart';
import '../components/header_section.dart';
import '../components/post_card.dart';
import '../models/post.dart';
import 'profile_page.dart';
import 'post_page.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

import '../components/filter_pill.dart';
import 'filter_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Service bound to configured base; DatabaseService appends /api
  late final DatabaseService _db = DatabaseService();

  // Paging state
  bool _loading = true;
  bool _fetchingMore = false;
  String? _nextCursor; // holds next page number as string

  List<Post> _posts = [];

  // Filters (structure preserved)
  String _query = '';
  final Set<String> _chipIds = <String>{};
  String? _categoryId = 'all';
  String? _roleId = 'any';

  final _scroll = ScrollController();

  // Like/Comment state (optimistic)
  final Set<String> _likedIds = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _commentCounts = {};
  int _likeCountOf(Post p) => _likeCounts[p.id] ?? p.likeCount;
  int _commentCountOf(Post p) => _commentCounts[p.id] ?? p.comment;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  // ---------- API calls ----------
  Future<void> _loadFirstPage() async {
    setState(() => _loading = true);

    try {
      final page = await _db.getPostsPage(page: 1, limit: _pageSize);
      setState(() {
        _posts = page.items;
        _nextCursor = page.nextCursor;
        _loading = false;
        for (final p in _posts) {
          _likeCounts[p.id] = p.likeCount;
          _commentCounts[p.id] = p.comment;
        }
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

    try {
      final nextPage = int.tryParse(_nextCursor!) ?? 2;
      final page = await _db.getPostsPage(page: nextPage, limit: _pageSize);
      setState(() {
        _posts.addAll(page.items);
        _nextCursor = page.nextCursor;
        _fetchingMore = false;
        for (final p in page.items) {
          _likeCounts[p.id] = p.likeCount;
          _commentCounts[p.id] = p.comment;
        }
      });
    } catch (e) {
      setState(() => _fetchingMore = false);
      _showSnack('Failed to load more');
    }
  }

  Future<void> _onRefresh() => _loadFirstPage();

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  // ---------- Like/Comment actions (mock/optimistic) ----------
  void _toggleLike(Post p) async {
    final wasLiked = _likedIds.contains(p.id);
    final current = _likeCounts[p.id] ?? p.likeCount;

    setState(() {
      if (wasLiked) {
        _likedIds.remove(p.id);
        _likeCounts[p.id] = math.max(0, current - 1);
      } else {
        _likedIds.add(p.id);
        _likeCounts[p.id] = current + 1;
      }
    });

    // TODO: API later (like/unlike) with rollback
  }

  void _openComments(Post p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostPage(post: p)),
    );
  }

  // ---------- UI ----------
  void _showSnack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildEmptyBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No posts. Pull to refresh.')),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeaderSection(
          onAvatarTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
          onSettingsTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
        ),
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilterPill(
                  label: 'filter',
                  leading: Icons.filter_list,
                  selected: false,
                  onTap: () async {
                    final result =
                        await showModalBottomSheet<FilterSheetResult>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => FilterBottomSheet(
                        loadFilters: mockLoadFilters, // keep structure; no-op
                        initial: const FilterSheetResult(
                          facultyIds: {}, clubIds: {}, categoryIds: {},
                        ),
                      ),
                    );

                    if (result != null) {
                      // Keep state structure; apply to API later
                      // setState(() { ... });
                      // _loadFirstPage();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );

    Widget postsList;
    if (_loading) {
      postsList = const Center(child: CircularProgressIndicator());
    } else if (_posts.isEmpty) {
      postsList = ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _buildEmptyBody(),
          const SizedBox(height: 100),
        ],
      );
    } else {
      postsList = ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _posts.length + 1,
        itemBuilder: (context, i) {
          if (i == _posts.length) {
            if (_fetchingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return const SizedBox(height: 16);
          }

          final p = _posts[i];
          final liked = _likedIds.contains(p.id);
          final likes = _likeCounts[p.id] ?? p.likeCount;
          final comments = _commentCounts[p.id] ?? p.comment;

          return PostCard(
            post: p,
            isLiked: liked,
            likeCount: likes,
            commentCount: comments,
            onToggleLike: () => _toggleLike(p),
            onCommentTap: () => _openComments(p),
            onCardTap: () => _openComments(p),
            onAvatarTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    userId: p.userId.isNotEmpty ? p.userId : null,
                    initialUsername: p.username,
                    initialName: null,
                    initialAvatarUrl: p.profilePic,
                    initialBio: null,
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          header,
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: postsList,
            ),
          ),
        ],
      ),
    );
  }
}
