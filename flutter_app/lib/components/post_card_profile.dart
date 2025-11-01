import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_app/components/app_colors.dart';
import 'package:flutter_app/models/post.dart' as models;
import 'package:video_player/video_player.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter_app/services/database_service.dart';

enum _MediaKind { image, video }

class _MediaItem {
  final _MediaKind kind;
  final String src;
  const _MediaItem(this.kind, this.src);
}

class _MediaGallery extends StatefulWidget {
  final List<_MediaItem> items;
  const _MediaGallery({required this.items, super.key});

  @override
  State<_MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<_MediaGallery> {
  final _controller = PageController();
  int _index = 0;

  String _abs(String u) {
    final s = u.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('/')) return '${AuthService.I.apiBase}$s';
    return s;
  }

  void _showImageOverlay(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                clipBehavior: Clip.none,
                child: SizedBox(
                  width: double.infinity,
                  child: _SmartImage(url: _abs(url), fit: BoxFit.contain, darkBg: true),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoOverlay(String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (_) => _VideoOverlay(url: _abs(url)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildItem(widget.items.first),
        ),
      );
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
      if (isAsset) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showImageOverlay(it.src),
          onLongPress: () => _showImageOverlay(it.src),
          child: Container(color: Colors.black12, child: Image.asset(it.src, fit: BoxFit.cover)),
        );
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showImageOverlay(it.src),
        onLongPress: () => _showImageOverlay(it.src),
        child: Container(
          color: Colors.black12,
          child: _SmartImage(url: _abs(it.src), fit: BoxFit.cover),
        ),
      );
    } else {
      return _VideoThumb(
        url: _abs(it.src),
        onTap: () => _showVideoOverlay(it.src),
      );
    }
  }
}

class _VideoThumb extends StatefulWidget {
  final String url;
  final VoidCallback onTap;
  const _VideoThumb({required this.url, required this.onTap});

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  late final VideoPlayerController _c;
  bool _init = false;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    final headers = AuthService.I.headers(extra: const {
      'User-Agent': 'Mozilla/5.0',
      'Accept': 'video/*,application/octet-stream,*/*',
    });
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url), httpHeaders: headers);
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _init = true);
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _err = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _init
        ? FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _c.value.size.width,
              height: _c.value.size.height,
              child: VideoPlayer(_c),
            ),
          )
        : _err
            ? Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, color: Colors.black45),
              )
            : const Center(child: CircularProgressIndicator());

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x55000000), Color(0x11000000)],
                    ),
                  ),
                  child: const Icon(Icons.play_circle_fill, size: 56, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoOverlay extends StatefulWidget {
  final String url;
  const _VideoOverlay({required this.url});
  @override
  State<_VideoOverlay> createState() => _VideoOverlayState();
}

class _VideoOverlayState extends State<_VideoOverlay> {
  late final VideoPlayerController _controller;
  bool _init = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final headers = AuthService.I.headers(extra: const {
      'User-Agent': 'Mozilla/5.0',
      'Accept': 'video/*,application/octet-stream,*/*',
    });
    final abs = widget.url.trim().startsWith('http')
        ? widget.url.trim()
        : (widget.url.trim().startsWith('/')
            ? '${AuthService.I.apiBase}${widget.url.trim()}'
            : widget.url.trim());
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(abs),
      httpHeaders: headers,
    );
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _init = true);
      _controller.play();
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _init && _controller.value.aspectRatio > 0
                  ? _controller.value.aspectRatio
                  : 16 / 9,
              child: _init
                  ? VideoPlayer(_controller)
                  : (_error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Cannot play video\n${_error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                      : const Center(child: CircularProgressIndicator(color: Colors.white))),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                    setState(() {});
                  },
                  icon: Icon(
                    _controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.white,
                    size: 42,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final bool darkBg;
  const _SmartImage({required this.url, this.fit = BoxFit.cover, this.darkBg = false});

  @override
  State<_SmartImage> createState() => _SmartImageState();
}

class _SmartImageState extends State<_SmartImage> {
  Uint8List? _bytes;
  bool _triedBytes = false;
  String? _mimeType;

  bool get _isSvg => widget.url.toLowerCase().trim().endsWith('.svg');

