// lib/pages/event/manage_participants_page.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import 'request_page.dart';
import 'participants_page.dart';

class ManageParticipantsPage extends StatefulWidget {
  const ManageParticipantsPage({super.key});

  @override
  State<ManageParticipantsPage> createState() => _ManageParticipantsPageState();
}

class _ManageParticipantsPageState extends State<ManageParticipantsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = DatabaseService().getManagedEventsFiber();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Participants'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load: ${snap.error}'));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('You don\'t manage any events'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final m = items[i];
              final id = (m['eventId'] ?? m['id'] ?? '').toString();
              final topic = (m['topic'] ?? m['name'] ?? 'Untitled').toString();
              final pending = (m['pendingCount'] as num?)?.toInt() ?? 0;
              final accepted = (m['acceptedCount'] as num?)?.toInt() ?? 0;
              final cap = (m['max_participation'] as num?)?.toInt();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: event info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pending: $pending • Accepted: $accepted${cap == null ? '' : ' / $cap'}',
                              style: t.bodyMedium?.copyWith(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Right: vertical small buttons
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SmallButtonWithBadge(
                              label: 'Requests',
                              icon: Icons.inbox_outlined,
                              color: Colors.white,
                              textColor: Colors.black87,
                              borderColor: Colors.black26,
                              badgeCount: pending,
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
                              color: const Color(0xFF7FAA3B),
                              textColor: Colors.white,
                              borderColor: const Color(0xFF7FAA3B),
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
                ),
              );
            },
          );
        },
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
