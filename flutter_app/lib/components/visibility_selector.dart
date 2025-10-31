// lib/components/visibility_selector.dart
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'app_colors.dart';

// ใช้ enum เดียวกันทั้งแอปจากที่นี่
enum VisibilityAccess { public, org, custom }

const _kFieldBg = Colors.white;
const _kGrayBorder = AppColors.chipGrey;
const _kText = Color(0xFF233127);
const _kSubtle = Color(0xFF9BA3A0);

class VisibilitySelector extends StatefulWidget {
  final VisibilityAccess value;
  final String? postedOrgPath;

  /// selected org_path (faculties as subtree, clubs as exact)
  final Set<String> facultySelected;
  final Set<String> clubSelected;

  final ValueChanged<VisibilityAccess> onAccessChanged;
  final ValueChanged<Set<String>> onFacultyChanged;
  final ValueChanged<Set<String>> onClubChanged;

  const VisibilitySelector({
    super.key,
    required this.value,
    required this.onAccessChanged,
    required this.onFacultyChanged,
    required this.onClubChanged,
    this.facultySelected = const {},
    this.clubSelected = const {},
    this.postedOrgPath,
  });

  @override
  State<VisibilitySelector> createState() => _VisibilitySelectorState();
}

class _VisibilitySelectorState extends State<VisibilitySelector> {
  bool _loading = false;
  List<Map<String, dynamic>> _orgUnits = const [];
  String _query = '';
  bool _openFaculty = false;
  bool _openClubs = false;

  // ข้อมูล org_path ที่ผู้ใช้เป็น parent (จาก memberships + manageable orgs)
  final Set<String> _myOrgRoots = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      // 1) โหลด memberships ของผู้ใช้
      final mems = await DatabaseService().getMyMembershipsFiber(active: 'true');
      for (final m in mems) {
        final p = (m['org_path'] ?? '').toString().trim();
        if (p.isNotEmpty) _myOrgRoots.add(_normalizePath(p));
      }

      // 2) โหลด manageable orgs (ถ้ามีถือเป็น root ได้ด้วย)
      final managables = await DatabaseService().getManageableOrgsFiber();
      for (final m in managables) {
        final p = (m['org_path'] ?? '').toString().trim();
        if (p.isNotEmpty) _myOrgRoots.add(_normalizePath(p));
      }

      // 3) โหลด org tree (ความลึกพอประมาณ)
      final tree = await DatabaseService().getOrgTreeFiber(start: '/', depth: 3, lang: 'th');
      final out = <Map<String, dynamic>>[];
      void walk(dynamic node) {
        if (node is Map<String, dynamic>) {
          final type = (node['type'] ?? '').toString();
          final path = _normalizePath((node['org_path'] ?? '').toString());
          final label = (node['label'] ?? node['short_name'] ?? '').toString();
          if (path.isNotEmpty && type.isNotEmpty) {
            out.add({'org_path': path, 'label': label, 'type': type});
          }
          final children = node['children'];
          if (children is List) {
            for (final c in children) {
              walk(c);
            }
          }
        } else if (node is List) {
          for (final c in node) walk(c);
        }
      }
      walk(tree);

