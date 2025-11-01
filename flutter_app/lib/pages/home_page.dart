// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import '../utils/app_controls.dart';

import '../components/post_card.dart';
import '../models/post.dart';
import 'profile/profile_page.dart';
import 'post_detail.dart';
import '../services/database_service.dart';
import '../models/event.dart';
import 'event/event_details_page.dart';
import 'explore/hashtag_feed_page.dart';

import '../components/filter_pill.dart';
import '../components/filter_sheet.dart';
// Removed header_section import to avoid conflicts; use local header instead
import '../controllers/like_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Service
  late final DatabaseService _db = DatabaseService();

  // Like controller
  late final FeedLikeController _likes;

  // Active Filter
  FilterSheetResult? _activeFilter;

  // Paging state
  bool _loading = true;
  bool _fetchingMore = false;
  String? _nextCursor;
  static const int _pageSize = 20;

  // Posts
  List<Post> _posts = [];

  // Events (header slider)
  bool _loadingEvents = true;
  List<AppEvent> _events = [];

  // Greeting
  String? _firstName;

  // Scrollers
  final _scroll = ScrollController();
  late final PageController _evCtrl = PageController(viewportFraction: 0.86);
  int _evIndex = 0;

  bool get _hasAnyFilter {
    final f = _activeFilter;
    if (f == null) return false;
    return f.categoryIds.isNotEmpty ||
        f.facultyIds.isNotEmpty ||
        f.clubIds.isNotEmpty ||
        f.departmentIds.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    _likes = FeedLikeController(
      db: _db,
      setState: setState,
      showSnack: _showSnack,
    );

    _loadFirstPage();
    _loadIncomingEvents();
    _loadMyName();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    _evCtrl.dispose();
    super.dispose();
  }

  // ---------- API calls ----------
  Future<void> _loadFirstPage() async {
    setState(() => _loading = true);
    try {
      // Always use getFeed; if no filters, just send limit=20
      final page = await _db.getFeed(
        limit: _pageSize,
        categories: _hasAnyFilter ? _activeFilter?.categoryIds.toList() : null,
        roles: _hasAnyFilter ? _activeFilter?.rolesIds.toList() : null,
        sort: 'time',
      );

      setState(() {
        _posts = page.items;
        _nextCursor = page.nextCursor;
        _loading = false;
      });

      // seed like state ให้ controller
      _likes.seedFromPosts(_posts);

      _enrichUserNamesFor(_posts);
    } catch (e) {
      setState(() {
        _posts = [];
        _nextCursor = null;
        _loading = false;
      });
      _showSnack('Failed to load posts');
    }
  }

  Future<void> _loadFirstPageFiltered(FilterSheetResult r) async {
    setState(() {
      _loading = true;
      _activeFilter = r;
      _posts = const <Post>[];
      _nextCursor = null;
    });

    try {
      final page = await _db.getFeed(
        limit: _pageSize,
        categories: r.categoryIds.toList(),
        roles: r.rolesIds.toList(),
        sort: 'time',
      );

      setState(() {
        _posts = page.items;
        _nextCursor = page.nextCursor;
        _loading = false;
      });

      // seed like state ให้ controller
      _likes.seedFromPosts(_posts);

      _enrichUserNamesFor(_posts);
    } catch (e) {
      setState(() {
        _posts = const <Post>[];
        _nextCursor = null;
        _loading = false;
      });
      _showSnack('Failed to load filtered posts');
    }
  }

  Future<void> _loadMore() async {
    if (_fetchingMore || _nextCursor == null) return;
    setState(() => _fetchingMore = true);

    try {
      // Always use getFeed; if no filters, just pass limit/cursor
      final page = await _db.getFeed(
        limit: _pageSize,
        cursor: _nextCursor,
        categories: _hasAnyFilter ? _activeFilter?.categoryIds.toList() : null,
        roles: _hasAnyFilter ? _activeFilter?.rolesIds.toList() : null,
        sort: 'time',
      );

      setState(() {
        _posts.addAll(page.items);
        _nextCursor = page.nextCursor;
        _fetchingMore = false;
      });

      // seed เฉพาะโพสต์ที่โหลดเพิ่ม
      _likes.seedFromPosts(page.items);

      _enrichUserNamesFor(page.items);
    } catch (e) {
      setState(() => _fetchingMore = false);
      _showSnack('Failed to load more');
    }
  }

  Future<void> _onRefresh() async {
    if (_activeFilter != null) {
      await Future.wait([_loadFirstPageFiltered(_activeFilter!), _loadIncomingEvents()]);
    } else {
      await Future.wait([_loadFirstPage(), _loadIncomingEvents()]);
    }
  }

  Future<void> _loadIncomingEvents() async {
    try {
      final list = await _db.getEventsFiberList();
      final now = DateTime.now();
      final upcoming = list
          .where((e) => e.startTime.isAfter(now.subtract(const Duration(days: 1))))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      setState(() {
        _events = upcoming.take(10).toList();
        _loadingEvents = false;
      });
    } catch (_) {
      setState(() {
        _events = const <AppEvent>[];
        _loadingEvents = false;
      });
    }
  }

  Future<void> _loadMyName() async {
    try {
      final me = await _db.getMeFiber();
      final f = (me['firstname'] ?? me['firstName'] ?? '').toString().trim();
      final l = (me['lastname'] ?? me['lastName'] ?? '').toString().trim();
      final full = [f, l].where((s) => s.isNotEmpty).join(' ').trim();
      if (!mounted) return;
      if (full.isNotEmpty) setState(() => _firstName = full);
    } catch (_) {}
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  // Replace uid/username with full name fetched from profile API
  // Also try to backfill avatar (profilePic) from profile data
  Future<void> _enrichUserNamesFor(List<Post> items) async {
    final hex24 = RegExp(r'^[a-fA-F0-9]{24}$');
    final ids = <String>{
      for (final p in items)
        if (p.userId.isNotEmpty && hex24.hasMatch(p.userId)) p.userId,
    };
    if (ids.isEmpty) return;

    final Map<String, String> nameById = {};
    final Map<String, String> avatarById = {};
    for (final id in ids) {
      try {
        final prof = await _db.getUserByObjectIdFiber(id);
        final first = (prof['firstname'] ?? prof['firstName'] ?? '').toString();
        final last = (prof['lastname'] ?? prof['lastName'] ?? '').toString();
        final full = [first, last].where((s) => s.isNotEmpty).join(' ').trim();
        if (full.isNotEmpty) nameById[id] = full;
        final avatar = (prof['profile_pic'] ??
                prof['profilePic'] ??
                prof['profile_picture'] ??
                prof['avatar_url'] ??
                prof['avatar'] ??
                prof['photo_url'] ??
                prof['photoUrl'] ??
                prof['avatarUrl'] ??
                '')
            .toString()
            .trim();
        if (avatar.isNotEmpty) avatarById[id] = avatar;
      } catch (_) {}
    }

    // Fallback: try search by username for posts without avatar
    final needByName = <String>{
      for (final p in items)
        if ((p.profilePic.trim().isEmpty) && p.username.trim().isNotEmpty) p.username.trim(),
    };
    if (needByName.isNotEmpty) {
      for (final name in needByName) {
        try {
          final res = await _db.searchUsers(q: name, limit: 1, cursor: null);
          if (res.items.isNotEmpty) {
            final u = res.items.first;
            final avatar = (u['profile_pic'] ?? u['profilePic'] ?? u['profile_picture'] ??
                    u['avatar_url'] ?? u['avatar'] ?? u['photo_url'] ?? u['photoUrl'] ?? u['avatarUrl'] ?? '')
                .toString()
                .trim();
            if (avatar.isNotEmpty) {
              // We don't know id mapping here; apply later by matching username
              avatarById['__name__::$name'] = avatar;
            }
          }
        } catch (_) {}
      }
    }

    if ((nameById.isEmpty && avatarById.isEmpty) || !mounted) return;
    setState(() {
      _posts = _posts.map((p) {
        final nm = nameById[p.userId];
        String? av = avatarById[p.userId];
        // fallback by username mapping
        av ??= avatarById['__name__::${p.username}'];
        if (nm == null && (av == null || av.isEmpty)) return p;
        return Post(
          id: p.id,
          userId: p.userId,
          profilePic: (p.profilePic.trim().isEmpty && av != null && av.isNotEmpty)
              ? av
              : p.profilePic,
          username: nm ?? p.username,
          category: p.category,
          message: p.message,
          likeCount: p.likeCount,
          comment: p.comment,
          isLiked: p.isLiked,
          authorRoles: p.authorRoles,
          visibilityRoles: p.visibilityRoles,
          timeStamp: p.timeStamp,
          picture: p.picture,
          video: p.video,
          images: p.images,
          videos: p.videos,
        );
      }).toList();
    });
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

  // ---------- Incoming events slider ----------
  Widget _incomingEventsSection(BuildContext context) {
    if (_loadingEvents) {
      return SizedBox(
        height: 140,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          scrollDirection: Axis.horizontal,
          itemBuilder: (_, __) => _eventSkeletonCard(),
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemCount: 3,
        ),
      );
    }
    if (_events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _evCtrl,
            onPageChanged: (i) => setState(() => _evIndex = i),
            itemCount: _events.length,
            itemBuilder: (context, i) {
              final w = MediaQuery.of(context).size.width;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                child: _eventCard(context, _events[i], width: w * 0.86),
              );
            },
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_events.length, (i) {
            final active = i == _evIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 12 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? Colors.black45 : Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _eventSkeletonCard() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 100,
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 140, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 6),
                  Container(height: 10, width: 90, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(BuildContext context, AppEvent e, {double? width}) {
    final img = (e.imageUrl ?? '').trim();
    final date = _formatEventDate(e.startTime, e.endTime);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailPage.fromListItem(event: e)),
        );
      },
      child: Container(
        width: width ?? 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 120,
                  height: 100,
                  child: img.isEmpty
                      ? Image.asset('assets/images/event_image.png', fit: BoxFit.cover)
                      : Image.network(
                          img,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset('assets/images/event_image.png', fit: BoxFit.cover),
                        ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 14, color: Colors.black54),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                    if ((e.location ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 14, color: Colors.black54),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  String _formatEventDate(DateTime start, DateTime? end) {
    final d = '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
    if (end == null) return d;
    final sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
    if (sameDay) return d;
    final d2 = '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
    return '$d - $d2';
  }

  // Navigate to comments / detail
  Future<void> _openComments(Post p) async {
    final synced = Post(
      id: p.id,
      userId: p.userId,
      profilePic: p.profilePic,
      username: p.username,
      category: p.category,
      message: p.message,
      likeCount: _likes.likeCountOf(p),
      comment: _likes.commentCountOf(p),
      isLiked: _likes.isLiked(p),
      authorRoles: p.authorRoles,
      visibilityRoles: p.visibilityRoles,
      timeStamp: p.timeStamp,
      picture: p.picture,
      video: p.video,
      images: p.images,
      videos: p.videos,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostPage(post: synced)),
    );

    if (!mounted || result == null) return;
    try {
      final m = result as Map<String, dynamic>;
      if ((m['postId'] ?? '') == p.id) {
        _likes.applyFromDetail(
          postId: p.id,
          liked: (m['liked'] == true),
          likeCount: m['likeCount'] as int?,
          commentCount: m['commentCount'] as int?,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Widget _logoHeader() {
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/ourlogo.png',
                height: 50,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => Image.asset(
                  'assets/images/KU.png',
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _logoHeader(),
        const SizedBox(height: 12),
        _incomingEventsSection(context),
        Material(
          // ✨ CHANGED: โปร่งใสเพื่อให้เห็นกราเดียนต์ด้านหลัง
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dynamic_feed_rounded, size: 18, color: Colors.black87),
                    SizedBox(width: 6),
                    Text('Your Feed', style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                FilterPill(
                  label: 'filter',
                  leading: Icons.filter_list,
                  selected: _activeFilter != null,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  onTap: () async {
                    final result = await showModalBottomSheet<FilterSheetResult>(
                      context: context,
                      isScrollControlled: true,
                      useRootNavigator: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => FilterBottomSheet(
                        loadFilters: () => loadFiltersWithDb(_db),
                        initial: _activeFilter ?? const FilterSheetResult(),
                      ),
                    );

                    if (result != null) {
                      await _loadFirstPageFiltered(result);
                    } else {
                      setState(() => _activeFilter = null);
                      await _loadFirstPage();
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
          final liked = _likes.isLiked(p);
          final likes = _likes.likeCountOf(p);
          final comments = _likes.commentCountOf(p);

          // Lazy sync (มี cooldown + anti-revert ใน controller)
          WidgetsBinding.instance.addPostFrameCallback((_) => _likes.ensureLikeState(p));

          return PostCard(
            post: p,
            isLiked: liked,
            likeCount: likes,
            commentCount: comments,
            onToggleLike: () => _likes.toggleLike(p),
            onCommentTap: () => _openComments(p),
            onCardTap: () => _openComments(p),
            onHashtagTap: (tag) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => HashtagFeedPage(hashtag: tag)));
            },
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

    const homeBg = Color(0xFFEDEDED);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.maybePop();
        } else {
          await AppControls.moveToBackground();
        }
      },
      child: Scaffold(
      backgroundColor: homeBg,
      body: ColoredBox(
        color: homeBg,
        child: SafeArea(
          bottom: false,
          child: Column(
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
        ),
      ),
      ),
    );
  }
}
