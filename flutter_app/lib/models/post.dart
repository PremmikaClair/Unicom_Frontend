// lib/models/post.dart
class Post {
  final String id;                   // "_id"
  final String userId;               // "user_id"
  final String profilePic;           // "profile pic" or "profile_pic"
  final String username;             // "username"
  final String category;             // first category if array, or string
  final String message;              // "message"
  final int likeCount;               // parse from int or string
  final int comment;                 // default 0 if missing
  final List<String> authorRoles;    // from "author_roles" or "Roles"
  final List<String> visibilityRoles;// from "visibility_roles" (string/array)
  final DateTime timeStamp;          // from "time_stamp" or "Date"

  // ✅ NEW: optional media
  final String? picture;             // "picture" | "image" | "photo" | first of "images"
  final String? video;               // "video" | "video_url" | "media_video"

  const Post({
    required this.id,
    required this.userId,
    required this.profilePic,
    required this.username,
    required this.category,
    required this.message,
    required this.likeCount,
    required this.comment,
    required this.authorRoles,
    required this.visibilityRoles,
    required this.timeStamp,
    this.picture,
    this.video,
  });

  static String _readId(dynamic v) {
    if (v is String) return v;
    if (v is Map && v[r'$oid'] != null) return v[r'$oid'].toString();
    return v?.toString() ?? '';
  }

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static DateTime _readDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is Map && v[r'$date'] != null) {
      final d = v[r'$date'];
      if (d is String) return DateTime.tryParse(d)?.toLocal() ?? DateTime.now();
      if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
    }
    return DateTime.now();
  }

  static List<String> _toStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v == null) return const [];
    return [v.toString()];
  }

  static String _firstCategory(dynamic v) {
    if (v is List && v.isNotEmpty) return v.first.toString();
    if (v is String) return v;
    return '';
  }

  static String? _readMedia(dynamic j, List<String> keys) {
    for (final k in keys) {
      final v = (j as Map<String, dynamic>)[k];
      if (v == null) continue;
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is List && v.isNotEmpty) return v.first.toString();
    }
    return null;
  }

  factory Post.fromJson(Map<String, dynamic> j) {
    final authorRolesRaw = j['author_roles'] ?? j['Roles'];
    final visibilityRaw  = j['visibility_roles'];
    final profile        = j['profile_pic'] ?? j['profile pic'];
    final dateRaw        = j['time_stamp'] ?? j['Date'];

    // ✅ NEW: read media from multiple possible keys
    final picture = _readMedia(j, ['picture', 'image', 'photo', 'images']);
    final video   = _readMedia(j, ['video', 'video_url', 'media_video']);

    return Post(
      id: _readId(j['_id']),
      userId: (j['user_id'] ?? '').toString(),
      profilePic: (profile ?? '').toString(),
      username: (j['username'] ?? '').toString(),
      category: _firstCategory(j['category']),
      message: (j['message'] ?? '').toString(),
      likeCount: _toInt(j['like_count']),
      comment: _toInt(j['comment']),
      authorRoles: _toStringList(authorRolesRaw),
      visibilityRoles: _toStringList(visibilityRaw),
      timeStamp: _readDate(dateRaw),
      picture: picture,
      video: video,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'user_id': userId,
        'profile_pic': profilePic,
        'username': username,
        'category': category,
        'message': message,
        'like_count': likeCount,
        'comment': comment,
        'author_roles': authorRoles,
        'visibility_roles': visibilityRoles,
        'time_stamp': timeStamp.toIso8601String(),
        if (picture != null) 'picture': picture,
        if (video != null) 'video': video,
      };
}