      setState(() => _orgUnits = out);
    } catch (_) {
      setState(() => _orgUnits = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizePath(String p) {
    if (p.isEmpty) return p;
    var s = p.trim();
    if (!s.startsWith('/')) s = '/$s';
    if (s.length > 1 && s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  bool _isAncestorOrSelf(String root, String target) {
    root = _normalizePath(root);
    target = _normalizePath(target);
    if (root == target) return true;
    if (!target.startsWith(root)) return false;
    // boundary: root == '/a/b' → target must be '/a/b/...'
    return target.length > root.length && target[root.length] == '/';
  }

  bool _isAllowedForUser(String targetPath) {
    for (final r in _myOrgRoots) {
      if (_isAncestorOrSelf(r, targetPath)) return true;
    }
    return false;
  }

  List<Map<String, dynamic>> get _faculties =>
      _orgUnits
          .where((o) => (o['type'] ?? '') == 'faculty')
          .where((o) => _isAllowedForUser((o['org_path'] ?? '').toString()))
          .toList();

  List<Map<String, dynamic>> get _clubs =>
      _orgUnits
          .where((o) => (o['type'] ?? '') == 'club')
          .where((o) => _isAllowedForUser((o['org_path'] ?? '').toString()))
          .toList();

  bool _matches(String s) {
    if (_query.isEmpty) return true;
    return s.toLowerCase().contains(_query.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = widget.value == VisibilityAccess.custom;

    return Container(
      decoration: BoxDecoration(
        color: _kFieldBg,
        border: Border.all(color: _kGrayBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioListTile<VisibilityAccess>(
            dense: true,
            value: VisibilityAccess.public,
            groupValue: widget.value,
            onChanged: (v) => widget.onAccessChanged(v!),
            activeColor: AppColors.deepGreen,
            title: const Text('Public (anyone can register)', style: TextStyle(color: _kText)),
          ),
          RadioListTile<VisibilityAccess>(
            dense: true,
            value: VisibilityAccess.org,
            groupValue: widget.value,
            onChanged: (v) => widget.onAccessChanged(v!),
            activeColor: AppColors.deepGreen,
            title: const Text('Only my organization (posted_as org_path)', style: TextStyle(color: _kText)),
          ),
          RadioListTile<VisibilityAccess>(
            dense: true,
            value: VisibilityAccess.custom,
            groupValue: widget.value,
            onChanged: (v) async {
              widget.onAccessChanged(v!);
              await _bootstrap();
            },
            activeColor: AppColors.deepGreen,
            title: const Text('Custom (select faculties & clubs)', style: TextStyle(color: _kText)),
          ),

          if (isCustom) ...[
            const Divider(height: 18),
            _searchBar(),
            const SizedBox(height: 8),
            _roleCard(
              color: AppColors.deepGreen,
              icon: Icons.school,
              title: 'Faculty',
              open: _openFaculty,
              onToggle: () => setState(() => _openFaculty = !_openFaculty),
              child: _pills(
                items: _faculties
                    .where((m) => _matches((m['label'] ?? '').toString()))
                    .map((m) => {
                          'id': (m['org_path'] ?? '').toString(),
                          'label': (m['label'] ?? '').toString()
                        })
                    .toList(),
                selected: widget.facultySelected,
                onChanged: (set) => widget.onFacultyChanged({...set}),
                color: AppColors.deepGreen,
              ),
            ),
            _roleCard(
              color: AppColors.deepGreen,
              icon: Icons.groups,
              title: 'Clubs',
              open: _openClubs,
              onToggle: () => setState(() => _openClubs = !_openClubs),
              child: _pills(
                items: _clubs
                    .where((m) => _matches((m['label'] ?? '').toString()))
                    .map((m) => {
                          'id': (m['org_path'] ?? '').toString(),
                          'label': (m['label'] ?? '').toString()
                        })
                    .toList(),
                selected: widget.clubSelected,
                onChanged: (set) => widget.onClubChanged({...set}),
                color: AppColors.deepGreen,
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(children: [
                  SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Loading organizations...')
                ]),
              ),
            if (!_loading && _faculties.isEmpty && _clubs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No organizations available for your role',
                    style: TextStyle(color: _kSubtle)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      onChanged: (v) => setState(() => _query = v.trim()),
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: 'Search…',
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(60),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _roleCard({
    required Color color,
    required IconData icon,
    required String title,
    required bool open,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(blurRadius: 12, color: Color(0x14000000), offset: Offset(0, 4))
        ],
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: _kSubtle),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 160),
            crossFadeState: open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _pills({
    required List<Map<String, String>> items, // {id,label}
    required Set<String> selected,
    required void Function(Set<String>) onChanged,
    required Color color,
  }) {
    final filtered = items.where((e) => _matches(e['label'] ?? '')).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: filtered
          .map((o) => InkWell(
                onTap: () {
                  final id = o['id']!;
                  final next = {...selected};
                  next.contains(id) ? next.remove(id) : next.add(id);
                  onChanged(next);
                  setState(() {}); // refresh selection state
                },
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected.contains(o['id']) ? color : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    o['label']!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected.contains(o['id']) ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
