// lib/pages/event/manage_participants_page.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/event.dart';
import 'participants_page.dart';

class ManageParticipantsPage extends StatefulWidget {
  final String? eventId;   // ถ้าส่งมา แสดงเฉพาะอีเวนต์นี้
  final String? eventTitle;
  const ManageParticipantsPage({super.key, this.eventId, this.eventTitle});

  @override
  State<ManageParticipantsPage> createState() => _ManageParticipantsPageState();
}

class _ManageParticipantsPageState extends State<ManageParticipantsPage> {
  late Future<List<AppEvent>> _future;

  @override
  void initState() {
    super.initState();
    // ดึงรายการอีเวนต์จาก GET /event (ฝั่ง DatabaseService จะกรองเฉพาะ active อยู่แล้ว)
    _future = DatabaseService().getEventsFiberList();
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
      body: FutureBuilder<List<AppEvent>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final items = snap.data ?? const <AppEvent>[];
          if (items.isEmpty) {
            return const Center(child: Text('No events found'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = items[i];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: ListTile(
                  title: Text(
                    e.title ?? 'Untitled',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: const Text('Participants'),
                    onPressed: (e.id == null || e.id!.isEmpty)
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegisterEventPage(eventId: e.id!),
                              ),
                            );
                          },
                  ),
                ),
              );
            },
            ),
          );
        },
      ),
    );
  }
}
