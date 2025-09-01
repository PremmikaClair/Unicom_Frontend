// lib/controllers/explore_controller.dart
import '../models/post.dart';
import '../services/database_service.dart';
import '../shared/paging.dart';
import 'base.dart';

class ExploreController extends BasePagedController<Post> {
  final DatabaseService db;
  ExploreController({required this.db});

  @override
  Future<PagedResult<Post>> fetchPage({
    required QueryState q,
    String? cursor,
    int limit = 20,
  }) {
    // Let the backend parse hashtags out of q (e.g., "#ce #freshers")
    return db.searchHashtags(q: q.query, limit: limit, cursor: cursor);
  }
}