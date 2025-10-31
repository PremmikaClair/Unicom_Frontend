// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../app_shell.dart';
import '../login/auth_gate.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';

import '../../models/user.dart';
import '../../models/post.dart' as models;
import '../../components/post_card.dart';

import 'package:flutter_app/pages/profile/allergies.dart';
import 'package:flutter_app/pages/profile/role_page.dart';
import 'package:flutter_app/pages/post_detail.dart';

/// --- Small POJO for robust author matching ---
class _AuthorTriplet {
  final String? id;
  final String? email;
  final String? username;
  const _AuthorTriplet({this.id, this.email, this.username});
}

class ProfilePage extends StatefulWidget {
  final String? userId;
  final String? initialUsername;
  final String? initialName;
  final String? initialAvatarUrl;
  final String? initialBio;

  const ProfilePage({
    super.key,
    this.userId,
    this.initialUsername,
    this.initialName,
    this.initialAvatarUrl,
    this.initialBio,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // theme
  static const _green900 = Color(0xFF6F8C5D);
  static const _green700 = Color(0xFF7FA06B);
  static const _green400 = Color(0xFFAEC9A0);
  static const _green100 = Color(0xFFE8F0E4);
  static const _green050 = Color(0xFFF3F7F0);

  final _db = DatabaseService();

  bool _loading = true;
  String? _error;

  UserProfile? _user;

  bool _loadingPosts = true;
  String? _postsError;
  final List<models.Post> _posts = [];

  String? _usernameAlias;
  String? _phoneNumber;
  String? _avatarUrl;

  static const _kAliasKey = 'profile_username_alias';
  static const _kPhoneKey = 'profile_phone_number';
  static const _kAvatarUrlKey = 'profile_avatar_url';

  static const List<String> _sampleAvatars = [
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1502685104226-ee32379fefbe?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1545996124-0501ebae84d5?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1541534401786-2077eed87a74?q=80&w=800&auto=format&fit=crop',
  ];

  final Set<String> _liked = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _commentCounts = {};
  String? _resolvedUid; // resolved user id when viewing others
  String? _postsNextCursor; // next cursor from getFeed for paging
  String? _feedCursor;      // internal cursor when scanning feed for user's posts
  bool _postsFetchingMore = false;

  // ===== Pagination / performance knobs =====
  static const int _pageLimit = 50;       // ต่อหน้า
  static const int _maxPages = 6;         // ดึงไม่เกิน 6 หน้า (≈ 300 โพสต์)
  static const int _hardCapItems = 300;   // เก็บรวมไม่เกินนี้เพื่อความเร็ว

  // ---------- HTTP helpers ----------
  Uri _withQuery(Uri base, Map<String, String?> add) {
    final q = Map<String, String>.from(base.queryParameters);
    add.forEach((k, v) {
      if (v == null) return;
      q[k] = v;
    });
    return base.replace(queryParameters: q);
  }

  dynamic _jsonDecodeSafe(String body) {
    try { return jsonDecode(body); } catch (_) { return null; }
  }

  Map<String, dynamic> _asMap(dynamic m) {
    if (m is Map<String, dynamic>) return m;
    if (m is Map) return Map<String, dynamic>.from(m);
    return <String, dynamic>{};
  }

  // คืน list<map> จากโครงสร้าง JSON หลากหลายแบบ
  List<Map<String, dynamic>> _extractListFromAny(dynamic v) {
    if (v == null) return const [];
    if (v is List) {
      return v.whereType<Map>()
              .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
              .toList();
    }
    if (v is Map) {
      final mm = Map<String, dynamic>.from(v);
      final keys = ['items','Items','data','posts','list','result','results','records'];
      for (final k in keys) {
        final arr = mm[k];
        if (arr is List) {
          return arr.whereType<Map>()
                    .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
                    .toList();
        }
      }
      final data = mm['data'];
      if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        for (final k in keys) {
          final arr = dm[k];
          if (arr is List) {
            return arr.whereType<Map>()
                      .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
                      .toList();
          }
        }
      }
    }
    return const [];
  }

  // หา next cursor/hasMore/page จาก response (รองรับ Map<dynamic, dynamic>)
  String? _findNextCursor(Map m) {
    final next = (m['next'] ?? m['nextCursor'] ?? m['cursorNext'] ?? m['cursor'] ?? m['pageToken'] ?? m['nextPage'])?.toString();
    if (next != null && next.isNotEmpty) return next;
    final links = m['links'];
    if (links is Map) {
      final n = links['next']?.toString();
      if (n != null && n.isNotEmpty) return n;
    }
    return null;
  }

  bool _hasMoreFlag(Map m, int page, int? totalPages, List listChunk) {
    final hm = m['hasMore'] ?? m['has_next'] ?? m['has_more'];
    if (hm is bool) return hm;
    if (totalPages != null && totalPages > 0) return page < totalPages;
    if (listChunk.length < _pageLimit) return false;
    return true;
  }

  /// ดึงข้อมูลหลายหน้า: รองรับ cursor / page / offset — เพิ่ม firstPageOnly เพื่อหยุดไว
  Future<List<Map<String, dynamic>>> _getPagedRaw(
    Uri base, { bool firstPageOnly = false }
  ) async {
    final headers = AuthService.I.headers(extra: const {'Accept': 'application/json'});
    final all = <Map<String, dynamic>>[];
    final seen = <String>{};

    Future<(bool ok, Map<String, dynamic>? body)> _ingestResponse(http.Response r) async {
      if (r.statusCode != 200) return (false, null);
      final dynamic decoded = _jsonDecodeSafe(r.body);

      List<Map<String, dynamic>> chunk;
      Map<String, dynamic>? body;
      if (decoded is List) {
        chunk = decoded
            .whereType<Map>()
            .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
            .toList();
        body = null; // array root → no cursor info
      } else if (decoded is Map) {
        body = Map<String, dynamic>.from(decoded);
        chunk = _extractListFromAny(body);
      } else {
        return (false, null);
      }

      for (final m in chunk) {
        final id = (m['_id'] ?? m['id'] ?? m['oid'])?.toString() ?? jsonEncode(m);
        if (seen.add(id)) all.add(m);
        if (all.length >= _hardCapItems) return (false, body);
      }
      return (chunk.isNotEmpty, body);
    }

    // ---------- A) cursor-first ----------
    {
      String? cursor;
      for (int i = 0; i < _maxPages; i++) {
        final variants = <Uri>[
          if (cursor == null) base else _withQuery(base, {'cursor': cursor}),
          if (cursor != null) _withQuery(base, {'pageToken': cursor}),
          if (cursor != null) _withQuery(base, {'next': cursor}),
          if (cursor != null) _withQuery(base, {'nextCursor': cursor}),
          if (cursor != null) _withQuery(base, {'nextPage': cursor}),
        ];

        bool progressed = false;
        for (final u in variants) {
          try {
            final r = await http.get(u, headers: headers)
                                .timeout(Duration(seconds: firstPageOnly ? 5 : 8));
            final (ok, body) = await _ingestResponse(r);
            if (!ok) continue;

            int? totalPages;
            if (body != null) {
              final rawTotal = (body['totalPages'] ?? body['total_pages'] ?? body['pageCount']);
              totalPages = (rawTotal is int) ? rawTotal : int.tryParse(rawTotal?.toString() ?? '');
            }

            final next = (body != null) ? _findNextCursor(body) : null;
            progressed = true;
            cursor = next;

            if (firstPageOnly) return all; // ต้องการหน้าเดียวจริงๆ
            if (all.length >= _hardCapItems) return all;

            if (body != null) {
              if (next == null && !_hasMoreFlag(body, i + 1, totalPages, _extractListFromAny(body))) {
                return all;
              }
            } else if (next == null) {
              return all;
            }
            break;
          } catch (_) {}
        }
        if (!progressed) break;
      }
    }

    if (all.isNotEmpty || firstPageOnly) return all;

    // ---------- B) page/limit ----------
    for (final pageKey in ['page', 'pageNumber']) {
      for (final limitKey in ['limit', 'per_page', 'pageSize', 'size']) {
        for (final start in [1, 0]) {
          for (int page = start; page - start < _maxPages; page++) {
            final u = _withQuery(base, { pageKey: '$page', limitKey: '$_pageLimit', 'sort': 'createdAt:desc' });
            try {
              final r = await http.get(u, headers: headers).timeout(const Duration(seconds: 5));
              final (ok, _) = await _ingestResponse(r);
              if (!ok) break;
            } catch (_) { break; }
            if (all.length >= _hardCapItems) return all;
          }
          if (all.isNotEmpty) return all;
        }
      }
    }

    // ---------- C) offset/limit ----------
    for (int i = 0; i < _maxPages; i++) {
      final offset = i * _pageLimit;
      final u = _withQuery(base, {'offset': '$offset', 'limit': '$_pageLimit', 'sort': 'createdAt:desc'});
      try {
        final r = await http.get(u, headers: headers).timeout(const Duration(seconds: 5));
        final (ok, _) = await _ingestResponse(r);
        if (!ok) break;
      } catch (_) { break; }
      if (all.length >= _hardCapItems) return all;
    }

    return all;
  }

  // ---------- Date helpers (sort newest) ----------
  DateTime _parseAnyDate(dynamic v) {
    if (v is String) {
      try { return DateTime.parse(v); } catch (_) {}
      final n = int.tryParse(v);
      if (n != null) return _epochToDate(n);
    }
    if (v is int) return _epochToDate(v);
    if (v is Map && v.containsKey(r'$date')) {
      return _parseAnyDate(v[r'$date']);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _epochToDate(int n) {
    if (n > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(n ~/ 1000); // micros
    if (n > 10000000000)   return DateTime.fromMillisecondsSinceEpoch(n);        // millis
    if (n < 10000000000)   return DateTime.fromMillisecondsSinceEpoch(n * 1000); // seconds
    return DateTime.fromMillisecondsSinceEpoch(n);
  }

  DateTime _extractCreatedAt(Map<String, dynamic> m) {
    final keys = [
      'createdAt','created_at','created',
      'timeStamp','timestamp',
      'publishedAt','updatedAt','date',
    ];
    for (final k in keys) {
      if (m.containsKey(k)) {
        final dt = _parseAnyDate(m[k]);
        if (dt.millisecondsSinceEpoch > 0) return dt;
      }
    }
    final meta = m['meta'];
    if (meta is Map) {
      final mm = _asMap(meta);
      for (final k in keys) {
        if (mm.containsKey(k)) {
          final dt = _parseAnyDate(mm[k]);
          if (dt.millisecondsSinceEpoch > 0) return dt;
        }
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> _sortNewestFirst(List<Map<String, dynamic>> raw) {
    final copy = [...raw];
    copy.sort((a, b) => _extractCreatedAt(b).compareTo(_extractCreatedAt(a)));
    return copy;
  }

  // ---------- Endpoint trust detectors ----------
  bool _isTrustedMine(Uri u) {
    final p = u.path.toLowerCase();
    final q = u.queryParameters.map((k, v) => MapEntry(k.toLowerCase(), (v ?? '').toLowerCase()));
    return p.contains('/me/') || p.endsWith('/me') || p.contains('/mine') || q['mine'] == 'true' || q['who'] == 'me';
  }

  bool _isTrustedUser(Uri u, String uid) {
    final low = uid.toLowerCase();
    final p = u.path.toLowerCase();
    final qp = u.queryParameters.map((k, v) => MapEntry(k.toLowerCase(), (v ?? '').toLowerCase()));
    if (p.contains('/$low')) return true;
    for (final k in ['user','user_id','userid','author','author_id','authorid','who']) {
      if (qp[k] == low) return true;
    }
    return false;
  }

  // ---------- Id extraction / author match ----------
  // ตัวแปลง ObjectId แบบเร็ว ไม่ใช้ RegExp
  String _stripObjectIdText(String s) {
    // fast path: 24-hex ล้วน
    if (s.length == 24) {
      final u = s.codeUnits;
      for (var k = 0; k < 24; k++) {
        final c = u[k];
        final isHex =
            (c >= 48 && c <= 57)  || // 0-9
            (c >= 65 && c <= 70)  || // A-F
            (c >= 97 && c <= 102);   // a-f
        if (!isHex) {
          break;
        }
        if (k == 23) return s;
      }
    }

    // slow path: หา ObjectId("...") หรือ ObjectId('...')
    final idx = s.indexOf('ObjectId(');
    if (idx == -1) return s;

    final units = s.codeUnits;
    final start = idx + 9; // 'ObjectId('.length
    var i = start;

    // ข้าม quote เปิดถ้ามี
    if (i < units.length && (units[i] == 34 /*"*/ || units[i] == 39 /*'*/)) i++;

    // เก็บช่วง [i, j) ที่เป็น hex 24 ตัว
    var j = i;
    var count = 0;
    while (j < units.length && count < 24) {
      final c = units[j];
      final isHex =
          (c >= 48 && c <= 57)  || // 0-9
          (c >= 65 && c <= 70)  || // A-F
          (c >= 97 && c <= 102);   // a-f
      if (!isHex) break;
      j++;
      count++;
    }

    return (count == 24) ? s.substring(i, j) : s;
  }

  String? _stringId(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) return _stripObjectIdText(v);
    if (v is num) return v.toString();
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      if (m.containsKey(r'$oid')) return m[r'$oid']?.toString();
      if (m.containsKey('_id'))  return _stringId(m['_id']);
      if (m.containsKey('id'))   return m['id']?.toString();
      if (m.containsKey('oid'))  return m['oid']?.toString();
    }
    return null;
  }

  _AuthorTriplet _authorTripletFromMap(Map<String, dynamic> m) {
    final authorRaw = m['author'] ?? m['user'] ?? m['owner'] ?? m['createdBy'] ?? m['postedBy'] ?? m['created_by'] ?? m['ownerBy'];
    String? idNest, emailNest, userNest;

    if (authorRaw is Map) {
      final a = Map<String, dynamic>.from(authorRaw);
      idNest = _stringId(a);
      emailNest = (a['email'] ?? a['mail'])?.toString();
      userNest  = (a['username'] ?? a['userName'] ?? a['name'] ?? a['handle'])?.toString();
    } else if (authorRaw is String) {
      idNest = _stripObjectIdText(authorRaw);
      userNest = authorRaw;
    }

    final idFlat = _stringId(
      m['authorId'] ?? m['author_id'] ?? m['userId'] ?? m['user_id'] ?? m['uid'] ??
      m['ownerId']  ?? m['owner_id']  ?? m['createdById'] ?? m['created_by_id'] ?? m['postedById']
    );

    final emailFlat = (m['authorEmail'] ?? m['email'] ?? m['user_email'] ?? m['owner_email'])?.toString();
    final userFlat  = (m['authorUsername'] ?? m['username'] ?? m['user_name'] ?? m['created_by_username'])?.toString();

    final id = idFlat ?? idNest;
    final email = emailFlat ?? emailNest;
    final username = userFlat ?? userNest;

    return _AuthorTriplet(id: id, email: email, username: username);
  }

  // -------- ID-only author extraction and filters --------
  String? _authorIdFromMap(Map<String, dynamic> m) {
    final authorRaw = m['author'] ?? m['user'] ?? m['owner'] ?? m['createdBy'] ?? m['postedBy'] ?? m['created_by'] ?? m['ownerBy'];
    if (authorRaw is Map) {
      final a = Map<String, dynamic>.from(authorRaw);
      final idNest = _stringId(a);
      if (idNest != null && idNest.isNotEmpty) return idNest;
    } else if (authorRaw is String) {
      final idText = _stripObjectIdText(authorRaw);
      if (idText.isNotEmpty) return idText;
    }
    final idFlat = _stringId(
      m['authorId'] ?? m['author_id'] ?? m['userId'] ?? m['user_id'] ?? m['uid'] ??
      m['ownerId']  ?? m['owner_id']  ?? m['createdById'] ?? m['created_by_id'] ?? m['postedById']
    );
    return idFlat;
  }

  List<Map<String, dynamic>> _filterToUserId(List<Map<String, dynamic>> raw, String uid) {
    final target = uid.toLowerCase();
    return raw.where((m) => (_authorIdFromMap(m)?.toLowerCase() == target)).toList();
  }

  // ---------- UI / logic ----------
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    safeSetState(() { _loading = true; _error = null; });

    try {
      if (_isMine) {
        final sp = await SharedPreferences.getInstance();
        _usernameAlias = sp.getString(_kAliasKey) ?? widget.initialUsername;
        _phoneNumber   = sp.getString(_kPhoneKey);
        _avatarUrl     = sp.getString(_kAvatarUrlKey) ?? widget.initialAvatarUrl;
      } else {
        _usernameAlias = widget.initialUsername;
        _avatarUrl     = widget.initialAvatarUrl;
      }

      // Resolve target user ID first if we are viewing others without a known id
      String? targetId = widget.userId?.trim();
      if ((targetId == null || targetId.isEmpty) && !_isMine) {
        String q = (_usernameAlias ?? widget.initialUsername ?? widget.initialName ?? '').toString().trim();
        if (q.startsWith('@')) q = q.substring(1);
        q = q.replaceAll(RegExp(r"\s+"), " ").trim();
        if (q.isNotEmpty) {
          targetId = await _resolveUserIdByQuery(q);
        }
      }
      if (targetId != null && targetId.isNotEmpty) {
        _resolvedUid = targetId;
      }

      UserProfile u;
      if (targetId != null && targetId.trim().isNotEmpty) {
        final map = await _db.getUserByObjectIdFiber(targetId.trim());
        u = UserProfile.fromJson(map);
      } else if (_isMine) {
        final map = await _db.getMeFiber();
        // Save resolved object id (if any) for fetching posts
        final resolved = _stringId(map['_id'] ?? map['id'] ?? map['oid']);
        if (resolved != null && resolved.isNotEmpty) {
          _resolvedUid = resolved;
        }
        u = UserProfile.fromJson(map);
      } else {
        // Viewing others without resolvable ID — build a minimal profile placeholder
        final name = (widget.initialName ?? '').trim();
        String? f;
        String? l;
        if (name.isNotEmpty) {
          final parts = name.split(' ');
          f = parts.isNotEmpty ? parts.first : null;
          l = parts.length > 1 ? parts.sublist(1).join(' ') : null;
        }
        u = UserProfile(
          id: null,
          oid: null,
          firstName: f,
          lastName: l,
          email: null,
          raw: const {},
        );
      }

      safeSetState(() {
        _user = u;
        _loading = false;
      });

      await _loadPostsFor(u);
    } catch (e) {
      safeSetState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Resolve user id using search API by username/email/display name
  Future<String?> _resolveUserIdByQuery(String q) async {
    try {
      final res = await _db.searchUsers(q: q, limit: 20, cursor: null);
      String readId(dynamic v) {
        if (v is Map && v[r'$oid'] != null) return v[r'$oid'].toString();
        return v?.toString() ?? '';
      }
      for (final m in res.items) {
        final id = [
          m['_id'], m['id'], m['user_id'], m['userId'], m['uid'], m['objectId'], m['object_id'], m['profileId'], m['profile_id']
        ].map(readId).firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');
        if (id.trim().isNotEmpty) return id.trim();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadPostsFor(UserProfile u) async {
    safeSetState(() { _loadingPosts = true; _postsError = null; _posts.clear(); });

    try {
      // Show only posts of the profile owner (my posts / target user's posts)
      final uid = _isMine
          ? (_stringId(u.oid) ?? _stringId(u.id) ?? u.id?.toString() ?? _resolvedUid ?? '').trim()
          : (_stringId(u.oid) ?? _stringId(u.id) ?? u.id?.toString() ?? _resolvedUid ?? '').trim();
      if (uid.isEmpty) {
        safeSetState(() { _loadingPosts = false; });
        return;
      }

      // Primary: call user-specific endpoint and filter, auto-fetch a few pages for completeness
      final first = await _db.getPostsByUser(userId: uid, limit: _pageLimit, cursor: null);
      List<models.Post> onlyUser = first.items.where((p) => p.userId.trim() == uid).toList();
      var cur = first.nextCursor;
      var hops = 1;
      while (cur != null && hops < _maxPages) {
        final pg = await _db.getPostsByUser(userId: uid, limit: _pageLimit, cursor: cur);
        final add = pg.items.where((p) => p.userId.trim() == uid).toList();
        if (add.isNotEmpty) onlyUser.addAll(add);
        cur = pg.nextCursor;
        hops++;
      }
      _postsNextCursor = cur;
      _feedCursor = null;

      // Fallback: if still empty, scan feed pages to collect this user's posts
      if (onlyUser.isEmpty) {
        final pair = await _fetchUserPostsFromFeed(uid, cursor: null, desired: _pageLimit);
        onlyUser = pair.items;
        _feedCursor = pair.cursor;
        _postsNextCursor = pair.cursor;
      }

      // Apply profile owner name to posts
      final withName = _mapPostsWithProfileName(onlyUser, owner: u);

      if (!mounted) return;
      safeSetState(() {
        _posts.addAll(withName);
        _loadingPosts = false;
      });
      _primeCountsFromPosts(withName);
    } catch (e) {
      safeSetState(() {
        _postsError = e.toString();
        _loadingPosts = false;
      });
    }
  }

  // Scan /posts/feed pages and collect only posts of a specific user
  Future<({List<models.Post> items, String? cursor})> _fetchUserPostsFromFeed(
    String uid, {
    String? cursor,
    int desired = 20,
    int maxHops = 12,
  }) async {
    final out = <models.Post>[];
    var cur = cursor;
    var hops = 0;
    while (hops < maxHops) {
      hops++;
      final page = await _db.getFeed(limit: _pageLimit, cursor: cur, sort: 'time');
      final filtered = page.items.where((p) => p.userId.trim() == uid).toList();
      out.addAll(filtered);
      if (out.length >= desired || page.nextCursor == null) {
        return (items: out, cursor: page.nextCursor);
      }
      cur = page.nextCursor;
    }
    return (items: out, cursor: cur);
  }

  Future<void> _loadMorePosts() async {
    if (_postsFetchingMore) return;
    final uid = (_stringId(_user?.oid) ?? _stringId(_user?.id) ?? _user?.id?.toString() ?? _resolvedUid ?? '').trim();
    if (uid.isEmpty) return;
    safeSetState(() { _postsFetchingMore = true; });
    try {
      if ((_postsNextCursor ?? '').isNotEmpty) {
        final page = await _db.getPostsByUser(userId: uid, limit: _pageLimit, cursor: _postsNextCursor);
        final onlyUser = page.items.where((p) => p.userId.trim() == uid).toList();
        final withName = _mapPostsWithProfileName(onlyUser, owner: _user);
        if (!mounted) return;
        safeSetState(() {
          _posts.addAll(withName);
          _postsNextCursor = page.nextCursor;
          _postsFetchingMore = false;
        });
        _primeCountsFromPosts(withName);
        return;
      }

      if ((_feedCursor ?? '').isNotEmpty) {
        final pair = await _fetchUserPostsFromFeed(uid, cursor: _feedCursor, desired: _pageLimit);
        final withName = _mapPostsWithProfileName(pair.items, owner: _user);
        if (!mounted) return;
        safeSetState(() {
          _posts.addAll(withName);
          _feedCursor = pair.cursor;
          _postsFetchingMore = false;
        });
        _primeCountsFromPosts(withName);
        return;
      }

      safeSetState(() { _postsFetchingMore = false; });
    } catch (_) {
      if (!mounted) return;
      safeSetState(() { _postsFetchingMore = false; });
    }
  }

  // Map posts so that username displays the owner's name for consistency
  List<models.Post> _mapPostsWithProfileName(List<models.Post> list, {UserProfile? owner}) {
    final o = owner ?? _user;
    if (o == null) return list;
    String display() {
      final f = (o.firstName ?? '').trim();
      final l = (o.lastName ?? '').trim();
      final full = [f, l].where((s) => s.isNotEmpty).join(' ').trim();
      if (full.isNotEmpty) return full;
      final alias = (_usernameAlias ?? '').trim();
      if (alias.isNotEmpty) return alias;
      final email = (o.email ?? '').trim();
      if (email.contains('@')) return email.split('@').first;
      return '';
    }
    final name = display();
    if (name.isEmpty) return list;
    return list.map((p) => models.Post(
      id: p.id,
      userId: p.userId,
      profilePic: p.profilePic,
      username: name,
      category: p.category,
      message: p.message,
      likeCount: p.likeCount,
      comment: p.comment,
      isLiked: p.isLiked,
      authorRoles: p.authorRoles,
      visibilityRoles: p.visibilityRoles,
      timeStamp: p.timeStamp,
      picture: p.picture,
      video: p.video,
      images: p.images,
      videos: p.videos,
    )).toList();
  }

  // Quick fetch: only first page of likely endpoints
  Future<List<models.Post>> _fetchMyPostsQuick() async {
    final base = AuthService.I.apiBase.endsWith('/')
        ? AuthService.I.apiBase.substring(0, AuthService.I.apiBase.length - 1)
        : AuthService.I.apiBase;

    final me = await _db.getMeFiber();
    final String? myId = _stringId(me['_id'] ?? me['id'] ?? me['oid']);
    if (myId == null || myId.isEmpty) return const <models.Post>[];

    final quickUris = <Uri>[
      Uri.parse('$base/posts?user_id=$myId&limit=$_pageLimit&sort=-createdAt'),
      Uri.parse('$base/users/me/posts'),
      Uri.parse('$base/posts/mine'),
    ];
    for (final u in quickUris) {
      try {
        final raw = await _getPagedRaw(u, firstPageOnly: true);
        if (raw.isEmpty) continue;
        final sorted = _sortNewestFirst(raw);
        return sorted.map((e) => models.Post.fromJson(e)).toList();
      } catch (_) {}
    }
    return const <models.Post>[];
  }

  Future<List<models.Post>> _fetchPostsByUserQuick(String userId) async {
    final uid = userId.trim();
    final base = AuthService.I.apiBase.endsWith('/')
        ? AuthService.I.apiBase.substring(0, AuthService.I.apiBase.length - 1)
        : AuthService.I.apiBase;
    final uris = <Uri>[
      if (uid.isNotEmpty) Uri.parse('$base/posts?user_id=$uid&limit=$_pageLimit&sort=-createdAt'),
      if (uid.isNotEmpty) Uri.parse('$base/users/profile/${Uri.encodeComponent(uid)}/posts'),
      if (uid.isNotEmpty) Uri.parse('$base/users/${Uri.encodeComponent(uid)}/posts'),
    ];
    for (final u in uris) {
      try {
        final raw = await _getPagedRaw(u, firstPageOnly: true);
        if (raw.isEmpty) continue;
        final filtered = _filterToUserId(raw, uid);
        if (filtered.isEmpty) continue;
        final sorted = _sortNewestFirst(filtered);
        return sorted.map((e) => models.Post.fromJson(e)).toList();
      } catch (_) {}
    }
    return const <models.Post>[];
  }

  // ====== ดึง "เฉพาะโพสต์ของฉัน" — QUICK + FILTER ======
  Future<List<models.Post>> _fetchMyPostsFast() async {
    final base = AuthService.I.apiBase.endsWith('/')
        ? AuthService.I.apiBase.substring(0, AuthService.I.apiBase.length - 1)
        : AuthService.I.apiBase;

    final me = await _db.getMeFiber();
    final String? myId       = _stringId(me['_id'] ?? me['id'] ?? me['oid']);
    final String? myEmail    = (me['email'] ?? me['Email'])?.toString();
    final String? myUsername = (me['username'] ?? me['userName'] ?? me['name'])?.toString();

    if (myId == null || myId.isEmpty) return const <models.Post>[];

    // QUICK PATH — ยิงเพจเดียวก่อน
    final quickUris = <Uri>[
      Uri.parse('$base/posts?user_id=$myId&limit=$_pageLimit&sort=-createdAt'),
      Uri.parse('$base/posts?author_id=$myId&limit=$_pageLimit&sort=-createdAt'),
      Uri.parse('$base/posts?authorId=$myId&limit=$_pageLimit&sort=-createdAt'),
      Uri.parse('$base/posts?userId=$myId&limit=$_pageLimit&sort=-createdAt'),
      Uri.parse('$base/posts?author=$myId&limit=$_pageLimit&sort=-createdAt'),
      Uri.parse('$base/users/me/posts'),
      Uri.parse('$base/posts/mine'),
      Uri.parse('$base/posts?mine=true'),
      Uri.parse('$base/posts?who=me'),
    ];

    for (final u in quickUris) {
      try {
        // Fetch all available pages for this endpoint to avoid truncation
        final raw = await _getPagedRaw(u);
        if (raw.isEmpty) continue;
        final filtered = _filterToUserId(raw, myId);
        if (filtered.isNotEmpty) {
          final sorted = _sortNewestFirst(filtered);
          final fromApis = sorted.map((e) => models.Post.fromJson(e)).toList();
          // Complement with DB scan to ensure completeness
          final fromDb = await _fetchPostsByUserFromDbLoop(myId);
          return _mergeAndSortPosts(fromApis, fromDb);
        }
      } catch (_) {}
    }

    // SLOWER FALLBACK — หลายเพจ/หลายพารามิเตอร์
    final preferMine = <Uri>[
      Uri.parse('$base/users/me/posts'),
      Uri.parse('$base/users/my/posts'),
      Uri.parse('$base/posts/mine'),
      Uri.parse('$base/posts/me'),
      Uri.parse('$base/my/posts'),
      Uri.parse('$base/posts?mine=true'),
      Uri.parse('$base/posts?who=me'),
      Uri.parse('$base/posts?authorId=$myId'),
      Uri.parse('$base/posts?author_id=$myId'),
      Uri.parse('$base/posts?userId=$myId'),
      Uri.parse('$base/posts?user_id=$myId'),
      Uri.parse('$base/posts?author=$myId'),
    ];

    final collected = <Map<String, dynamic>>[];
    final seen = <String>{};

    Future<void> _collect(Uri u) async {
      final candidates = <Uri>[
        u,
        _withQuery(u, {'sort': 'createdAt:desc'}),
        _withQuery(u, {'order': 'desc'}),
        _withQuery(u, {'sortBy': 'createdAt', 'order': 'desc'}),
        _withQuery(u, {'sort': '-createdAt'}),
      ];
      for (final v in candidates) {
        try {
          final raw = await _getPagedRaw(v);
          if (raw.isEmpty) continue;
          final filtered = _filterToUserId(raw, myId);
          if (filtered.isEmpty) continue;

          for (final m in filtered) {
            final id = (m['_id'] ?? m['id'] ?? m['oid'])?.toString() ?? jsonEncode(m);
            if (seen.add(id)) collected.add(m);
            if (collected.length >= _hardCapItems) break;
          }
        } catch (_) {}
        if (collected.length >= _hardCapItems) break;
      }
    }

    for (final u in preferMine) {
      await _collect(u);
      if (collected.length >= _hardCapItems) break;
    }

    // เผื่อไม่เจออะไรเลย: ยิง /posts แล้วกรองเอง
    if (collected.isEmpty) {
      try {
        final v = _withQuery(Uri.parse('$base/posts'), {'sort': 'createdAt:desc'});
        final raw = await _getPagedRaw(v);
        final mine = _filterToUserId(raw, myId);
        for (final m in mine) {
          final id = (m['_id'] ?? m['id'] ?? m['oid'])?.toString() ?? jsonEncode(m);
          if (seen.add(id)) collected.add(m);
          if (collected.length >= _hardCapItems) break;
        }
      } catch (_) {}
    }

    if (collected.isEmpty) {
      // Full DB scan fallback
      return _fetchPostsByUserFromDbLoop(myId);
    }
    final sorted = _sortNewestFirst(collected);
    final fromApis = sorted.map((e) => models.Post.fromJson(e)).toList();
    final fromDb = await _fetchPostsByUserFromDbLoop(myId);
    return _mergeAndSortPosts(fromApis, fromDb);
  }

  // ====== ดึงโพสต์ของ user เป้าหมาย — FAST + FILTER ======
  Future<List<models.Post>> _fetchPostsByUserFast(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) {
      return const <models.Post>[];
    }

    final base = AuthService.I.apiBase.endsWith('/')
        ? AuthService.I.apiBase.substring(0, AuthService.I.apiBase.length - 1)
        : AuthService.I.apiBase;

    // 0) SUPER-FAST PATH — query params we trust; don't over-filter
    Future<List<models.Post>> _tryDirectParams() async {
      final direct = <Uri>[
        Uri.parse('$base/posts?user_id=$uid'),
        Uri.parse('$base/posts?userId=$uid'),
        Uri.parse('$base/posts?author_id=$uid'),
        Uri.parse('$base/posts?authorId=$uid'),
      ];
      final out = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final u in direct) {
        try {
          final raw = await _getPagedRaw(u, firstPageOnly: true);
          for (final m in raw) {
            final id = (m['_id'] ?? m['id'] ?? m['oid'])?.toString() ?? jsonEncode(m);
            if (seen.add(id)) out.add(m);
          }
        } catch (_) {}
      }
      if (out.isEmpty) return const <models.Post>[];
      final filtered = _filterToUserId(out, uid);
      if (filtered.isEmpty) return const <models.Post>[];
      final sorted = _sortNewestFirst(filtered);
      return sorted.map((e) => models.Post.fromJson(e)).toList();
    }

    final directHits = await _tryDirectParams();
    if (directHits.isNotEmpty) return directHits;

    final preferUser = <Uri>[
      Uri.parse('$base/users/profile/${Uri.encodeComponent(uid)}/posts'),
      Uri.parse('$base/users/${Uri.encodeComponent(uid)}/posts'),
      Uri.parse('$base/posts/user/${Uri.encodeComponent(uid)}'),
      Uri.parse('$base/posts?user=$uid'),
      // the query-param variants above were already tried without filtering; keep others here
      Uri.parse('$base/posts?author=$uid'),
      Uri.parse('$base/posts?who=$uid'),
    ];

    final collected = <Map<String, dynamic>>[];
    final seen = <String>{};

    Future<void> _collect(Uri u) async {
      final candidates = <Uri>[
        u,
        _withQuery(u, {'sort': 'createdAt:desc'}),
        _withQuery(u, {'order': 'desc'}),
        _withQuery(u, {'sortBy': 'createdAt', 'order': 'desc'}),
        _withQuery(u, {'sort': '-createdAt'}),
      ];
      for (final v in candidates) {
        try {
          // Fetch across pages/cursors for full history
          final raw = await _getPagedRaw(v);
          if (raw.isEmpty) continue;
          final filtered = _filterToUserId(raw, uid);
          if (filtered.isEmpty) continue;

          for (final m in filtered) {
            final id = (m['_id'] ?? m['id'] ?? m['oid'])?.toString() ?? jsonEncode(m);
            if (seen.add(id)) collected.add(m);
            if (collected.length >= _hardCapItems) break;
          }
        } catch (_) {}
        if (collected.length >= _hardCapItems) break;
      }
    }

    for (final u in preferUser) {
      await _collect(u);
      if (collected.length >= _hardCapItems) break;
    }

    // Fallback: /posts + กรองเอง
    if (collected.isEmpty) {
      try {
        final v = _withQuery(Uri.parse('$base/posts'), {'sort': 'createdAt:desc'});
        final raw = await _getPagedRaw(v);
        final filtered = _filterToUserId(raw, uid);
        for (final m in filtered) {
          final id = (m['_id'] ?? m['id'] ?? m['oid'])?.toString() ?? jsonEncode(m);
          if (seen.add(id)) collected.add(m);
          if (collected.length >= _hardCapItems) break;
        }
      } catch (_) {}
    }

    if (collected.isEmpty) {
      // Full DB scan fallback
      return _fetchPostsByUserFromDbLoop(uid);
    }
    final sorted = _sortNewestFirst(collected);
    final fromApis = sorted.map((e) => models.Post.fromJson(e)).toList();
    final fromDb = await _fetchPostsByUserFromDbLoop(uid);
    return _mergeAndSortPosts(fromApis, fromDb);
  }

  // -------- Fallback: scan /posts via DatabaseService and filter by user id --------
  Future<List<models.Post>> _fetchPostsByUserFromDbLoop(String uid) async {
    final out = <models.Post>[];
    final seen = <String>{};
    String? cursor;
    int hops = 0;
    const int maxHops = 12; // speed: scan fewer pages on fallback
    while (true) {
      hops++;
      final page = await _db.getPosts(limit: _pageLimit, cursor: cursor);
      final matched = page.items.where((p) => p.userId.trim() == uid).toList();
      for (final p in matched) {
        if (seen.add(p.id)) out.add(p);
        if (out.length >= _hardCapItems) break;
      }
      if (out.length >= _hardCapItems) break;
      cursor = page.nextCursor;
      if (cursor == null || hops >= maxHops) break;
    }
    out.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
    return out;
  }

  List<models.Post> _mergeAndSortPosts(List<models.Post> a, List<models.Post> b) {
    final seen = <String>{};
    final out = <models.Post>[];
    for (final p in [...a, ...b]) {
      if (seen.add(p.id)) out.add(p);
      if (out.length >= _hardCapItems) break;
    }
    out.sort((x, y) => y.timeStamp.compareTo(x.timeStamp));
    return out;
  }

  // ---------- helpers ----------
  void safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  String _pid(models.Post p) {
    try { final v = (p as dynamic).id; if (v != null) return '$v'; } catch (_) {}
    try { final v = (p as dynamic).oid; if (v != null) return '$v'; } catch (_) {}
    try { final v = (p as dynamic).postId; if (v != null) return '$v'; } catch (_) {}
    try {
      final v = (p as dynamic)._id;
      if (v is Map && v[r'$oid'] != null) return v[r'$oid'].toString();
    } catch (_) {}
    return '';
  }

  int _initialLikeCount(models.Post p) {
    try { final v = (p as dynamic).likeCount; if (v is int) return v; } catch (_) {}
    try { final v = (p as dynamic).likes; if (v is int) return v; } catch (_) {}
    try { final v = (p as dynamic).like_count; if (v is int) return v; } catch (_) {}
    return 0;
  }

  int _initialCommentCount(models.Post p) {
    try { final v = (p as dynamic).commentCount; if (v is int) return v; } catch (_) {}
    try { final v = (p as dynamic).comments; if (v is int) return v; } catch (_) {}
    try { final v = (p as dynamic).comment_count; if (v is int) return v; } catch (_) {}
    return 0;
  }

  bool _initialLikedFlag(models.Post p) {
    try { final v = (p as dynamic).liked; if (v is bool) return v; } catch (_) {}
    try { final v = (p as dynamic).isLiked; if (v is bool) return v; } catch (_) {}
    try { final v = (p as dynamic).likedByMe; if (v is bool) return v; } catch (_) {}
    try { final v = (p as dynamic).hasLiked; if (v is bool) return v; } catch (_) {}
    return false;
  }

  void _primeCountsFromPosts(List<models.Post> list) {
    for (final p in list) {
      final id = _pid(p);
      if (id.isEmpty) continue;
      _likeCounts[id] ??= _initialLikeCount(p);
      _commentCounts[id] ??= _initialCommentCount(p);
      if (_initialLikedFlag(p)) _liked.add(id);
    }
  }

  Future<void> _toggleLikePost(String postId) async {
    if (postId.isEmpty) return;
    final wasLiked = _liked.contains(postId);

    safeSetState(() {
      if (wasLiked) {
        _liked.remove(postId);
        _likeCounts[postId] = (_likeCounts[postId] ?? 0) - 1;
        if ((_likeCounts[postId] ?? 0) < 0) _likeCounts[postId] = 0;
      } else {
        _liked.add(postId);
        _likeCounts[postId] = (_likeCounts[postId] ?? 0) + 1;
      }
    });

    try {
      final res = await _db.toggleLike(targetId: postId, targetType: 'post');
      safeSetState(() {
        if (res.liked) {
          _liked.add(postId);
        } else {
          _liked.remove(postId);
        }
        _likeCounts[postId] = res.likeCount;
      });
    } catch (e) {
      safeSetState(() {
        if (wasLiked) {
          _liked.add(postId);
          _likeCounts[postId] = (_likeCounts[postId] ?? 0) + 1;
        } else {
          _liked.remove(postId);
          _likeCounts[postId] = (_likeCounts[postId] ?? 1) - 1;
          if ((_likeCounts[postId] ?? 0) < 0) _likeCounts[postId] = 0;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Like failed: $e')),
      );
    }
  }

  Future<void> _openPostDetail(models.Post p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostPage(post: p)),
    );
  }

  Future<void> _openAllergies() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AllergiesPage()),
    );
  }

  Future<void> _openRoles() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RolePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _green050,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _green700,
        surfaceTintColor: _green700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
        actions: [
          if (_isMine)
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(_error!, onRetry: _load)
              : _buildScrollContent(context),
    );
  }

  void _handleBack() {
    FocusScope.of(context).unfocus();

    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }

    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.pop();
      return;
    }
  }

  Widget _buildScrollContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        if (_user != null) {
          await _loadPostsFor(_user!);
        } else {
          await _load();
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildProfileHeaderCard(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined, size: 18, color: Colors.black87),
                  const SizedBox(width: 6),
                  Text(
                    _isMine ? 'Your posts' : 'User posts',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (_loadingPosts)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_postsError != null)
            SliverToBoxAdapter(child: _buildError(_postsError!, onRetry: () => _loadPostsFor(_user!)))
          else if (_posts.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No posts yet', style: TextStyle(color: Colors.grey))),
              ),
            )
          else ...[
            SliverList.builder(
              itemCount: _posts.length,
              itemBuilder: (context, i) {
                final p = _posts[i];
                final pid = _pid(p);
                return Padding(
                  padding: EdgeInsets.fromLTRB(8, i == 0 ? 4 : 0, 8, 8),
                  child: PostCard(
                    post: p,
                    isLiked: _liked.contains(pid),
                    likeCount: _likeCounts[pid] ?? 0,
                    commentCount: _commentCounts[pid] ?? 0,
                    onToggleLike: pid.isEmpty ? null : () => _toggleLikePost(pid),
                    onCommentTap: () => _openPostDetail(p),
                    onCardTap: () => _openPostDetail(p),
                    onAvatarTap: null,
                    onHashtagTap: (tag) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hashtag: #$tag')),
                      );
                    },
                  ),
                );
              },
            ),
            if (_postsFetchingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_feedCursor != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loadMorePosts,
                      child: const Text('Load more posts'),
                    ),
                  ),
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildProfileHeaderCard(BuildContext context) {
    final studentId = (() {
      final s = (_user?.studentId ?? '').toString().trim();
      return s.isNotEmpty ? s : '—';
    })();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green100),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, _isMine ? 20 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: _avatarProvider(),
                      backgroundColor: _green100,
                      child: (_avatarProvider() == null)
                          ? const Icon(Icons.person, size: 36, color: Colors.white)
                          : null,
                    ),
                    if (_isMine)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Material(
                          color: _green700,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _changePhoto,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.edit, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: _green900,
                        ),
                      ),
                      // Removed username row per request
                      if (_isMine) ...[
                        const SizedBox(height: 4),
                        // Student ID above phone number
                        Row(
                          children: [
                            const Icon(Icons.badge_outlined, size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text(
                              (_user?.studentId ?? '').trim().isNotEmpty
                                  ? (_user!.studentId!)
                                  : '—',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.phone_iphone, size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text(
                              _phoneNumber?.trim().isNotEmpty == true ? _phoneNumber! : '—',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ],
                        ),
                        // adviser row removed per request
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _user?.email ?? '—',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                        if ((_advisorEmail ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.school_outlined, size: 16, color: Colors.black54),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'adviser  ${_advisorEmail!}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (_isMine)
                  IconButton(
                    tooltip: 'Edit phone number',
                    onPressed: _openEditUsernamePhoneSheet,
                    icon: const Icon(Icons.edit_note, color: Colors.black87),
                  ),
              ],
            ),

            if (_isMine) ...[
              const SizedBox(height: 12),
              const Divider(height: 0, color: Color(0xFFE3F0E6)),
              const SizedBox(height: 8),

              // Action buttons (mine only)
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.medical_information_outlined),
                      label: const Text('Health'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green900,
                        side: BorderSide(color: _green400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _openAllergies,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Roles'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green900,
                        side: BorderSide(color: _green400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _openRoles,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kvTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: _green050,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildError(String msg, {required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Failed to load', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(msg, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  bool get _isMine {
    if (widget.userId != null && widget.userId!.isNotEmpty) return false;
    if ((widget.initialUsername ?? widget.initialAvatarUrl ?? widget.initialName) != null) return false;
    return true;
  }

  String get _displayName {
    final name = _user != null
        ? [(_user!.firstName ?? '').trim(), (_user!.lastName ?? '').trim()].where((s) => s.isNotEmpty).join(' ')
        : '-';
    return name.isNotEmpty ? name : '—';
  }

  String get _displayUsername {
    if (_usernameAlias != null && _usernameAlias!.trim().isNotEmpty) {
      return '@${_usernameAlias!.trim()}';
    }
    final email = _user?.email ?? '';
    if (email.isNotEmpty) {
      final local = email.split('@').first;
      return local.isNotEmpty ? '@$local' : email;
    }
    return '@—';
  }

  ImageProvider<Object>? _avatarProvider() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return NetworkImage(_avatarUrl!);
    }
    return null;
  }

  // Adviser email helper (reads from multiple possible keys)
  String? get _advisorEmail {
    final raw = _user?.raw ?? const <String, dynamic>{};
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = raw[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }
    final viaKey = pick(['advisor_email','advisorEmail','advisor_mail','advisor']);
    if (viaKey != null && viaKey.contains('@')) return viaKey;
    final id = (_user?.advisorId ?? '').trim();
    if (id.contains('@')) return id;
    return null;
  }

  // -------- Edit phone only --------
  Future<void> _openEditUsernamePhoneSheet() async {
    if (!_isMine) return;

    final phoneCtrl = TextEditingController(text: _phoneNumber ?? '');

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Center(
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.92,
              margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _green100),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Edit Phone Number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _green700, foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.pop(ctx, {
                              'phone': phoneCtrl.text.trim(),
                            });
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;

    await _saveProfileChanges(
      username: _usernameAlias ?? _deriveLocalFromEmail(),
      phone: result['phone'] ?? (_phoneNumber ?? ''),
      avatarUrl: '',
    );
  }

  // -------- เปลี่ยนรูปโปรไฟล์ --------
  Future<void> _changePhoto() async {
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose profile picture', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sampleAvatars.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final url = _sampleAvatars[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text('Use custom image URL'),
                  onPressed: () async {
                    final ctrl = TextEditingController();
                    final url = await showDialog<String>(
                      context: context,
                      builder: (dctx) {
                        return AlertDialog(
                          title: const Text('Enter image URL'),
                          content: TextField(
                            controller: ctrl,
                            decoration: const InputDecoration(hintText: 'https://...'),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.pop(dctx, ctrl.text.trim()), child: const Text('Use')),
                          ],
                        );
                      },
                    );
                    if (url != null && url.isNotEmpty) {
                      if (context.mounted) Navigator.of(context).pop(url);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || selected.isEmpty) return;

    await _saveProfileChanges(
      username: _usernameAlias ?? '',
      phone: _phoneNumber ?? '',
      avatarUrl: selected,
    );
  }

 Future<void> _saveProfileChanges({
  required String username,
  required String phone,
  required String avatarUrl,
}) async {
  if (username.isNotEmpty) _usernameAlias = username;
  _phoneNumber = phone;
  if (avatarUrl.isNotEmpty) _avatarUrl = avatarUrl;
  safeSetState(() {});

  if (_isMine) {
    final sp = await SharedPreferences.getInstance();
    if (username.isNotEmpty) await sp.setString(_kAliasKey, _usernameAlias!);
    await sp.setString(_kPhoneKey, _phoneNumber ?? '');
    if (avatarUrl.isNotEmpty) await sp.setString(_kAvatarUrlKey, _avatarUrl!);
  }

  try {
    final base = AuthService.I.apiBase.endsWith('/')
        ? AuthService.I.apiBase.substring(0, AuthService.I.apiBase.length - 1)
        : AuthService.I.apiBase;
    final headers = AuthService.I.headers(
      extra: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
    );

    // Try minimal telephone-only first to avoid validation on username/avatar
    final payloadVariants = <Map<String, dynamic>>[
      {'telephone': phone},
      // Common payloads used by different backends
      {'username': username, 'phone': phone, 'avatarUrl': avatarUrl},
      {'userName': username, 'phoneNumber': phone, 'photoUrl': avatarUrl},
      {'alias': username, 'mobile': phone, 'avatar': avatarUrl},
    ];

    final endpoints = <Uri>[
      Uri.parse('$base/users/myprofile'),
      Uri.parse('$base/users/me'),
      Uri.parse('$base/users/profile/me'),
      Uri.parse('$base/profile/me'),
      Uri.parse('$base/profile'),
    ];

    bool ok = false;
    for (final uri in endpoints) {
      for (final body in payloadVariants) {
        try {
          final r = await http
              .patch(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 10));
          if (r.statusCode >= 200 && r.statusCode < 300) { ok = true; break; }

          final r2 = await http
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 10));
          if (r2.statusCode >= 200 && r2.statusCode < 300) { ok = true; break; }
        } catch (_) {}
      }
      if (ok) break;
    }

    // Feedback toast
    if (mounted) {
      final m = ScaffoldMessenger.maybeOf(context);
      m?.hideCurrentSnackBar();
      m?.showSnackBar(
        SnackBar(
          content: Text(ok ? 'Phone number updated' : 'Failed to update phone number'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Profile updated' : 'Saved locally. Server update failed.')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
  }
}

  String _deriveLocalFromEmail() {
    final email = _user?.email ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return '';
  }

  Future<void> _logout() async {
    await AuthService.I.logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate(child: AppShell())),
      (route) => false,
    );
  }
}
