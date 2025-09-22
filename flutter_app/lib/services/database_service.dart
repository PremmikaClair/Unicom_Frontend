// lib/services/database_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../shared/paging.dart';
import '../models/post.dart';
import '../models/event.dart';
import '../models/user.dart';

class DatabaseService {
  final String baseUrl;
  final http.Client _client;
  DatabaseService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AuthService.I.base,
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
      AuthService.I.headers();

  Future<http.Response> _get(Uri uri, {Map<String, String>? extra}) {
    return _client
        .get(uri, headers: _headers(extra))
        .timeout(const Duration(seconds: 12));
  }

  // ---------- New API: /api/posts (Fiber backend) ----------
  // Returns array only (no wrapper). We convert to PagedResult.
  Future<PagedResult<Post>> getPostsPage({int page = 1, int limit = 20}) async {
    final b = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$b/api/posts')
        .replace(queryParameters: {'page': '$page', 'limit': '$limit'});

    // Attach Authorization header if logged in
    final res = await _get(uri);

    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! List) {
      throw const HttpException('Unexpected posts response shape');
    }
    final items = data
        .whereType<Map<String, dynamic>>()
        .map((j) => Post.fromJson(j))
        .toList();
    final String? next = items.length >= limit ? '${page + 1}' : null;
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
    final uri = _buildUri('/post', {
      'q': q,
      'filters': (filters?.isNotEmpty ?? false) ? filters!.join(',') : null,
      'category': category,
      'role': role,
      'sort': sort,
      'limit': '$limit',
      'cursor': cursor,
    });
    return _getPaged(uri, (j) => Post.fromJson(j));
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
    // เช่นถ้า backend จริงใช้ /events ให้แก้ตรงนี้เป็น '/events'
    final uri = _buildUri('/Event', {
      'q': q,
      'filters': (filters?.isNotEmpty ?? false) ? filters!.join(',') : null,
      'category': category,
      'role': role,
      'sort': sort,
      'limit': '$limit',
      'cursor': cursor,
    });
    return _getPaged(uri, (j) => AppEvent.fromJson(j));
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
    final next = map['nextCursor'] as String?;
    return PagedResult(items: items, nextCursor: next);
  }

  // ---------- Users ----------
  Future<Map<String, dynamic>> getMeFiber() async {
    final b = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$b/api/user/me');

    final res = await _get(uri);

    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // GET /api/users/:id  (id is Mongo ObjectID string, not int)
  Future<Map<String, dynamic>> getUserByObjectIdFiber(String objectId) async {
    final b = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$b/api/users/${Uri.encodeComponent(objectId)}');

    final res = await _get(uri);

    if (res.statusCode != 200) {
      throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
