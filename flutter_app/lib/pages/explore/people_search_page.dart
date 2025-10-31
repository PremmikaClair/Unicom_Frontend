import 'package:flutter/material.dart';

import '../../components/app_colors.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../profile/profile_page.dart';
import '../profile/role_page.dart';

class PeopleSearchPage extends StatefulWidget {
  final String query;
  final DatabaseService db;

  const PeopleSearchPage({super.key, required this.query, required this.db});

  @override
  State<PeopleSearchPage> createState() => _PeopleSearchPageState();
}

class _PeopleSearchPageState extends State<PeopleSearchPage> {
  final List<_PeopleMatch> _items = <_PeopleMatch>[];
  bool _loading = true;
  bool _fetchingMore = false;
  String? _cursor;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _fetchingMore = false;
        _error = null;
        _items.clear();
        _cursor = null;
      });
    } else {
      if (_fetchingMore || _cursor == null) return;
      setState(() {
        _fetchingMore = true;
        _error = null;
      });
    }

    try {
      final res = await widget.db.searchUsers(
        q: widget.query,
        limit: 20,
        cursor: reset ? null : _cursor,
      );
      final lower = widget.query.toLowerCase();
      final newItems = res.items
          .map((raw) => _PeopleMatch.fromJson(raw, lower))
          .whereType<_PeopleMatch>()
          .toList();
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(newItems);
        } else {
          for (final item in newItems) {
            final idx = _items.indexWhere((m) => m.id == item.id);
            if (idx >= 0) {
              _items[idx] = item;
            } else {
              _items.add(item);
            }
          }
        }
        _cursor = res.nextCursor;
        _loading = false;
        _fetchingMore = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        if (reset) {
          _loading = false;
        } else {
          _fetchingMore = false;
        }
        _error = e;
      });
    }
  }

  Future<void> _refresh() => _load(reset: true);

  @override
  Widget build(BuildContext context) {
    final listChildren = <Widget>[
      _Header(query: widget.query, count: _items.length, loading: _loading),
    ];

    if (_loading && _items.isEmpty) {
      listChildren.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ));
    } else if (_error != null && _items.isEmpty) {
      listChildren.add(_ErrorState(onRetry: () => _load(reset: true)));
    } else if (_items.isEmpty) {
      listChildren.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('No matching people found')),
      ));
    } else {
      for (final item in _items) {
        listChildren.add(
          _PeopleTile(
            match: item,
            onTap: () => _openProfile(item),
            onRolesTap: () => _openRoles(item),
          ),
        );
      }
      if (_fetchingMore) {
        listChildren.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ));
      } else if (_cursor != null) {
        listChildren.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sage,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () => _load(reset: false),
            icon: const Icon(Icons.people_outline),
            label: const Text('Load more people'),
          ),
        ));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F3),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('People'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: listChildren,
        ),
      ),
    );
  }

  void _openProfile(_PeopleMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: match.id,
          initialUsername: match.username.isNotEmpty ? match.username : null,
          initialName: match.displayName.isNotEmpty ? match.displayName : null,
          initialAvatarUrl: match.avatarUrl.isNotEmpty ? match.avatarUrl : null,
          initialBio: null,
        ),
      ),
    );
  }

  void _openRoles(_PeopleMatch match) {
    if (match.id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RolePage(),
      ),
    );
  }
}

class _PeopleTile extends StatelessWidget {
  final _PeopleMatch match;
  final VoidCallback onTap;
  final VoidCallback onRolesTap;

  const _PeopleTile({
    required this.match,
    required this.onTap,
    required this.onRolesTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ImageProvider? avatar;
    final src = match.avatarUrl;
    if (src.isNotEmpty) {
      final abs = _absoluteUrl(src);
      final uri = Uri.tryParse(abs);
      if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
        avatar = NetworkImage(abs);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6)),
              ],
              border: Border.all(color: AppColors.sage.withOpacity(.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: avatar,
                  backgroundColor: AppColors.sage.withOpacity(.2),
                  child: avatar == null
                      ? const Icon(Icons.person_outline, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.primaryLabel,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (match.secondaryLabel.isNotEmpty)
                        Text(
                          match.secondaryLabel,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                        ),
                      if (match.id.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onRolesTap,
                            icon: const Icon(Icons.badge_outlined, size: 16),
                            label: const Text('Roles'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: const Color(0xFF7D6BC5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _absoluteUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    if (trimmed.startsWith('/')) return '${AuthService.I.apiBase}$trimmed';
    return trimmed;
  }
}

class _Header extends StatelessWidget {
  final String query;
  final int count;
  final bool loading;

  const _Header({required this.query, required this.count, required this.loading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'People results',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.sage),
          ),
          const SizedBox(height: 4),
          Text(
            'search: "$query"',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 6),
          if (!loading)
            Text(
              '$count people found',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.black38),
          const SizedBox(height: 16),
          const Text('Unable to load people', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _PeopleMatch {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String secondaryLabel;
  final String email;

  const _PeopleMatch({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.secondaryLabel,
    required this.email,
  });

  String get primaryLabel {
    if (displayName.isNotEmpty) return displayName;
    if (username.isNotEmpty) return '@$username';
    return 'Unnamed user';
  }

  static _PeopleMatch? fromJson(Map<String, dynamic> raw, String lowerQuery) {
    String read(dynamic v) => v?.toString().trim() ?? '';
    String readId(dynamic v) {
      if (v is Map && v[r'$oid'] != null) return v[r'$oid'].toString();
      return read(v);
    }

    String resolveUserId() {
      final keys = [
        '_id',
        'id',
        'user_id',
        'userId',
        'uid',
        'objectId',
        'object_id',
        'profileId',
        'profile_id',
      ];
      for (final key in keys) {
        final value = readId(raw[key]);
        if (value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return '';
    }

    final id = resolveUserId();
    if (id.isEmpty) return null;

    final first = read(raw['firstName']);
    final last = read(raw['lastName']);
    final display = [first, last].where((s) => s.isNotEmpty).join(' ').trim();
    final email = read(raw['email']);
    final usernameRaw = read(raw['username'] ?? raw['userName'] ?? raw['alias']);
    final student = read(raw['student_id'] ?? raw['studentId']);

    String deriveUsername() {
      if (usernameRaw.isNotEmpty) return usernameRaw;
      if (email.contains('@')) {
        final local = email.split('@').first.trim();
        if (local.isNotEmpty) return local;
      }
      if (display.isNotEmpty) return display.replaceAll(' ', '').toLowerCase();
      return 'user$id';
    }

    final username = deriveUsername();
    final avatar = read(raw['profile_pic'] ?? raw['profilePic'] ?? raw['avatar_url'] ?? raw['avatar']);

    bool contains(String value) => value.toLowerCase().contains(lowerQuery);
    final matchable = <String>{
      first,
      last,
      '$first $last',
      email,
      usernameRaw,
      username,
      student,
      display,
    }..removeWhere((e) => e.isEmpty);

    final roles = raw['roles'];
    if (roles is List) {
      for (final r in roles) {
        matchable.add(read(r));
      }
    }

    if (matchable.every((s) => !contains(s))) return null;

    String secondary = '';
    if (display.isNotEmpty && username.isNotEmpty) {
      secondary = '@$username';
    } else if (email.isNotEmpty) {
      secondary = email;
    } else if (student.isNotEmpty) {
      secondary = student;
    }

    return _PeopleMatch(
      id: id,
      username: username,
      displayName: display,
      avatarUrl: avatar,
      secondaryLabel: secondary,
      email: email,
    );
  }
}
