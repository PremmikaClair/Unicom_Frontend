// lib/pages/post_detail.dart
import 'package:flutter/material.dart';
import 'package:flutter_app/components/app_colors.dart';
import 'package:flutter_app/components/post_card.dart';
import 'package:flutter_app/models/post.dart' as models;
import 'package:flutter_app/services/database_service.dart';
import 'profile/profile_page.dart';
import 'explore/hashtag_feed_page.dart';

class PostPage extends StatefulWidget {
  final models.Post post;
  const PostPage({super.key, required this.post});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  // ---- API base ----
  late final DatabaseService _db = DatabaseService();

  // ---- comment state ----
  final List<_CommentItem> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _nextCursor; // for paging if needed later

  // ---- input state ----
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _listController = ScrollController();

  // ---- like/comment counters (local view) ----
  bool _liked = false; // initial from post.isLiked
  late int _likeCount = widget.post.likeCount;
  late int _commentCount = widget.post.comment;
  bool _likingPost = false; // in-flight guard for post like
  final Set<String> _likingCommentIds = {}; // in-flight guard for comment likes

  // ✅ track ว่าเรารีเฟรชสถานะจาก /posts/:id แล้วหรือยัง
  bool _initialRefreshed = false;

  // ✅ anti-race: เพิ่ม epoch และ flag ว่าผู้ใช้เคยกดหัวใจแล้ว
  int _likeEpoch = 0;               // เพิ่มทุกครั้งที่มี action like/unlike ในหน้า
  bool _userTouchedLike = false;    // true หลังผู้ใช้กดหัวใจครั้งแรก

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.comment;

    _refreshPostLikeState(); // ✅ ดึงสถานะจริงของโพสต์จาก backend (มี guard)
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _refreshPostLikeState() async {
    // จด epoch ตอนเริ่ม เพื่อกันผลลัพธ์ล้าสมัย
    final startedAt = _likeEpoch;
    try {
      final fresh = await _db.getPostByIdFiber(widget.post.id);
      if (!mounted) return;

      // ถ้าระหว่างรอ ผู้ใช้กดหัวใจไปแล้ว หรือ epoch เปลี่ยน → อย่าทับค่า optimistic
      if (_userTouchedLike || startedAt != _likeEpoch) return;

      setState(() {
        _liked = fresh.isLiked;
        _likeCount = fresh.likeCount;
        _commentCount = fresh.comment;
        _initialRefreshed = true;
      });
    } catch (_) {
      // ignore silently
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final page = await _db.getComments(postId: widget.post.id, limit: 20, cursor: null);
      final items = page.items
          .map((c) => _CommentItem(
                id: c.id,
                user: c.userId, // will enrich to name below
                avatar: null,
                text: c.text,
                createdAt: c.createdAt,
                likeCount: c.likeCount,
                liked: false,
              ))
          .toList();

      setState(() {
        _comments
          ..clear()
          ..addAll(items);
        _nextCursor = page.nextCursor;
        _loading = false;
      });

      await _enrichCommentUsers();
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('โหลดคอมเมนต์ไม่สำเร็จ');
    }
  }

