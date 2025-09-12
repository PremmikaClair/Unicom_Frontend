// lib/pages/explore_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../components/header_section_1.dart';
import '../components/search_bar.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  // ---- API base ----
  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend-xe4h.onrender.com',
  );
  late final _api = _TrendsApi(baseUrl: _defaultBaseUrl);

  // ---- State ----
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _fetchingMore = false;
  String? _error;

  String _location = 'ประเทศไทย';
  final String _category = 'trending'; // ไม่มีแถบเลือกแล้ว ใช้ค่าคงที่
  String? _nextCursor;

  List<TrendItem> _items = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {})); // filter realtime
    _loadFirstPage();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
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
      final res = await _api.fetchTrends(
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
      final res = await _api.fetchTrends(
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

  List<TrendItem> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((e) {
      final t = (e.title + (e.tag ?? '') + (e.context ?? '')).toLowerCase();
      return t.contains(q);
    }).toList();
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Center(
            child: AvatarButton(
              radius: 18,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('เปิดโปรไฟล์')),
                );
              },
            ),
          ),
        ),
        titleSpacing: 0,
        title: SearchBarField(
          controller: _searchCtrl,
          hintText: 'Search',
          onSubmitted: (_) => setState(() {}),
        ),
        actions: [
          SettingsButton(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('เปิด Settings')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
  if (_loading) {
    // โชว์สเกเลตันระหว่างโหลด
    return ListView.builder(
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

  final list = _filtered;

  // +2 = 1 แถวหัวข้อ + 1 แถวท้าย (loading/สิ้นสุด)
  return ListView.separated(
    controller: _scrollCtrl,
    physics: const AlwaysScrollableScrollPhysics(),
    itemCount: list.length + 2,
    separatorBuilder: (_, index) =>
        index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
    itemBuilder: (context, index) {
      // แถวแรก: หัวข้อ Trending ใต้ Search
      if (index == 0) {
        return _trendingHeader();
      }

      // แถวท้าย: แสดงกำลังโหลดต่อ หรือจบรายการ
      if (index == list.length + 1) {
        if (_nextCursor != null || _fetchingMore) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return const SizedBox(height: 24);
      }

      // รายการเทรนด์จริง เริ่มหลังหัวข้อ
      final item = list[index - 1];
      return _trendTile(item);
    },
  );
}


  Widget _trendTile(TrendItem t) {
  return ListTile(
    onTap: () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปิด ${t.title}')),
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
    // ไม่มี trailing / ไม่มีเมนูสามจุดแล้ว
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
  final color = Colors.black; // เปลี่ยนเป็นสีแบรนด์ได้
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Trending',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: .3,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.trending_up_rounded, size: 18, color: color),
        ],
      ),
    ),
  );
}

}

// ===== Model & API =====

class TrendItem {
  final String title;     // เช่น "#ELLE80thxNuNew"
  final String? tag;      // ถ้าเป็นแฮชแท็ก
  final String? context;  // เช่น "Only on X · Trending"
  final int? postCount;   // เช่น 83_000
  final int rank;         // 1..N

  TrendItem({
    required this.title,
    required this.rank,
    this.tag,
    this.context,
    this.postCount,
  });

  factory TrendItem.fromJson(Map<String, dynamic> j) => TrendItem(
        title: j['title'] as String,
        tag: j['tag'] as String?,
        context: j['context'] as String?,
        postCount: j['postCount'] as int?,
        rank: (j['rank'] ?? 0) as int,
      );
}

class TrendsResponse {
  final List<TrendItem> items;
  final String? nextCursor;
  TrendsResponse({required this.items, this.nextCursor});
}

class _TrendsApi {
  final String baseUrl;
  _TrendsApi({required this.baseUrl});

  Future<TrendsResponse> fetchTrends({
    required String location,
    required String category, // ค่าคงที่ 'trending'
    String? cursor,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/trends').replace(queryParameters: {
      'location': location,
      'category': category,
      'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
    });

    try {
      final resp = await http.get(uri, headers: {'Accept': 'application/json'});
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List)
            .map((e) => TrendItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final next = data['nextCursor'] as String?;
        return TrendsResponse(items: items, nextCursor: next);
      }
      return _mock(location: location, category: category, cursor: cursor, limit: limit);
    } catch (_) {
      return _mock(location: location, category: category, cursor: cursor, limit: limit);
    }
  }

  // ---- Mock ที่มี "หน้า" (pagination) ----
  TrendsResponse _mock({
    required String location,
    required String category,
    String? cursor,
    int limit = 20,
  }) {
    // 30 รายการ (ชื่อแนว ๆ เทรนด์จริง)
    final seeds = <Map<String, dynamic>>[
      {'title':'#ELLE80thxNuNew','postCount':83000,'context':'Trending'},
      {'title':'CHAWARIN AT ELLE PARTY','postCount':76900,'context':'Trending'},
      {'title':'#TEASER_BAMBAMXTIMETHAI','postCount':152000,'context':'Trending'},
      {'title':'#Givenchy','postCount':15400,'context':'Trending'},
      {'title':'#BUSSINGJAPANEP6','postCount':440000,'context':'Trending'},
      {'title':'#MillexPerthSanta','postCount':753000,'context':'Trending'},
      {'title':'#Tpop', 'postCount':92000,'context':'Trending'},
      {'title':'#Blackpink', 'postCount':215000,'context':'Trending'},
      {'title':'#KinnPorsche', 'postCount':128000,'context':'Trending'},
      {'title':'#Ninew', 'postCount':56000,'context':'Trending'},
      {'title':'#GMMTV2025', 'postCount':301000,'context':'Trending'},
      {'title':'#LISA', 'postCount':580000,'context':'Trending'},
      {'title':'#Bangkok', 'postCount':64000,'context':'Trending'},
      {'title':'#MetGala', 'postCount':442000,'context':'Trending'},
      {'title':'#SEA Games', 'postCount':101000,'context':'Trending'},
      {'title':'#PremierLeague', 'postCount':390000,'context':'Trending'},
      {'title':'#ThailandElection', 'postCount':88000,'context':'Trending'},
      {'title':'#AI', 'postCount':225000,'context':'Trending'},
      {'title':'#Flutter', 'postCount':36000,'context':'Trending'},
      {'title':'#DartLang', 'postCount':21000,'context':'Trending'},
      {'title':'#UIUX', 'postCount':15100,'context':'Trending'}
    ];

    // ใส่อันดับ + context locale
    final list = List<TrendItem>.generate(seeds.length, (i) {
      final m = seeds[i];
      final ctx = (m['context'] as String?) ?? 'Trending in $location';
      return TrendItem(
        title: m['title'] as String,
        rank: i + 1,
        postCount: m['postCount'] as int?,
        context: ctx.replaceAll('Trending in Thailand', 'Trending in $location'),
      );
    });

    // mock pagination: ใช้ cursor เป็น index เริ่ม
    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = (start + limit).clamp(0, list.length);
    final pageItems = list.sublist(start, end);
    final next = end < list.length ? '$end' : null;

    return TrendsResponse(items: pageItems, nextCursor: next);
  }
}
