// lib/pages/search_feed_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../components/post_card.dart';
import '../../models/post.dart';
import '../post_detail.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class SearchFeedPage extends StatefulWidget {
  final String initialQuery;
  const SearchFeedPage({super.key, this.initialQuery = ''});

  @override
  State<SearchFeedPage> createState() => _SearchFeedPageState();
}

class _SearchFeedPageState extends State<SearchFeedPage> {
  late final DatabaseService _db = DatabaseService();

  // Query + paging
  final _qCtrl = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = false;
  bool _fetchingMore = false;
  String? _nextCursor;
  List<Post> _posts = [];
  String _lastExecutedQ = '';

  // Like state
  final Set<String> _likedIds = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _commentCounts = {};
  final Set<String> _liking = {};

  @override
  void initState() {
    super.initState();
    _qCtrl.text = widget.initialQuery;
    _scroll.addListener(_maybeLoadMore);
    if (_qCtrl.text.trim().isNotEmpty) {
      _searchFirst();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    _qCtrl.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _searchFirst() async {
    final q = _qCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _posts = [];
      _nextCursor = null;
      _lastExecutedQ = q;
    });
    try {
      final page = await _fetchPage(q: q, limit: 20);
      if (!mounted) return;
      setState(() {
        _posts = page.items;
        _nextCursor = page.nextCursor;
        _loading = false;
      });
      _syncCounts(page.items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _posts = [];
        _nextCursor = null;
      });
      _snack('Search failed: $e');
    }
  }

  Future<void> _loadMore() async {
    if (_fetchingMore || _nextCursor == null || _lastExecutedQ.isEmpty) return;
    setState(() => _fetchingMore = true);
    try {
      final page = await _fetchPage(q: _lastExecutedQ, limit: 20, cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _posts.addAll(page.items);
        _nextCursor = page.nextCursor;
        _fetchingMore = false;
      });
      _syncCounts(page.items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _fetchingMore = false);
      _snack('Failed to load more: $e');
    }
  }

  void _syncCounts(List<Post> list) {
    for (final p in list) {
      _likeCounts[p.id] = p.likeCount;
      _commentCounts[p.id] = p.comment;
      if (p.isLiked) _likedIds.add(p.id);
    }
  }

  /// ยิง /posts/feed โดย:
  /// 1) ยิงไปยัง AuthService.I.apiBase ก่อน
  /// 2) ถ้าไม่ 200 (เช่น 404 เพราะอยู่พอร์ต 3000) จะสลับไปพอร์ต 8000 แล้วยิงซ้ำอัตโนมัติ
  Future<_FeedPaged> _fetchPage({required String q, int limit = 20, String? cursor}) async {
    final headers = AuthService.I.headers(extra: const {'Accept': 'application/json'});

    Future<http.Response> _try(Uri u) =>
        http.get(u, headers: headers).timeout(const Duration(seconds: 12));

    Uri _build(Uri base, {int? portOverride}) {
      final path = '/posts/feed';
      final baseClean = base.replace(
        path: path,
        queryParameters: {
          'q': q,
          'limit': '$limit',
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
        port: portOverride ?? base.port,
      );
      return baseClean;
    }

    // ---- attempt 1: ใช้ apiBase ตรง ๆ ----
    final base = Uri.parse(
      AuthService.I.apiBase.endsWith('/')
          ? AuthService.I.apiBase.substring(0, AuthService.I.apiBase.length - 1)
          : AuthService.I.apiBase,
    );
    var uri = _build(base);
    var res = await _try(uri);

    // ---- attempt 2: ถ้าไม่ 200 → ลองพอร์ต 8000 ตามสเปกใหม่ ----
    if (res.statusCode != 200) {
      // เฉพาะกรณี dev มักใช้ 3000; เราจะบังคับไป 8000 อัตโนมัติ
      final alt = _build(base, portOverride: 8000);
      final res2 = await _try(alt);
      if (res2.statusCode != 200) {
        throw Exception('GET $uri -> ${res.statusCode}; then GET $alt -> ${res2.statusCode}\n${res2.body}');
      }
      uri = alt;
      res = res2;
    }

    final String body = res.body.trim();
    if (body.isEmpty) return const _FeedPaged(items: [], nextCursor: null);

    final parsed = jsonDecode(body);
    final list = (parsed is Map<String, dynamic>)
        ? (parsed['items'] ?? parsed['data'] ?? parsed['results'] ?? parsed['posts'] ?? const []) as List<dynamic>
        : (parsed is List ? parsed : const []);
    final next = (parsed is Map<String, dynamic>)
        ? (parsed['next_cursor'] ?? parsed['nextCursor'])?.toString()
        : null;

    final items = list
        .whereType<Map<String, dynamic>>()
        .map((j) => Post.fromJson(j))
        .toList();

    return _FeedPaged(items: items, nextCursor: next);
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
      if (!mounted) return;
      setState(() {
        if (r.liked) {
          _likedIds.add(p.id);
        } else {
          _likedIds.remove(p.id);
        }
        _likeCounts[p.id] = r.likeCount;
      });
    } catch (_) {
      if (!mounted) return;
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
    final canSearch = !_loading && !_fetchingMore;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextField(
            controller: _qCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchFirst(),
            decoration: InputDecoration(
              hintText: 'ค้นหาโพสต์ ผู้เขียน หรือ #แท็ก',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              filled: true,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: canSearch ? _searchFirst : null,
            tooltip: 'ค้นหา',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (_lastExecutedQ.isEmpty) return;
                await _searchFirst();
              },
              child: (_posts.isEmpty && _lastExecutedQ.isEmpty)
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('พิมพ์คำค้นด้านบนเพื่อเริ่มค้นหา')),
                        SizedBox(height: 120),
                      ],
                    )
                  : (_posts.isEmpty)
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('ไม่พบผลลัพธ์')),
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
                              onHashtagTap: (_) {}, // ไม่ chain ต่อในหน้าค้นหา
                            );
                          },
                        ),
            ),
    );
  }
}

/* --------- Local model for paging --------- */
class _FeedPaged {
  final List<Post> items;
  final String? nextCursor;
  const _FeedPaged({required this.items, required this.nextCursor});
}