  Future<void> _loadBytes() async {
    if (_triedBytes || _bytes != null) return;
    _triedBytes = true;
    try {
      if (widget.url.startsWith('data:')) {
        final data = UriData.fromString(widget.url);
        if (mounted) {
          setState(() {
            _bytes = data.contentAsBytes();
            _mimeType = data.mimeType;
          });
        }
        return;
      }
      final uri = Uri.parse(widget.url);
      final res = await http
          .get(uri, headers: const {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _bytes = res.bodyBytes;
          final ct = res.headers['content-type'];
          _mimeType = ct != null ? ct.split(';').first.trim().toLowerCase() : null;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isSvg) {
      return SvgPicture.network(
        widget.url,
        headers: const {'User-Agent': 'Mozilla/5.0'},
        fit: widget.fit,
        placeholderBuilder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }
    if (_bytes != null) {
      if ((_mimeType ?? '').contains('svg')) {
        return SvgPicture.memory(_bytes!, fit: widget.fit);
      }
      if (_mimeType == null || _mimeType!.startsWith('image') || _mimeType == 'application/octet-stream') {
        return Image.memory(_bytes!, fit: widget.fit);
      }
      return Center(
        child: Icon(Icons.broken_image, size: 40, color: widget.darkBg ? Colors.white70 : Colors.black45),
      );
    }
    return Image.network(
      widget.url,
      headers: const {'User-Agent': 'Mozilla/5.0'},
      fit: widget.fit,
      errorBuilder: (_, __, ___) {
        _loadBytes();
        return Center(
          child: Icon(Icons.broken_image, size: 40, color: widget.darkBg ? Colors.white70 : Colors.black45),
        );
      },
    );
  }
}

class PostCard extends StatelessWidget {
  final models.Post post;

  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final VoidCallback? onToggleLike;
  final VoidCallback? onCommentTap;

  // แตะส่วนที่เหลือของการ์ด = เข้าโพสต์
  final VoidCallback? onCardTap;
  final VoidCallback? onAvatarTap;
  final void Function(String hashtag)? onHashtagTap;
  final Future<void> Function()? onDeleted;

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
    this.onHashtagTap,
    this.onDeleted,
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

    final media = <_MediaItem>[];
    if (post.images.isNotEmpty || post.videos.isNotEmpty) {
      media.addAll(post.images.map((u) => _MediaItem(_MediaKind.image, u)));
      media.addAll(post.videos.map((u) => _MediaItem(_MediaKind.video, u)));
    } else {
      if (post.picture != null && post.picture!.isNotEmpty) {
        media.add(_MediaItem(_MediaKind.image, post.picture!));
      }
      if (post.video != null && post.video!.isNotEmpty) {
        media.add(_MediaItem(_MediaKind.video, post.video!));
      }
    }

    Widget card = Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 254, 254, 251),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Color(0x11000000), offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onCardTap, // แตะพื้นที่ว่าง/ข้อความ = เข้าโพสต์
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
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
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onAvatarTap,
                          child: Text(
                            post.username,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepGreen,
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dotted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (post.authorRoles.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('Post as: ${post.authorRoles.first}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                        const SizedBox(height: 6),
                        if (post.category.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [ _Chip(text: post.category) ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Message (ไม่ต้องซ้อน GestureDetector แล้ว)
              if (post.message.isNotEmpty)
                _buildMessageWithHashtags(context, post.message),

              // Media (แตะรูป=overlay / วิดีโอ=overlay)
              if (media.isNotEmpty) ...[
                const SizedBox(height: 10),
                _MediaGallery(items: media),
              ],

              const SizedBox(height: 10),

              // Footer
              Row(
                children: [
                  Text(
                    _formatDate(post.timeStamp),
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const Spacer(),
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
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onCommentTap,
                    icon: const Icon(Icons.mode_comment_outlined, size: 18, color: Colors.black87),
                  ),
                  Text('$commentCount', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              )
            ],
          ),
        ),
      ),
    );

    Future<void> _confirmAndDelete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text(
            'Delete post?',
            style: TextStyle(color: AppColors.deepGreen),
          ),
          content: const Text(
            'This action cannot be undone.',
            style: TextStyle(color: AppColors.deepGreen),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: AppColors.deepGreen),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.deepGreen,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await DatabaseService().deletePost(post.id);
        if (onDeleted != null) {
          await onDeleted!();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Stack(
        children: [
          card,
          if (onDeleted != null)
            Positioned(
              right: 6,
              top: 6,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  tooltip: 'Delete post',
                  visualDensity: VisualDensity.compact,
                  onPressed: _confirmAndDelete,
                  iconSize: 18,
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.deepGreen),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  Widget _buildMessageWithHashtags(BuildContext context, String text) {
    final baseStyle = const TextStyle(fontSize: 13, height: 1.35, color: Colors.black87);
    final spans = _buildHashtagSpans(context, text, baseStyle);
    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }

  List<InlineSpan> _buildHashtagSpans(BuildContext context, String text, TextStyle baseStyle) {
    final re = RegExp(r'(^|(?<=\s))#([\u0E00-\u0E7FA-Za-z0-9_]+)', unicode: true, multiLine: true);
    final spans = <InlineSpan>[];
    int idx = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > idx) {
        spans.add(TextSpan(text: text.substring(idx, m.start)));
      }
      final tagWithHash = text.substring(m.start, m.end);
      final tag = tagWithHash.replaceFirst('#', '');
      spans.add(
        TextSpan(
          text: tagWithHash,
          style: baseStyle.copyWith(
            color: AppColors.deepGreen,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (onHashtagTap != null) onHashtagTap!(tag);
            },
        ),
      );
      idx = m.end;
    }
    if (idx < text.length) {
      spans.add(TextSpan(text: text.substring(idx)));
    }
    return spans;
  }
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
