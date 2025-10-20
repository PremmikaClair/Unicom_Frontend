// lib/services/database_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../shared/paging.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../models/trend.dart';

class DatabaseService {
  final String baseUrl;
  final http.Client _client;
  DatabaseService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AuthService.I.apiBase,
        _client = client ?? http.Client();

  Uri _buildUri(String path, Map<String, String?> qp) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p').replace(queryParameters: {
      for (final e in qp.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    });
  }

  Map<String, String> _headers([Map<String, String>? extra]) =>
      AuthService.I.headers(extra: extra);

  Future<http.Response> _get(Uri uri, {Map<String, String>? extra}) {
    return _client
        .get(uri, headers: _headers(extra))
        .timeout(const Duration(seconds: 12));
  }

  // ---------- Posts (main-webbase) ----------
  // GET /posts?limit=&cursor=
  Future<PagedResult<Post>> getPostsPage({int page = 1, int limit = 20}) async {
    final uri = _buildUri('/posts', {'limit': '$limit'});
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body);
    final list = (body is Map<String, dynamic>)
        ? (body['items'] ?? body['Items'] ?? body['data']) as List<dynamic>
        : (body is List ? body : const []);
    final items = list
        .whereType<Map<String, dynamic>>()
        .map((j) => Post.fromJson(j))
        .toList();
    final String? next = (body is Map<String, dynamic>)
        ? (body['next_cursor'] ?? body['NextCursor'] ?? body['nextCursor'])?.toString()
        : null;
    return PagedResult(items: items, nextCursor: next);
  }

  Future<PagedResult<Post>> getPosts({
    String? q,
    List<String>? filters,
    String? category,
    String? role,
    String sort = 'recent',
    int limit = 20,
    String? cursor,
  }) async {
    // Map to /posts (filters not supported server-side; keep client-only)
    final params = <String, String?>{
      'limit': '$limit',
      'cursor': cursor,
    };
    final query = q?.trim();
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }
    final uri = _buildUri('/posts', params);
    final res = await _get(uri, extra: const {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (map['items'] ?? map['Items'] ?? map['data']) as List<dynamic>;
    final items = list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
    final next = (map['next_cursor'] ?? map['NextCursor'] ?? map['nextCursor'])?.toString();
    return PagedResult(items: items, nextCursor: next);
  }

  Future<PagedResult<Post>> getFeed({
    String? q,
    List<String>? categories,
    List<String>? roles,
    String sort = 'time',
    int limit = 20,
    String? cursor,
  }) async {
    final params = <String, String?>{
      'limit': '$limit',
      'cursor': cursor,
    };

    final query = q?.trim();
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }

    final sortValue = sort.trim();
    if (sortValue.isNotEmpty) {
      params['sort'] = sortValue;
    }

    if (categories != null && categories.isNotEmpty) {
      params['categoryIds'] = categories.join(',');
      for (var i = 0; i < categories.length; i++) {
        final value = categories[i];
        if (value.isNotEmpty) {
          params['categoryIds[$i]'] = value;
        }
      }
    }

    if (roles != null && roles.isNotEmpty) {
      params['roles'] = roles.join(',');
      for (var i = 0; i < roles.length; i++) {
        final value = roles[i];
        if (value.isNotEmpty) {
          params['roles[$i]'] = value;
        }
      }
    }

    final uri = _buildUri('/feed', params);
    final res = await _get(uri, extra: const {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final map = jsonDecode(res.body);
    List<dynamic> list;
    String? next;
    if (map is Map<String, dynamic>) {
      list = (map['items'] ?? map['data'] ?? map['posts']) as List<dynamic>? ?? const [];
      next = (map['next_cursor'] ?? map['NextCursor'] ?? map['nextCursor'])?.toString();
    } else if (map is List) {
      list = map;
      next = null;
    } else {
      list = const [];
      next = null;
    }
    final items = list
        .whereType<Map<String, dynamic>>()
        .map((e) => Post.fromJson(e))
        .toList();
    return PagedResult(items: items, nextCursor: next);
  }

  Future<Post> getPostByIdFiber(String postId) async {
    final uri = _buildUri('/posts/$postId', const {});
    final res = await _get(uri, extra: const {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final body = res.body.trim();
    if (body.isEmpty) {
      throw StateError('Empty response when loading post $postId');
    }
    final decoded = jsonDecode(body);
    Map<String, dynamic>? map;
    if (decoded is Map<String, dynamic>) {
      final candidates = [
        decoded['item'],
        decoded['post'],
        decoded['data'],
        decoded['Post'],
      ];
      for (final candidate in candidates) {
        if (candidate is Map<String, dynamic>) {
          map = Map<String, dynamic>.from(candidate);
          break;
        }
      }
      map ??= Map<String, dynamic>.from(decoded);
    } else if (decoded is List) {
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          map = Map<String, dynamic>.from(entry);
          break;
        }
      }
    }
    if (map == null || map.isEmpty) {
      throw StateError('Invalid post payload for $postId: $decoded');
    }
    return Post.fromJson(map);
  }

  Future<PagedResult<Map<String, dynamic>>> searchUsers({
    required String q,
    int limit = 20,
    String? cursor,
  }) async {
    final params = <String, String?>{
      'q': q.trim(),
      'limit': '$limit',
      'cursor': cursor,
    };
    final uri = _buildUri('/users', params);
    final res = await _get(uri, extra: const {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (map['items'] ?? map['data'] ?? map['Items'] ?? const []) as List<dynamic>;
    final items = list
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final next = (map['nextCursor'] ?? map['next_cursor'])?.toString();
    return PagedResult(items: items, nextCursor: next);
  }

  // ---------- Likes ----------
  // POST /likes { targetId, targetType: 'post' | 'comment' }
  Future<({bool liked, int likeCount})> toggleLike({
    required String targetId,
    required String targetType,
  }) async {
    final uri = _buildUri('/likes', {});
    final res = await _client
        .post(
          uri,
          headers: _headers(const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          }),
          body: jsonEncode({
            'targetId': targetId,
            'targetType': targetType,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw HttpException('POST $uri -> ${res.statusCode}: ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final liked = (m['liked']?.toString() == 'true');
    final likeCount = (m['likeCount'] is int)
        ? m['likeCount'] as int
        : int.tryParse('${m['likeCount']}') ?? 0;
    return (liked: liked, likeCount: likeCount);
  }

  // ---------- Comments ----------
  // GET /posts/:postId/comments?limit=&cursor=
  Future<PagedResult<Comment>> getComments({
    required String postId,
    int limit = 20,
    String? cursor,
  }) async {
    final uri = _buildUri('/posts/$postId/comments', {
      'limit': '$limit',
      'cursor': cursor,
    });
    final res = await _get(uri, extra: const {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (map['comments'] ?? map['items'] ?? map['data']) as List<dynamic>;
    final items = list
        .whereType<Map<String, dynamic>>()
        .map((j) => Comment.fromJson(j))
        .toList();
    final next = (map['next_cursor'] ?? map['NextCursor'] ?? map['nextCursor'])?.toString();
    return PagedResult(items: items, nextCursor: next);
  }

  // POST /posts/:postId/comments { text }
  Future<Comment> addComment({
    required String postId,
    required String text,
  }) async {
    final uri = _buildUri('/posts/$postId/comments', {});
    final res = await _client
        .post(
          uri,
          headers: _headers(const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          }),
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 201) {
      throw HttpException('POST $uri -> ${res.statusCode}: ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return Comment.fromJson(m);
  }

  Future<PagedResult<Post>> searchHashtags({
    required String q,
    int limit = 20,
    String? cursor,
  }) async {
    // เช็กให้ตรงกับ backend ว่า endpoint ต้องเป็น /explore หรือ /Explore
    final uri = _buildUri('/Explore', {
      'q': q,
      'limit': '$limit',
      'cursor': cursor,
    });
    return _getPaged(uri, (j) => Post.fromJson(j));
  }

  Future<PagedResult<AppEvent>> getEvents({
    String? q,
    List<String>? filters,
    String? category,
    String? role,
    String sort = 'recent',
    int limit = 20,
    String? cursor,
  }) async {
    // Backend returns array (no paging). Wrap as single page.
    final list = await getEventsFiberList();
    return PagedResult(items: list, nextCursor: null);
  }

  Future<PagedResult<T>> _getPaged<T>(
      Uri uri, T Function(Map<String, dynamic>) fromJson) async {
    // log ให้เห็นชัด ๆ
    // ignore: avoid_print
    print('GET $uri');
    final res = await _get(uri, extra: const {'Accept': 'application/json'});

    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    // ปรับ key ให้ตรง backend: 'items' vs 'data'
    final list = (map['items'] ?? map['data']) as List<dynamic>;
    final items =
        list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    final next = (map['nextCursor'] ?? map['next_cursor']) as String?;
    return PagedResult(items: items, nextCursor: next);
  }

  // ---------- Trends (trending tags + posts) ----------
  // Integrates with backend endpoints:
  // - GET /trending/today  (top hashtags today)
  // - GET /trending/all    (top hashtags overall)
  // - GET /trending/posts?tag=...
  // Existing ExplorePage calls this with a 'category' string —
  // treat 'today' or 'trending' as /trending/today, and 'all' as /trending/all.
  Future<TrendsResponse> getTrends({
    required String location, // ignored by backend; kept for UI context
    required String category,
    String? cursor,
    int limit = 20,
  }) async {
    // Choose endpoint by category; keep backward-compat for 'trending'
    final scope = category.toLowerCase();
    final path = (scope == 'all') ? '/trending/all' : '/trending/today';
    final uri = _buildUri(path, const {});

    try {
      final resp = await _get(uri, extra: const {'Accept': 'application/json'});
      if (resp.statusCode != 200) {
        return _mockTrends(location: location, category: category, cursor: cursor, limit: limit);
      }

      final body = resp.body.trim();
      if (body.isEmpty) {
        return TrendsResponse(items: const <TrendItem>[], nextCursor: null);
      }

      final parsed = jsonDecode(body);
      List<dynamic> list;
      if (parsed is List) {
        list = parsed;
      } else if (parsed is Map<String, dynamic>) {
        // Try common containers
        list = (parsed['items'] ?? parsed['data'] ?? parsed['tags'] ?? parsed['trending']) as List<dynamic>? ?? const [];
      } else {
        list = const [];
      }

      int i = 0;
      String normalizeTag(dynamic v) {
        if (v == null) return '';
        if (v is String) return v.replaceAll('#', '').trim();
        if (v is Map<String, dynamic>) {
          final cand = (v['tag'] ?? v['hashtag'] ?? v['name'] ?? v['title'] ?? v['key'] ?? '').toString();
          return cand.replaceAll('#', '').trim();
        }
        return v.toString().replaceAll('#', '').trim();
      }

      int? normalizeCount(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is String) return int.tryParse(v);
        return int.tryParse(v.toString());
      }

      final items = <TrendItem>[];
      for (final e in list) {
        String tag;
        int? count;
        String? ctx;
        if (e is String) {
          tag = normalizeTag(e);
          count = null;
          ctx = null;
        } else if (e is Map<String, dynamic>) {
          tag = normalizeTag(e);
          count = normalizeCount(e['count'] ?? e['postCount'] ?? e['posts'] ?? e['usage']);
          final c = e['context'];
          if (c is String && c.trim().isNotEmpty) ctx = c.trim();
        } else {
          tag = normalizeTag(e);
          count = null;
          ctx = null;
        }
        if (tag.isEmpty) continue;
        items.add(TrendItem(
          title: '#$tag',
          tag: tag,
          rank: (++i),
          postCount: count,
          context: ctx ?? (scope == 'all' ? 'Trending (All time)' : 'Trending Today'),
        ));
      }

      return TrendsResponse(items: items, nextCursor: null);
    } catch (_) {
      // Network/parse error → fallback to mock for now
      return _mockTrends(location: location, category: category, cursor: cursor, limit: limit);
    }
  }

  TrendsResponse _mockTrends({
    required String location,
    required String category,
    String? cursor,
    int limit = 20,
  }) {
    final seeds = <Map<String, dynamic>>[
      {'title':'#ELLE80thxNuNew','postCount':83000,'context':'Trending'},
      {'title':'CHAWARIN AT ELLE PARTY','postCount':76900,'context':'Trending'},
      {'title':'#TEASER_BAMBAMXTIMETHAI','postCount':152000,'context':'Trending'},
      {'title':'#Givenchy','postCount':15400,'context':'Trending'},
      {'title':'#BUSSINGJAPANEP6','postCount':440000,'context':'Trending'},
      {'title':'#MillexPerthSanta','postCount':753000,'context':'Trending'},
      {'title':'#Tpop','postCount':92000,'context':'Trending'},
      {'title':'#Blackpink','postCount':215000,'context':'Trending'},
      {'title':'#KinnPorsche','postCount':128000,'context':'Trending'},
      {'title':'#Ninew','postCount':56000,'context':'Trending'},
      {'title':'#GMMTV2025','postCount':301000,'context':'Trending'},
      {'title':'#LISA','postCount':580000,'context':'Trending'},
      {'title':'#Bangkok','postCount':64000,'context':'Trending'},
      {'title':'#MetGala','postCount':442000,'context':'Trending'},
      {'title':'#SEA Games','postCount':101000,'context':'Trending'},
      {'title':'#PremierLeague','postCount':390000,'context':'Trending'},
      {'title':'#ThailandElection','postCount':88000,'context':'Trending'},
      {'title':'#AI','postCount':225000,'context':'Trending'},
      {'title':'#Flutter','postCount':36000,'context':'Trending'},
      {'title':'#DartLang','postCount':21000,'context':'Trending'},
      {'title':'#UIUX','postCount':15100,'context':'Trending'},
    ];

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

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = (start + limit).clamp(0, list.length);
    final pageItems = list.sublist(start, end);
    final next = end < list.length ? '$end' : null;

    return TrendsResponse(items: pageItems, nextCursor: next);
  }

  // GET /trending/posts?tag=...
  // Returns list of posts for a given hashtag. Backend may not paginate; wrap as single page.
  Future<PagedResult<Post>> getTrendingPostsByTag({
    required String tag,
    int limit = 20,
    String? cursor,
  }) async {
    final uri = _buildUri('/trending/posts', {
      'tag': tag.replaceAll('#', '').trim(),
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (limit > 0) 'limit': '$limit',
    });
    final res = await _get(uri, extra: const {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final body = res.body.trim();
    if (body.isEmpty) return PagedResult(items: const <Post>[], nextCursor: null);
    final parsed = jsonDecode(body);
    List<dynamic> list;
    String? next;
    if (parsed is List) {
      list = parsed;
      next = null;
    } else if (parsed is Map<String, dynamic>) {
      list = (parsed['items'] ?? parsed['data'] ?? parsed['posts']) as List<dynamic>? ?? const [];
      next = (parsed['next_cursor'] ?? parsed['nextCursor'])?.toString();
    } else {
      list = const [];
      next = null;
    }
    final items = list
        .whereType<Map<String, dynamic>>()
        .map((j) => Post.fromJson(j))
        .toList();
    return PagedResult(items: items, nextCursor: next);
  }

  // ---------- Users ----------
  Future<Map<String, dynamic>> getMeFiber() async {
    final uri = _buildUri('/users/myprofile', {});

    final res = await _get(uri);

    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ---------- Memberships ----------
  // No direct endpoint to list memberships by user. Derive from my profile.
  Future<List<Map<String, dynamic>>> getMyMembershipsFiber({String active = 'true'}) async {
    final prof = await getMeFiber();
    final mems = (prof['memberships'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    // Normalize to { org_path, position_key, active }
    return mems.map((m) {
      final org = (m['org_unit'] ?? m['org']) as Map<String, dynamic>?;
      final pos = (m['position'] as Map?)?.cast<String, dynamic>();
      final orgPath = (org?['org_path'] ?? m['org_path'])?.toString();
      String orgShort = (org?['shortname'] ?? org?['short_name'] ?? '')?.toString() ?? '';
      final posKey  = (pos?['key'] ?? m['position_key'])?.toString();
      final posDisplay = (() {
        final disp = (pos?['display'] as Map?)?.cast<String, dynamic>();
        if (disp != null) {
          final th = disp['th']?.toString();
          final en = disp['en']?.toString();
          if (th != null && th.trim().isNotEmpty) return th.trim();
          if (en != null && en.trim().isNotEmpty) return en.trim();
        }
        return posKey?.toString();
      })();
      if (orgShort.isEmpty && orgPath != null && orgPath.isNotEmpty) {
        final parts = orgPath.split('/')..removeWhere((e) => e.isEmpty);
        if (parts.isNotEmpty) orgShort = parts.last.toUpperCase();
      }
      final id = '${orgPath ?? ''}::${posKey ?? ''}';
      final label = (posDisplay != null && posDisplay.isNotEmpty && orgShort.isNotEmpty)
          ? '${posDisplay} • ${orgShort}'
          : (posDisplay ?? posKey ?? '');
      return {
        '_id': id,
        'org_path': orgPath ?? '',
        'org_short': orgShort,
        'position_key': posKey ?? '',
        'label': label.isNotEmpty ? label : '${posKey ?? ''} • ${orgPath ?? ''}',
        'active': true,
      };
    }).toList();
  }

  // ---------- Org units ----------
  // GET /org/units/tree?start=&depth=&lang=
  Future<List<Map<String, dynamic>>> getOrgTreeFiber({String? start, int? depth, String? lang}) async {
    final qp = <String, String>{};
    if (start != null && start.isNotEmpty) qp['start'] = start;
    if (depth != null && depth > 0) qp['depth'] = '$depth';
    if (lang != null && lang.isNotEmpty) qp['lang'] = lang;
    final uri = _buildUri('/org/units/tree', qp);
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ---------- Categories ----------
  // GET /categories -> [ { _id, category_name, short_name } ]
  Future<List<Map<String, dynamic>>> getCategoriesFiber() async {
    final uri = _buildUri('/categories', const {});
    final res = await _get(uri, extra: const {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is! List) return const <Map<String, dynamic>>[];
    // Normalize ids to string and expose name/short
    return data.map<Map<String, dynamic>>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      String idStr;
      final id = m['_id'];
      if (id is Map && id['\$oid'] != null) {
        idStr = id['\$oid'].toString();
      } else {
        idStr = id?.toString() ?? '';
      }
      return {
        'id': idStr,
        'name': (m['category_name'] ?? m['name'] ?? '').toString(),
        'short': (m['short_name'] ?? m['short'] ?? '').toString(),
      };
    }).toList();
  }

  // ---------- Posts (Fiber) ----------
  // POST /posts (CreatePostDTO)
  Future<Map<String, dynamic>> createPostFiber({
    required String uid, // kept for callers; not sent
    required String name, // kept for callers; not sent
    required String username, // kept; not sent
    required String message,
    Map<String, dynamic>? postedAs, // { org_path, position_key, label? }
    Map<String, dynamic>? visibility, // { access, audience? }
    String? orgOfContent,
    String? status,
    String? imagePath, // optional local path to image file to upload
    Uint8List? imageBytes, // optional raw bytes (useful for web)
    String? imageFilename, // optional filename hint when using bytes
    List<String>? categoryIds, // optional category ObjectID strings
  }) async {
    final uri = _buildUri('/posts', {});

    // Always prefer multipart form to satisfy backend's FormValue requirements
    // for postAs.org_path and postAs.position_key. Attach image if provided.
    final req = http.MultipartRequest('POST', uri);
    // Do not set Content-Type manually; MultipartRequest handles boundary.
    req.headers.addAll(_headers(const {'Accept': 'application/json'}));

    // Required content
    req.fields['postText'] = message;

    // Posted-as (required by backend via FormValue)
    if (postedAs != null) {
      final orgPath = (postedAs['org_path'] ?? '').toString();
      final posKey = (postedAs['position_key'] ?? '').toString();
      if (orgPath.isNotEmpty) req.fields['postAs.org_path'] = orgPath;
      if (posKey.isNotEmpty) req.fields['postAs.position_key'] = posKey;
      if ((postedAs['label'] ?? '').toString().isNotEmpty) {
        req.fields['postAs.label'] = postedAs['label'].toString();
      }
    }

    // Visibility (fallback to public)
    final access = (visibility?['access'] ?? 'public').toString();
    req.fields['visibility.access'] = access;
    final aud = visibility?['audience'];
    if (aud is List) {
      // Try common patterns for decoding slices from form data.
      // 1) Comma-separated single field
      if (aud.isNotEmpty) {
        req.fields['visibility.audience'] = aud.map((e) => e.toString()).join(',');
      }
      // 2) Also send indexed fields (some decoders support this)
      for (var i = 0; i < aud.length; i++) {
        final v = aud[i];
        if (v == null) continue;
        req.fields['visibility.audience[$i]'] = v.toString();
      }
    }

    if (orgOfContent != null && orgOfContent.isNotEmpty) {
      req.fields['org_of_content'] = orgOfContent;
    }

    // Categories (optional)
    if (categoryIds != null && categoryIds.isNotEmpty) {
      // Comma-separated & indexed to help backend parse either form
      req.fields['categoryIds'] = categoryIds.join(',');
      for (var i = 0; i < categoryIds.length; i++) {
        final v = categoryIds[i];
        if (v.isEmpty) continue;
        req.fields['categoryIds[$i]'] = v;
      }
    }

    // Optional image file (prefer bytes if provided to support web)
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final fname = (imageFilename == null || imageFilename.isEmpty)
          ? 'upload.jpg'
          : imageFilename;
      final file = http.MultipartFile.fromBytes('file', imageBytes, filename: fname);
      req.files.add(file);
    } else if (imagePath != null && imagePath.isNotEmpty) {
      try {
        final file = await http.MultipartFile.fromPath('file', imagePath);
        req.files.add(file);
      } catch (e) {
        throw HttpException('Attach file failed: $e');
      }
    }

    final streamed = await req.send().timeout(const Duration(seconds: 20));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 201) {
      throw HttpException('POST $uri -> ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // GET /users/profile/:id  (id is Mongo ObjectID string)
  Future<Map<String, dynamic>> getUserByObjectIdFiber(String objectId) async {
    final uri = _buildUri('/users/profile/${Uri.encodeComponent(objectId)}', {});

    final res = await _get(uri);

    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ---------- Events (main-webbase direct list) ----------
  // GET /event -> [ { event: {...}, schedules: [...] }, ... ]
  Future<List<AppEvent>> getEventsFiberList() async {
    final uri = _buildUri('/event', {});
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is! List) {
      throw const HttpException('Unexpected response shape for /event');
    }

    DateTime? _parseTime(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      final s = v.toString();
      return DateTime.tryParse(s);
    }

    String? _str(dynamic v) => v == null ? null : v.toString();
    bool _looksImage(String url) =>
        RegExp(r"\.(png|jpe?g|gif|webp|bmp|svg)(\?.*)?", caseSensitive: false).hasMatch(url);

    final items = <AppEvent>[];
    for (final e in data) {
      if (e is! Map) continue;
      final ev = e['event'] as Map<String, dynamic>?;
      final schedules = (e['schedules'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (ev == null) continue;

      // pick first schedule (if exists) as primary time/location
      DateTime start = DateTime.now();
      DateTime? end;
      String? loc;
      if (schedules.isNotEmpty) {
        final s0 = schedules.first;
        start = _parseTime(s0['time_start']) ?? start;
        end = _parseTime(s0['time_end']);
        loc = _str(s0['location']);
      }

      final postedAs = (ev['posted_as'] as Map?)?.cast<String, dynamic>();
      final postedLabel = (postedAs?['label'] ?? postedAs?['tag'] ?? postedAs?['position_key'])?.toString();

      // Try to derive imageUrl from common fields or media array
      String? imageUrl;
      // Accept various backend keys: imageUrl/image_url, pictureURL/picture_url, plus common fallbacks
      final cand = ev['imageUrl'] ?? ev['image_url'] ?? ev['pictureURL'] ?? ev['picture_url'] ?? ev['image'] ?? ev['cover'] ?? ev['banner'] ?? ev['poster'];
      if (cand != null && cand.toString().trim().isNotEmpty) {
        imageUrl = cand.toString().trim();
      } else {
        final media = ev['media'];
        if (media is List && media.isNotEmpty) {
          for (final m in media) {
            if (m == null) continue;
            final s = m.toString().trim();
            if (s.isEmpty) continue;
            if (_looksImage(s)) { imageUrl = s; break; }
          }
        }
      }

      items.add(AppEvent(
        id: _str(ev['id']) ?? _str(ev['_id']) ?? '',
        title: _str(ev['topic']) ?? _str(ev['title']) ?? '(untitled)',
        description: _str(ev['description']),
        category: null,
        role: postedLabel, // show organizer role/tag on card chips
        location: loc,
        startTime: start,
        endTime: end,
        imageUrl: imageUrl,
        organizer: _str(ev['org_of_content']),
        isFree: null,
        likeCount: null,
        capacity: int.tryParse('${ev['max_participation']}'),
        haveForm: ev['have_form'] == true,
      ));
    }

    return items;
  }

  // GET /event/:event_id -> detail (current_participation, max_participation, form_id, schedules)
  Future<Map<String, dynamic>> getEventDetailFiber(String eventId) async {
    final uri = _buildUri('/event/${Uri.encodeComponent(eventId)}', {});
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return map;
  }

  // POST /event/participate/:event_id (only for events without form)
  Future<void> joinEventNoFormFiber(String eventId) async {
    final uri = _buildUri('/event/participate/${Uri.encodeComponent(eventId)}', {});
    final res = await _client
        .post(uri, headers: _headers(const {'Accept': 'application/json'}))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw HttpException('POST $uri -> ${res.statusCode}: ${res.body}');
    }
  }

  // GET /event/:eventId/form/questions
  Future<List<Map<String, dynamic>>> getEventFormQuestionsFiber(String eventId) async {
    final uri = _buildUri('/event/${Uri.encodeComponent(eventId)}/form/questions', {});
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (m['Questions'] ?? m['questions'] ?? m['data'] ?? const []) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // POST /event/:eventId/form/answers { answers: [ { question_id, answer_value, order_index } ] }
  Future<void> submitEventFormAnswersFiber(String eventId, List<Map<String, dynamic>> answers) async {
    final uri = _buildUri('/event/${Uri.encodeComponent(eventId)}/form/answers', {});
    final res = await _client
        .post(
          uri,
          headers: _headers(const {'Content-Type': 'application/json', 'Accept': 'application/json'}),
          body: jsonEncode({'answers': answers}),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw HttpException('POST $uri -> ${res.statusCode}: ${res.body}');
    }
  }

  // GET /event/participant/mystatus/:eventId -> { status: "accept"|"stall"|"reject" }
  Future<String?> getMyEventStatusFiber(String eventId) async {
    final uri = _buildUri('/event/participant/mystatus/${Uri.encodeComponent(eventId)}', {});
    final res = await _get(uri);
    if (res.statusCode != 200) {
      return null;
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final st = m['status'];
    if (st is String) return st;
    if (st is Map) {
      final inner = st['status'];
      if (inner is String) return inner;
      if (inner != null) return inner.toString();
    }
    return null;
  }

  // ----- Event management (organizers) -----

  // POST /event { dto.EventRequestDTO }
  Future<Map<String, dynamic>> createEventFiber(Map<String, dynamic> payload, {
    String? imagePath,
    Uint8List? imageBytes,
    String? imageFilename,
    Map<String, dynamic>? postedAs, // { org_path, position_key }
    String? nodeId,
  }) async {
    // If an image is provided, use multipart (backend expects multipart for /event)
    if ((imageBytes != null && imageBytes.isNotEmpty) || (imagePath != null && imagePath.isNotEmpty)) {
      final uri = _buildUri('/event', {});
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll(_headers(const {'Accept': 'application/json'}));

      // Required fields used by backend handler
      final pa = postedAs ?? payload['posted_as'] as Map<String, dynamic>?;
      final orgPath = (pa?['org_path'] ?? payload['org_of_content'] ?? '').toString();
      final posKey  = (pa?['position_key'] ?? '').toString();
      final nid     = (nodeId ?? payload['node_id'] ?? payload['NodeID'] ?? '').toString();
      if (nid.isNotEmpty) req.fields['NodeID'] = nid;
      if (orgPath.isNotEmpty) req.fields['postedAs.org_path'] = orgPath;
      if (posKey.isNotEmpty) req.fields['postedAs.position_key'] = posKey;

      // Optional extras: topic/description/capacity/visibility as flat fields for forward-compat
      void putField(String k) {
        final v = payload[k];
        if (v == null) return;
        final s = v is String ? v : jsonEncode(v);
        if (s.isNotEmpty) req.fields[k] = s;
      }
      for (final k in ['topic','description','max_participation','visibility','org_of_content','status','have_form']) {
        putField(k);
      }
      if (payload['schedules'] != null) {
        // Send schedules as JSON string
        req.fields['schedules'] = jsonEncode(payload['schedules']);
      }

      // Attach image
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final fname = (imageFilename == null || imageFilename.isEmpty) ? 'cover.jpg' : imageFilename;
        req.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: fname));
      } else if (imagePath != null && imagePath.isNotEmpty) {
        req.files.add(await http.MultipartFile.fromPath('file', imagePath));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 201) {
        throw HttpException('POST $uri -> ${res.statusCode}: ${res.body}');
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    // Fallback: JSON request (kept for compatibility)
    final uri = _buildUri('/event', {});
    final res = await _client
        .post(uri,
            headers: _headers(const {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            }),
            body: jsonEncode(payload))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 201) {
      throw HttpException('POST $uri -> ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // POST /event/:eventId/form/initialize
  Future<Map<String, dynamic>> initializeFormFiber(String eventId) async {
    final uri = _buildUri('/event/${Uri.encodeComponent(eventId)}/form/initialize', {});
    final res = await _client
        .post(uri, headers: _headers(const {'Accept': 'application/json'}))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw HttpException('POST $uri -> ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // POST /event/:eventId/form/disable
  Future<void> disableFormFiber(String eventId) async {
    final uri = _buildUri('/event/${Uri.encodeComponent(eventId)}/form/disable', {});
    final res = await _client
        .post(uri, headers: _headers(const {'Accept': 'application/json'}))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw HttpException('POST $uri -> ${res.statusCode}: ${res.body}');
    }
  }

  // POST /event/:eventId/form/questions { questions: [ {question_text, required, order_index} ] }
  Future<List<Map<String, dynamic>>> createFormQuestionsFiber(
      String eventId, List<Map<String, dynamic>> questions) async {
    final uri = _buildUri('/event/${Uri.encodeComponent(eventId)}/form/questions', {});
    final res = await _client
        .post(
          uri,
          headers: _headers(const {'Content-Type': 'application/json', 'Accept': 'application/json'}),
          body: jsonEncode({'questions': questions}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException('POST $uri -> ${res.statusCode}: ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (m['data'] ?? m['Questions'] ?? m['questions'] ?? const []) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // GET /event/:eventId/form/matrix
  Future<Map<String, dynamic>> getFormMatrixFiber(String eventId) async {
    final uri = _buildUri('/event/${Uri.encodeComponent(eventId)}/form/matrix', {});
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // PUT /event/participant/status { user_id, event_id, status }
  Future<void> updateParticipantStatusFiber({
    required String userId,
    required String eventId,
    required String status, // accept|stall|reject
  }) async {
    final uri = _buildUri('/event/participant/status', {});
    final res = await _client
        .put(
          uri,
          headers: _headers(const {'Content-Type': 'application/json', 'Accept': 'application/json'}),
          body: jsonEncode({'user_id': userId, 'event_id': eventId, 'status': status}),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 201) {
      throw HttpException('PUT $uri -> ${res.statusCode}: ${res.body}');
    }
  }

  // DELETE /event/:event_id (soft delete)
  Future<void> deleteEventFiber(String eventId) async {
    final uri = _buildUri('/event/${Uri.encodeComponent(eventId)}', {});
    final res = await _client.delete(uri, headers: _headers()).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw HttpException('DELETE $uri -> ${res.statusCode}: ${res.body}');
    }
  }

  // POST /event/:eventId/qa { questionText }
  Future<Map<String, dynamic>> postEventQuestionFiber(String eventId, String questionText) async {
    final uri = _buildUri('/event/${Uri.encodeComponent(eventId)}/qa', {});
    final res = await _client
        .post(
          uri,
          headers: _headers(const {'Content-Type': 'application/json', 'Accept': 'application/json'}),
          body: jsonEncode({'questionText': questionText}),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 201) {
      throw HttpException('POST $uri -> ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // PATCH /qa/:qaId/answer { answerText }
  Future<Map<String, dynamic>> answerEventQaFiber(String qaId, String answerText) async {
    final uri = _buildUri('/qa/${Uri.encodeComponent(qaId)}/answer', {});
    final res = await _client
        .patch(
          uri,
          headers: _headers(const {'Content-Type': 'application/json', 'Accept': 'application/json'}),
          body: jsonEncode({'answerText': answerText}),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw HttpException('PATCH $uri -> ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // GET /event/:eventId/qa -> [ EventQAResponse ]
  Future<List<Map<String, dynamic>>> getEventQaListFiber(String eventId) async {
    final uri = _buildUri('/event/${Uri.encodeComponent(eventId)}/qa', {});
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ===== New: Event management helpers =====
  // GET /event/managed -> [ { eventId, topic, pendingCount, acceptedCount, max_participation } ]
  Future<List<Map<String, dynamic>>> getManagedEventsFiber() async {
    final uri = _buildUri('/event/managed', {});
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // GET /event/:eventId/participants?status=accept|stall|reject&role=participant|organizer
  Future<List<Map<String, dynamic>>> getEventParticipantsFiber(
      String eventId, {String? status, String? role}) async {
    final qp = <String, String>{};
    if (status != null && status.isNotEmpty) qp['status'] = status;
    if (role != null && role.isNotEmpty) qp['role'] = role;
    final uri = _buildUri('/event/${Uri.encodeComponent(eventId)}/participants', qp);
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // GET /event/manageable-orgs?search=
  Future<List<Map<String, dynamic>>> getManageableOrgsFiber({String? search}) async {
    final uri = _buildUri('/event/manageable-orgs', {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // GET /policies?org_prefix=&position_key=
  Future<List<Map<String, dynamic>>> getPoliciesFiber({String? orgPrefix, String? positionKey}) async {
    final qp = <String, String>{};
    if (orgPrefix != null && orgPrefix.isNotEmpty) qp['org_prefix'] = orgPrefix;
    if (positionKey != null && positionKey.isNotEmpty) qp['position_key'] = positionKey;
    final uri = _buildUri('/policies', qp);
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // GET /org/units?start=&search=&limit=
  Future<List<Map<String, dynamic>>> getOrgUnitsSearchFiber({String? start, String? search, int? limit}) async {
    final qp = <String, String>{};
    if (start != null && start.isNotEmpty) qp['start'] = start;
    if (search != null && search.isNotEmpty) qp['search'] = search;
    if (limit != null && limit > 0) qp['limit'] = '$limit';
    final uri = _buildUri('/org/units', qp);
    final res = await _get(uri);
    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is! List) return const <Map<String, dynamic>>[];
    return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
