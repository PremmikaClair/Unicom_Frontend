import 'package:flutter/material.dart';

import '../components/app_colors.dart';
import '../components/header_section.dart';
import '../components/post_card.dart';
import '../models/post.dart';
import 'profile_page.dart';
import 'post_page.dart';
import '../services/database_service.dart';

import '../components/filter_pill.dart';
import 'filter_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-xe4h.onrender.com/post',
  );

  late final DatabaseService _db = DatabaseService(baseUrl: _defaultBaseUrl);

  bool _loading = true;
  bool _fetchingMore = false;
  String? _nextCursor;

  List<Post> _posts = [];

  String _query = '';
  final Set<String> _chipIds = <String>{};
  String? _categoryId = 'all';
  String? _roleId = 'any';

  final _scroll = ScrollController();

  // ----- NEW: state สำหรับ like/comment -----
  final Set<String> _likedIds = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _commentCounts = {};

  int _likeCountOf(Post p) => _likeCounts[p.id] ?? p.likeCount;
  int _commentCountOf(Post p) => _commentCounts[p.id] ?? p.comment;

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

  // ---------- Backend calls ----------
  Future<void> _loadFirstPage() async {
    setState(() => _loading = true);

    final sort = _chipIds.contains('liked') ? 'liked' : 'recent';

    try {
      final page = await _db.getPosts(
        q: _query,
        filters: _chipIds.toList(),
        category: _categoryId == 'all' ? null : _categoryId,
        role: _roleId == 'any' ? null : _roleId,
        sort: sort,
        limit: 20,
        cursor: null,
      );
      setState(() {
        _posts = page.items;
        _nextCursor = page.nextCursor;
        _loading = false;

        // init ตัวเลขจากโหลดรอบนี้
        for (final p in _posts) {
          _likeCounts[p.id] = p.likeCount;
          _commentCounts[p.id] = p.comment;
        }
      });
    } catch (e) {
      // setState(() {
      //   _posts = [];
      //   _nextCursor = null;
      //   _loading = false;
      // });
      // _showSnack('Failed to load posts');
    }
  }

  Future<void> _loadMore() async {
    if (_fetchingMore || _nextCursor == null) return;
    setState(() => _fetchingMore = true);

    final sort = _chipIds.contains('liked') ? 'liked' : 'recent';

    try {
      final page = await _db.getPosts(
        q: _query,
        filters: _chipIds.toList(),
        category: _categoryId == 'all' ? null : _categoryId,
        role: _roleId == 'any' ? null : _roleId,
        sort: sort,
        limit: 20,
        cursor: _nextCursor,
      );
      setState(() {
        _posts.addAll(page.items);
        _nextCursor = page.nextCursor;
        _fetchingMore = false;

        for (final p in page.items) {
          _likeCounts[p.id] = p.likeCount;
          _commentCounts[p.id] = p.comment;
        }
      });
    } catch (e) {
      setState(() => _fetchingMore = false);
      _showSnack('Failed to load more');
    }
  }

  Future<void> _onRefresh() => _loadFirstPage();

  void _maybeLoadMore() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }


  // ---------- Like/Comment actions ----------
  void _toggleLike(Post p) async {
    final wasLiked = _likedIds.contains(p.id);
    final current = _likeCounts[p.id] ?? p.likeCount;

    setState(() {
      if (wasLiked) {
        _likedIds.remove(p.id);
        _likeCounts[p.id] = (current - 1).clamp(0, 1 << 31);
      } else {
        _likedIds.add(p.id);
        _likeCounts[p.id] = current + 1;
      }
    });

    // TODO: ยิง API จริงแบบ optimistic
    // try { await _db.like/unlike(p.id); } catch (e) { rollback }
  }

  void _openComments(Post p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostPage(post: p)),
    );
  }

  // ---------- UI ----------
  void _showSnack(String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ---------------------- MOCK (DB-shape) ----------------------
  final List<Map<String, dynamic>> mockPostDocs = [
    {
      '_id': 'p2',
      'user_id': 'u2',
      'profile_pic': 'assets/mock/avatar1.png',
      'username': 'fernfern05',
      'category': 'announcement',
      'message': 'เชิญชวนร่วมงาน comsampan เสาร์นี้ที่วิศวะคอมค่ะ #cpsk',
      'picture': 'https://images.pexels.com/photos/3861958/pexels-photo-3861958.jpeg?auto=compress&cs=tinysrgb&w=800',
      'like_count': 10,
      'comment': 2,
      'author_roles': ['student'],
      'visibility_roles': ['public'],
      'time_stamp': '2025-08-21T09:30:00Z',
    },
    {
      '_id': 'p21',
      'user_id': 'u21',
      'profile_pic': 'assets/mock/avatar21.png',
      'username': 'study_buddy',
      'category': 'study',
      'message': 'หากลุ่มอ่านหนังสือสอบกลางภาคด้วยกัน #ติวหนังสือ',
      'picture': 'https://picsum.photos/seed/study/800/500',
      'like_count': 12,
      'comment': 3,
      'author_roles': ['student'],
      'visibility_roles': ['public'],
      'time_stamp': '2025-08-22T09:00:00Z',
    },
    {
      '_id': 'p3',
      'user_id': 'u3',
      'profile_pic': 'assets/mock/avatar2.png',
      'username': 'kub_samurai',
      'category': 'market',
      'message': 'ใครมีเสื้อบอล KU ของแท้ แนะนำหน่อยครับ #พร้อมแลก',
      'video': 'assets/mock/post_market.mp4',
      'like_count': 5,
      'comment': 1,
      'author_roles': ['student'],
      'visibility_roles': ['public'],
      'time_stamp': '2025-08-20T14:00:00Z',
    },
    {
      '_id': 'p4',
      'user_id': 'u4',
      'profile_pic': 'assets/mock/avatar3.png',
      'username': 'doremodereme',
      'category': 'qa',
      'message': 'หาเพื่อนดูโดราเอม่อน ep905 ครับ #เพื่อนน้อยพร้อมอวย',
      'like_count': 7,
      'comment': 0,
      'author_roles': ['student'],
      'visibility_roles': ['public'],
      'time_stamp': '2025-08-19T18:40:00Z',
    },
    {
      '_id': 'p5',
      'user_id': 'u5',
      'profile_pic': 'assets/mock/avatar4.png',
      'username': 'chanoknarin',
      'category': 'study',
      'message': 'เปิดรับเพื่อนติวสอบคณิต ช่วยกันอ่านเด้อ',
      'like_count': 2,
      'comment': 0,
      'author_roles': ['student'],
      'visibility_roles': ['public'],
      'time_stamp': '2025-08-18T08:10:00Z',
    },
    {
      '_id': 'p6',
      'user_id': 'u6',
      'profile_pic': 'assets/mock/avatar5.png',
      'username': 'mintymilk',
      'category': 'market',
      'message': 'ขายหนังสือมือสอง สภาพดี #ตลาดนัดนักศึกษา',
      'picture': 'https://picsum.photos/seed/market/800/500',
      'video': 'assets/mock/post_books.mp4',
      'like_count': 9,
      'comment': 4,
      'author_roles': ['student'],
      'visibility_roles': ['public'],
      'time_stamp': '2025-08-17T12:00:00Z',
    },
    {
      '_id': 'p7',
      'user_id': 'u7',
      'profile_pic': 'assets/mock/avatar6.png',
      'username': 'pon_kung',
      'category': 'sport',
      'message': 'รับสมัครสมาชิกทีมบาสเพิ่ม 2 ตำแหน่ง',
      'like_count': 3,
      'comment': 1,
      'author_roles': ['student'],
      'visibility_roles': ['public'],
      'time_stamp': '2025-08-16T16:25:00Z',
    },
  ];

  late final List<Post> mockPostsUi =
      mockPostDocs.map((j) => Post.fromJson(j)).toList();

  Widget _buildEmptyBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...mockPostsUi.map((p) {
            // init state สำหรับ mock
            final liked = _likedIds.contains(p.id);
            final likes = _likeCounts[p.id] ?? p.likeCount;
            final comments = _commentCounts[p.id] ?? p.comment;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: 0.9,
                child: PostCard(
                  post: p,
                  isLiked: liked,
                  likeCount: likes,
                  commentCount: comments,
                  onToggleLike: () => _toggleLike(p),
                  onCommentTap: () => _openComments(p),
                  onCardTap: () => _openComments(p),
                  onAvatarTap: () {},
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _onRefresh,
            child: const Text('รีเฟรช / รีเซ็ตตัวกรอง'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeaderSection(
          onAvatarTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
        ),
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row (
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilterPill(
                  label: 'filter',
                  leading: Icons.filter_list,
                  selected: false,
                  onTap: () async {
                    final result = await showModalBottomSheet<FilterSheetResult>(
                      context: context,
                      isScrollControlled: true,            // สำคัญสำหรับ DraggableScrollableSheet
                      backgroundColor: Colors.transparent, // ให้มุมบนโค้งสวย
                      builder: (_) => FilterBottomSheet(
                        loadFilters: mockLoadFilters,      // ใส่ loader จริงของคุณได้
                        initial: const FilterSheetResult(
                          facultyIds: {}, clubIds: {}, categoryIds: {},
                        ),
                      ),
                    );

  if (result != null) {
    // TODO: นำ result.facultyIds / clubIds / categoryIds
    // ไป map เข้าฟิลเตอร์หน้า HomePage แล้วเรียก _loadFirstPage()
  }
}
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
            onAvatarTap: () {},
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
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
    );
  }
}