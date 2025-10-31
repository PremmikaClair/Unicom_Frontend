// lib/models/post.dart
class Post {
  final String id;                   // "_id"
  final String userId;               // "user_id" | "uid"
  final String profilePic;           // "profile_pic" | "profile pic"
  final String username;             // "username" | "name" | "uid"
  final String category;             // first category if array, or string
  final String message;              // "message" | "post_text" | "postText"
  final int likeCount;               // robust mapping
  final int comment;                 // robust mapping
  final bool isLiked;                // "is_liked" | "liked"
  final List<String> authorRoles;    // "author_roles" | "Roles" | posted_as label
  final List<String> visibilityRoles;// "visibility_roles"
  final DateTime timeStamp;          // "created_at" | "timestamp" | "time_stamp" | "Date"

  // Optional media
  final String? picture;
  final String? video;
  final List<String> images;
  final List<String> videos;

  const Post({
    required this.id,
    required this.userId,
    required this.profilePic,
    required this.username,
    required this.category,
    required this.message,
    required this.likeCount,
    required this.comment,
    this.isLiked = false,
    required this.authorRoles,
    required this.visibilityRoles,
    required this.timeStamp,
    this.picture,
    this.video,
    this.images = const [],
    this.videos = const [],
  });

  // ---------- helpers ----------
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

  static int _toCount(dynamic v, [int fb = 0]) {
    if (v is List) return v.length;
    return _toInt(v, fb);
  }

