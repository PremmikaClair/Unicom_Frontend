// lib/models/comment.dart
class Comment {
  final String id;
  final String postId;
  final String userId;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likeCount;
  final bool isLiked; // <- non-null, default false

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    required this.likeCount,
    this.isLiked = false,
  });

  static String _s(dynamic v) => v?.toString() ?? '';
  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
  static DateTime _t(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    final s = v.toString();
    return DateTime.tryParse(s) ?? DateTime.now();
  }
  static bool? _b(dynamic v) {
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is num) return v != 0;
    return null;
  }

  // เพิ่ม defaultIsLiked สำหรับ fallback จากระดับ response
  factory Comment.fromJson(Map<String, dynamic> j, {bool defaultIsLiked = false}) {
    final likedItem = _b(j['isLiked'] ?? j['liked']);
    return Comment(
      id: _s(j['id'] ?? j['_id']),
      postId: _s(j['postId'] ?? j['post_id']),
      userId: _s(j['userId'] ?? j['user_id']),
      text: _s(j['text']),
      createdAt: _t(j['createdAt'] ?? j['created_at']),
      updatedAt: _t(j['updatedAt'] ?? j['updated_at']),
      likeCount: _i(j['likeCount'] ?? j['like_count']),
      isLiked: likedItem ?? defaultIsLiked, // <- ใช้ fallback
    );
  }
}
