// lib/controllers/like_controller.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/database_service.dart';

import 'package:flutter_app/services/database_service.dart';
import 'package:flutter_app/models/comment.dart';

/// Controller สำหรับจัดการสถานะ/การกระทำที่เกี่ยวกับ 'ไลก์' ในฟีด
/// - เก็บ state: likedIds, likeCounts, commentCounts, cooldowns
/// - มี method: seedFromPosts, ensureLikeState, toggleLike, applyFromDetail
class FeedLikeController {
  final DatabaseService _db;
  final void Function(void Function()) _setState; // ใช้ setState ของหน้า host
  final void Function(String) _showSnack;

  FeedLikeController({
    required DatabaseService db,
    required void Function(void Function()) setState,
    required void Function(String) showSnack,
  })  : _db = db,
        _setState = setState,
        _showSnack = showSnack;

  // ---------- State ----------
  final Set<String> _likedIds = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _commentCounts = {};

  final Set<String> _liking = {};              // ป้องกันการยิงซ้ำ
  final Set<String> _checkedLikeIds = {};      // ป้องกัน ensure ซ้ำต่อเฟรม
  final Map<String, int> _rev = {};            // เวอร์ชันต่อโพสต์
  final Map<String, DateTime> _lastEnsuredAt = {};
  final Map<String, DateTime> _lastMutatedAt = {}; // เวลาที่ผู้ใช้เพิ่งกดไลก์/อันไลก์

  // ---------- Read helpers ----------
  bool isLiked(Post p) => _likedIds.contains(p.id);
  int likeCountOf(Post p) => _likeCounts[p.id] ?? p.likeCount;
  int commentCountOf(Post p) => _commentCounts[p.id] ?? p.comment;

  // ใช้ตอนโหลด page แรก/โหลดเพิ่ม เพื่อ seed ค่าตั้งต้น
  void seedFromPosts(List<Post> posts) {
    if (posts.isEmpty) return;
    _setState(() {
      for (final p in posts) {
        _likeCounts[p.id] = p.likeCount;
        _commentCounts[p.id] = p.comment;
        if (p.isLiked) _likedIds.add(p.id);
        // ปล่อยให้ ensure ทำงานได้อีก
        _checkedLikeIds.remove(p.id);
      }
    });
  }

  bool _isVideoPost(Post p) =>
      (p.video != null && p.video!.trim().isNotEmpty) ||
      (p.videos.isNotEmpty);

  // ---------- Lazy sync (ดึงสถานะจริงแบบหน่วง) ----------
  Future<void> ensureLikeState(Post p) async {
    if (_liking.contains(p.id)) return;
    if (_checkedLikeIds.contains(p.id)) return;

    final now = DateTime.now();

    // cooldown ต่อโพสต์ (ลดการยิงซ้ำรัว ๆ)
    final last = _lastEnsuredAt[p.id];
    if (last != null && now.difference(last).inMilliseconds < 600) return;
    _lastEnsuredAt[p.id] = now;

    // กันทับผลทันทีหลังผู้ใช้เพิ่งกด (stale override)
    final lastMut = _lastMutatedAt[p.id];
    final mutateCooldownMs = _isVideoPost(p) ? 1800 : 1000;
    if (lastMut != null && now.difference(lastMut).inMilliseconds < mutateCooldownMs) {
      return;
    }

    _checkedLikeIds.add(p.id);

    try {
      final fresh = await _db.getPostByIdFiber(p.id);

      final prevLikes = _likeCounts[p.id] ?? p.likeCount;
      final safeLikes = (fresh.likeCount < 0) ? prevLikes : fresh.likeCount;

      final prevComments = _commentCounts[p.id] ?? p.comment;
      final safeComments = (fresh.comment < 0) ? prevComments : fresh.comment;

      if (_isVideoPost(p)) {
        final looksLikeBadZero = (prevLikes >= 1 && safeLikes == 0);
        final looksLikeStaleOneWhenShouldBeTwo =
            (_likedIds.contains(p.id) && prevLikes >= 2 && safeLikes == 1);
        if (looksLikeBadZero || looksLikeStaleOneWhenShouldBeTwo) {
          return; // อย่า override UI ในเคสเสี่ยง
        }
      }

      _setState(() {
        if (fresh.isLiked) {
          _likedIds.add(p.id);
        } else {
          _likedIds.remove(p.id);
        }
        _likeCounts[p.id] = safeLikes;
        _commentCounts[p.id] = safeComments;
      });
    } catch (_) {
      _checkedLikeIds.remove(p.id); // ล้มเหลว ให้ลองใหม่รอบหน้าได้
    }
  }

