import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../components/app_colors.dart';
import '../../components/post_card.dart';
import '../../components/search_bar.dart';
import '../../models/post.dart' as models;
import '../../services/database_service.dart';
import '../post_detail.dart';
import '../profile/profile_page.dart';
import 'hashtag_feed_page.dart';
import 'people_search_page.dart';

class _MatchedUser {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String secondaryLabel;

  const _MatchedUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.secondaryLabel = '',
  });

  _MatchedUser copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? secondaryLabel,
  }) {
    return _MatchedUser(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
    );
  }

  String get primaryLabel {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (username.trim().isNotEmpty) return '@${username.trim()}';
    return 'Unnamed user';
  }

}

class SearchFeedPage extends StatefulWidget {
  final String initialQuery;

  const SearchFeedPage({super.key, required this.initialQuery});

  @override
  State<SearchFeedPage> createState() => _SearchFeedPageState();
}

class _SearchFeedPageState extends State<SearchFeedPage> {
  static const int _pageSize = 20;

  late final TextEditingController _ctrl;
  final ScrollController _scrollCtrl = ScrollController();
  late final DatabaseService _db = DatabaseService();

  final List<models.Post> _posts = <models.Post>[];
  final Set<String> _likedIds = <String>{};
  final Set<String> _liking = <String>{};
  final Map<String, int> _likeCounts = <String, int>{};
  final Map<String, int> _commentCounts = <String, int>{};

  bool _loading = false;
  bool _fetchingMore = false;
  String? _nextCursor;
  Object? _error;

