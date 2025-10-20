import 'package:flutter/material.dart';
import '../home_page.dart';
import '../explore/explore_page.dart';
import '../event/events_page.dart';
import 'club_page.dart';
import 'profile_page.dart';
import '../../components/bottom_nav.dart';
import '../../services/database_service.dart';
import '../../models/user.dart' as model;

class RolePage extends StatefulWidget {
  final String? userId;
  final String? initialName;
  final String? initialEmail;

  const RolePage({
    super.key,
    this.userId,
    this.initialName,
    this.initialEmail,
  });

  bool get isSelf => userId == null || userId!.trim().isEmpty;

  static const _brandGreen = Color(0xFF556B2F);
  static const _mintBg = Color(0xFFE6F0E6);

  @override
  State<RolePage> createState() => _RolePageState();
}

class RoleScreenData {
  final model.UserProfile profile;
  final List<Map<String, dynamic>> memberships; // from /api/memberships
  const RoleScreenData({required this.profile, required this.memberships});
}

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
    color: RolePage._brandGreen,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );
  static const listTitle = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 16,
    color: Colors.black,
  );
}

class _RolePageState extends State<RolePage> {
  int _selectedIndex = -1; // not highlighting any tab
  final _db = DatabaseService();

  bool get _viewingSelf => widget.isSelf;

  Future<void> _goBackToPrevious() async {
    FocusScope.of(context).unfocus();
    if (await Navigator.of(context).maybePop()) return;
    await Navigator.of(context, rootNavigator: true).maybePop();
  }

