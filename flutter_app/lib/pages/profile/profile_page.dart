// lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/bottom_nav.dart';
import 'allergies.dart';
import 'role_page.dart';
import '../app_shell.dart';
import '../home_page.dart';
import '../login/auth_gate.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/user.dart';

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

  Future<void> _goBackToPrevious() async {
    FocusScope.of(context).unfocus();
    if (await Navigator.of(context).maybePop()) return;
    await Navigator.of(context, rootNavigator: true).maybePop();
  }

  // Real API data
  UserProfile? _user;

  // Local preferences (for fields not supported by backend yet)
  String? _usernameAlias; // preferred display username (alias)
  String? _phoneNumber;
  String? _avatarUrl;

  // In-memory photo (device upload not enabled in this build)
  // Uint8List? _avatarBytes;

  static const _kAliasKey = 'profile_username_alias';
  static const _kPhoneKey = 'profile_phone_number';
  static const _kAvatarUrlKey = 'profile_avatar_url';

  static const List<String> _sampleAvatars = [
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1502685104226-ee32379fefbe?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1545996124-0501ebae84d5?q=80&w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1541534401786-2077eed87a74?q=80&w=800&auto=format&fit=crop',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Load local prefs (alias/phone/avatarUrl) for current user view
      if (_isMine) {
        final sp = await SharedPreferences.getInstance();
        _usernameAlias = sp.getString(_kAliasKey) ?? widget.initialUsername;
        _phoneNumber = sp.getString(_kPhoneKey);
        _avatarUrl = sp.getString(_kAvatarUrlKey) ?? widget.initialAvatarUrl;
      } else {
        _usernameAlias = widget.initialUsername;
        _avatarUrl = widget.initialAvatarUrl;
      }

      // Fetch user from backend
      UserProfile? u;
      if (widget.userId != null && widget.userId!.trim().isNotEmpty) {
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToPrevious,
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Failed to load profile'),
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isMyProfile = _isMine;
    final profileId = _user?.oid ?? _user?.id?.toString() ?? '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundImage: _avatarProvider(),
            child: (_avatarProvider() == null)
                ? const Icon(Icons.person, size: 48)
                : null,
          ),
          if (isMyProfile) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _changePhoto,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Change photo'),
            ),
          ] else ...[
            const SizedBox(height: 16),
          ],
          Text(
            _displayName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _displayUsername,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (isMyProfile) ...[
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: Colors.black54),
                    padding: EdgeInsets.zero,
                    tooltip: 'Change username alias',
                    onPressed: () => _editUsername(_usernameAlias ?? ''),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                (_phoneNumber ?? '—'),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (isMyProfile) ...[
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: Colors.black54),
                    padding: EdgeInsets.zero,
                    tooltip: 'Change phone number',
                    onPressed: () => _editPhoneNumber(_phoneNumber ?? ''),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(_user?.email ?? '—', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),

          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.perm_identity, color: Colors.black87),
                  title: const Text('User ID', style: TextStyle(fontSize: 16, color: Colors.black)),
                  subtitle: Text(profileId, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ),
                const Divider(height: 0),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.badge_outlined, color: Colors.black87),
                  title: const Text('First name', style: TextStyle(fontSize: 16, color: Colors.black)),
                  subtitle: Text((_user?.firstName ?? '—'), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ),
                const Divider(height: 0),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.badge_outlined, color: Colors.black87),
                  title: const Text('Last name', style: TextStyle(fontSize: 16, color: Colors.black)),
                  subtitle: Text((_user?.lastName ?? '—'), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.zero,
            child: ListTileTheme(
              data: const ListTileThemeData(
                dense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                minVerticalPadding: 12,
                horizontalTitleGap: 12,
                minLeadingWidth: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Personal information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const Divider(height: 0, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.medical_information_outlined, color: Colors.black87, size: 20),
                      title: const Text('Health', style: TextStyle(fontSize: 16, color: Colors.black)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.black),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AllergiesPage()),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 0, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.badge_outlined, color: Colors.black87, size: 20),
                      title: const Text('Roles', style: TextStyle(fontSize: 16, color: Colors.black)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.black),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RolePage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
        : '-';
    return name.isNotEmpty ? name : '—';
  }

  String get _displayUsername {
    if (_usernameAlias != null && _usernameAlias!.trim().isNotEmpty) {
      return '@${_usernameAlias!.trim()}';
    }
    final email = _user?.email ?? '';
    if (email.isNotEmpty) {
      final local = email.split('@').first;
      return local.isNotEmpty ? '@$local' : email;
    }
    return '@—';
  }

  ImageProvider<Object>? _avatarProvider() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return NetworkImage(_avatarUrl!);
    }
    return null;
  }

  void _onDockTap(BuildContext context, int index) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AppShell(initialIndex: index)),
    );
  }

  Future<void> _changePhoto() async {
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload from device'),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device upload not enabled in this build')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Text('Choose profile picture',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sampleAvatars.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final url = _sampleAvatars[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text('Use custom image URL'),
                  onPressed: () async {
                    final ctrl = TextEditingController();
                    final url = await showDialog<String>(
                      context: context,
                      builder: (dctx) {
                        return AlertDialog(
                          title: const Text('Enter image URL'),
                          content: TextField(
                            controller: ctrl,
                            decoration: const InputDecoration(
                              hintText: 'https://...',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
                              child: const Text('Use'),
                            ),
                          ],
                        );
                      },
                    );
                    if (url != null && url.isNotEmpty) {
                      if (context.mounted) {
                        Navigator.of(context).pop(url);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected.isNotEmpty) {
      _avatarUrl = selected;
      if (_isMine) {
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_kAvatarUrlKey, selected);
      }
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _editUsername(String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Center(
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.85,
              margin: const EdgeInsets.symmetric(vertical: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Change username',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'your username',
                      filled: true,
                      fillColor: Color(0xFFF6F6F6),
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.black87, width: 1.2),
                      ),
                    ),
                    onSubmitted: (v) async {
                      final nv = v.trim();
                      if (nv.isNotEmpty && nv != current) {
                        Navigator.pop(ctx, nv);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black54),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (ctrl.text.trim().isNotEmpty && ctrl.text.trim() != current)
                            ? () async { Navigator.pop(ctx, ctrl.text.trim()); }
                            : null,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty && result != current) {
      _usernameAlias = result;
      if (_isMine) {
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_kAliasKey, _usernameAlias!);
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated')),
      );
    }
  }

  Future<void> _editPhoneNumber(String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Center(
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.85,
              margin: const EdgeInsets.symmetric(vertical: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Change phone number',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: '+66 8x xxx xxxx',
                      filled: true,
                      fillColor: Color(0xFFF6F6F6),
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.black26),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: Colors.black87, width: 1.2),
                      ),
                    ),
                    onSubmitted: (v) async {
                      final nv = v.trim();
                      if (nv.length >= 6 && nv != current) {
                        Navigator.pop(ctx, nv);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black54),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (ctrl.text.trim().length >= 6 && ctrl.text.trim() != current)
                            ? () async { Navigator.pop(ctx, ctrl.text.trim()); }
                            : null,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty && result != current) {
      _phoneNumber = result;
      if (_isMine) {
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_kPhoneKey, _phoneNumber!);
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number updated')),
      );
    }
  }
 

  Future<void> _logout() async {
    await AuthService.I.logout();
    if (!mounted) return;
    // Use ROOT navigator so LoginPage replaces the whole app,
    // not inside a tab Navigator (prevents bottom nav "following").
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate(child: AppShell())),
      (route) => false,
    );
  }
}
