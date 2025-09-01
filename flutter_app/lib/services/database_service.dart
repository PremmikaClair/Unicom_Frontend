// lib/services/database_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../shared/paging.dart';
import '../models/post.dart';
import '../models/event.dart';

class DatabaseService {
  final String baseUrl;
  DatabaseService({required this.baseUrl});

  Uri _buildUri(String path, Map<String, String?> qp) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: {
        for (final e in qp.entries)
          if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
      });

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
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('getPosts ${res.statusCode}');
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (map['items'] as List).map((j) => Post.fromJson(j)).toList();
    return PagedResult(items: items, nextCursor: map['nextCursor'] as String?);
  }

  Future<PagedResult<Post>> searchHashtags({
    required String q, // just the raw text; backend extracts #tags
    int limit = 20,
    String? cursor,
  }) async {
    final uri = _buildUri('/Explore', {
      'q': q,
      'limit': '$limit',
      'cursor': cursor,
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('searchHashtags ${res.statusCode}');
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (map['items'] as List).map((j) => Post.fromJson(j)).toList();
    return PagedResult(items: items, nextCursor: map['nextCursor'] as String?);
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
    final uri = _buildUri('/Event', {
      'q': q,
      'filters': (filters?.isNotEmpty ?? false) ? filters!.join(',') : null,
      'category': category,
      'role': role,
      'sort': sort,
      'limit': '$limit',
      'cursor': cursor,
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('getEvents ${res.statusCode}');
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (map['items'] as List).map((j) => AppEvent.fromJson(j)).toList();
    return PagedResult(items: items, nextCursor: map['nextCursor'] as String?);
  }
}