// lib/controllers/feed_controller.dart
import '../models/post.dart';
import '../services/database_service.dart';
import '../shared/paging.dart';
import 'base.dart';

class FeedController extends BasePagedController<Post> {
  final DatabaseService db;
  FeedController({required this.db});

  @override
  Future<PagedResult<Post>> fetchPage({
    required QueryState q,
    String? cursor,
    int limit = 20,
  }) {
    final filters = q.chips.toList(); // e.g., ['liked']
    final category = q.dropdowns['category'];
    final role = q.dropdowns['role'];
    return db.getPosts(
      q: q.query,
      filters: filters,
      category: category,
      role: role,
      sort: q.sort,
      limit: limit,
      cursor: cursor,
    );
  }
}