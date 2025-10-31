// lib/pages/post_detail.dart
import 'package:flutter/material.dart';
import 'package:flutter_app/components/app_colors.dart';
import 'package:flutter_app/components/post_card.dart';
import 'package:flutter_app/models/post.dart' as models;
import 'package:flutter_app/services/database_service.dart';
import 'profile/profile_page.dart';
import 'explore/hashtag_feed_page.dart';

import '../controllers/like_controller.dart'; // ใช้ทั้ง FeedLikeController และ CommentLikeController

class PostPage extends StatefulWidget {
  final models.Post post;
  const PostPage({super.key, required this.post});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  // ---- API base ----
  late final DatabaseService _db = DatabaseService();

  // ---- Like controllers ----
  late final FeedLikeController _likes;           // ไลก์ของ "โพสต์"
  late final CommentLikeController _commentLikes; // ไลก์ของ "คอมเมนต์"

  // ---- comment state ----
  final List<_CommentItem> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _nextCursor;               // ใช้เรียกหน้าเพิ่ม
  bool _loadingMore = false;         // สถานะกำลังโหลดหน้าเพิ่ม

  // ---- input state ----
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _listController = ScrollController();
  final Map<String, String> _userNameCache = {}; // cache userId -> display name
  final Set<String> _fetchingUserIds = {};       // avoid duplicate in-flight fetches

  // ---- counters ----
  late int _commentCount = widget.post.comment;

  @override
  void initState() {
    super.initState();

    // Controller สำหรับไลก์ "โพสต์"
    _likes = FeedLikeController(
      db: _db,
      setState: setState,
      showSnack: _showSnack,
    );
    _likes.seedFromPosts([widget.post]);
    _likes.ensureLikeState(widget.post);

    // Controller สำหรับไลก์ "คอมเมนต์"
    _commentLikes = CommentLikeController(
      db: _db,
      setState: setState,
      showSnack: _showSnack,
    );

    // (ออปชัน) auto-load หน้าเพิ่มเมื่อเลื่อนใกล้ล่าง
    _listController.addListener(() {
      if (_nextCursor == null || _loadingMore || _loading) return;
      final pos = _listController.position;
      if (pos.pixels > pos.maxScrollExtent - 200) {
        _loadMoreComments();
      }
    });

    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _listController.dispose();
    super.dispose();
  }

  // ---------- โหลดหน้าแรก ----------
  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final page = await _db.getComments(
        postId: widget.post.id,
        limit: 20,
        cursor: null,
      );

      // seed like states สำหรับคอมเมนต์
      _commentLikes.seedFromComments(page.items);

      final items = page.items.map((c) {
        final liked = _commentLikes.isLikedById(c.id);
        final likeCount = _commentLikes.likeCountOfId(c.id);
        return _CommentItem(
          id: c.id,
          user: c.userId,
          avatar: null,
          text: c.text,
          createdAt: c.createdAt,
          likeCount: likeCount,
          liked: liked,
        );
      }).toList();

