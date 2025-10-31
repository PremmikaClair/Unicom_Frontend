import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// โปรเจกต์ของคุณ
import '../../services/auth_service.dart';             // AuthService.I.apiBase, .headers()
import '../../services/database_service.dart';         // DatabaseService()
import '../../models/event.dart';                      // AppEvent
import '../event/event_details_page.dart';              // EventDetailPage.fromListItem

// ===== Theme =====
const _header = Color(0xFF7E9766);
const _bg = Color(0xFFF2F3EF);
const _cardBg = Colors.white;
const _textPrimary = Colors.black87;
const _textSecondary = Colors.black;

// ===== Model (ตาม backend) =====
class _NotiItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool read;           // จากลิสต์ฝั่ง backend: อาจเป็น false ทั้งหมดเพราะเป็น "unread"
  final String? refEntity;   // "event" | "qa" | ...
  final String? refId;       // eventId หรือ answerId (hex string)

  const _NotiItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.refEntity,
    this.refId,
  });

  static String? _asOid(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map && v[r'$oid'] != null) return v[r'$oid'].toString();
    return v.toString();
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.tryParse(v.toString());
  }

  factory _NotiItem.fromJson(Map<String, dynamic> j) {
    final ref = j['ref'] as Map<String, dynamic>?;
    return _NotiItem(
      id: _asOid(j['id'] ?? j['_id']) ?? '',
      type: (j['type'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      createdAt: _asDate(j['createdAt']),
      read: (j['read']?.toString() == 'true'),
      refEntity: ref?['entity']?.toString(),
      refId: _asOid(ref?['id']),
    );
  }
}

// ===== API Service (ตาม routes ที่ให้มา) =====
class _NotiApi {
  final http.Client _client;
  _NotiApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _basePath = '/notifications';

  Uri _buildUri(String path, [Map<String, String?> qp = const {}]) {
    final base = AuthService.I.apiBase.endsWith('/')
        ? AuthService.I.apiBase.substring(0, AuthService.I.apiBase.length - 1)
        : AuthService.I.apiBase;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p').replace(queryParameters: {
      for (final e in qp.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    });
  }

  Map<String, String> _headers([Map<String, String>? extra]) =>
      AuthService.I.headers(extra: {
        'Accept': 'application/json',
        if (extra != null) ...extra,
      });

  /// GET /notifications/ → คืนรายการ unread ทั้งหมด (ไม่มี paging)
  Future<List<_NotiItem>> listUnread() async {
    final uri = _buildUri('$_basePath/');
    final res = await _client.get(uri, headers: _headers()).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('GET $uri -> ${res.statusCode}: ${res.body}');
    }
    final body = res.body.trim();
    if (body.isEmpty) return const <_NotiItem>[];
    final parsed = jsonDecode(body);
    if (parsed is List) {
      return parsed.whereType<Map<String, dynamic>>().map(_NotiItem.fromJson).toList();
    } else if (parsed is Map<String, dynamic>) {
      final list = (parsed['items'] ?? parsed['data'] ?? parsed['rows'] ?? const []) as List<dynamic>;
      return list.whereType<Map<String, dynamic>>().map(_NotiItem.fromJson).toList();
    }
    return const <_NotiItem>[];
  }

  /// GET /notifications/:id → ได้ noti เดี่ยวและ mark read ในตัว
  Future<_NotiItem?> getAndMarkRead(String id) async {
    final uri = _buildUri('$_basePath/$id');
    final res = await _client.get(uri, headers: _headers()).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      // บางกรณี backend อาจคืน 404 ถ้าอ่านไปแล้ว หรือไม่พบ
      return null;
    }
    final parsed = jsonDecode(res.body);
    if (parsed is Map<String, dynamic>) {
      return _NotiItem.fromJson(parsed);
    }
    return null;
  }
}

