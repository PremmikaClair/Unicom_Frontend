// lib/controllers/base_paged_controller.dart
import 'package:flutter/foundation.dart';
import '../shared/paging.dart';

class QueryState {
  String query = '';
  Set<String> chips = <String>{};               // e.g. {'liked'}
  Map<String, String?> dropdowns = {};          // e.g. {'category': 'news', 'role': 'admin'}
  String sort = 'recent';
}

abstract class BasePagedController<T> extends ChangeNotifier {
  final QueryState state = QueryState();
  bool loading = true;
  bool fetchingMore = false;
  String? nextCursor;
  List<T> items = [];

  // Subclass implements backend call:
  Future<PagedResult<T>> fetchPage({
    required QueryState q,
    String? cursor,
    int limit,
  });

  Future<void> refresh({int limit = 20}) async {
    loading = true;
    notifyListeners();
    final page = await fetchPage(q: state, cursor: null, limit: limit);
    items = page.items;
    nextCursor = page.nextCursor;
    loading = false;
    notifyListeners();
  }

  Future<void> loadMore({int limit = 20}) async {
    if (fetchingMore || nextCursor == null) return;
    fetchingMore = true;
    notifyListeners();
    final page = await fetchPage(q: state, cursor: nextCursor, limit: limit);
    items = [...items, ...page.items];
    nextCursor = page.nextCursor;
    fetchingMore = false;
    notifyListeners();
  }

  // UI hooks
  void updateQuery(String q) {
    state.query = q;
    refresh();
  }

  void updateChips(Set<String> chips) {
    state.chips = {...chips};
    // example: infer sort from chips
    state.sort = state.chips.contains('liked') ? 'liked' : 'recent';
    refresh();
  }

  void updateDropdown(String groupId, String? value) {
    state.dropdowns[groupId] = value;
    refresh();
  }

  void setSort(String s) {
    state.sort = s;
    refresh();
  }
}