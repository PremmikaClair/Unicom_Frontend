// lib/pages/event/manage_participants_page.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../components/app_colors.dart';
import 'request_page.dart';
import 'participants_page.dart';

class ManageParticipantsPage extends StatefulWidget {
  final String? eventId;   // ถ้าส่งมา แสดงเฉพาะอีเวนต์นี้
  final String? eventTitle;
  const ManageParticipantsPage({super.key, this.eventId, this.eventTitle});

  @override
  State<ManageParticipantsPage> createState() => _ManageParticipantsPageState();
}

class _ManageParticipantsPageState extends State<ManageParticipantsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadManagedForMe();
  }

  Future<List<Map<String, dynamic>>> _loadManagedForMe() async {
    // If a specific eventId is passed, only show that event
    if (widget.eventId != null && widget.eventId!.trim().isNotEmpty) {
      return [
        {'id': widget.eventId!.trim(), 'topic': widget.eventTitle ?? 'Event'}
      ];
    }

    final db = DatabaseService();
    final me = await db.getMeFiber();

    String? _flatId(dynamic v) {
      if (v == null) return null;
      if (v is String) return v.trim();
      if (v is Map && v['\$oid'] != null) return v['\$oid'].toString();
      return v.toString();
    }
    final myId = _flatId(me['_id'] ?? me['id'] ?? me['oid']);

    bool _postedByMe(Map<String, dynamic> m) {
      if (myId == null || myId.isEmpty) return false;
      final keys = ['created_by','createdBy','ownerId','owner_id','user_id','userId','postedBy','posted_by'];
      for (final k in keys) {
        final v = m[k];
        final sid = _flatId(v is Map ? (v['_id'] ?? v['id']) : v);
        if (sid != null && sid.isNotEmpty && sid == myId) return true;
      }
      final ev = m['event'];
      if (ev is Map) {
        for (final k in keys) {
          final v = ev[k];
          final sid = _flatId(v is Map ? (v['_id'] ?? v['id']) : v);
          if (sid != null && sid.isNotEmpty && sid == myId) return true;
        }
      }
      return false;
    }

    String _eventIdOf(Map<String, dynamic> m) {
      final ev = m['event'];
      final id = _flatId(m['eventId'] ?? m['id'] ?? (ev is Map ? (ev['id'] ?? ev['_id']) : null));
      return id ?? '';
    }

    String _topicOf(Map<String, dynamic> m) {
      final ev = m['event'];
      final t = (m['topic'] ?? m['name'] ?? (ev is Map ? (ev['topic'] ?? ev['name']) : '')).toString();
      return t.trim().isEmpty ? 'Untitled' : t.trim();
    }

    final list = await db.getManagedEventsFiber();
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final e in list) {
      final m = Map<String, dynamic>.from(e);
      if (!_postedByMe(m)) continue;
      final id = _eventIdOf(m);
      if (id.isEmpty || !seen.add(id)) continue;
      out.add({'id': id, 'topic': _topicOf(m)});
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('Manage Participants'),
      ),
      backgroundColor: const Color(0xFFF7F8F3),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          // ถ้ามี eventId ส่งมา ให้แสดงเฉพาะอีเวนต์นั้น
          if (widget.eventId != null && widget.eventId!.trim().isNotEmpty) {
            final id = widget.eventId!.trim();
            final title = widget.eventTitle ?? 'Event';
            final single = [{ 'id': id, 'topic': title }];
            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _ManagedEventTile(id: id, topic: title, pendingHint: null, acceptedHint: null, capacityHint: null),
                ],
              ),
            );
          }

          final items = snap.data ?? const <Map<String, dynamic>>[];

          if (items.isEmpty) {
            return const Center(child: Text('You don\'t manage any events'));
          }
          return RefreshIndicator(
            onRefresh: () async { setState(() { _future = _loadManagedForMe(); }); await _future; },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: items.length,
              itemBuilder: (context, i) {
              final m = items[i];
              final id = (m['id'] ?? '').toString();
              final topic = (m['topic'] ?? 'Untitled').toString();
              final pendingHint = (m['pendingCount'] as num?)?.toInt();
              final acceptedHint = (m['acceptedCount'] as num?)?.toInt();
              final capHint = (m['max_participation'] as num?)?.toInt();
              return _ManagedEventTile(
                id: id,
                topic: topic.isEmpty ? 'Untitled' : topic,
                pendingHint: pendingHint,
                acceptedHint: acceptedHint,
                capacityHint: capHint,
              );
            },
            ),
          );
        },
      ),
    );
  }
}

class _ManagedEventTile extends StatefulWidget {
  final String id;
  final String topic;
  final int? pendingHint;
  final int? acceptedHint;
  final int? capacityHint;
  const _ManagedEventTile({
    required this.id,
    required this.topic,
    this.pendingHint,
    this.acceptedHint,
    this.capacityHint,
  });

  @override
  State<_ManagedEventTile> createState() => _ManagedEventTileState();
}

class _ManagedEventTileState extends State<_ManagedEventTile> {
  int? _pending;
  int? _accepted;
  int? _cap;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _pending = widget.pendingHint;
    _accepted = widget.acceptedHint;
    _cap = widget.capacityHint;
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseService();
    try {
      final p = await db.getEventParticipantsFiber(widget.id, status: 'stall');
      final a = await db.getEventParticipantsFiber(widget.id, status: 'accept');
      int? cap = _cap;
      if (cap == null) {
        try {
          final d = await db.getEventDetailFiber(widget.id);
          cap = int.tryParse('${d['max_participation'] ?? d['capacity'] ?? ''}');
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _pending = p.length;
        _accepted = a.length;
        _cap = cap;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final id = widget.id;
    final pending = _pending ?? 0;
    final accepted = _accepted ?? 0;
    final cap = _cap;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(blurRadius: 10, color: Color(0x11000000), offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.topic,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                _loading
                    ? const Text('Loading…', style: TextStyle(color: Colors.black45))
                    : Text(
                        'Pending: $pending • Accepted: $accepted${cap == null ? '' : ' / $cap'}',
                        style: t.bodyMedium?.copyWith(color: Colors.black54),
                      ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SmallButtonWithBadge(
                  label: 'Requests',
                  icon: Icons.inbox_outlined,
                  color: Colors.white,
                  textColor: Colors.black87,
                  borderColor: AppColors.sage,
                  badgeCount: _pending ?? 0,
                  onTap: id.isEmpty ? null : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RequestPage(eventId: id)),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _SmallButtonWithBadge(
                  label: 'Participants',
                  icon: Icons.people_outline,
                  color: AppColors.sage,
                  textColor: Colors.white,
                  borderColor: AppColors.sage,
                  onTap: id.isEmpty ? null : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RegisterEventPage(eventId: id)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButtonWithBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color borderColor;
  final int? badgeCount;
  final VoidCallback? onTap;

  const _SmallButtonWithBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.borderColor,
    this.badgeCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    final hasBadge = (badgeCount != null) && (badgeCount! > 0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: btn,
        ),
        if (hasBadge)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                badgeCount! > 99 ? '99+' : '${badgeCount!}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1.0),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
