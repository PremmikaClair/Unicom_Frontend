// lib/pages/post_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_app/components/app_colors.dart';
import 'package:flutter_app/components/post_card.dart';
import 'package:flutter_app/models/post.dart' as models;
import 'package:flutter_app/services/database_service.dart';

class PostPage extends StatefulWidget {
  final models.Post post;
  const PostPage({super.key, required this.post});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  // ---- API base ----
  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-xe4h.onrender.com/post',
  );
  late final DatabaseService _db = DatabaseService(baseUrl: _defaultBaseUrl);

  // ---- comment state ----
  final List<_CommentItem> _comments = [];
  bool _loading = true;
  bool _sending = false;

  // ---- input state ----
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _listController = ScrollController();

  // ---- like/comment counters (local view) ----
  bool _liked = false; // ปรับตามข้อมูลจริงได้
  late int _likeCount = widget.post.likeCount;
  late int _commentCount = widget.post.comment;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      // TODO: ถ้าคุณมี endpoint จริง ให้ใช้ _db.getComments(widget.post.id)
      // ตัวอย่าง mock ชั่วคราว:
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final mock = <_CommentItem>[
        // ตัวอย่างคอมเมนต์เริ่มต้น (จะเป็น [] ก็ได้)
        // _CommentItem(user: 'mintymilk', avatar: 'assets/mock/avatar5.png', text: 'น่าสนใจมากเลยครับ', createdAt: DateTime.now().subtract(const Duration(minutes: 30))),
      ];
      setState(() {
        _comments
          ..clear()
          ..addAll(mock);
        // ถ้าคุณต้องการให้ตัวเลขนับจากคอมเมนต์จริง:
        _commentCount = _comments.length; // หรือคงไว้ตาม server ก็ได้
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showSnack('โหลดคอมเมนต์ไม่สำเร็จ');
    }
  }

  void _focusCommentField() {
    FocusScope.of(context).requestFocus(_focus);
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    // optimistic add
    final temp = _CommentItem(
      user: 'you', // TODO: ใส่ชื่อผู้ใช้จริงจากโปรไฟล์/ auth
      avatar: null, // 'assets/mock/your_avatar.png'
      text: text,
      createdAt: DateTime.now(),
      localId: UniqueKey().toString(),
    );

    setState(() {
      _comments.add(temp);
      _commentCount = _comments.length;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      // TODO: call real API
      // await _db.addComment(widget.post.id, text);

      await Future<void>.delayed(const Duration(milliseconds: 250)); // mock

      // ถ้าสำเร็จ: อาจจะรีเฟรชจากเซิร์ฟเวอร์เพื่อ sync id/time ที่แท้จริง
      setState(() {
        // do nothing; optimistic OK
      });
    } catch (e) {
      // rollback เมื่อ error
      setState(() {
        _comments.removeWhere((c) => c.localId == temp.localId);
        _commentCount = _comments.length;
      });
      _showSnack('ส่งคอมเมนต์ไม่สำเร็จ');
    } finally {
      setState(() => _sending = false);
    }
  }

  void _toggleLike() {
    // optimistic like
    setState(() {
      if (_liked) {
        _liked = false;
        _likeCount = (_likeCount - 1).clamp(0, 1 << 31);
      } else {
        _liked = true;
        _likeCount += 1;
      }
    });

    // TODO: ยิง API จริง (_db.like/unlike(widget.post.id)) + rollback เมื่อ error
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
      onAvatarTap: () {}, // แล้วแต่ต้องการ
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black87),
          onPressed: () => Navigator.of(context).maybePop(),
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
                  ..._comments.map((c) => _CommentTile(item: c)).toList(),
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
  const _CommentTile({required this.item});

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
  final String user;
  final String? avatar;
  final String text;
  final DateTime createdAt;

  // สำหรับ optimistic/rollback
  final String? localId;

  _CommentItem({
    required this.user,
    required this.avatar,
    required this.text,
    required this.createdAt,
    this.localId,
  });
}
