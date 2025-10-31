// lib/components/filter_event_sheet.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

import '../services/database_service.dart';
import '../models/filter_models.dart';


class FilterSheetResult {
  final Set<String> facultyIds;
  final Set<String> clubIds;

  const FilterSheetResult({
    this.facultyIds = const <String>{},
    this.clubIds = const <String>{},
  });

  // rolesIds: faculty/club -> wildcard path "…/*"
  Set<String> get rolesIds {
    final out = <String>{};
    for (final f in facultyIds) { final n=_normPath(f); if (n.isNotEmpty) out.add('$n/*'); }
    for (final c in clubIds)    { final n=_normPath(c); if (n.isNotEmpty) out.add('$n/*'); }
    return out;
  }

  @override
  String toString() =>
    'FilterSheetResult(faculty=$facultyIds, clubs=$clubIds, roles=$rolesIds)';
}

/* ─────────── Bottom Sheet ─────────── */
class FilterBottomSheet extends StatefulWidget {
  final Future<FilterData> Function() loadFilters;
  final FilterSheetResult initial;

  const FilterBottomSheet({
    super.key,
    required this.loadFilters,
    this.initial = const FilterSheetResult(),
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  bool _openFaculty = true;
  bool _openClubs = true;

  late Set<String> _facultySel, _clubSel;

  final _searchCtl = TextEditingController();
  String _query = '';

  late Future<FilterData> _filtersFuture;

  @override
  void initState() {
    super.initState();
    _facultySel  = {...widget.initial.facultyIds};
    _clubSel     = {...widget.initial.clubIds};

    _filtersFuture = widget.loadFilters();

    _searchCtl.addListener(() {
      setState(() => _query = _searchCtl.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return FutureBuilder<FilterData>(
          future: _filtersFuture,
          builder: (context, snap) {
            Widget child;
            if (snap.connectionState == ConnectionState.waiting) {
              child = const Center(child: CircularProgressIndicator());
            } else if (snap.hasError || !snap.hasData) {
              child = Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Failed to load filters',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            } else {
              final data = snap.data!;
              child = Column(
                children: [
                  const SizedBox(height: 8),
                  _grabber(),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.sage,
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 12),
              // Only roles (Faculty/Clubs)
              _searchBar(),
              const Divider(height: 1),
              Expanded(child: _rolesPanel(data)),
              // ▼▼▼ สรุปตัวเลือกที่ถูกเลือก (เฉพาะ faculty/club) ▼▼▼
              _selectedSummaryArea(data),
              // ▲▲▲
              _bottomButtons(),
                ],
              );
            }
            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: child,
            );
          },
        );
      },
    );
  }

  /* UI helpers */
  Widget _grabber() => Container(
    width: 40, height: 4,
    decoration: BoxDecoration(
      color: Colors.black26,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  // segmented tabs removed (only roles)

  Widget _searchBar({
    double height = 40,
    double radius = 60,
    double fontSize = 15,
    EdgeInsets margin = const EdgeInsets.fromLTRB(12, 6, 12, 8),
  }) {
    return Padding(
      padding: margin,
      child: SizedBox(
        height: height,
        child: TextField(
          controller: _searchCtl,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(fontSize: fontSize),
          decoration: InputDecoration(
            hintText: 'Search…',
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            prefixIcon: const Icon(Icons.search),
            prefixIconConstraints: BoxConstraints(minWidth: height, minHeight: height),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  /* Panels */
  Widget _rolesPanel(FilterData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        _roleCard(
          color: Colors.teal,
          icon: Icons.school,
          title: 'Faculty',
          open: _openFaculty,
          onToggle: () => setState(() => _openFaculty = !_openFaculty),
          child: _facultyContent(data),
        ),
        _roleCard(
          color: Colors.indigo,
          icon: Icons.groups,
          title: 'Clubs',
          open: _openClubs,
          onToggle: () => setState(() => _openClubs = !_openClubs),
          child: _clubsContent(data),
        ),
      ],
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
        boxShadow: const [BoxShadow(blurRadius: 12, color: Color(0x14000000), offset: Offset(0, 4))],
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
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: color.withOpacity(.12), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('', style: TextStyle(fontSize: 0, fontWeight: FontWeight.w700))),
                  Expanded(
                    flex: 100,
                    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: Colors.black54),
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

  // Faculty content (no departments – select faculty only)
  Widget _facultyContent(FilterData data) {
    final items = _filtered(data.faculties);
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: items.map((o) => _pill(
        o, _facultySel.contains(o.id), Colors.teal,
        onTap: () => setState(() {
          _facultySel.contains(o.id) ? _facultySel.remove(o.id) : _facultySel.add(o.id);
        }),
      )).toList(),
    );
  }
  // removed department selection

  Widget _clubsContent(FilterData data) {
    final items = _filtered(data.clubs);
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: items.map((o) => _pill(
        o, _clubSel.contains(o.id), Colors.indigo,
        onTap: () => setState(() {
          _clubSel.contains(o.id) ? _clubSel.remove(o.id) : _clubSel.add(o.id);
        }),
      )).toList(),
    );
  }

  Widget _pill(OptionItem o, bool selected, Color color, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          o.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  bool _matches(String s) {
    if (_query.isEmpty) return true;
    return s.toLowerCase().contains(_query.toLowerCase());
  }

  List<OptionItem> _filtered(List<OptionItem> xs) {
    if (_query.isEmpty) return xs;
    final q = _query.toLowerCase();
    return xs.where((e) => e.label.toLowerCase().contains(q)).toList();
  }

  // ─────────── Selected summary pills ───────────
  Widget _selectedSummaryArea(FilterData data) {
    final facLabel = { for (final f in data.faculties) _normPath(f.id) : f.label };
    final clubLabel = { for (final c in data.clubs) _normPath(c.id) : c.label };

    final pills = <Widget>[];

    // Faculties
    for (final rawId in _facultySel) {
      final id = _normPath(rawId);
      final label = facLabel[id] ?? id.split('/').last;
      pills.add(_smallRemovablePill(label, onRemove: () {
        setState(() {
          _facultySel.removeWhere((x) => _normPath(x) == id);
        });
      }));
    }

    // Clubs
    for (final rawId in _clubSel) {
      final id = _normPath(rawId);
      final label = clubLabel[id] ?? id.split('/').last;
      pills.add(_smallRemovablePill(label, onRemove: () {
        setState(() => _clubSel.removeWhere((x) => _normPath(x) == id));
      }));
    }

    if (pills.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selected', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: pills),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _smallRemovablePill(String label, {required VoidCallback onRemove}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF2F3),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFDDE3E6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const Icon(Icons.close, size: 16, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _bottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() {
                _facultySel.clear();
                _clubSel.clear();
              } ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sage,
                side: const BorderSide(color: AppColors.sage),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60)),
              ),
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final hasAny = _facultySel.isNotEmpty || _clubSel.isNotEmpty;

                if (!hasAny) {
                  // ไม่มีตัวเลือกใด ๆ → คืนค่า null
                  Navigator.of(context).pop<FilterSheetResult?>(null);
                  return;
                }
                Navigator.of(context).pop(
                  FilterSheetResult(
                    facultyIds: _facultySel,
                    clubIds: _clubSel,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sage,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(60)),
                elevation: 2,
              ),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────────────────────────────────────────────────────────────
 *  Loader ผ่าน DatabaseService (ไม่ยิง http ตรง)
 * ────────────────────────────────────────────────────────────────────────────*/

String _normPath(String p) {
  var s = p.trim();
  if (s.isEmpty) return s;
  if (!s.startsWith('/')) s = '/$s';
  if (s.endsWith('/') && s.length > 1) s = s.substring(0, s.length - 1);
  s = s.replaceAll(RegExp(r'/+'), '/');
  return s;
}

/// เดินต้นไม้ org แล้ว flatten เป็น OptionItem(org_path, name)
List<OptionItem> _extractNodes(dynamic data) {
  final out = <OptionItem>[];

  void dig(dynamic n) {
    if (n == null) return;
    if (n is List) { for (final x in n) { dig(x); } return; }
    if (n is Map<String, dynamic>) {
      final rawPath = (n['org_path'] ?? n['path'] ?? n['orgPath'] ?? '').toString();
      final path = _normPath(rawPath);
      final name = (n['name'] ?? n['display_name'] ?? n['title'] ?? n['label'] ?? path).toString();
      if (path.isNotEmpty) out.add(OptionItem(path, name));
      final children = n['children'];
      if (children != null) dig(children);
      return;
    }
  }

  dig(data);
  return out;
}

/// หา segment ราก (เช่น 'fac' หรือ 'faculty' หรือ 'faculties')
String? _detectRootSegment(Iterable<OptionItem> nodes, List<String> candidates) {
  final seen = nodes.map((n) => _normPath(n.id)).toList();
  for (final seg in candidates) {
    final pat = RegExp('/$seg(/|\$)');
    if (seen.any((p) => pat.hasMatch(p))) return seg;
  }
  return null;
}

/// คืน “คณะ” เป็นลูกชั้นแรกของ <segment>
List<OptionItem> _immediateChildrenBySegment(List<OptionItem> flat, String segment) {
  final out = <String, String>{}; // id -> label
  final labelById = { for (final n in flat) _normPath(n.id) : n.label };

  for (final n in flat) {
    final id = _normPath(n.id);
    final parts = id.split('/'); // ["", "...", "fac|faculty", "<fac>", ...]
    final idx = parts.indexOf(segment);
    if (idx <= 0) continue;
    if (idx + 1 >= parts.length) continue;
    final facId = '/$segment/${parts[idx + 1]}';
    out.putIfAbsent(facId, () => labelById[facId] ?? n.label);
  }
  return out.entries.map((e) => OptionItem(e.key, e.value)).toList();
}

/// อยู่ใต้คณะที่กำหนด (ทุกชั้น)
bool _isUnderFacultyBySegment(String nodeId, String facultyId, String segment) {
  final nid = _normPath(nodeId);
  final fid = _normPath(facultyId);
  final facSlug = fid.split('/').last;
  return RegExp('/$segment/${RegExp.escape(facSlug)}/').hasMatch('$nid/');
}

/// โหลด filters ทั้งหมดผ่าน DatabaseService
Future<FilterData> loadFiltersWithDb(DatabaseService db) async {
  // Faculties tree
  List<Map<String, dynamic>> facTree = const [];
  for (final start in const ['/fac', '/faculty', '/faculties']) {
    try {
      facTree = await db.getOrgTreeFiber(start: start, depth: 10);
      if (facTree.isNotEmpty) break;
    } catch (_) {/* try next */}
  }
  final facNodes = _extractNodes(facTree);
  final rootSeg = _detectRootSegment(facNodes, const ['fac', 'faculty', 'faculties']);
  final List<OptionItem> faculties = (rootSeg == null)
      ? const <OptionItem>[]
      : _immediateChildrenBySegment(facNodes, rootSeg);

  // Departments not used in this sheet
  final Map<String, List<OptionItem>> departmentsByFaculty = {
    for (final f in faculties) _normPath(f.id): const <OptionItem>[],
  };

  // Clubs (all descendants)
  List<Map<String, dynamic>> clubTree = const [];
  for (final start in const ['/club', '/clubs']) {
    try {
      clubTree = await db.getOrgTreeFiber(start: start, depth: 10);
      if (clubTree.isNotEmpty) break;
    } catch (_) {/* try next */}
  }
  final clubNodes = _extractNodes(clubTree);
  final List<OptionItem> clubs = clubNodes.where((n) {
    final id = _normPath(n.id);
    return id.startsWith('/club/') || id.startsWith('/clubs/');
  }).map((n) => OptionItem(_normPath(n.id), n.label)).toList();

  // Categories removed for event filter sheet
  final categories = const <OptionItem>[];

  // sort by label
  int _cmp(OptionItem a, OptionItem b) =>
      a.label.toLowerCase().compareTo(b.label.toLowerCase());
  faculties.sort(_cmp);
  clubs.sort(_cmp);

  return FilterData(
    faculties: faculties,
    clubs: clubs,
    categories: categories,
    departmentsByFaculty: departmentsByFaculty,
  );
}

// ใช้ชื่อง่ายๆ ให้หน้าอื่นเรียก
Future<FilterData> mockLoadFilters() {
  final db = DatabaseService();
  return loadFiltersWithDb(db);
}
