// lib/services/database_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../shared/paging.dart';
import '../models/post.dart';
import '../models/event.dart';

class DatabaseService {
  final String baseUrl;
  final http.Client _client;
  DatabaseService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

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
    final res = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));

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
}