  final List<_MatchedUser> _userMatches = <_MatchedUser>[];
  bool _userLoading = false;
  String? _userCursor;
  Object? _userError;

  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _currentQuery = widget.initialQuery.trim();
    _scrollCtrl.addListener(_maybeLoadMore);
    if (_currentQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch(reset: true));
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_maybeLoadMore);
    _scrollCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollCtrl.hasClients) return;
    if (_fetchingMore || _loading || _nextCursor == null) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 280) {
      _runSearch(reset: false);
    }
  }

  Future<void> _runSearch({required bool reset}) async {
    final q = _currentQuery;
    if (q.isEmpty) {
      setState(() {
        _loading = false;
        _fetchingMore = false;
        _error = null;
        _posts.clear();
        _nextCursor = null;
        _likedIds.clear();
        _likeCounts.clear();
        _commentCounts.clear();
        _userMatches.clear();
        _userCursor = null;
        _userLoading = false;
        _userError = null;
      });
      return;
    }

    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _posts.clear();
        _nextCursor = null;
        _likedIds.clear();
        _likeCounts.clear();
        _commentCounts.clear();
        _userMatches.clear();
        _userCursor = null;
        _userLoading = true;
        _userError = null;
      });
    } else {
      if (_fetchingMore || _nextCursor == null) return;
      setState(() {
        _fetchingMore = true;
        _error = null;
      });
    }

    try {
      final lower = q.toLowerCase();
      final List<models.Post> updated =
          reset ? <models.Post>[] : List<models.Post>.from(_posts);
      final Set<String> existingIds = updated.map((e) => e.id).toSet();
      final List<models.Post> newlyMatched = <models.Post>[];
      var cursor = reset ? null : _nextCursor;
      var hops = 0;
      const int maxAutoHop = 12;
      const int minDesiredMatches = 8;

      while (true) {
        if (!reset && cursor == null) break;
        hops++;
        final page = await _db.getPosts(
          q: q,
          limit: _pageSize,
          cursor: cursor,
        );
        if (!mounted || _currentQuery != q) return;
        final filtered = page.items.where((p) => _matchesQuery(p, lower)).toList();
        for (final p in filtered) {
          _likeCounts[p.id] = p.likeCount;
          _commentCounts[p.id] = p.comment;
          if (p.isLiked) {
            _likedIds.add(p.id);
          } else {
            _likedIds.remove(p.id);
          }

          if (existingIds.contains(p.id)) {
            final idx = updated.indexWhere((e) => e.id == p.id);
            if (idx >= 0) updated[idx] = p;
          } else if (newlyMatched.every((e) => e.id != p.id)) {
            newlyMatched.add(p);
          }
        }

        cursor = page.nextCursor;
        final bool hasMore = cursor != null;
        final bool continueSearch = hasMore &&
            newlyMatched.length < minDesiredMatches &&
            hops < maxAutoHop;
        if (!continueSearch) {
          break;
        }
      }

      if (!mounted || _currentQuery != q) return;
      setState(() {
        if (reset) {
          updated
            ..clear()
            ..addAll(newlyMatched);
        } else {
          updated.addAll(newlyMatched);
        }

        _posts
          ..clear()
          ..addAll(updated);
        _nextCursor = cursor;
        _loading = false;
        _fetchingMore = false;
        _error = null;
      });
      if (!mounted || _currentQuery != q) return;
      if (reset) {
        await _searchUsers(query: q, reset: true);
      }
    } catch (e, st) {
      debugPrint('search posts failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        if (reset) {
          _loading = false;
          _userLoading = false;
        } else {
          _fetchingMore = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to search posts')),
      );
    }
  }

  bool _usernameMatches(models.Post post, String queryLower) {
    final name = post.username.trim();
    if (name.isEmpty) return false;
    return name.toLowerCase().contains(queryLower);
  }

  bool _matchesQuery(models.Post post, String queryLower) {
    if (queryLower.isEmpty) return true;
    bool contains(String value) => value.toLowerCase().contains(queryLower);

    if (_usernameMatches(post, queryLower)) return true;
    if (contains(post.message)) return true;
    if (contains(post.category)) return true;
    for (final role in post.authorRoles) {
      if (contains(role)) return true;
    }
    return false;
  }

  Future<void> _searchUsers({required String query, required bool reset}) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (_userMatches.isNotEmpty) {
        setState(() {
          _userMatches.clear();
          _userCursor = null;
          _userLoading = false;
          _userError = null;
        });
      }
      return;
    }

    if (!mounted || _currentQuery != query) return;

    if (reset) {
      _userCursor = null;
    } else {
      if (_userLoading || _userCursor == null) return;
    }

    setState(() {
      _userLoading = true;
      _userError = null;
      if (reset) {
        _userMatches.clear();
      }
    });

    try {
      final lower = q.toLowerCase();
      final res = await _db.searchUsers(q: q, limit: 12, cursor: reset ? null : _userCursor);
      if (!mounted || _currentQuery != query) return;
      final newUsers =
          res.items.map((raw) => _mapToMatchedUser(raw, lower)).whereType<_MatchedUser>().toList();
      setState(() {
        if (reset) {
          _userMatches
            ..clear()
            ..addAll(newUsers);
        } else {
          for (final u in newUsers) {
            final idx = _userMatches.indexWhere((m) => m.id == u.id);
            if (idx >= 0) {
              _userMatches[idx] = u;
            } else {
              _userMatches.add(u);
            }
          }
        }
        _userCursor = res.nextCursor;
        _userLoading = false;
        _userError = null;
      });
    } catch (e, st) {
      debugPrint('search users failed: $e\n$st');
      if (!mounted || _currentQuery != query) return;
      setState(() {
        _userLoading = false;
        _userError = e;
      });
    }
  }

  _MatchedUser? _mapToMatchedUser(Map<String, dynamic> j, String queryLower) {
    String readId(dynamic v) {
      if (v is Map && v[r'$oid'] != null) return v[r'$oid'].toString();
      return v?.toString() ?? '';
    }

    String resolveUserId() {
      final keys = [
        '_id',
        'id',
        'user_id',
        'userId',
        'uid',
        'objectId',
        'object_id',
        'profileId',
        'profile_id',
      ];
      for (final key in keys) {
        final value = readId(j[key]);
        if (value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return '';
    }

    final id = resolveUserId();
    if (id.isEmpty) return null;

    String readStr(dynamic v) => v?.toString().trim() ?? '';

    final first = readStr(j['firstName']);
    final last = readStr(j['lastName']);
    final email = readStr(j['email']);
    final usernameRaw = readStr(j['username'] ?? j['userName'] ?? j['alias']);
    final studentId = readStr(j['student_id'] ?? j['studentId']);
    final display = [first, last].where((s) => s.isNotEmpty).join(' ').trim();

    String deriveUsername() {
      if (usernameRaw.isNotEmpty) return usernameRaw;
      if (email.contains('@')) {
        final local = email.split('@').first.trim();
        if (local.isNotEmpty) return local;
      }
      if (display.isNotEmpty) return display.replaceAll(' ', '').toLowerCase();
      return 'user$id';
    }

    final avatar = readStr(j['profile_pic'] ??
        j['profilePic'] ??
        j['avatar_url'] ??
        j['avatar'] ??
        j['photo']);

    final derivedUsername = deriveUsername();

    bool contains(String value) => value.toLowerCase().contains(queryLower);
    final matchable = <String>[
      first,
      last,
      '$first $last',
      email,
      usernameRaw,
      studentId,
      display,
      derivedUsername,
    ];
    final roster = j['roles'];
    if (roster is List) {
      for (final r in roster) {
        matchable.add(readStr(r));
      }
    }
    if (matchable.every((s) => s.isEmpty || !contains(s))) {
      return null;
    }

    final username = derivedUsername;

    String secondary = '';
    if (display.isNotEmpty && username.isNotEmpty) {
      secondary = '@$username';
    } else if (email.isNotEmpty) {
      secondary = email;
    } else if (studentId.isNotEmpty) {
      secondary = studentId;
    }

    return _MatchedUser(
      id: id,
      username: username,
      displayName: display,
      avatarUrl: avatar,
      secondaryLabel: secondary,
    );
  }

  Future<void> _refresh() => _runSearch(reset: true);

  void _doSearch(String raw) {
    final q = raw.trim();
    setState(() {
      _currentQuery = q;
    });
    FocusScope.of(context).unfocus();
    _runSearch(reset: true);
  }

  void _toggleLike(models.Post post) {
    final id = post.id;
    if (_liking.contains(id)) return;

    final wasLiked = _likedIds.contains(id);
    final prevCount = _likeCounts[id] ?? post.likeCount;

    setState(() {
      if (wasLiked) {
        _likedIds.remove(id);
        _likeCounts[id] = prevCount > 0 ? prevCount - 1 : 0;
      } else {
        _likedIds.add(id);
        _likeCounts[id] = prevCount + 1;
      }
    });

    _liking.add(id);
    _db.toggleLike(targetId: id, targetType: 'post').then((res) {
      if (!mounted) return;
      setState(() {
        if (res.liked) {
          _likedIds.add(id);
        } else {
          _likedIds.remove(id);
        }
        _likeCounts[id] = res.likeCount;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          _likedIds.add(id);
        } else {
          _likedIds.remove(id);
        }
        _likeCounts[id] = prevCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update like')),
      );
    }).whenComplete(() {
      _liking.remove(id);
    });
  }

  void _openPost(models.Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostPage(post: post)),
    );
  }

  void _openHashtag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HashtagFeedPage(hashtag: tag)),
    );
  }

  void _openProfile(models.Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: post.userId.isNotEmpty ? post.userId : null,
          initialUsername: post.username,
          initialName: null,
          initialAvatarUrl: post.profilePic,
          initialBio: null,
        ),
      ),
    );
  }

  int _likeCountOf(models.Post post) => _likeCounts[post.id] ?? post.likeCount;
  int _commentCountOf(models.Post post) => _commentCounts[post.id] ?? post.comment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: SearchBarField(
                        controller: _ctrl,
                        hintText: 'Search',
                        onSubmitted: _doSearch,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final q = _currentQuery;
    if (q.isEmpty) {
      return const Center(child: Text('Start typing to search'));
    }

    if (_loading && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final loadingMore = _fetchingMore && _posts.isNotEmpty;
    final showUserSection = _currentQuery.isNotEmpty;
    final headerCount = showUserSection ? 1 : 0;
    final showPlaceholder = _posts.isEmpty;
    final baseCount = _posts.length;
    final itemCount = headerCount +
        baseCount +
        (loadingMore ? 1 : 0) +
        (showPlaceholder ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (showUserSection && index == 0) {
            return _matchedUsersSection();
          }

          final headerOffset = headerCount;
          final bodyIndex = index - headerOffset;

          if (showPlaceholder && bodyIndex == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _error != null ? Icons.wifi_off_rounded : Icons.search,
                    size: 56,
                    color: Colors.black38,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error != null
                        ? 'Unable to load search results'
                        : 'No posts matching "$q"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => _runSearch(reset: true),
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            );
          }

          if (loadingMore && bodyIndex >= baseCount && !showPlaceholder) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (bodyIndex < 0 || bodyIndex >= baseCount) {
            return const SizedBox.shrink();
          }
          final postIndex = bodyIndex;
          if (postIndex < 0 || postIndex >= _posts.length) {
            return const SizedBox.shrink();
          }
          final post = _posts[postIndex];
          return PostCard(
            post: post,
            isLiked: _likedIds.contains(post.id),
            likeCount: _likeCountOf(post),
            commentCount: _commentCountOf(post),
            onToggleLike: () => _toggleLike(post),
            onCommentTap: () => _openPost(post),
            onCardTap: () => _openPost(post),
            onHashtagTap: _openHashtag,
            onAvatarTap: () => _openProfile(post),
          );
        },
      ),
    );
  }

  Widget _matchedUsersSection() {
    final entries = _userMatches
        .take(3)
        .toList()
      ..sort((a, b) => a.primaryLabel.toLowerCase().compareTo(b.primaryLabel.toLowerCase()));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.people_outline, color: Color(0xFF7D6BC5)),
                  label: const Text('People'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7D6BC5),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _currentQuery.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PeopleSearchPage(
                                query: _currentQuery,
                                db: _db,
                              ),
                            ),
                          );
                        },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF7D6BC5),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _currentQuery.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PeopleSearchPage(
                                query: _currentQuery,
                                db: _db,
                              ),
                            ),
                          );
                        },
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_userLoading && entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_userError != null && entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unable to load people',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white),
                    onPressed: () => _searchUsers(query: _currentQuery, reset: true),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          if (!_userLoading && _userError == null && entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No matching people found',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          if (entries.isNotEmpty) ...[
            ...entries.map((m) => _previewUserTile(context, m)),
          ],
          if (_userMatches.length > entries.length)
            const SizedBox(height: 6),
          const SizedBox(height: 8),
          const Divider(height: 0),
        ],
      ),
    );
  }

  Widget _previewUserTile(BuildContext context, _MatchedUser match) {
    final theme = Theme.of(context);
    final bg = AppColors.sage.withOpacity(.12);

    ImageProvider? _avatar() {
      final raw = match.avatarUrl.trim();
      if (raw.isEmpty) return null;
      if (raw.startsWith('assets/')) return AssetImage(raw);
      if (raw.startsWith('http://') || raw.startsWith('https://')) return NetworkImage(raw);
      if (raw.startsWith('/')) {
        // Use same absolute rule as people_search_page
        final base = DatabaseService().baseUrl; // API base
        final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
        return NetworkImage('$b$raw');
      }
      return null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openProfileMatch(match),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sage.withOpacity(.35)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: _avatar(),
                  backgroundColor: AppColors.sage.withOpacity(.25),
                  child: _avatar() == null
                      ? const Icon(Icons.person_outline, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.primaryLabel,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (match.secondaryLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          match.secondaryLabel,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openProfileMatch(_MatchedUser match) {
    if (match.id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: match.id,
          initialUsername: match.username.isNotEmpty ? match.username : null,
          initialName: match.displayName.isNotEmpty ? match.displayName : null,
          initialAvatarUrl: match.avatarUrl.isNotEmpty ? match.avatarUrl : null,
          initialBio: null,
        ),
      ),
    );
  }

}
