import 'package:flutter/material.dart';
import 'package:flutter_app/components/app_colors.dart';
import 'package:flutter_app/models/post.dart' as models;

/// ประเภทสื่อ
enum _MediaKind { image, video }

/// item เดียวในแกลเลอรี
class _MediaItem {
  final _MediaKind kind;
  final String src;
  const _MediaItem(this.kind, this.src);
}

/// แกลเลอรีสื่อ (ภาพ/วิดีโอ) แบบสไลด์ + จุดบอกตำแหน่ง
class _MediaGallery extends StatefulWidget {
  final List<_MediaItem> items;
  const _MediaGallery({required this.items, super.key});

  @override
  State<_MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<_MediaGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.length == 1) {
      return _buildItem(widget.items.first);
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _buildItem(widget.items[i]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.items.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _index == i ? 14 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _index == i ? Colors.black87 : Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(_MediaItem it) {
    if (it.kind == _MediaKind.image) {
      final isAsset = it.src.startsWith('assets/');
      final img = isAsset
          ? Image.asset(it.src, fit: BoxFit.cover)
          : Image.network(
              it.src,
              // กันบางโฮสต์ 403 (เช่น picsum ในบางเคส)
              headers: const {'User-Agent': 'Mozilla/5.0'},
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, size: 40, color: Colors.black45),
              ),
            );
      return Container(color: Colors.black12, child: img);
    } else {
      // วิดีโอ: placeholder (จะสลับเป็น video_player ภายหลังได้)
      return Container(
        color: Colors.black12,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_fill, size: 44, color: Colors.black87),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  it.src,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

/// การ์ดโพสต์แบบ presentational (ไม่เก็บ state เอง)
class PostCard extends StatelessWidget {
  final models.Post post;

  // สถานะ/ตัวเลข + callback (ให้หน้าที่เรียกเป็นคนจัดการ)
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final VoidCallback? onToggleLike;
  final VoidCallback? onCommentTap;

  // การคลิกอื่น ๆ
  final VoidCallback? onCardTap;
  final VoidCallback? onAvatarTap;

  const PostCard({
    super.key,
    required this.post,
    this.isLiked = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.onToggleLike,
    this.onCommentTap,
    this.onCardTap,
    this.onAvatarTap,
  });

  ImageProvider? _safeAvatar(String? src) {
    if (src == null || src.trim().isEmpty) return null;
    if (src.startsWith('assets/')) return AssetImage(src);
    final uri = Uri.tryParse(src.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return null;
    return NetworkImage(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _safeAvatar(post.profilePic);

    // สร้างรายการสื่อ (รูป/วิดีโอ)
    final media = <_MediaItem>[];
    if (post.picture != null && post.picture!.isNotEmpty) {
      media.add(_MediaItem(_MediaKind.image, post.picture!));
    }
    if (post.video != null && post.video!.isNotEmpty) {
      media.add(_MediaItem(_MediaKind.video, post.video!));
    }

    Widget card = Container(
      decoration: BoxDecoration(
        color: AppColors.cardGrey,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(blurRadius: 10, color: Color(0x11000000), offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name + chips
            Row(
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: avatar,
                    child: avatar == null
                        ? const Icon(Icons.person, size: 18, color: Colors.black54)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (post.category.isNotEmpty) _Chip(text: post.category),
                          if (post.authorRoles.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _Chip(text: post.authorRoles.first),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz, color: Colors.black87),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ข้อความ
            if (post.message.isNotEmpty)
              Text(
                post.message,
                style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.black87),
              ),

            // แกลเลอรีสื่อ (ถ้ามี)
            if (media.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MediaGallery(items: media),
            ],

            const SizedBox(height: 10),

            // Footer: วันเวลา + like/comment (ปุ่มทำงานจริง)
            Row(
              children: [
                Text(
                  _formatDate(post.timeStamp),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const Spacer(),

                // Like
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleLike,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: isLiked ? Colors.redAccent : Colors.black87,
                  ),
                ),
                Text('$likeCount', style: const TextStyle(fontSize: 11, color: Colors.black54)),

                const SizedBox(width: 8),

                // Comment
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onCommentTap,
                  icon: const Icon(Icons.mode_comment_outlined, size: 18, color: Colors.black87),
                ),
                Text('$commentCount', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );

    if (onCardTap != null) {
      card = InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onCardTap,
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: card,
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.chipGrey, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.deepGreen),
      ),
    );
  }
}
