import 'dart:math' as math;
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
  // --- Keep your compile-time config & service (unused for now, API later) ---
  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-xe4h.onrender.com',
  );
  late final DatabaseService _db = DatabaseService(baseUrl: _defaultBaseUrl);

  // --- Paging/Fetching state (unchanged API shape) ---
  bool _loading = true;
  bool _fetchingMore = false;
  String? _nextCursor; // we'll use String index into the mock list

  List<Post> _posts = [];

  // --- Query/filters (kept for structure; not applied to mocks yet) ---
  String _query = '';
  final Set<String> _chipIds = <String>{};
  String? _categoryId = 'all';
  String? _roleId = 'any';

  final _scroll = ScrollController();

  // --- Like/Comment state (optimistic) ---
  final Set<String> _likedIds = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _commentCounts = {};
  int _likeCountOf(Post p) => _likeCounts[p.id] ?? p.likeCount;
  int _commentCountOf(Post p) => _commentCounts[p.id] ?? p.comment;

  // ---------------------- MOCK (DB-shape) ----------------------
  final List<Map<String, dynamic>> mockPostDocs = [
  {
    '_id': 'p101',
    'user_id': 'u101',
    'profile_pic': 'assets/mock/avatar1.png',
    'username': 'fernfern05',
    'category': 'announcement',
    'message': 'ชวนไปงาน comsampan เสาร์นี้ มีบูธกิจกรรมและเวิร์กชอป #cpsk',
    // ทั้งรูป + วิดีโอ
    'picture': 'https://images.pexels.com/photos/3861958/pexels-photo-3861958.jpeg?auto=compress&cs=tinysrgb&w=800',
    'video': 'https://samplelib.com/lib/preview/mp4/sample-5s.mp4',
    'like_count': 18,
    'comment': 4,
    'author_roles': ['student'],
    'visibility_roles': ['public'],
    'time_stamp': '2025-09-07T13:40:00Z',
  },
  {
    '_id': 'p102',
    'user_id': 'u102',
    'profile_pic': 'assets/mock/avatar2.png',
    'username': 'study_buddy',
    'category': 'study',
    'message': 'รวมทีมอ่านมิดเทอม วิชา Data Structure คืนนี้ที่ห้องสมุดชั้น 3',
    // รูปแนวนอน 16:9
    'picture': 'https://picsum.photos/seed/ds-midterm/1280/720',
    'like_count': 12,
    'comment': 3,
    'author_roles': ['student'],
    'visibility_roles': ['public'],
    'time_stamp': '2025-09-06T18:10:00Z',
  },
  {
    '_id': 'p103',
    'user_id': 'u103',
    'profile_pic': 'assets/mock/avatar3.png',
    'username': 'market_mint',
    'category': 'market',
    'message': 'ปล่อย iPad Gen9 สภาพดี แถมเคส #ตลาดนัดKU',
    'like_count': 27,
    'comment': 6,
    'author_roles': ['student'],
    'visibility_roles': ['public'],
    'time_stamp': '2025-09-05T10:05:00Z',
  },
  {
    '_id': 'p104',
    'user_id': 'u104',
    'profile_pic': 'assets/mock/avatar4.png',
    'username': 'lostnfound',
    'category': 'lost-found',
    'message': 'เก็บบัตรนิสิตได้ที่หน้าอาคารเรียนรวม รหัสขึ้นต้น 66xxxx',
    // ไม่มีสื่อ
    'like_count': 5,
    'comment': 1,
    'author_roles': ['staff'],
    'visibility_roles': ['public'],
    'time_stamp': '2025-09-04T07:55:00Z',
  },
  {
    '_id': 'p105',
    'user_id': 'u105',
    'profile_pic': 'assets/mock/avatar5.png',
    'username': 'coding_club',
    'category': 'club',
    'message': 'รับสมัครสมาชิกชมรม Coding รุ่นที่ 5 มีเวิร์กชอปฟรีทุกสัปดาห์',
    'like_count': 34,
    'comment': 9,
    'author_roles': ['student'],
    'visibility_roles': ['student_only'],
    'time_stamp': '2025-09-03T12:30:00Z',
  },
  {
    '_id': 'p106',
    'user_id': 'u106',
    'profile_pic': 'assets/mock/avatar6.png',
    'username': 'ku_event',
    'category': 'event',
    'message': 'บรรยากาศงานกีฬาเฟรชชี่ สนุกมาก!',
    // รูปพาโนรามาแนวกว้าง
    'picture': 'https://picsum.photos/seed/panorama-ku/1200/400',
    'like_count': 21,
    'comment': 2,
    'author_roles': ['student'],
    'visibility_roles': ['public'],
    'time_stamp': '2025-09-02T15:20:00Z',
  },
  {
    '_id': 'p107',
    'user_id': 'u107',
    'profile_pic': 'assets/mock/avatar7.png',
    'username': 'help_me',
    'category': 'qa',
    'message': 'ใครผ่านวิชา OS แล้วมีโน้ตแนะนำไหมครับ 🙏',
    'like_count': 8,
    'comment': 5,
    'author_roles': ['student'],
    'visibility_roles': ['public'],
    'time_stamp': '2025-09-01T20:45:00Z',
  },
  {
    '_id': 'p108',
    'user_id': 'u108',
    'profile_pic': 'assets/mock/avatar8.png',
    'username': 'meme_lab',
    'category': 'meme',
    'message': 'เมื่ออาจารย์บอก “ควิซสั้น ๆ” แต่สไลด์ 120 หน้า 😂',
    'picture': 'https://picsum.photos/seed/meme-quiz/900/900',
    'like_count': 56,
    'comment': 11,
    'author_roles': ['student'],
    'visibility_roles': ['public'],
    'time_stamp': '2025-08-31T11:00:00Z',
  },
  {
    '_id': 'p109',
    'user_id': 'u109',
    'profile_pic': 'assets/mock/avatar9.png',
    'username': 'home_seek',
    'category': 'housing',
    'message': 'หอพักแถวประตูงามวงศ์วาน ห้องว่างเดือนหน้า ติดต่อ DM',
    // หลายรูป (คละสัดส่วน)
    'images': [
      'https://picsum.photos/seed/dorm1/1000/700',
      'https://picsum.photos/seed/dorm2/800/1200',
      'https://picsum.photos/seed/dorm3/1200/800',
    ],
    'like_count': 14,
    'comment': 3,
    'author_roles': ['student'],
    'visibility_roles': ['public'],
    'time_stamp': '2025-08-30T09:15:00Z',
  },
  {
    '_id': 'p110',
    'user_id': 'u110',
    'profile_pic': 'assets/mock/avatar10.png',
    'username': 'career_center',
    'category': 'job',
    'message': 'รับสมัคร TA วิชา Programming Lab ชม.ละ 120 มีใบประกาศนียบัตร',
    // วิดีโอ (ใช้ asset ภายในโปรเจกต์)
    'video': 'assets/mock/ta_recruit.mp4',
    'like_count': 19,
    'comment': 7,
    'author_roles': ['staff'],
    'visibility_roles': ['student_only'],
    'time_stamp': '2025-08-29T08:00:00Z',
  },
];


  late final List<Post> mockPostsUi =
      mockPostDocs.map((j) => Post.fromJson(j)).toList();

  // --- Mock paging cache (keeps order of your mock list) ---
  static const int _pageSize = 20;
  late final List<Post> _allMock = List<Post>.of(mockPostsUi);

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

  // ---------- Mock "Backend" calls ----------
  Future<void> _loadFirstPage() async {
    setState(() => _loading = true);

    try {
      // Fake first page slice
      final start = 0;
      final end = (_allMock.length < _pageSize) ? _allMock.length : _pageSize;
      final firstPage = _allMock.sublist(start, end);
      final next = (end < _allMock.length) ? end.toString() : null;

      setState(() {
        _posts = firstPage;
        _nextCursor = next;
        _loading = false;

        // init counters from first page
        for (final p in _posts) {
          _likeCounts[p.id] = p.likeCount;
          _commentCounts[p.id] = p.comment;
        }
      });
    } catch (e) {
      setState(() {
        _posts = [];
        _nextCursor = null;
        _loading = false;
      });
      _showSnack('Failed to load posts (mock)');
    }
  }

  Future<void> _loadMore() async {
    if (_fetchingMore || _nextCursor == null) return;
    setState(() => _fetchingMore = true);

    try {
      final start = int.tryParse(_nextCursor!) ?? 0;
      if (start >= _allMock.length) {
        setState(() {
          _nextCursor = null;
          _fetchingMore = false;
        });
        return;
      }

      final end = (start + _pageSize <= _allMock.length)
          ? start + _pageSize
          : _allMock.length;

      final pageItems = _allMock.sublist(start, end);
      final next = (end < _allMock.length) ? end.toString() : null;

      setState(() {
        _posts.addAll(pageItems);
        _nextCursor = next;
        _fetchingMore = false;

        for (final p in pageItems) {
          _likeCounts[p.id] = p.likeCount;
          _commentCounts[p.id] = p.comment;
        }
      });
    } catch (e) {
      setState(() => _fetchingMore = false);
      _showSnack('Failed to load more (mock)');
    }
  }

  Future<void> _onRefresh() => _loadFirstPage();

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  // ---------- Like/Comment actions (mock/optimistic) ----------
  void _toggleLike(Post p) async {
    final wasLiked = _likedIds.contains(p.id);
    final current = _likeCounts[p.id] ?? p.likeCount;

    setState(() {
      if (wasLiked) {
        _likedIds.remove(p.id);
        _likeCounts[p.id] = math.max(0, current - 1);
      } else {
        _likedIds.add(p.id);
        _likeCounts[p.id] = current + 1;
      }
    });

    // TODO: API later (like/unlike) with rollback
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

  Widget _buildEmptyBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No posts (mock). Pull to refresh.')),
          SizedBox(height: 100),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilterPill(
                  label: 'filter',
                  leading: Icons.filter_list,
                  selected: false,
                  onTap: () async {
                    final result =
                        await showModalBottomSheet<FilterSheetResult>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => FilterBottomSheet(
                        loadFilters: mockLoadFilters, // keep structure; no-op
                        initial: const FilterSheetResult(
                          facultyIds: {}, clubIds: {}, categoryIds: {},
                        ),
                      ),
                    );

                    if (result != null) {
                      // Keep state structure; apply to API later
                      // setState(() { ... });
                      // _loadFirstPage();
                    }
                  },
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
