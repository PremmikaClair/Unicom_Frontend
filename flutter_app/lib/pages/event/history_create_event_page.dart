// lib/pages/event/history_create_event_page.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class HistoryCreateEventPage extends StatefulWidget {
  const HistoryCreateEventPage({super.key});

  @override
  State<HistoryCreateEventPage> createState() => _HistoryCreateEventPageState();
}

class _HistoryItem {
  final String id;
  final String name;
  final DateTime? createdAt;
  final String? status;

  _HistoryItem({required this.id, required this.name, this.createdAt, this.status});
}

class _HistoryCreateEventPageState extends State<HistoryCreateEventPage> {
  late Future<List<_HistoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchHistory();
  }

  DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String _pickId(Map<String, dynamic> m) {
    for (final k in const ['eventId', 'event_id', 'id', '_id']) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String _pickName(Map<String, dynamic> m) {
    for (final k in const ['topic', 'title', 'name']) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString();
      if (s.isNotEmpty) return s;
    }
    return '(untitled)';
  }

  Future<List<_HistoryItem>> _fetchHistory() async {
    final db = DatabaseService();
    final list = await db.getManagedEventsFiber();
    if (list.isEmpty) return const <_HistoryItem>[];

    // Try to fill createdAt/status from managed list first, then fetch detail if needed
    final items = <_HistoryItem>[];
    for (final m in list) {
      final Map<String, dynamic> mm = Map<String, dynamic>.from(m);
      final id = _pickId(mm);
      final name = _pickName(mm);
      final created = _parseTime(mm['created_at'] ?? mm['createdAt'] ?? mm['createdAT']);
      final status = (mm['status'] ?? '').toString().trim().isEmpty ? null : mm['status'].toString();
      items.add(_HistoryItem(id: id, name: name, createdAt: created, status: status));
    }

    // For entries missing createdAt or status, fetch details
    final needDetail = items.where((e) => e.createdAt == null || e.status == null).toList();
    if (needDetail.isEmpty) return items;

    await Future.wait(needDetail.map((it) async {
      if (it.id.isEmpty) return;
      try {
        final d = await db.getEventDetailFiber(it.id);
        final created = _parseTime(d['created_at'] ?? d['createdAt'] ?? d['createdAT']);
        final status = d['status']?.toString();
        final idx = items.indexWhere((e) => e.id == it.id);
        if (idx >= 0) {
          items[idx] = _HistoryItem(
            id: items[idx].id,
            name: items[idx].name,
            createdAt: items[idx].createdAt ?? created,
            status: items[idx].status ?? status,
          );
        }
      } catch (_) {}
    }));

    return items;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติอีเวนต์ที่สร้าง'),
      ),
      body: FutureBuilder<List<_HistoryItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final items = snap.data ?? const <_HistoryItem>[];
          if (items.isEmpty) {
            return const Center(child: Text('No created events'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = items[i];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(
                    e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Created: ${_formatDate(e.createdAt)}\nStatus: ${e.status ?? '-'}',
                    style: t.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
