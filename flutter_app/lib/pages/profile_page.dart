// lib/pages/profile_page.dart
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  /// null = my profile (editable)
  final String? userId;

  /// Optional initial values (useful when navigating from a post)
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

  // Profile data
  String _username = '';
  String _name = '';
  String _avatarUrl = '';
  String _bio = '';

  // Editing state (allowed only if isMe)
  bool _editing = false;
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();

  bool get _isMe => widget.userId == null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Seed quick UI from initial hints (if provided)
    _username = widget.initialUsername ?? _username;
    _name = widget.initialName ?? _name;
    _avatarUrl = widget.initialAvatarUrl ?? _avatarUrl;
    _bio = widget.initialBio ?? _bio;

    // Show seeded data immediately
    setState(() {
      _loading = false;
    });

    // TODO: fetch real data
    // If you have a UserService, call it here:
    // final baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://backend-xe4h.onrender.com');
    // final users = UserService(baseUrl);
    // try {
    //   final u = _isMe ? await users.getMe() : await users.getUser(widget.userId!);
    //   if (!mounted) return;
    //   setState(() {
    //     _username = u.username;
    //     _name = u.name;
    //     _avatarUrl = u.avatarUrl ?? '';
    //     _bio = u.bio ?? '';
    //     _error = null;
    //   });
    // } catch (e) {
    //   if (!mounted) return;
    //   setState(() => _error = e.toString());
    // }
  }

  void _enterEdit() {
    _nameCtrl.text = _name;
    _usernameCtrl.text = _username;
    _bioCtrl.text = _bio;
    _avatarCtrl.text = _avatarUrl;
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    // TODO: call PUT /users/:id (or /auth/me) to save
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 400)); // fake latency

    setState(() {
      _name = _nameCtrl.text.trim();
      _username = _usernameCtrl.text.trim();
      _bio = _bioCtrl.text.trim();
      _avatarUrl = _avatarCtrl.text.trim();
      _editing = false;
      _loading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  void _cancel() {
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isMe ? 'My Profile' : 'Profile';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isMe && !_editing && !_loading)
            IconButton(icon: const Icon(Icons.edit), onPressed: _enterEdit),
          if (_isMe && _editing)
            IconButton(icon: const Icon(Icons.check), onPressed: _save),
          if (_isMe && _editing)
            IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 48,
                        backgroundImage:
                            _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                        child: _avatarUrl.isEmpty
                            ? const Icon(Icons.person, size: 48)
                            : null,
                      ),
                      const SizedBox(height: 12),

                      if (_isMe && _editing)
                        TextField(
                          controller: _avatarCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Avatar URL',
                            hintText: 'https://…',
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Name
                      _isMe && _editing
                          ? TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'Name'),
                            )
                          : Text(
                              _name.isNotEmpty ? _name : '—',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),

                      const SizedBox(height: 6),

                      // Username
                      _isMe && _editing
                          ? TextField(
                              controller: _usernameCtrl,
                              decoration: const InputDecoration(labelText: 'Username'),
                            )
                          : Text(
                              _username.isNotEmpty ? '@$_username' : '@—',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),

                      const SizedBox(height: 16),

                      // Bio
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Bio', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      const SizedBox(height: 6),
                      _isMe && _editing
                          ? TextField(
                              controller: _bioCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Tell people about yourself…',
                                border: OutlineInputBorder(),
                              ),
                              minLines: 3,
                              maxLines: 6,
                            )
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _bio.isNotEmpty ? _bio : 'No bio yet.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),

                      const SizedBox(height: 24),

                      // Actions for viewing other users
                      if (!_isMe && !_editing)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                // TODO: POST /users/:id/follow
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Followed (mock)')),
                                );
                              },
                              child: const Text('Follow'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () {
                                // TODO: open chat
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Message (mock)')),
                                );
                              },
                              child: const Text('Message'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}