// ===== Page =====
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _api = _NotiApi();
  final _items = <_NotiItem>[];
  bool _loading = true;
  String? _error;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
    });
    try {
      final list = await _api.listUnread();
      setState(() {
        _items.addAll(list);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'โหลดข้อมูลไม่สำเร็จ';
      });
    }
  }

  String _timeAgo(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'เมื่อสักครู่';
    if (d.inMinutes < 60) return '${d.inMinutes} นาทีที่แล้ว';
    if (d.inHours < 24) return '${d.inHours} ชม.ที่แล้ว';
    return '${d.inDays} วันที่แล้ว';
  }

  Future<void> _openByRef(_NotiItem n) async {
    // 1) กดแล้ว → เรียก GET /notifications/:id เพื่อ mark read (ตาม backend)
    await _api.getAndMarkRead(n.id);

    // 2) อัปเดต UI (ลบออกจากลิสต์ เพราะหน้า list เป็น "unread only")
    setState(() {
      _items.removeWhere((e) => e.id == n.id);
    });

    // 3) นำทางไปเป้าหมาย (เฉพาะ event ตอนนี้)
    final refEntity = n.refEntity?.toLowerCase();
    final refId = n.refId ?? '';
    if (refEntity == 'event' && refId.isNotEmpty) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _EventDetailLoaderPage(eventId: refId),
      ));
    } else {
      // ถ้าเป็นประเภทอื่นยังไม่ได้รองรับ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิดเนื้อหานี้ไม่ได้ (ยังไม่รองรับประเภทนี้)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _header,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Event Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        itemBuilder: (_, __) => const _SkeletonCard(),
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.wifi_off, size: 48, color: _textSecondary),
          const SizedBox(height: 12),
          Center(child: Text(_error!, style: const TextStyle(color: _textSecondary))),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 40),
          Icon(Icons.notifications_none_rounded, size: 48, color: _textSecondary),
          SizedBox(height: 12),
          Center(child: Text('ยังไม่มีการแจ้งเตือนใหม่', style: TextStyle(color: _textSecondary))),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final n = _items[index];
        return _NotificationCard(
          title: n.title.isEmpty ? '(untitled)' : n.title,
          message: n.body,
          timeAgo: _timeAgo(n.createdAt),
          read: n.read,
          onTap: () => _openByRef(n),
        );
      },
    );
  }
}

