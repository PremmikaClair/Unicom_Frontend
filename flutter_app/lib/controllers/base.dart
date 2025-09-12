// lib/controllers/base.dart
import 'package:flutter/foundation.dart';
import '../shared/paging.dart'; // มี PagedResult<T>

class QueryState {
  final String query;
  final Set<String> chips;
  final Map<String, String> dropdowns;
  final String sort;

  const QueryState({
    this.query = '',
    this.chips = const {},
    this.dropdowns = const {},
    this.sort = 'recent',
  });

  QueryState copyWith({
    String? query,
    Set<String>? chips,
    Map<String, String>? dropdowns,
    String? sort,
  }) {
    return QueryState(
      query: query ?? this.query,
      chips: chips ?? this.chips,
      dropdowns: dropdowns ?? this.dropdowns,
      sort: sort ?? this.sort,
    );
  }
}

abstract class BasePagedController<T> extends ChangeNotifier {
  bool loading = false;
  bool fetchingMore = false;
  Object? error;

  List<T> items = <T>[];
  String? nextCursor;

  QueryState state = const QueryState();

  /// ต้องให้ subclass implement
  Future<PagedResult<T>> fetchPage({
    required QueryState q,
    String? cursor,
    int limit,
  });

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await fetchPage(q: state, cursor: null, limit: 20);
      items = page.items;
      nextCursor = page.nextCursor;
    } catch (e, st) {
      error = e;
      debugPrint('refresh error: $e\n$st');
    } finally {
      loading = false;           // << ปิดโหลดเสมอ
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loading || fetchingMore || nextCursor == null) return;
    fetchingMore = true;
    notifyListeners();
    try {
      final page = await fetchPage(q: state, cursor: nextCursor, limit: 20);
      items = [...items, ...page.items];
      nextCursor = page.nextCursor;
    } catch (e, st) {
      error = e;
      debugPrint('loadMore error: $e\n$st');
    } finally {
      fetchingMore = false;      // << ปิดโหลดเสมอ
      notifyListeners();
    }
  }

  // --- setters สำหรับ UI ---
  void updateQuery(String q) {
    state = state.copyWith(query: q);
    refresh();
  }

  void updateChips(Set<String> chips) {
    state = state.copyWith(chips: chips);
    refresh();
  }

  void updateDropdown(String id, String? value) {   // <-- รับ String? แทน
    final next = Map<String, String>.from(state.dropdowns);

    // ถ้าไม่มีค่า/เป็น default ก็ลบออกจาก map เพื่อไม่ส่งไป query
    if (value == null || value.isEmpty || value == 'all' || value == 'any') {
      next.remove(id);
    } else {
      next[id] = value;
    }

    state = state.copyWith(dropdowns: next);
    refresh();
  }

  void updateSort(String sort) {
    state = state.copyWith(sort: sort);
    refresh();
  }
}
