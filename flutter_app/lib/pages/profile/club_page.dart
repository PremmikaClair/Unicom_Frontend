import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/user.dart' as model;

class ClubPage extends StatefulWidget {
  const ClubPage({super.key});

  @override
  State<ClubPage> createState() => _ClubPageState();
}

// --- Styles copied from RolePage ---
const _brandGreen = Color(0xFF556B2F);
const _mintBg = Color(0xFFE6F0E6);

class _RoleTextStyles {
  static const header = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 24,
    color: Colors.black87,
  );
  static const name = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 24,
    color: Colors.black87,
  );
  static const email = TextStyle(
    fontSize: 16,
    color: Colors.grey,
  );
  static const sectionTitle = TextStyle(
    color: _brandGreen,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );
  static const listTitle = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: Colors.black,
  );
}

class _ClubPageState extends State<ClubPage> {
  final _db = DatabaseService();

  String _formatRoleTitle(String pos, String path) {
    final raw = (pos).toString().trim();
    if (raw.isEmpty) return 'member';
    final plow = raw.toLowerCase();
    // last node from org_path
    final parts = path
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final last = parts.isNotEmpty ? parts.last.toLowerCase() : '';

    String base;
    if (plow == 'root_admin' || plow.replaceAll('_', ' ') == 'root admin') {
      base = 'admin';
    } else if (plow.startsWith('student')) {
      base = 'student';
    } else {
      base = plow.replaceAll('_', ' ');
    }

    // Append last node for readability on club page (e.g., head cpsk, member cpsk)
    if (last.isNotEmpty && base != 'admin') {
      return '$base $last';
    }
    return base;
  }

  Future<void> _goBackToPrevious() async {
    FocusScope.of(context).unfocus();
    if (await Navigator.of(context).maybePop()) return;
    await Navigator.of(context, rootNavigator: true).maybePop();
  }

  late final Future<_ClubScreenData> _future = _load();

  Future<_ClubScreenData> _load() async {
    final meMap = await _db.getMeFiber();
    final me = model.UserProfile.fromJson(meMap);
    final all = await _db.getMyMembershipsFiber(active: 'true');
    final clubs = all.where((m) => (m['org_path']?.toString() ?? '').contains('/club')).toList();
    return _ClubScreenData(profile: me, clubs: clubs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: FutureBuilder<_ClubScreenData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() {}),
                        child: const Text('ลองอีกครั้ง'),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!;
              final profile = data.profile;
              final clubs = data.clubs;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with back button and title (same as RolePage)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black87),
                          onPressed: _goBackToPrevious,
                        ),
                        const Expanded(
                          child: Center(
                            child: Text('Personal Information', style: _RoleTextStyles.header),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Profile avatar
                    const CircleAvatar(
                      radius: 64,
                      child: Icon(Icons.person, size: 48),
                    ),
                    const SizedBox(height: 16),

                    // Name & email
                    Text(
                      [profile.firstName ?? '', profile.lastName ?? '']
                          .where((s) => s.trim().isNotEmpty)
                          .join(' ')
                          .trim(),
                      textAlign: TextAlign.center,
                      style: _RoleTextStyles.name,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.email ?? '—',
                      textAlign: TextAlign.center,
                      style: _RoleTextStyles.email,
                    ),

                    const SizedBox(height: 28),

                    // Clubs card (styled like RolePage card)
                    Container(
                      decoration: BoxDecoration(
                        color: _mintBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text('My club', style: _RoleTextStyles.sectionTitle.copyWith(color: Colors.black)),
                          ),
                          const SizedBox(height: 8),
                          // Only club memberships here
                          ...List.generate(clubs.length, (i) {
                            final m = clubs[i];
                            final pos = (m['position_key'] ?? '').toString();
                            final path = (m['org_path'] ?? '').toString();
                            final active = m['active'] == true;
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                  minLeadingWidth: 24,
                                  horizontalTitleGap: 10,
                                  leading: Icon(
                                    Icons.group_outlined,
                                    size: 28,
                                    color: active ? Colors.black : Colors.black45,
                                  ),
                                  title: Text(_formatRoleTitle(pos, path), style: _RoleTextStyles.listTitle),
                                ),
                                if (i != clubs.length - 1) const Divider(height: 0),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ClubScreenData {
  final model.UserProfile profile;
  final List<Map<String, dynamic>> clubs;
  const _ClubScreenData({required this.profile, required this.clubs});
}