// ===== Card with soft shadow =====
class _NotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final String? timeAgo;
  final bool read;
  final VoidCallback? onTap;
  const _NotificationCard({
    required this.title,
    required this.message,
    required this.read,
    this.timeAgo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: _textPrimary,
      fontSize: 16,
      fontWeight: read ? FontWeight.w600 : FontWeight.w800,
    );
    const msgStyle = TextStyle(
      color: _textSecondary,
      fontSize: 14,
      height: 1.25,
    );
    const timeStyle = TextStyle(
      color: _textSecondary,
      fontSize: 12,
    );

    return Material(
      color: _cardBg,
      elevation: 6,
      shadowColor: Colors.black12,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // วงกลมไอคอน
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: read ? _header.withOpacity(.6) : _header,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              // ข้อความ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                    const SizedBox(height: 4),
                    Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: msgStyle),
                    if (timeAgo != null && timeAgo!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(timeAgo!, style: timeStyle),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Skeleton while loading =====
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFEDEDED),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: const [
                _ShimmerBar(widthFactor: 0.7, height: 16),
                SizedBox(height: 8),
                _ShimmerBar(widthFactor: 1.0, height: 14),
                SizedBox(height: 6),
                _ShimmerBar(widthFactor: 0.9, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final double widthFactor;
  final double height;
  const _ShimmerBar({required this.widthFactor, required this.height});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// ===== Loader: ดึง /event/:id -> map เป็น AppEvent + dayDetails แล้วเปิด EventDetailPage =====
class _EventDetailLoaderPage extends StatelessWidget {
  final String eventId;
  const _EventDetailLoaderPage({super.key, required this.eventId});

  DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.tryParse(v.toString());
  }

  String? _str(dynamic v) => v == null ? null : v.toString();

  bool _looksImage(String url) =>
      RegExp(r'\.(png|jpe?g|gif|webp|bmp|svg)(\?.*)?$', caseSensitive: false).hasMatch(url);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseService().getEventDetailFiber(eventId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || snap.data == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: _bg, elevation: 0),
            body: const Center(child: Text('Event not found')),
          );
        }

        final d = snap.data!;
        final ev = (d['event'] is Map<String, dynamic>) ? d['event'] as Map<String, dynamic> : d;
        final schedules = (d['schedules'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

        DateTime start =
            _parseTime(ev['time_start']) ??
            _parseTime(ev['start']) ??
            (schedules.isNotEmpty ? (_parseTime(schedules.first['time_start']) ?? _parseTime(schedules.first['start'])) : null) ??
            DateTime.now();

        final DateTime? end =
            _parseTime(ev['time_end']) ??
            _parseTime(ev['end']) ??
            (schedules.isNotEmpty ? (_parseTime(schedules.first['time_end']) ?? _parseTime(schedules.first['end'])) : null);

        String? location =
            _str(ev['location']) ??
            (schedules.isNotEmpty ? _str(schedules.first['location']) : null);

        String? imageUrl;
        final cand = ev['imageUrl'] ?? ev['image_url'] ?? ev['image'] ?? ev['cover'] ?? ev['banner'] ?? ev['poster'];
        if (cand != null && cand.toString().trim().isNotEmpty) {
          imageUrl = cand.toString().trim();
        } else {
          final media = ev['media'];
          if (media is List && media.isNotEmpty) {
            for (final m in media) {
              if (m == null) continue;
              final s = m.toString().trim();
              if (s.isEmpty) continue;
              if (_looksImage(s)) { imageUrl = s; break; }
            }
          }
        }

        int? capacity;
        final cp = d['max_participation'] ?? ev['max_participation'];
        if (cp is int) capacity = cp; else if (cp != null) capacity = int.tryParse('$cp');

        final appEvent = AppEvent(
          id: _str(ev['id']) ?? _str(ev['_id']) ?? eventId,
          title: _str(ev['topic']) ?? _str(ev['title']) ?? '(untitled)',
          description: _str(ev['description']),
          category: _str(ev['category']),
          role: _str((ev['posted_as'] as Map?)?['label']) ??
                _str((ev['posted_as'] as Map?)?['position_key']),
          location: location,
          startTime: start,
          endTime: end,
          imageUrl: imageUrl,
          organizer: _str(ev['org_of_content']) ?? _str(ev['organizer']),
          isFree: (ev['is_free'] == true) ? true : null,
          likeCount: (ev['likeCount'] is int) ? ev['likeCount'] as int? : null,
          capacity: capacity,
          haveForm: ev['have_form'] == true,
        );

        final dayDetails = <EventDayDetail>[];
        for (final s in schedules) {
          final st = _parseTime(s['time_start']) ?? _parseTime(s['start']) ?? start;
          final en = _parseTime(s['time_end'])   ?? _parseTime(s['end'])   ?? (st.add(const Duration(hours: 1)));
          final dd = _parseTime(s['date']) ?? st;
          dayDetails.add(EventDayDetail(
            date: DateTime(dd!.year, dd.month, dd.day),
            startTime: st,
            endTime: en,
            title: _str(s['title']),
            location: _str(s['location']) ?? location,
            description: _str(s['description']) ?? _str(ev['description']),
            notes: _str(s['notes']),
            mapUrl: _str(s['mapUrl']),
            isFree: (s['isFree'] == true) ? true : appEvent.isFree,
          ));
        }
        if (dayDetails.isEmpty) {
          dayDetails.add(EventDayDetail(
            date: DateTime(start.year, start.month, start.day),
            startTime: start,
            endTime: end ?? start.add(const Duration(hours: 1)),
            title: null,
            location: location,
            description: appEvent.description,
            notes: null,
            mapUrl: null,
            isFree: appEvent.isFree,
          ));
        }

        return EventDetailPage.fromListItem(
          event: appEvent,
          dayDetails: dayDetails,
          overrideMode: (appEvent.haveForm == true)
              ? EventRegMode.requestToJoin
              : EventRegMode.registerNow,
        );
      },
    );
  }
}
