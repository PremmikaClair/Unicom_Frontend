// lib/pages/explore_page.dart
import 'package:flutter/material.dart';

import '../../components/header_section_explore.dart';
import 'hashtag_feed_page.dart';
import '../profile/profile_page.dart';
import '../../services/database_service.dart';
import '../../models/trend.dart' as tr;
import 'search_feed_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  // ---- Centralized service ----
  late final DatabaseService _db = DatabaseService();

  // ---- State ----
  final _scrollCtrl = ScrollController();
  bool _loading = true;
  bool _fetchingMore = false;
  String? _error;

  String _location = 'ประเทศไทย';
  final String _category = 'all';
  String? _nextCursor;

  List<tr.TrendItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ---- Data ----
  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _nextCursor = null;
    });
    try {
      final res = await _db.getTrends(
        location: _location,
        category: _category,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _nextCursor = res.nextCursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchMore() async {
    if (_fetchingMore || _nextCursor == null) return;
    setState(() => _fetchingMore = true);
    try {
      final res = await _db.getTrends(
        location: _location,
        category: _category,
        cursor: _nextCursor,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _nextCursor = res.nextCursor;
        _fetchingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _fetchingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 320) {
      _fetchMore();
    }
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    final header = HeaderSectionExplore(
      onAvatarTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
      },
      searchEditable: false,
      onSearchTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SearchFeedPage(
              key: UniqueKey(),      // <- บังคับ instance ใหม่
              initialQuery: '',      // พรีฟิลได้ตามต้องการ
            ),
            fullscreenDialog: true,   // (ทางเลือก) ให้ฟีล modal
          ),
        );
      },

    );

    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFirstPage,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 12,
        itemBuilder: (_, __) => _skeletonTile(),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.warning_amber_rounded,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          const Center(child: Text('โหลดเทรนด์ไม่สำเร็จ')),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(
              onPressed: _loadFirstPage,
              child: const Text('ลองใหม่'),
            ),
          ),
        ],
      );
    }

    final list = _items;

    return ListView.separated(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length + 2,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) return _trendingHeader();

        if (index == list.length + 1) {
          if (_nextCursor != null || _fetchingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox(height: 24);
        }

        final item = list[index - 1];
        return _trendTile(item);
      },
    );
  }

  Widget _trendTile(tr.TrendItem t) {
    return ListTile(
      onTap: () {
        final tag = (t.tag ?? t.title).replaceFirst('#', '');
        Navigator.of(context).pushNamed(
          HashtagFeedPage.routeName,
          arguments: tag,
        );
      },
      title: Text(
        t.title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          [
            t.context ?? 'Trending in $_location',
            if (t.postCount != null) '${_fmtPosts(t.postCount!)} posts',
          ].join(' · '),
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _skeletonTile() {
    return ListTile(
      title: Container(
        height: 16,
        margin: const EdgeInsets.only(right: 80),
        decoration: BoxDecoration(
          color: Colors.black12, borderRadius: BorderRadius.circular(6),
        ),
      ),
      subtitle: Container(
        height: 12,
        margin: const EdgeInsets.only(top: 8, right: 140),
        decoration: BoxDecoration(
          color: Colors.black12, borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  String _fmtPosts(int v) {
    if (v >= 1000000) {
      final d = v / 1000000;
      return '${d.toStringAsFixed(d >= 10 ? 0 : 1)}M';
    }
    if (v >= 1000) {
      final d = v / 1000;
      return '${d.toStringAsFixed(d >= 10 ? 0 : 1)}K';
    }
    return '$v';
  }

  Widget _trendingHeader() {
    final color = Colors.black;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Trending',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: .3,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.trending_up_rounded, size: 25, color: color),
          ],
        ),
      ),
    );
  }
}