  void _onDockTap(BuildContext context, int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ExplorePage()),
        );
        break;
      case 2:
        // Add page
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EventsPage()),
        );
        break;
    }
  }

  late final Future<RoleScreenData> _future = _load();

  Future<RoleScreenData> _load() async {
    if (_viewingSelf) {
      final meMap = await _db.getMeFiber();
      final me = model.UserProfile.fromJson(meMap);
      final mems = await _db.getMyMembershipsFiber(active: 'true');
      return RoleScreenData(profile: me, memberships: mems);
    }

    final targetId = widget.userId!.trim();
    final userMap = await _db.getUserByObjectIdFiber(targetId);
    final profile = model.UserProfile.fromJson(userMap);
    final memberships = _normalizeMembershipsFromProfile(userMap);
    return RoleScreenData(profile: profile, memberships: memberships);
  }

  List<Map<String, dynamic>> _normalizeMembershipsFromProfile(Map<String, dynamic> profile) {
    final raw = profile['memberships'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    final output = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        final norm = _normalizeMembershipMap(Map<String, dynamic>.from(item));
        if (norm != null) {
          output.add(norm);
        }
      }
    }
    return output;
  }

  Map<String, dynamic>? _normalizeMembershipMap(Map<String, dynamic> m) {
    final org = (m['org_unit'] ?? m['org']) as Map<String, dynamic>?;
    final posMapRaw = m['position'];
    Map<String, dynamic>? pos;
    if (posMapRaw is Map) {
      pos = posMapRaw.map((key, value) => MapEntry(key.toString(), value));
    }
    final orgPath = (org?['org_path'] ?? m['org_path'])?.toString();
    String orgShort = (org?['shortname'] ?? org?['short_name'] ?? '')?.toString() ?? '';
    final posKey = (pos?['key'] ?? m['position_key'] ?? m['position'])?.toString();
    final posDisplay = (() {
      final display = pos?['display'];
      if (display is Map) {
        final disp = display.map((key, value) => MapEntry(key.toString(), value));
        final th = disp['th']?.toString();
        final en = disp['en']?.toString();
        if (th != null && th.trim().isNotEmpty) return th.trim();
        if (en != null && en.trim().isNotEmpty) return en.trim();
      }
      final label = m['label']?.toString();
      if (label != null && label.trim().isNotEmpty) return label.trim();
      return posKey ?? '';
    })();
    if (orgShort.isEmpty && orgPath != null && orgPath.isNotEmpty) {
      final parts = orgPath.split('/')..removeWhere((e) => e.isEmpty);
      if (parts.isNotEmpty) orgShort = parts.last.toUpperCase();
    }
    final id = '${orgPath ?? ''}::${posKey ?? ''}';
    final baseLabel = (posDisplay.isNotEmpty && orgShort.isNotEmpty)
        ? '$posDisplay • $orgShort'
        : (posDisplay.isNotEmpty ? posDisplay : '${posKey ?? ''} • ${orgPath ?? ''}');
    final safeLabel = baseLabel.trim().isNotEmpty
        ? baseLabel.trim()
        : (posKey != null && posKey.trim().isNotEmpty
            ? posKey.trim()
            : 'member');
    return {
      '_id': id,
      'org_path': orgPath ?? '',
      'org_short': orgShort,
      'position_key': posKey ?? '',
      'label': safeLabel,
      'active': (m['active'] ?? m['isActive'] ?? true) == true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: FutureBuilder<RoleScreenData>(
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

              final data = snapshot.data;
              if (data == null) {
                return const Center(child: Text('ไม่พบข้อมูล'));
              }

              final profile = data.profile;
              final roles = data.memberships;
              bool hasClubs = roles.any((m) => (m['org_path']?.toString() ?? '').contains('/club'));

              String resolvedName = ([profile.firstName ?? '', profile.lastName ?? '']
                      .where((s) => s.trim().isNotEmpty)
                      .join(' ')
                      .trim());
              if (resolvedName.isEmpty) {
                resolvedName = widget.initialName?.trim() ?? '—';
              }
              String resolvedEmail = profile.email?.trim() ?? '';
              if (resolvedEmail.isEmpty) {
                final initialEmail = widget.initialEmail?.trim();
                if (initialEmail != null && initialEmail.isNotEmpty) {
                  resolvedEmail = initialEmail;
                }
              }
              if (resolvedEmail.isEmpty) resolvedEmail = '—';

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with back button and title
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black87),
                          onPressed: _goBackToPrevious,
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              widget.isSelf ? 'Personal Information' : 'Profile Information',
                              style: _RoleTextStyles.header.copyWith(fontSize: 20),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Profile avatar (use placeholder since backend has no avatar field)
                    const CircleAvatar(
                      radius: 64,
                      child: Icon(Icons.person, size: 48),
                    ),
                    const SizedBox(height: 16),

                    // Name & email
                    Text(
                      resolvedName,
                      textAlign: TextAlign.center,
                      style: _RoleTextStyles.name,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      resolvedEmail,
                      textAlign: TextAlign.center,
                      style: _RoleTextStyles.email,
                    ),

                    const SizedBox(height: 28),

                    // Roles card
                    Container(
                      decoration: BoxDecoration(
                        color: RolePage._mintBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(
                              widget.isSelf ? 'My role' : 'Roles',
                              style: _RoleTextStyles.sectionTitle.copyWith(color: Colors.black),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Clubs entry
                          Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                minLeadingWidth: 24,
                                horizontalTitleGap: 10,
                                leading: const Icon(Icons.groups_outlined, size: 28, color: Colors.black),
                                title: const Text('Clubs', style: _RoleTextStyles.listTitle),
                                trailing: hasClubs ? const Icon(Icons.chevron_right, color: Colors.black) : null,
                                onTap: hasClubs
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const ClubPage()),
                                        );
                                      }
                                    : null,
                              ),
                              const Divider(height: 0),
                            ],
                          ),
                          // List all memberships
                          ...List.generate(roles.length, (i) {
                            final m = roles[i];
                            final pos = (m['position_key'] ?? '').toString();
                            final label = (m['label'] ?? '').toString();
                            final path = (m['org_path'] ?? '').toString();
                            final active = m['active'] == true;
                            final displayTitle = label.isNotEmpty
                                ? label
                                : (pos.isNotEmpty ? pos : 'member');
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                  minLeadingWidth: 24,
                                  horizontalTitleGap: 10,
                                  leading: Icon(
                                    Icons.badge_outlined,
                                    size: 28,
                                    color: active ? Colors.black : Colors.black45,
                                  ),
                                  title: Text(
                                    displayTitle,
                                    style: _RoleTextStyles.listTitle,
                                  ),
                                  subtitle: path.isNotEmpty ? Text(path) : null,
                                ),
                                if (i != roles.length - 1) const Divider(height: 0),
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