  static DateTime _readDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
    if (v is int) {
      final n = v;
      if (n > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(n ~/ 1000); // micros -> ms
      if (n > 10000000000)   return DateTime.fromMillisecondsSinceEpoch(n);        // ms
      if (n < 10000000000)   return DateTime.fromMillisecondsSinceEpoch(n * 1000); // sec -> ms
      return DateTime.fromMillisecondsSinceEpoch(n);
    }
    if (v is Map && v[r'$date'] != null) {
      final d = v[r'$date'];
      if (d is String) return DateTime.tryParse(d)?.toLocal() ?? DateTime.now();
      if (d is int) {
        final n = d;
        if (n > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(n ~/ 1000);
        if (n > 10000000000)   return DateTime.fromMillisecondsSinceEpoch(n);
        if (n < 10000000000)   return DateTime.fromMillisecondsSinceEpoch(n * 1000);
        return DateTime.fromMillisecondsSinceEpoch(n);
      }
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

  static String? _readMediaFirst(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      final v = j[k];
      if (v == null) continue;
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is List && v.isNotEmpty) return v.first.toString();
    }
    return null;
  }

  static bool _looksImage(String url) =>
      RegExp(r"\.(png|jpe?g|gif|webp|bmp|svg)(\?.*)?$", caseSensitive: false).hasMatch(url);
  static bool _looksVideo(String url) =>
      RegExp(r"\.(mp4|mov|webm|mkv|avi|m3u8|m4v)(\?.*)?$", caseSensitive: false).hasMatch(url);

  factory Post.fromJson(Map<String, dynamic> j) {
    // Try to resolve nested author/user objects where present
    Map<String, dynamic>? _asMap(dynamic v) =>
        (v is Map<String, dynamic>) ? v : (v is Map ? Map<String, dynamic>.from(v) : null);

    final userObj = _asMap(j['user']) ?? _asMap(j['author']) ?? _asMap(j['posted_by']) ?? _asMap(j['owner']);
    final authorRolesRaw = j['author_roles'] ?? j['Roles'];
    final visibilityRaw  = j['visibility_roles'];
    final profile        = j['profile_pic'] ?? j['profile pic'];
    final dateRaw        = j['createdAt'] ?? j['created_at'] ?? j['createdAT'] ??
                           j['timestamp'] ?? j['time_stamp'] ??
                           j['Date'] ?? j['date'];

    // posted_as -> display label if possible
    String? _postedAsLabel() {
      final pa = j['posted_as'] ?? j['postAs'];
      if (pa is Map<String, dynamic>) {
        final lbl = (pa['label'] ?? pa['tag'])?.toString();
        if (lbl != null && lbl.trim().isNotEmpty) return lbl.trim();
        final pk = pa['position_key']?.toString();
        final op = pa['org_path']?.toString();
        if ((pk != null && pk.isNotEmpty) || (op != null && op.isNotEmpty)) {
          if (pk != null && pk.isNotEmpty && op != null && op.isNotEmpty) {
            return '$pk • $op';
          }
          return (pk ?? op)!;
        }
      }
      final tag = j['tag'];
      if (tag is String && tag.trim().isNotEmpty) return tag.trim();
      final tags = j['tags'];
      if (tags is List && tags.isNotEmpty) return tags.first.toString();
      return null;
    }
    final postedAs = _postedAsLabel();

    // media gather
    final pictureSingle = _readMediaFirst(j, ['picture', 'image', 'photo']);
    final videoSingle   = _readMediaFirst(j, ['video', 'video_url', 'media_video']);

    final imgs = <String>[];
    final vids = <String>[];
    final media = j['media'];
    if (media is List) {
      for (final m in media) {
        final s = m?.toString().trim() ?? '';
        if (s.isEmpty) continue;
        if (_looksImage(s)) imgs.add(s);
        else if (_looksVideo(s)) vids.add(s);
      }
    }
    if (imgs.isEmpty && pictureSingle != null) imgs.add(pictureSingle);
    if (vids.isEmpty && videoSingle != null) vids.add(videoSingle);

    final likeCount = _toCount(
      j['likeCount'] ?? j['like_count'] ?? j['likes_count'] ?? j['likes'] ?? j['totalLikes'] ?? j['total_likes'],
      0,
    );
    final commentCount = _toCount(
      j['commentCount'] ?? j['comment_count'] ?? j['comments_count'] ?? j['comments'] ?? j['comment'],
      0,
    );

    // Resolve user id robustly
    String _resolveUserId() {
      final direct = _readId(j['user_id'] ?? j['userId'] ?? j['author_id'] ?? j['authorId'] ?? j['uid']);
      if (direct.isNotEmpty) return direct;
      if (userObj != null) {
        final fromUser = _readId(userObj['_id'] ?? userObj['id'] ?? userObj['uid'] ?? userObj['user_id']);
        if (fromUser.isNotEmpty) return fromUser;
      }
      // Only trust top-level 'user' when it's an ObjectId-like string or a map
      final userField = j['user'];
      if (userField is Map) {
        final fromMap = _readId(userField['_id'] ?? userField['id'] ?? userField['uid'] ?? userField['user_id']);
        if (fromMap.isNotEmpty) return fromMap;
      } else if (userField is String) {
        final s = userField.trim();
        final hex24 = RegExp(r'^[a-fA-F0-9]{24}$');
        if (hex24.hasMatch(s)) return s; // looks like ObjectId
      }
      return '';
    }

    // Resolve username robustly
    String _resolveUsername() {
      final direct = (j['username'] ?? j['userName'] ?? j['name'])?.toString();
      if (direct != null && direct.trim().isNotEmpty) return direct.trim();
      if (userObj != null) {
        final u = (userObj['username'] ?? userObj['userName'] ?? userObj['name'])?.toString();
        if (u != null && u.trim().isNotEmpty) return u.trim();
        final email = (userObj['email'] ?? '').toString();
        if (email.contains('@')) return email.split('@').first;
      }
      final email = (j['email'] ?? '').toString();
      if (email.contains('@')) return email.split('@').first;
      return '';
    }

    return Post(
      id: _readId(j['_id'] ?? j['id']),
      userId: _resolveUserId(),
      profilePic: (profile ?? '').toString(),
      username: _resolveUsername(),
      category: _firstCategory(j['category']),
      // Prefer sanitized text from API (postText/post_text) over raw message
      message: (j['postText'] ?? j['post_text'] ?? j['message'] ?? '').toString(),
      likeCount: likeCount,
      comment: commentCount,
      isLiked: ((j['is_liked'] ?? j['liked'])?.toString() == 'true'),
      authorRoles: postedAs != null
          ? <String>[postedAs]
          : (_toStringList(authorRolesRaw).isNotEmpty
              ? _toStringList(authorRolesRaw)
              : _toStringList(j['tag'] ?? j['tags'])),
      visibilityRoles: _toStringList(visibilityRaw),
      timeStamp: _readDate(dateRaw),
      picture: imgs.isNotEmpty ? imgs.first : null,
      video: vids.isNotEmpty ? vids.first : null,
      images: imgs,
      videos: vids,
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
        'comment_count': comment,
        'author_roles': authorRoles,
        'visibility_roles': visibilityRoles,
        'time_stamp': timeStamp.toIso8601String(),
        if (picture != null) 'picture': picture,
        if (video != null) 'video': video,
      };
}