      setState(() {
        _comments
          ..clear()
          ..addAll(items);
        _nextCursor = page.nextCursor; // <- เก็บ cursor ไว้ใช้หน้าเพิ่ม
        _loading = false;
      });
      // enrich รายชื่อแบบเบื้องหลัง ไม่บล็อก UI
      _enrichCommentUsers();
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('โหลดคอมเมนต์ไม่สำเร็จ');
    }
  }

  // ---------- โหลดหน้าเพิ่ม ----------
  Future<void> _loadMoreComments() async {
    if (_nextCursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _db.getComments(
        postId: widget.post.id,
        limit: 20,
        cursor: _nextCursor,
      );

      // seed like states สำหรับคอมเมนต์หน้าใหม่
      _commentLikes.seedFromComments(page.items);

      final more = page.items.map((c) {
        final liked = _commentLikes.isLikedById(c.id);
        final likeCount = _commentLikes.likeCountOfId(c.id);
        return _CommentItem(
          id: c.id,
          user: c.userId,
          avatar: null,
          text: c.text,
          createdAt: c.createdAt,
          likeCount: likeCount,
          liked: liked,
        );
      }).toList();

      setState(() {
        _comments.addAll(more);
        _nextCursor = page.nextCursor; // ถ้าไม่มีต่อ จะเป็น null
      });

      // enrich แบบเบื้องหลัง ไม่บล็อกการเลื่อน
      _enrichCommentUsers();
    } catch (e) {
      _showSnack('โหลดคอมเมนต์หน้าเพิ่มไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // Enrich comment.user from userId -> profile name (concurrent + cached)
  Future<void> _enrichCommentUsers() async {
    if (!mounted) return;
    final hex24 = RegExp(r'^[a-fA-F0-9]{24}$');
    // เก็บเฉพาะ id ที่ยังเป็นรูปแบบ ObjectId และยังไม่ได้ cache
    final pending = <String>[
      for (final c in _comments)
        if (c.user.isNotEmpty && hex24.hasMatch(c.user) && !_userNameCache.containsKey(c.user)) c.user,
    ].toSet().toList();
    if (pending.isEmpty) return;

    // จำกัดจำนวนสูงสุดต่อรอบ เพื่อไม่อัด network
    const int maxResolve = 20;
    final ids = pending.take(maxResolve).where((id) => !_fetchingUserIds.contains(id)).toList();
    if (ids.isEmpty) return;
    _fetchingUserIds.addAll(ids);

    // ยิงพร้อมกันทีละเป็น batch เล็ก ๆ ให้เร็วแต่ไม่หนักเกินไป
    const int perBatch = 6;
    for (var i = 0; i < ids.length; i += perBatch) {
      final batch = ids.sublist(i, (i + perBatch).clamp(0, ids.length));
      try {
        final futures = batch.map((id) async {
          try {
            final prof = await _db.getUserByObjectIdFiber(id);
            final first = (prof['firstname'] ?? prof['firstName'] ?? '').toString();
            final last  = (prof['lastname']  ?? prof['lastName']  ?? '').toString();
            final full = [first, last].where((s) => s.isNotEmpty).join(' ').trim();
            if (full.isNotEmpty) return MapEntry(id, full);
          } catch (_) {}
          return null;
        }).toList();
        final results = await Future.wait(futures);
        final updates = <String, String>{
          for (final e in results)
            if (e != null) e.key: e.value,
        };

        if (updates.isNotEmpty && mounted) {
          setState(() {
            _userNameCache.addAll(updates);
            for (final c in _comments) {
              final nm = _userNameCache[c.user];
              if (nm != null) c.user = nm;
            }
          });
        }
      } finally {
        _fetchingUserIds.removeAll(batch);
      }
    }
  }

  void _focusCommentField() {
    FocusScope.of(context).requestFocus(_focus);
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final created = await _db.addComment(postId: widget.post.id, text: text);

      // seed สถานะไลก์ของคอมเมนต์ใหม่เข้า controller
      _commentLikes.seedFromComments([created]);

      setState(() {
        _comments.add(_CommentItem(
          id: created.id,
          user: created.userId,
          avatar: null,
          text: created.text,
          createdAt: created.createdAt,
          likeCount: _commentLikes.likeCountOfId(created.id),
          liked: _commentLikes.isLikedById(created.id),
        ));
        _commentCount = _commentCount + 1;
        _controller.clear();
      });
      _scrollToBottom();
      _enrichCommentUsers();
    } catch (e) {
      _showSnack('ส่งคอมเมนต์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Toggle like คอมเมนต์ผ่าน CommentLikeController
  Future<void> _toggleCommentLike(int index) async {
    final item = _comments[index];
    final id = item.id;
    if (id == null || id.isEmpty) return;

    await _commentLikes.toggle(id);

    if (!mounted) return;
    setState(() {
      _comments[index].liked = _commentLikes.isLikedById(id);
      _comments[index].likeCount = _commentLikes.likeCountOfId(id);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listController.hasClients) return;
      _listController.animateTo(
        _listController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(msg)));
  }

  // ส่งสถานะล่าสุดกลับหน้า Home เมื่อผู้ใช้กดย้อนกลับ
  Future<bool> _onWillPop() async {
    Navigator.of(context).pop({
      'postId': widget.post.id,
      'liked': _likes.isLiked(widget.post),
      'likeCount': _likes.likeCountOf(widget.post),
      'commentCount': _commentCount,
    });
    return false; // เรา pop เองแล้ว
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // การ์ดโพสต์ — ไลก์โพสต์ใช้ controller เหมือน Home
    final postCard = PostCard(
      post: widget.post,
      isLiked: _likes.isLiked(widget.post),
      likeCount: _likes.likeCountOf(widget.post),
      commentCount: _commentCount,
      onToggleLike: () => _likes.toggleLike(widget.post),
      onCommentTap: _focusCommentField,
      onCardTap: () {}, // ไม่ต้องทำอะไรในหน้ารายละเอียด
      onHashtagTap: (tag) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HashtagFeedPage(hashtag: tag)),
        );
      },
      onAvatarTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(
              userId: widget.post.userId.isNotEmpty ? widget.post.userId : null,
              initialUsername: widget.post.username,
              initialAvatarUrl: widget.post.profilePic,
            ),
          ),
        );
      },
    );

    // lazy sync สถานะจริงของโพสต์
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _likes.ensureLikeState(widget.post);
    });

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black87),
            onPressed: () => _onWillPop(),
          ),
          centerTitle: true,
          title: const _KucomTitle(),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _listController,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: postCard,
                  ),

                  // --- Comments header ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                    child: Row(
                      children: [
                        const Icon(Icons.forum_outlined, size: 18, color: Colors.black87),
                        const SizedBox(width: 6),
                        Text(
                          'Comments ($_commentCount)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),

                  // --- Comments list ---
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Opacity(
                        opacity: 0.7,
                        child: Column(
                          children: const [
                            Icon(Icons.chat_bubble_outline, size: 36, color: Colors.black45),
                            SizedBox(height: 8),
                            Text('ยังไม่มีคอมเมนต์ ลองพิมพ์คอมเมนต์แรกดูสิ'),
                          ],
                        ),
                      ),
                    )
                  else
                    ...[
                      // แสดงคอมเมนต์ทั้งหมด
                      ..._comments.asMap().entries.map((e) {
                        final i = e.key;
                        final c = e.value;
                        return _CommentTile(
                          item: c,
                          onToggleLike: () => _toggleCommentLike(i),
                        );
                      }),

                      // ปุ่ม "โหลดคอมเมนต์เพิ่ม" (ถ้ายังมี nextCursor)
                      if (_nextCursor != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _loadingMore ? null : _loadMoreComments,
                              child: _loadingMore
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('โหลดคอมเมนต์เพิ่ม'),
                            ),
                          ),
                        ),
                    ],

                  const SizedBox(height: 80), // เผื่อพื้นที่ให้ input bar
                ],
              ),
            ),

            // --- Input bar ---
            Container(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    const Icon(Icons.add_comment_outlined, size: 20, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitComment(),
                        decoration: const InputDecoration(
                          hintText: 'เขียนคอมเมนต์…',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: Color(0xFFF0F0F0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _submitComment,
                      icon: _sending
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 22, color: AppColors.sage),
                      splashRadius: 22,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- UI helpers ----------

class _KucomTitle extends StatelessWidget {
  const _KucomTitle();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        children: [
          TextSpan(
            text: 'KU',
            style: TextStyle(
              color: AppColors.deepGreen,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: 'COM',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final _CommentItem item;
  final VoidCallback? onToggleLike;
  const _CommentTile({required this.item, this.onToggleLike});

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _safeAvatar(item.avatar);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: avatarProvider,
            child: avatarProvider == null
                ? const Icon(Icons.person, size: 16, color: Colors.black54)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    child: Row(
                      children: [
                        Text(item.user, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                        const SizedBox(width: 8),
                        Text(_formatDateTime(item.createdAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.text),

                  // --- like row ---
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: onToggleLike,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                item.liked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: item.liked ? AppColors.sage : Colors.black45,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item.likeCount}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: item.liked ? AppColors.sage : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _safeAvatar(String? src) {
    if (src == null || src.trim().isEmpty) return null;
    if (src.startsWith('assets/')) return AssetImage(src);
    final uri = Uri.tryParse(src.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return null;
    return NetworkImage(uri.toString());
  }

  String _formatDateTime(DateTime dt) {
    final d = dt;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year;
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }
}

// ---------- lightweight comment model (local) ----------
class _CommentItem {
  final String? id;     // id จริงของคอมเมนต์
  String user;          // อาจ enrich จาก userId -> name
  final String? avatar;
  final String text;
  final DateTime createdAt;

  final String? localId; // เผื่อใช้ภายหลัง (optimistic)

  int likeCount;
  bool liked;

  _CommentItem({
    this.id,
    required this.user,
    required this.avatar,
    required this.text,
    required this.createdAt,
    this.localId,
    this.likeCount = 0,
    this.liked = false,
  });
}
