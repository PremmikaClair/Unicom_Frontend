import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../components/post_card.dart';
import '../../models/post.dart';
import '../post_detail.dart';
import '../../services/database_service.dart';

/// Hashtag feed page. Push with:
/// Navigator.pushNamed(HashtagFeedPage.routeName, arguments: tag)
class HashtagFeedPage extends StatefulWidget {
  static const String routeName = '/explore/hashtag';

  final String hashtag;
  const HashtagFeedPage({super.key, required this.hashtag});

  @override
  State<HashtagFeedPage> createState() => _HashtagFeedPageState();
}

class _HashtagFeedPageState extends State<HashtagFeedPage> {
  late final DatabaseService _db = DatabaseService();

  // Paging
  bool _loading = true;
  bool _fetchingMore = false;
  String? _nextCursor;
  List<Post> _posts = [];

  // Like state
  final Set<String> _likedIds = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _commentCounts = {};
  final Set<String> _liking = {};

  final _scroll = ScrollController();

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

  Future<void> _loadFirstPage() async {
    setState(() => _loading = true);
    try {
      final page = await _db.getTrendingPostsByTag(tag: widget.hashtag, limit: 20);
      setState(() {
        _posts = page.items;
        _nextCursor = page.nextCursor; // may be null if server doesn’t paginate
        _loading = false;
        for (final p in _posts) {
          _likeCounts[p.id] = p.likeCount;
          _commentCounts[p.id] = p.comment;
          if (p.isLiked) _likedIds.add(p.id);
        }
      });
    } catch (_) {
      setState(() {
        _posts = [];
        _nextCursor = null;
        _loading = false;
      });
      _snack('Failed to load hashtag posts');
    }
  }

  Future<void> _loadMore() async {
    if (_fetchingMore || _nextCursor == null) return;
    setState(() => _fetchingMore = true);
    try {
      final page = await _db.getTrendingPostsByTag(tag: widget.hashtag, limit: 20, cursor: _nextCursor);
      setState(() {
        _posts.addAll(page.items);
        _nextCursor = page.nextCursor;
        _fetchingMore = false;
        for (final p in page.items) {
          _likeCounts[p.id] = p.likeCount;
          _commentCounts[p.id] = p.comment;
          if (p.isLiked) _likedIds.add(p.id);
        }
      });
    } catch (_) {
      setState(() => _fetchingMore = false);
      _snack('Failed to load more');
    }
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _toggleLike(Post p) async {
    if (_liking.contains(p.id)) return;
    _liking.add(p.id);
    final prevLiked = _likedIds.contains(p.id);
    final prevCount = _likeCounts[p.id] ?? p.likeCount;
    setState(() {
      if (prevLiked) {
        _likedIds.remove(p.id);
        _likeCounts[p.id] = math.max(0, prevCount - 1);
      } else {
        _likedIds.add(p.id);
        _likeCounts[p.id] = prevCount + 1;
      }
    });
    try {
      final r = await _db.toggleLike(targetId: p.id, targetType: 'post');
      setState(() {
        if (r.liked) {
          _likedIds.add(p.id);
        } else {
          _likedIds.remove(p.id);
        }
        _likeCounts[p.id] = r.likeCount;
      });
    } catch (_) {
      setState(() {
        if (prevLiked) {
          _likedIds.add(p.id);
        } else {
          _likedIds.remove(p.id);
        }
        _likeCounts[p.id] = prevCount;
      });
      _snack('Failed to update like');
    } finally {
      _liking.remove(p.id);
    }
  }

  void _openComments(Post p) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PostPage(post: p)));
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('#${widget.hashtag}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFirstPage,
              child: _posts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No posts for this hashtag')),
                        SizedBox(height: 120),
                      ],
                    )
                  : ListView.builder(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
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
                          onAvatarTap: null,
                          onHashtagTap: (tag) {
                            if (tag.toLowerCase() == widget.hashtag.toLowerCase()) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => HashtagFeedPage(hashtag: tag)),
                            );
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
