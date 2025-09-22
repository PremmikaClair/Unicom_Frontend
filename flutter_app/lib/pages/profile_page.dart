// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'auth_gate.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user.dart';

class ProfilePage extends StatefulWidget {
  /// If null -> show current user profile (editable). If not null -> user ObjectID string.
  final String? userId;

  /// Optional initial hints when navigating from post/author tap
  final String? initialUsername;
  final String? initialName;
  final String? initialAvatarUrl;
  final String? initialBio;

  const ProfilePage({
    super.key,
    this.userId,
    this.initialUsername,
    this.initialName,
    this.initialAvatarUrl,
    this.initialBio,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  String? _error;

  final _db = DatabaseService();

  UserProfile? _user;
  String? _usernameHint;
  String? _nameHint;
  String? _avatarHint;
 

  @override
  void initState() {
    super.initState();
    _usernameHint = widget.initialUsername;
    _nameHint = widget.initialName;
    _avatarHint = widget.initialAvatarUrl;
    _load();
  }

  Future<void> _load() async {
    // If this is an author's profile without id, show hints only (no fetch)
    if (!_isMine && (widget.userId == null || widget.userId!.isEmpty)) {
      setState(() { _loading = false; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      UserProfile? u;
      if (widget.userId != null && widget.userId!.trim().isNotEmpty) {
        // New fiber users API expects Mongo ObjectID in path
        final map = await _db.getUserByObjectIdFiber(widget.userId!.trim());
        u = UserProfile.fromJson(map);
      } else {
        final map = await _db.getMeFiber();
        u = UserProfile.fromJson(map);
      }
      setState(() { _user = u; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006400)),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => AppShell(initialIndex: 0)),
              );
            }
          },
        ),
        actions: [
          if (_isMine)
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $_error'),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildAvatar(),
                      const SizedBox(height: 16),
                      Text(_displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black)),
                      const SizedBox(height: 8),
                      if (_displayUsername != null)
                        Text(_displayUsername!, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 32),
                      _buildInfoList(),
                      const SizedBox(height: 16),
                      if (_isMine)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text('Logout'),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  bool get _isMine {
    if (widget.userId != null && widget.userId!.isNotEmpty) return false;
    // Treat as author's profile when initial hints are provided
    if ((widget.initialUsername ?? widget.initialAvatarUrl ?? widget.initialName) != null) return false;
    return true; // default to current user (e.g., header tap)
  }

  String get _displayName {
    final name = _user != null
        ? [(_user!.firstName ?? '').trim(), (_user!.lastName ?? '').trim()]
            .where((s) => s.isNotEmpty)
            .join(' ')
        : (_nameHint ?? '—');
    return name.isNotEmpty ? name : '—';
  }

  String? get _displayUsername {
    if (_user?.email != null && _user!.email!.isNotEmpty) return _user!.email;
    if (_usernameHint != null && _usernameHint!.isNotEmpty) return '@${_usernameHint!}';
    return null;
  }

  Widget _buildAvatar() {
    final url = _avatarHint; // no avatar URL from current backend yet
    return CircleAvatar(
      radius: 48,
      backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
      child: (url == null || url.isEmpty) ? const Icon(Icons.person, size: 48) : null,
    );
  }

  Widget _buildInfoList() {
    final rows = <MapEntry<String, String?>>[
      MapEntry('ID', _user?.id?.toString()),
      MapEntry('Email', _user?.email),
      MapEntry('Student ID', _user?.studentId),
      MapEntry('Advisor ID', _user?.advisorId),
      MapEntry('Gender', _user?.gender),
      MapEntry('Type', _user?.typePerson),
      MapEntry('Status', _user?.status),
    ];
    final shownKeys = <String>{'id','email','student_id','advisor_id','gender','type_person','status'};
    final extra = _user?.raw.entries
            .where((e) => !shownKeys.contains(e.key))
            .map((e) => MapEntry(e.key, e.value?.toString()))
            .toList() ??
        const <MapEntry<String,String?>>[];
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFE6F4EA), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          for (final e in rows)
            if (e.value != null && e.value!.isNotEmpty)
              Column(children: [
                ListTile(
                  dense: true,
                  title: Text(e.key),
                  subtitle: Text(e.value!),
                ),
                const Divider(height: 1),
              ]),
          for (final e in extra)
            Column(children: [
              ListTile(
                dense: true,
                title: Text(e.key),
                subtitle: Text(e.value ?? ''),
              ),
              const Divider(height: 1),
            ]),
        ],
      ),
    );
  }

 

  Future<void> _logout() async {
    await AuthService.I.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate(child: AppShell())),
      (route) => false,
    );
  }
}
