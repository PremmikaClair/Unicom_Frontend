import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class ClubPage extends StatefulWidget {
  const ClubPage({super.key});

  @override
  State<ClubPage> createState() => _ClubPageState();
}

class _ClubPageState extends State<ClubPage> {
  final _db = DatabaseService();
  late final Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final all = await _db.getMyMembershipsFiber(active: 'true');
    return all.where((m) => (m['org_path']?.toString() ?? '').contains('/club')).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Clubs'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load: ${snapshot.error}'),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No club memberships'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final m = items[i];
              final path = (m['org_path'] ?? '').toString();
              final pos = (m['position_key'] ?? '').toString();
              return ListTile(
                leading: const Icon(Icons.group_outlined),
                title: Text(path),
                subtitle: Text(pos.isNotEmpty ? pos : 'member'),
              );
            },
          );
        },
      ),
    );
  }
}

