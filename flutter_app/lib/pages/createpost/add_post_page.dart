import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../home_page.dart';

class _AddPostData {
  final Map<String, dynamic> me;
  final List<Map<String, dynamic>> memberships;
  final List<Map<String, String>> orgOptions; // {path,label}
  _AddPostData(this.me, this.memberships, this.orgOptions);
}

class AddPostPage extends StatefulWidget {
  const AddPostPage({super.key});
  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  final _db = DatabaseService();
  final _msg = TextEditingController();

  // UI state
  String? _selectedMembershipId; // 'self' = myself, else membership _id
  String _access = 'public';
  String? _selectedOrgPath;
  String _orgScope = 'exact';
  final List<String> _categories = const ['General', 'Event', 'Announcement', 'Question'];
  final Set<String> _selectedCategories = {};
  bool _posting = false;

  late Future<_AddPostData> _future = _load();

  Future<_AddPostData> _load() async {
    final me = await _db.getMeFiber();
    final mems = await _db.getMyMembershipsFiber(active: 'true');
    final tree = await _db.getOrgTreeFiber();
    // flatten tree
    final out = <Map<String, String>>[];
    void walk(List<dynamic> nodes, int depth) {
      for (final n in nodes) {
        if (n is! Map) continue;
        final m = n.cast<String, dynamic>();
        final path = (m['org_path'] ?? m['OrgPath'] ?? m['path'] ?? '').toString();
        final label = (m['label'] ?? m['Label'] ?? path).toString();
        if (path.isNotEmpty) out.add({'path': path, 'label': '${'  ' * (depth - 1)}$label'});
        final children = m['children'] as List<dynamic>?;
        if (children != null && children.isNotEmpty) walk(children, depth + 1);
      }
    }
    walk(tree, 1);
    return _AddPostData(me, mems, out);
  }

  String _displayName(Map<String, dynamic> me) {
    final f = (me['firstName'] ?? '').toString().trim();
    final l = (me['lastName'] ?? '').toString().trim();
    final n = [f, l].where((s) => s.isNotEmpty).join(' ');
    return n.isEmpty ? '—' : n;
  }

  String _usernameFromEmail(Map<String, dynamic> me) {
    final email = (me['email'] ?? '').toString();
    return email.isEmpty ? 'user' : email.split('@').first;
  }

  Future<void> _submit(_AddPostData data) async {
    if (_posting) return;
    final message = _msg.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }
    if (_access == 'org' && (_selectedOrgPath == null || _selectedOrgPath!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an organization')));
      return;
    }

    setState(() => _posting = true);
    try {
      final uid = (data.me['_id'] ?? data.me['oid'] ?? data.me['id'] ?? '').toString();
      final name = _displayName(data.me);
      final username = _usernameFromEmail(data.me);

      Map<String, dynamic>? postedAs;
      if (_selectedMembershipId != null && _selectedMembershipId != 'self') {
        final m = data.memberships.firstWhere(
          (e) => (e['_id'] ?? '').toString() == _selectedMembershipId,
          orElse: () => const <String, dynamic>{},
        );
        if (m.isNotEmpty) {
          postedAs = {
            'org_path': (m['org_path'] ?? '').toString(),
            'position_key': (m['position_key'] ?? '').toString(),
          };
        }
      }

      Map<String, dynamic>? visibility;
      if (_access == 'public') {
        visibility = {'access': 'public'};
      } else {
        visibility = {
          'access': 'org',
          'audience': [
            {'org_path': _selectedOrgPath, 'scope': _orgScope},
          ],
        };
      }

      await _db.createPostFiber(
        uid: uid,
        name: name,
        username: username,
        message: message,
        postedAs: postedAs,
        visibility: visibility,
        orgOfContent: _selectedOrgPath,
        status: 'active',
      );

      if (!mounted) return;
      _msg.clear();
      _selectedCategories.clear();
      setState(() {
        _selectedMembershipId = 'self';
        _access = 'public';
        _selectedOrgPath = null;
        _orgScope = 'exact';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post created')));
      // Redirect to Home tab
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AddPostData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || snap.data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Failed to load'),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => setState(() => _future = _load()), child: const Text('Retry')),
              ],
            ),
          );
        }
        final data = snap.data!;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Create Post'),
            actions: [
              TextButton(
                onPressed: _posting ? null : () => _submit(data),
                child: _posting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Post'),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _msg,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: "What's happening?",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Categories'),
                  Wrap(
                    spacing: 8,
                    children: _categories.map((c) {
                      final on = _selectedCategories.contains(c);
                      return FilterChip(
                        label: Text(c),
                        selected: on,
                        onSelected: (v) => setState(() => v ? _selectedCategories.add(c) : _selectedCategories.remove(c)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Post as'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedMembershipId ?? 'self',
                    items: [
                      const DropdownMenuItem<String>(value: 'self', child: Text('Myself')),
                      ...data.memberships.map((m) {
                        final id = (m['_id'] ?? '').toString();
                        final pos = (m['position_key'] ?? '').toString();
                        final path = (m['org_path'] ?? '').toString();
                        final label = [pos.isNotEmpty ? pos : 'member', path].where((s) => s.isNotEmpty).join(' • ');
                        return DropdownMenuItem<String>(value: id, child: Text(label));
                      }),
                    ],
                    onChanged: (id) => setState(() => _selectedMembershipId = id),
                  ),
                  const SizedBox(height: 16),
                  const Text('Who can see this post'),
                  const SizedBox(height: 6),
                  Row(children: [
                    ChoiceChip(label: const Text('Public'), selected: _access == 'public', onSelected: (_) => setState(() => _access = 'public')),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('Org'), selected: _access == 'org', onSelected: (_) => setState(() => _access = 'org')),
                  ]),
                  const SizedBox(height: 8),
                  if (_access == 'org') ...[
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedOrgPath,
                      items: data.orgOptions
                          .map((o) => DropdownMenuItem<String>(value: o['path']!, child: Text(o['label']!)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedOrgPath = v),
                      decoration: const InputDecoration(labelText: 'Organization', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Text('Scope:'),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _orgScope,
                        items: const [
                          DropdownMenuItem(value: 'exact', child: Text('Exact')),
                          DropdownMenuItem(value: 'subtree', child: Text('Subtree')),
                        ],
                        onChanged: (v) => setState(() => _orgScope = v ?? 'exact'),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
