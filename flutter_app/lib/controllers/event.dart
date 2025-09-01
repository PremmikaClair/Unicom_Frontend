// lib/controllers/events_controller.dart
import '../models/event.dart';
import '../services/database_service.dart';
import '../shared/paging.dart';
import 'base.dart';

class EventsController extends BasePagedController<AppEvent> {
  final DatabaseService db;
  EventsController({required this.db});

  @override
  Future<PagedResult<AppEvent>> fetchPage({
    required QueryState q,
    String? cursor,
    int limit = 20,
  }) {
    final filters = q.chips.toList();
    final category = q.dropdowns['category'];
    final role = q.dropdowns['role'];
    return db.getEvents(
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