  // Enrich comment.user from userId -> profile name
  Future<void> _enrichCommentUsers() async {
    final hex24 = RegExp(r'^[a-fA-F0-9]{24}$');
    final ids = <String>{
      for (final c in _comments)
        if (c.user.isNotEmpty && hex24.hasMatch(c.user)) c.user,
    };
    if (ids.isEmpty) return;
    final Map<String, String> nameById = {};
    for (final id in ids) {
      try {
        final prof = await _db.getUserByObjectIdFiber(id);
        final first = (prof['firstname'] ?? prof['firstName'] ?? '').toString();
        final last = (prof['lastname'] ?? prof['lastName'] ?? '').toString();
        final full = [first, last].where((s) => s.isNotEmpty).join(' ').trim();
        if (full.isNotEmpty) nameById[id] = full;
      } catch (_) {
        // ignore per-user failures
      }
    }
    if (nameById.isEmpty || !mounted) return;
    setState(() {
      for (final c in _comments) {
        final nm = nameById[c.user];
        if (nm != null) {
          c.user = nm;
        }
      }
    });
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
      setState(() {
        _comments.add(_CommentItem(
          id: created.id,
          user: created.userId,
          avatar: null,
          text: created.text,
          createdAt: created.createdAt,
          likeCount: created.likeCount,
          liked: false,
        ));
        _commentCount = _commentCount + 1;
        _controller.clear();
      });
      _scrollToBottom();
      await _enrichCommentUsers();
    } catch (e) {
      _showSnack('ส่งคอมเมนต์ไม่สำเร็จ');
    } finally {
      setState(() => _sending = false);
    }
  }

  void _toggleLike() async {
    if (_likingPost) return;
    setState(() {
      _likingPost = true;
      _userTouchedLike = true;   // ผู้ใช้เริ่มแตะ like แล้ว
    });

    final currentEpoch = ++_likeEpoch; // bump ก่อนยิง request (ผูก response กับ epoch นี้)
    final wasLiked = _liked;
    final prevCount = _likeCount;

    // ✅ Optimistic
    setState(() {
      _liked = !wasLiked;
      _likeCount = wasLiked ? (prevCount - 1).clamp(0, 1 << 30) : prevCount + 1;
    });

    try {
      final r = await _db.toggleLike(targetId: widget.post.id, targetType: 'post');

      // ถ้าระหว่างรอ มีการกด like รอบใหม่ (epoch เปลี่ยน) → response นี้ล้าสมัย ไม่ต้อง apply
      if (!mounted || currentEpoch != _likeEpoch) return;

      // ✅ Reconcile กันเคส backend ส่ง delta (0/1) มา
      final optimisticNow = _likeCount; // หลังจาก optimistic แล้ว
      final serverVal = r.likeCount;

      int reconciled;
      final looksLikeDelta =
          serverVal <= 2 && (optimisticNow - serverVal).abs() > 2 && prevCount >= 2;

      if (serverVal < 0) {
        reconciled = optimisticNow;
      } else if (looksLikeDelta) {
        reconciled = optimisticNow;
      } else {
        reconciled = serverVal;
      }

      setState(() {
        _liked = r.liked;
        _likeCount = reconciled;
      });

      // ไม่ต้องรีเฟรชทันทีเพื่อลดโอกาสโดนทับ (มีปุ่มย้อนกลับ sync ค่าให้ Home อยู่แล้ว)
      // ถ้าต้องการรีเช็คจริง ๆ ให้ทำเมื่อผู้ใช้กลับหน้าเดิมหรือดึงเพื่อรีเฟรช
      // _refreshPostLikeState();

    } catch (_) {
      if (!mounted) return;
      // rollback
      setState(() {
        _liked = wasLiked;
        _likeCount = prevCount;
      });
      _showSnack('อัปเดตไลค์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _likingPost = false);
    }
  }

  // ----  toggle like คอมเมนต์ ----
  Future<void> _toggleCommentLike(int index) async {
    final item = _comments[index];
    final key = item.id ?? item.localId ?? '#$index';
    if (_likingCommentIds.contains(key)) return;
    _likingCommentIds.add(key);

    final wasLiked = item.liked;
    final prevCount = item.likeCount;

    // ✅ Optimistic
    setState(() {
      item.liked = !wasLiked;
      item.likeCount = wasLiked ? (prevCount - 1) : (prevCount + 1);
      if (item.likeCount < 0) item.likeCount = 0;
    });

    try {
      if (item.id != null) {
        final r = await _db.toggleLike(targetId: item.id!, targetType: 'comment');

        // ✅ Reconcile กันเคส delta
        final optimisticNow = item.likeCount;
        final serverVal = r.likeCount;
        final looksLikeDelta =
            serverVal <= 2 && (optimisticNow - serverVal).abs() > 2 && prevCount >= 2;

        int reconciled;
        if (serverVal < 0) {
          reconciled = optimisticNow;
        } else if (looksLikeDelta) {
          reconciled = optimisticNow;
        } else {
          reconciled = serverVal;
        }

        if (!mounted) return;
        setState(() {
          item.liked = r.liked;
          item.likeCount = reconciled < 0 ? 0 : reconciled;
        });
      }
    } catch (_) {
      if (!mounted) return;
      // rollback
      setState(() {
        item.liked = wasLiked;
        item.likeCount = prevCount;
      });
      _showSnack('กดไลค์คอมเมนต์ไม่สำเร็จ');
    } finally {
      _likingCommentIds.remove(key);
    }
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

  // ✅ ส่งสถานะล่าสุดกลับหน้า Home เมื่อผู้ใช้กดย้อนกลับ
  Future<bool> _onWillPop() async {
    Navigator.of(context).pop({
      'postId': widget.post.id,
      'liked': _liked,
      'likeCount': _likeCount,
      'commentCount': _commentCount,
    });
    return false; // เรา pop เองแล้ว
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // การ์ดโพสต์ (ใช้ PostCard เดิม)
    final postCard = PostCard(
      post: widget.post,
      isLiked: _liked,
      likeCount: _likeCount,
      commentCount: _commentCount,
      onToggleLike: _toggleLike,
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

    return WillPopScope(
      onWillPop: _onWillPop, // ✅ wrap เพื่อส่งค่ากลับ
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
                    ..._comments.asMap().entries.map((e) {
                      final i = e.key;
                      final c = e.value;
                      return _CommentTile(
                        item: c,
                        onToggleLike: () => _toggleCommentLike(i),
                      );
                    }).toList(),
                  const SizedBox(height: 80), // เผื่อพื้นที่ให้ input bar
                ],
              ),
            ),

            // --- Input bar (ส่งคอมเมนต์) ---
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
  final VoidCallback? onToggleLike; // NEW
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
  final String? id;     // id จริงของคอมเมนต์ (อาจยังไม่มีตอน optimistic)
  String user;          // may be enriched from userId -> name
  final String? avatar;
  final String text;
  final DateTime createdAt;

  // สำหรับ optimistic/rollback
  final String? localId;

  // สำหรับ like คอมเมนต์
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
