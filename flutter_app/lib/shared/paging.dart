// lib/shared/paging.dart
class PagedResult<T> {
  final List<T> items;
  final String? nextCursor;
  const PagedResult({required this.items, this.nextCursor});
}