  // ---------- Toggle like (optimistic) ----------
  Future<void> toggleLike(Post p) async {
    if (_liking.contains(p.id)) return;
    _liking.add(p.id);

    final curRev = (_rev[p.id] ?? 0) + 1;
    _rev[p.id] = curRev;

    final wasLiked = _likedIds.contains(p.id);

    // ใช้เฉพาะค่าปัจจุบันใน controller; ถ้ายังไม่เคย seed ให้ตกไปใช้ p.likeCount ครั้งแรกเท่านั้น
    final prevCount = _likeCounts[p.id] ?? p.likeCount;


    // Optimistic & จำเวลา mutate
    _setState(() {
      if (wasLiked) {
        _likedIds.remove(p.id);
        _likeCounts[p.id] = math.max(0, prevCount - 1);
      } else {
        _likedIds.add(p.id);
        _likeCounts[p.id] = prevCount + 1;
      }
      _lastMutatedAt[p.id] = DateTime.now();
    });

    try {
      final r = await _db.toggleLike(targetId: p.id, targetType: 'post');
      final reconciled = wasLiked ? math.max(0, prevCount - 1) : prevCount + 1;

      if ((_rev[p.id] ?? 0) == curRev) {
        _setState(() {
          if (r.liked) {
            _likedIds.add(p.id);
          } else {
            _likedIds.remove(p.id);
          }
          _likeCounts[p.id] = reconciled;
          _lastMutatedAt[p.id] = DateTime.now();
        });

        // ปล่อยให้ ensure ทับได้หลังจากนี้ (กัน flicker)
        Future.delayed(const Duration(milliseconds: 1200), () {
          _checkedLikeIds.remove(p.id);
        });
      }
    } catch (_) {
      if ((_rev[p.id] ?? 0) == curRev) {
        _setState(() {
          if (wasLiked) {
            _likedIds.add(p.id);
            _likeCounts[p.id] = prevCount;
          } else {
            _likedIds.remove(p.id);
            _likeCounts[p.id] = prevCount;
          }
          _lastMutatedAt[p.id] = DateTime.now();
        });
        _showSnack('Failed to update like');
      }
    } finally {
      _liking.remove(p.id);
    }
  }

  /// ใช้ตอนกลับมาจากหน้า detail เพื่อ sync ค่าที่ผู้ใช้ทำไว้ในหน้านั้น
  void applyFromDetail({
    required String postId,
    bool? liked,
    int? likeCount,
    int? commentCount,
  }) {
    _setState(() {
      if (liked != null) {
        if (liked) _likedIds.add(postId); else _likedIds.remove(postId);
      }
      if (likeCount != null) _likeCounts[postId] = likeCount;
      if (commentCount != null) _commentCounts[postId] = commentCount;
      _checkedLikeIds.remove(postId);
    });
  }
}

class CommentLikeController {
  final DatabaseService db;
  final void Function(void Function()) setState;
  final void Function(String) showSnack;

  final Map<String, bool> _liked = {};
  final Map<String, int> _count = {};
  final Set<String> _inflight = {};

  CommentLikeController({
    required this.db,
    required this.setState,
    required this.showSnack,
  });

  // Seed จากรายการคอมเมนต์ที่เพิ่งโหลด
  void seedFromComments(List<Comment> list) {
    for (final c in list) {
      if (c.id.isEmpty) continue;
      _liked[c.id] = c.isLiked;
      _count[c.id] = c.likeCount;
    }
  }

  bool isLikedById(String? id) => (id != null) && (_liked[id] ?? false);
  int likeCountOfId(String? id) => id == null ? 0 : (_count[id] ?? 0);

  Future<void> toggle(String id) async {
    if (_inflight.contains(id)) return;
    _inflight.add(id);

    final prevLiked = _liked[id] ?? false;
    final prevCount = _count[id] ?? 0;

    // optimistic
    setState(() {
      final nowLiked = !prevLiked;
      _liked[id] = nowLiked;
      _count[id] = (nowLiked ? prevCount + 1 : prevCount - 1);
      if (_count[id]! < 0) _count[id] = 0;
    });

    try {
      final r = await db.toggleLike(targetId: id, targetType: 'comment');

      // reconcile
      setState(() {
        _liked[id] = r.liked;
        _count[id] = r.likeCount < 0 ? 0 : r.likeCount;
      });
    } catch (_) {
      // rollback
      setState(() {
        _liked[id] = prevLiked;
        _count[id] = prevCount;
      });
      showSnack('กดไลค์คอมเมนต์ไม่สำเร็จ');
    } finally {
      _inflight.remove(id);
    }
  }
}