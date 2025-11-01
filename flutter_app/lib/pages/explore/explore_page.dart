// lib/pages/explore/explore_page.dart
import 'package:flutter/material.dart';

import 'hashtag_feed_page.dart';
import 'searching_page.dart';
import '../profile/profile_page.dart';
import '../../services/database_service.dart';
import '../../models/trend.dart' as tr;
import '../../shared/page_transitions.dart';
import '../../components/app_colors.dart';

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
      setState(() {
        _items = res.items;
        _nextCursor = res.nextCursor;
        _loading = false;
      });
    } catch (e) {
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
      setState(() {
        _items.addAll(res.items);
        _nextCursor = res.nextCursor;
        _fetchingMore = false;
      });
    } catch (_) {
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
    const headerG = Color(0xFF7E9766);
    const greyBG = Color(0xFFEDEDED);

    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final subtitleSize = screenWidth < 360 ? 17.0 : 20.0;
    final illoHeight = screenWidth < 360 ? 128.0 : 140.0;

    const ctlHeight = 42.0;
    const ctlRadius = 24.0;

    return Scaffold(
      backgroundColor: headerG,
      body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Green header
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [headerG, headerG],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: illoHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10, right: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TREND',
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: textTheme.displaySmall?.copyWith(
                                  fontSize: 52,
                                  color: Color(0xFFF1F4EA),
                                  fontWeight: FontWeight.w900,
                                  height: 0.90,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'at Kasetsart',
                                maxLines: 1,
                                softWrap: true,
                                overflow: TextOverflow.visible,
                                style: textTheme.titleLarge?.copyWith(
                                  fontSize: subtitleSize,
                                  color: const Color(0xFF283128).withOpacity(.78),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right:5),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Transform.translate(
                            offset: const Offset(0, 0),
                            child: _crowdIllustration(illoHeight),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Grey rounded top + search
          SliverToBoxAdapter(
            child: Material(
              color: greyBG,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(ctlRadius),
                            onTap: () {
                              Navigator.of(context).push(
                                fadeSlideRoute(const SearchingPage(autoFocus: true)),
                              );
                            },
                            child: Container(
                              height: ctlHeight,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(ctlRadius),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.search, size: 20, color: Colors.black45),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Search posts, events, tags…',
                                      style: TextStyle(color: Colors.black45, fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _dateChip(),
                ],
              ),
            ),
          ),
        ],
        body: Container(
          color: greyBG,
          child: RefreshIndicator(
            onRefresh: _loadFirstPage,
            child: _buildBody(),
          ),
        ),
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
      padding: EdgeInsets.zero,
      itemCount: list.length + 1, // footer
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        // Footer
        if (index == list.length) {
          if (_nextCursor != null || _fetchingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox(height: 24);
        }

        final item = list[index];
        return _trendTile(item);
      },
    );
  }

  Widget _trendTile(tr.TrendItem t) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 0,
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

  Widget _dateChip() {
    final label = _formattedDate();
    final base = Theme.of(context).textTheme.titleLarge;
    final style = (base ?? const TextStyle()).copyWith(
      fontSize: 16,
      color: const Color(0xFFF1F4EA),
      fontWeight: FontWeight.w600,
      letterSpacing: .4,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 0, top: 14, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.sage,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
          ),
          child: Text(label, style: style),
        ),
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    final m = months[now.month - 1];
    final day = now.day;
    return '$day $m ${now.year}';
  }

  Widget _crowdIllustration(double size) {
    return SizedBox(
      height: size,
      width: size,
      child: Image.asset(
        'assets/images/crowedpeople.png',
        fit: BoxFit.contain,
        alignment: const Alignment(0.5, 0.8),
      ),
    );
  }
}
