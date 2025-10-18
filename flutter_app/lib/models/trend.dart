// lib/models/trend.dart

class TrendItem {
  final String title;
  final String? tag;
  final String? context;
  final int? postCount;
  final int rank;

  TrendItem({
    required this.title,
    required this.rank,
    this.tag,
    this.context,
    this.postCount,
  });

  factory TrendItem.fromJson(Map<String, dynamic> j) => TrendItem(
        title: j['title'] as String,
        tag: j['tag'] as String?,
        context: j['context'] as String?,
        postCount: j['postCount'] is int
            ? j['postCount'] as int
            : int.tryParse(j['postCount']?.toString() ?? ''),
        rank: (j['rank'] ?? 0) is int
            ? j['rank'] as int
            : int.tryParse(j['rank']?.toString() ?? '0') ?? 0,
      );
}

class TrendsResponse {
  final List<TrendItem> items;
  final String? nextCursor;
  TrendsResponse({required this.items, this.nextCursor});
}

