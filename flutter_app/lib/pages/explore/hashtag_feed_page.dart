import 'package:flutter/material.dart';

import '../../components/app_colors.dart';
import '../../components/post_card.dart';
import '../../models/post.dart';
import '../post_detail.dart';
import '../../services/database_service.dart';
import '../../controllers/like_controller.dart';

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
  late final FeedLikeController _likes;

  // Paging
  bool _loading = true;
  bool _fetchingMore = false;
  String? _nextCursor;
  List<Post> _posts = [];

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _likes = FeedLikeController(
      db: _db,
      setState: setState,
      showSnack: _snack,
    );
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
      });
      _likes.seedFromPosts(page.items);
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
      });
      _likes.seedFromPosts(page.items);
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

  void _toggleLike(Post p) {
    _likes.toggleLike(p);
  }

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

    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => PostPage(post: synced)),
    );

    if (!mounted || result == null) return;
    final postIdRaw = result['postId'];
    if (postIdRaw is! String || postIdRaw.isEmpty) return;
    if (postIdRaw != p.id) return;
    _likes.applyFromDetail(
      postId: postIdRaw,
      liked: result['liked'] as bool?,
      likeCount: result['likeCount'] as int?,
      commentCount: result['commentCount'] as int?,
    );
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: Colors.black87,
        );

    Widget headerBar = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('#${widget.hashtag}', style: titleStyle, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );

    Widget listBody;
    if (_loading) {
      listBody = const Center(child: CircularProgressIndicator());
    } else {
      listBody = RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: _posts.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No posts for this hashtag', style: TextStyle(color: Colors.black54))),
                  SizedBox(height: 120),
                ],
              )
            : ListView.builder(
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
                  WidgetsBinding.instance.addPostFrameCallback((_) => _likes.ensureLikeState(p));
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
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          headerBar,
          Expanded(child: listBody),
        ],
      ),
    );
  }
}

