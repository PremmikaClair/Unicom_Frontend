import 'package:flutter/material.dart';
import '../models/event.dart';

class EventCard extends StatelessWidget {
  final AppEvent event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  String _fmtDateRange(DateTime start, DateTime? end) {
    // Lightweight display; customize with intl if you want locales.
    final s = '${start.year}/${_2(start.month)}/${_2(start.day)} ${_2(start.hour)}:${_2(start.minute)}';
    if (end == null) return s;
    final e = '${_2(end.month)}/${_2(end.day)} ${_2(end.hour)}:${_2(end.minute)}';
    return '$s → $e';
  }

  String _2(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    if (event.category != null && event.category!.isNotEmpty) {
      chips.add(Chip(label: Text(event.category!), visualDensity: VisualDensity.compact));
    }
    if (event.role != null && event.role!.isNotEmpty) {
      chips.add(Chip(label: Text(event.role!), visualDensity: VisualDensity.compact));
    }
    if (event.isFree == true) {
      chips.add(const Chip(label: Text('Free'), visualDensity: VisualDensity.compact));
    }

    String initials(String s) {
      final parts = s.trim().split(RegExp(r"\s+"));
      final a = parts.isNotEmpty ? parts.first : '';
      final b = parts.length > 1 ? parts[1] : '';
      final ini = ((a.isNotEmpty ? a[0] : '') + (b.isNotEmpty ? b[0] : '')).toUpperCase();
      return ini.isEmpty ? 'E' : ini;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Optional thumbnail
              if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    event.imageUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 64, height: 64),
                  ),
                )
              else
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.primary.withOpacity(.10),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(.25)),
                  ),
                  child: Center(
                    child: Text(
                      initials(event.title),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              // Textual content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    if ((event.organizer ?? '').isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              event.organizer!,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _fmtDateRange(event.startTime, event.endTime),
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if ((event.location ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.place, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              event.location!,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: chips),
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
