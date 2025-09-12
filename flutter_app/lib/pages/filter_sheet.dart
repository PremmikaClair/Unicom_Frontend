import 'package:flutter/material.dart';
import '../components/app_colors.dart';

/// ---------- Models ----------
class OptionItem {
  final String id;
  final String label;
  const OptionItem(this.id, this.label);
}

class FilterData {
  final List<OptionItem> faculties;           // Roles > Faculty (with Departments)
  final List<OptionItem> clubs;               // Roles > Clubs
  final List<OptionItem> categories;          // Category tab
  final List<OptionItem> roles;               // Roles > Others (Student/Teacher/Staff)
  final Map<String, List<OptionItem>> departmentsByFaculty; // facultyId -> departments

  FilterData({
    required this.faculties,
    required this.clubs,
    required this.categories,
    required this.roles,
    Map<String, List<OptionItem>>? departmentsByFaculty,
  }) : departmentsByFaculty = departmentsByFaculty ?? {};

  FilterData mergeWith({
    List<OptionItem>? faculties,
    List<OptionItem>? clubs,
    List<OptionItem>? categories,
    List<OptionItem>? roles,
    Map<String, List<OptionItem>>? departmentsByFaculty,
  }) {
    List<OptionItem> _mergeList(List<OptionItem> base, List<OptionItem>? inc) {
      if (inc == null) return base;
      final byId = {for (final o in base) o.id: o};
      for (final o in inc) {
        byId[o.id] = o; // API overrides base on same id
      }
      return byId.values.toList();
    }

    Map<String, List<OptionItem>> _mergeMap(
      Map<String, List<OptionItem>> base,
      Map<String, List<OptionItem>>? inc,
    ) {
      if (inc == null) return base;
      final out = <String, List<OptionItem>>{...base};
      for (final e in inc.entries) {
        out[e.key] = _mergeList(base[e.key] ?? const [], e.value);
      }
      return out;
    }

    return FilterData(
      faculties: _mergeList(this.faculties, faculties),
      clubs: _mergeList(this.clubs, clubs),
      categories: _mergeList(this.categories, categories),
      roles: _mergeList(this.roles, roles),
      departmentsByFaculty: _mergeMap(this.departmentsByFaculty, departmentsByFaculty),
    );
  }
}

/// Result back to caller
class FilterSheetResult {
  final Set<String> facultyIds;
  final Set<String> clubIds;
  final Set<String> categoryIds;
  final Set<String> departmentIds;
  final Set<String> rolesIds;

  const FilterSheetResult({
    this.facultyIds = const <String>{},
    this.clubIds = const <String>{},
    this.categoryIds = const <String>{},
    this.departmentIds = const <String>{},
    this.rolesIds = const <String>{},
  });

  FilterSheetResult copyWith({
    Set<String>? facultyIds,
    Set<String>? clubIds,
    Set<String>? categoryIds,
    Set<String>? departmentIds,
    Set<String>? rolesIds,
  }) {
    return FilterSheetResult(
      facultyIds: facultyIds ?? this.facultyIds,
      clubIds: clubIds ?? this.clubIds,
      categoryIds: categoryIds ?? this.categoryIds,
      departmentIds: departmentIds ?? this.departmentIds,
      rolesIds: rolesIds ?? this.rolesIds,
    );
  }
}

/// Left menu: ONLY 2 top-level tabs
enum _TabId { roles, category }

/// Roles sub-menu buttons (left)
enum _RolesSub { faculty, clubs, others }

/// Global-search suggestion types
enum _SugType { faculty, department, club, category, role }

class _Suggestion {
  final _SugType type;
  final String id;
  final String label;
  final String? parentFacultyId;
  final String? parentFacultyLabel;

  const _Suggestion({
    required this.type,
    required this.id,
    required this.label,
    this.parentFacultyId,
    this.parentFacultyLabel,
  });
}

/// ---------- Bottom Sheet ----------
class FilterBottomSheet extends StatefulWidget {
  /// Load filters from backend API
  final Future<FilterData> Function() loadFilters;

  /// Initial selections
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
  _TabId _current = _TabId.roles; // default
  _RolesSub _currentRolesSub = _RolesSub.faculty;
  bool _rolesExpanded = true;
 


  // selections
  late Set<String> _facultySel;
  late Set<String> _clubSel;
  late Set<String> _categorySel;
  late Set<String> _rolesSel;
  late Set<String> _deptSel;

  // future cache
  late Future<FilterData> _filtersFuture;

  // scroll + section keys
  final ScrollController _rightScroll = ScrollController();
  // Top-level sections
  final _rolesTopKey = GlobalKey();
  final _categoryTopKey = GlobalKey();
  // Sub-sections inside Roles
  final _rolesFacultyKey = GlobalKey();
  final _rolesClubsKey = GlobalKey();
  final _rolesOthersKey = GlobalKey();

  // faculty -> expanded departments?
  final Map<String, bool> _deptOpenByFaculty = {};

  // expand toggles
  bool _expandClubs = false;
  bool _expandCategories = false;
  bool _expandRolesOthers = false;
  static const int _showLimit = 10;

  // ---------- Global Search ----------
  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFn = FocusNode();
  String _globalQuery = '';

  @override
  void initState() {
    super.initState();
    _facultySel = {...widget.initial.facultyIds};
    _clubSel = {...widget.initial.clubIds};
    _categorySel = {...widget.initial.categoryIds};
    _deptSel = {...widget.initial.departmentIds};
    _rolesSel = {...widget.initial.rolesIds};

    // All data from API — no hardcoded base defaults
    _filtersFuture = widget.loadFilters().then((data) {
      for (final f in data.faculties) {
        _deptOpenByFaculty.putIfAbsent(f.id, () => false);
      }
      return data;
    });

    _rightScroll.addListener(_onRightScroll);

    _searchCtl.addListener(() {
      setState(() {
        _globalQuery = _searchCtl.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _rightScroll.removeListener(_onRightScroll);
    _rightScroll.dispose();
    _searchCtl.dispose();
    _searchFn.dispose();
    super.dispose();
  }

  // ===== Scroll-sync: update left highlight while right pane scrolls =====
  void _onRightScroll() {
    if (_globalQuery.isNotEmpty) return; // don't auto-switch while searching
    _maybeUpdateCurrent(_rolesTopKey, _TabId.roles);
    _maybeUpdateCurrent(_categoryTopKey, _TabId.category);

    if (_current == _TabId.roles) {
      _maybeUpdateCurrentRolesSub();
    }
  }

  void _maybeUpdateCurrent(GlobalKey key, _TabId tab) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < 140 && top > -box.size.height / 2) {
      if (_current != tab) setState(() => _current = tab);
    }
  }

  bool _isInView(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return false;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final top = box.localToGlobal(Offset.zero).dy;
    return top < 220 && top > -box.size.height * 0.4;
  }

  void _maybeUpdateCurrentRolesSub() {
    if (_isInView(_rolesFacultyKey)) {
      if (_currentRolesSub != _RolesSub.faculty) {
        setState(() => _currentRolesSub = _RolesSub.faculty);
      }
    } else if (_isInView(_rolesClubsKey)) {
      if (_currentRolesSub != _RolesSub.clubs) {
        setState(() => _currentRolesSub = _RolesSub.clubs);
      }
    } else if (_isInView(_rolesOthersKey)) {
      if (_currentRolesSub != _RolesSub.others) {
        setState(() => _currentRolesSub = _RolesSub.others);
      }
    }
  }

  // Smooth scroll to a section
  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.05,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _clearAll() {
    setState(() {
      _facultySel.clear();
      _clubSel.clear();
      _categorySel.clear();
      _deptSel.clear();
      _rolesSel.clear();
      for (final k in _deptOpenByFaculty.keys) {
        _deptOpenByFaculty[k] = false;
      }
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      FilterSheetResult(
        facultyIds: _facultySel,
        clubIds: _clubSel,
        categoryIds: _categorySel,
        departmentIds: _deptSel,
        rolesIds: _rolesSel,
      ),
    );
  }

  // ---------- SEARCH UI ----------
  Widget _buildSearchBar(FilterData data) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _searchCtl,
            focusNode: _searchFn,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search (Faculty/Dept/Clubs/Categories/Roles)',
              hintStyle: const TextStyle(fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              suffixIcon: (_globalQuery.isNotEmpty)
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _globalQuery = '';
                          _searchCtl.clear();
                        });
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
          ),
        ),
        if (_globalQuery.isNotEmpty)
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.40,
            child: _buildSuggestions(data, _globalQuery),
          )
      ],
    );
  }

  Widget _buildSuggestions(FilterData data, String queryRaw) {
    final q = queryRaw.toLowerCase();
    final suggestions = <_Suggestion>[];

    // Faculty + Departments
    for (final f in data.faculties) {
      if (f.label.toLowerCase().contains(q)) {
        suggestions.add(_Suggestion(type: _SugType.faculty, id: f.id, label: f.label));
      }
      for (final d in (data.departmentsByFaculty[f.id] ?? const <OptionItem>[])) {
        if (d.label.toLowerCase().contains(q)) {
          suggestions.add(_Suggestion(
            type: _SugType.department,
            id: d.id,
            label: d.label,
            parentFacultyId: f.id,
            parentFacultyLabel: f.label,
          ));
        }
      }
    }

    // Clubs
    for (final c in data.clubs) {
      if (c.label.toLowerCase().contains(q)) {
        suggestions.add(_Suggestion(type: _SugType.club, id: c.id, label: c.label));
      }
    }

    // Categories
    for (final c in data.categories) {
      if (c.label.toLowerCase().contains(q)) {
        suggestions.add(_Suggestion(type: _SugType.category, id: c.id, label: c.label));
      }
    }

    // Roles (Others)
    for (final r in data.roles) {
      if (r.label.toLowerCase().contains(q)) {
        suggestions.add(_Suggestion(type: _SugType.role, id: r.id, label: r.label));
      }
    }

    if (suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text(
          'No matches in Faculty/Departments/Clubs/Categories/Roles',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    final fac  = suggestions.where((s) => s.type == _SugType.faculty).toList();
    final dept = suggestions.where((s) => s.type == _SugType.department).toList();
    final club = suggestions.where((s) => s.type == _SugType.club).toList();
    final cat  = suggestions.where((s) => s.type == _SugType.category).toList();
    final role = suggestions.where((s) => s.type == _SugType.role).toList();

    Widget _group(String title, List<_Suggestion> items, Color color) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          ...items.take(8).map((s) => ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -2),
                title: Text(s.label),
                subtitle: (s.type == _SugType.department && s.parentFacultyLabel != null)
                    ? Text('Department · ${s.parentFacultyLabel}', style: const TextStyle(fontSize: 12))
                    : null,
                trailing: _typeChip(s.type),
                onTap: () => _onSelectSuggestion(data, s),
              )),
          const SizedBox(height: 4),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Color(0x14000000), offset: Offset(0, 2))],
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _group('Faculty', fac, Colors.teal),
            _group('Departments', dept, Colors.teal.shade700),
            _group('Clubs', club, Colors.indigo),
            _group('Categories', cat, Colors.orange),
            _group('Roles (Others)', role, Colors.brown),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(_SugType t) {
    String text; Color color;
    switch (t) {
      case _SugType.faculty:    text = 'Faculty';    color = Colors.teal; break;
      case _SugType.department: text = 'Dept.';      color = Colors.teal.shade700; break;
      case _SugType.club:       text = 'Club';       color = Colors.indigo; break;
      case _SugType.category:   text = 'Category';   color = Colors.orange; break;
      case _SugType.role:       text = 'Role';       color = Colors.brown; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  void _onSelectSuggestion(FilterData data, _Suggestion s) {
    setState(() {
      switch (s.type) {
        case _SugType.faculty:
          _toggleFaculty(data, s.id);
          _scrollTo(_rolesTopKey);
          _current = _TabId.roles;
          _currentRolesSub = _RolesSub.faculty;
          break;
        case _SugType.department:
          final fid = s.parentFacultyId!;
          if (!_facultySel.contains(fid)) _facultySel.add(fid);
          _openOnlyFaculty(fid);
          _deptSel.contains(s.id) ? _deptSel.remove(s.id) : _deptSel.add(s.id);
          _scrollTo(_rolesTopKey);
          _current = _TabId.roles;
          _currentRolesSub = _RolesSub.faculty;
          break;
        case _SugType.club:
          _clubSel.contains(s.id) ? _clubSel.remove(s.id) : _clubSel.add(s.id);
          _scrollTo(_rolesTopKey);
          _current = _TabId.roles;
          _currentRolesSub = _RolesSub.clubs;
          break;
        case _SugType.category:
          _categorySel.contains(s.id) ? _categorySel.remove(s.id) : _categorySel.add(s.id);
          _scrollTo(_categoryTopKey);
          _current = _TabId.category;
          break;
        case _SugType.role:
          _rolesSel.contains(s.id) ? _rolesSel.remove(s.id) : _rolesSel.add(s.id);
          _scrollTo(_rolesTopKey);
          _current = _TabId.roles;
          _currentRolesSub = _RolesSub.others;
          break;
      }
    });
  }

  void _openOnlyFaculty(String fid) {
    for (final key in _deptOpenByFaculty.keys) {
      _deptOpenByFaculty[key] = key == fid;
    }
  }

  void _toggleFaculty(FilterData data, String facultyId) {
    final isSelected = _facultySel.contains(facultyId);
    if (isSelected) {
      setState(() {
        _facultySel.remove(facultyId);
        _deptOpenByFaculty[facultyId] = false;
      });
    } else {
      setState(() {
        _facultySel.add(facultyId);
        _openOnlyFaculty(facultyId);
      });
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return FutureBuilder<FilterData>(
          future: _filtersFuture,
          builder: (context, snap) {
            final left = _buildLeftMenu();
            Widget right;

            if (snap.connectionState == ConnectionState.waiting) {
              right = const Center(child: CircularProgressIndicator());
            } else if (snap.hasError || !snap.hasData) {
              right = Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Failed to load filters'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => setState(() { _filtersFuture = widget.loadFilters(); }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            } else {
              right = Column(
                children: [
                  _buildSearchBar(snap.data!),
                  const Divider(height: 1),
                  Expanded(child: _buildRightPanels(snap.data!)),
                ],
              );
            }

            return _sheetScaffold(left: left, right: right);
          },
        );
      },
    );
  }

  Widget _sheetScaffold({required Widget left, required Widget right}) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 140, child: left),
                  const VerticalDivider(width: 1),
                  Expanded(child: right),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(blurRadius: 12, color: Color(0x22000000), offset: Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearAll,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.deepGreen,
                        side: const BorderSide(color: AppColors.sage),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// ===== Left menu (Roles box has triangle inside, after the word "Roles") =====
Widget _buildLeftMenu() {
  final bool isRolesActive = (_globalQuery.isEmpty && _current == _TabId.roles);
  final bool isCategoryActive = (_globalQuery.isEmpty && _current == _TabId.category);

  return ListView(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
    children: [
      // ===== Box: Roles =====
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () {
            if (_globalQuery.isNotEmpty) return;
            _scrollTo(_rolesTopKey);
            setState(() {
              _current = _TabId.roles;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isRolesActive ? Colors.white : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isRolesActive ? AppColors.sage : const Color(0xFFE0E0E0),
                width: 1.2,
              ),
              boxShadow: isRolesActive
                  ? const [BoxShadow(
                      blurRadius: 10,
                      color: Color(0x15000000),
                      offset: Offset(0, 2),
                    )]
                  : const [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // label
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isRolesActive ? AppColors.sage : const Color(0xFFBDBDBD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Roles',
                      style: TextStyle(
                        fontWeight: isRolesActive ? FontWeight.w700 : FontWeight.w500,
                        color: isRolesActive ? AppColors.sage : Colors.black87,
                      ),
                    ),
                  ],
                ),
                // triangle on the right
                GestureDetector(
                  onTap: () {
                    setState(() => _rolesExpanded = !_rolesExpanded);
                  },
                  child: Icon(
                    _rolesExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    size: 20,
                    color: isRolesActive ? AppColors.sage : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // sub menu under Roles (Faculty / Clubs / Others) — only when expanded and current tab is Roles
      if (_current == _TabId.roles && _rolesExpanded) ...[
        const SizedBox(height: 10),
        _rolesSubButton(
          title: 'Faculty',
          active: _currentRolesSub == _RolesSub.faculty,
          onTap: () {
            if (_globalQuery.isNotEmpty) return;
            _scrollTo(_rolesFacultyKey);
            setState(() => _currentRolesSub = _RolesSub.faculty);
          },
        ),
        _rolesSubButton(
          title: 'Clubs',
          active: _currentRolesSub == _RolesSub.clubs,
          onTap: () {
            if (_globalQuery.isNotEmpty) return;
            _scrollTo(_rolesClubsKey);
            setState(() => _currentRolesSub = _RolesSub.clubs);
          },
        ),
        _rolesSubButton(
          title: 'Others',
          active: _currentRolesSub == _RolesSub.others,
          onTap: () {
            if (_globalQuery.isNotEmpty) return;
            _scrollTo(_rolesOthersKey);
            setState(() => _currentRolesSub = _RolesSub.others);
          },
        ),
      ],

      const SizedBox(height: 16),

      // ===== Box: Category (unchanged) =====
      InkWell(
        onTap: () {
          if (_globalQuery.isNotEmpty) return;
          _scrollTo(_categoryTopKey);
          setState(() {
            _current = _TabId.category;
            _rolesExpanded = false; // common UX: collapse Roles when switching tab
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isCategoryActive ? Colors.white : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCategoryActive ? AppColors.sage : const Color(0xFFE0E0E0),
              width: 1.2,
            ),
            boxShadow: isCategoryActive
                ? const [BoxShadow(blurRadius: 10, color: Color(0x15000000), offset: Offset(0, 2))]
                : const [],
          ),
          child: Row(
            children: [
              Container(
                width: 3, height: 18,
                decoration: BoxDecoration(
                  color: isCategoryActive ? AppColors.sage : const Color(0xFFBDBDBD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Category',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}


  // Square full-width button for Roles sub items
  Widget _rolesSubButton({
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.sage : const Color(0xFFE0E0E0),
              width: active ? 1.2 : 1,
            ),
            boxShadow: active
                ? const [BoxShadow(blurRadius: 10, color: Color(0x15000000), offset: Offset(0, 2))]
                : const [],
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: active ? AppColors.sage : const Color(0xFFBDBDBD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.sage : Colors.black87,
                  ),
                ),
              ),
              if (active) const Icon(Icons.check, size: 16, color: AppColors.sage),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Right side: 2 big sections =====
  Widget _buildRightPanels(FilterData data) {
    return ListView(
      controller: _rightScroll,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        // ---- ROLES (Faculty + Clubs + Others) ----
        _sectionHeader(key: _rolesTopKey, title: 'Roles', color: Colors.brown),

        const SizedBox(height: 12),
        _subHeader('Faculty', Colors.teal, key: _rolesFacultyKey),
        const SizedBox(height: 10),
        ...data.faculties.map((f) => _buildFacultyBlock(data, f)).toList(),

        const SizedBox(height: 18),
        _subHeader('Clubs', Colors.indigo, key: _rolesClubsKey),
        const SizedBox(height: 10),
        _pillsWithLimit(
          items: data.clubs,
          selected: _clubSel,
          color: Colors.indigo,
          expanded: _expandClubs,
          onToggle: (id) => setState(() {
            _clubSel.contains(id) ? _clubSel.remove(id) : _clubSel.add(id);
            _current = _TabId.roles;
            _currentRolesSub = _RolesSub.clubs;
          }),
          onToggleExpand: () => setState(() => _expandClubs = !_expandClubs),
        ),

        const SizedBox(height: 18),
        _subHeader('Others', Colors.brown, key: _rolesOthersKey),
        const SizedBox(height: 10),
        _pillsWithLimit(
          items: data.roles,
          selected: _rolesSel,
          color: Colors.brown,
          expanded: _expandRolesOthers,
          onToggle: (id) => setState(() {
            _rolesSel.contains(id) ? _rolesSel.remove(id) : _rolesSel.add(id);
            _current = _TabId.roles;
            _currentRolesSub = _RolesSub.others;
          }),
          onToggleExpand: () => setState(() => _expandRolesOthers = !_expandRolesOthers),
        ),

        const SizedBox(height: 28),

        // ---- CATEGORY ----
        _sectionHeader(key: _categoryTopKey, title: 'Category', color: Colors.orange),
        const SizedBox(height: 10),
        _pillsWithLimit(
          items: data.categories,
          selected: _categorySel,
          color: Colors.orange,
          expanded: _expandCategories,
          onToggle: (id) => setState(() {
            _categorySel.contains(id) ? _categorySel.remove(id) : _categorySel.add(id);
            _current = _TabId.category;
          }),
          onToggleExpand: () => setState(() => _expandCategories = !_expandCategories),
        ),
      ],
    );
  }

  // Faculty block with optional Departments list
  Widget _buildFacultyBlock(FilterData data, OptionItem faculty) {
    final fid = faculty.id;
    final isSelected = _facultySel.contains(fid);
    final isOpen = _deptOpenByFaculty[fid] ?? false;

    final facultyPill = Wrap(
      spacing: 8, runSpacing: 10,
      children: _buildMultiPills(
        [faculty],
        _facultySel,
        Colors.teal,
        onToggle: (_) => _toggleFaculty(data, fid),
      ),
    );

    Widget deptArea = const SizedBox.shrink();
    if (isSelected && isOpen) {
      final depts = data.departmentsByFaculty[fid] ?? const <OptionItem>[];

      if (depts.isEmpty) {
        deptArea = const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('No departments for this faculty', style: TextStyle(color: Colors.black54)),
        );
      } else {
        const showLimit = 6;
        final expandedKey = 'deptLimit:$fid';
        final isExpanded = _deptOpenByFaculty[expandedKey] ?? false;
        final visible = isExpanded ? depts : depts.take(showLimit).toList();

        deptArea = Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _subHeader('Departments (${faculty.label})', Colors.teal),
              const SizedBox(height: 8),

              _buildSelectAllPillForFaculty(data, fid),

              const SizedBox(height: 8),

              Wrap(
                spacing: 8, runSpacing: 10,
                children: _buildMultiPills(
                  visible,
                  _deptSel,
                  Colors.teal.shade700,
                  onToggle: (id) => setState(() {
                    _deptSel.contains(id) ? _deptSel.remove(id) : _deptSel.add(id);
                    _current = _TabId.roles;
                    _currentRolesSub = _RolesSub.faculty;
                  }),
                ),
              ),
              if (depts.length > showLimit) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () =>
                      setState(() => _deptOpenByFaculty[expandedKey] = !isExpanded),
                  child: Text(isExpanded ? 'Show less' : 'Show more'),
                ),
              ],
            ],
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [facultyPill, deptArea],
      ),
    );
  }

  Widget _sectionHeader({required Key key, required String title, required Color color}) {
    return Container(
      key: key,
      child: Row(
        children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _subHeader(String title, Color color, {Key? key}) {
    return Row(
      key: key,
      children: [
        Container(
          width: 3, height: 14,
          decoration: BoxDecoration(color: color.withOpacity(.7), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // "Select all" departments for a faculty
  Widget _buildSelectAllPillForFaculty(FilterData data, String fid) {
    final allSelected = _areAllDeptsSelectedForFaculty(data, fid);
    final Color color = Colors.teal;
    return InkWell(
      onTap: () => _toggleSelectAllDeptsForFaculty(data, fid),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: allSelected ? color.withOpacity(.08) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: allSelected ? color : Colors.transparent, width: 1.2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (allSelected) Icon(Icons.check, size: 14, color: color),
          if (allSelected) const SizedBox(width: 6),
          const Text('Select all', style: TextStyle(fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _pillsWithLimit({
    required List<OptionItem> items,
    required Set<String> selected,
    required Color color,
    required bool expanded,
    required void Function(String id) onToggle,
    required VoidCallback onToggleExpand,
  }) {
    final showItems = expanded ? items : items.take(_showLimit).toList();
    final pills = _buildMultiPills(showItems, selected, color, onToggle: onToggle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pills.isEmpty)
          const Text('No items', style: TextStyle(color: Colors.black54))
        else
          Wrap(spacing: 8, runSpacing: 10, children: pills),
        if (items.length > _showLimit && !expanded) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onToggleExpand, child: const Text('Show more')),
        ],
      ],
    );
  }

  List<Widget> _buildMultiPills(
    List<OptionItem> options,
    Set<String> selected,
    Color color, {
    required void Function(String id) onToggle,
  }) {
    return options.map((o) {
      final sel = selected.contains(o.id);
      return InkWell(
        onTap: () => onToggle(o.id),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(.08) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: sel ? color : Colors.transparent, width: 1.2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (sel) Icon(Icons.check, size: 14, color: color),
            if (sel) const SizedBox(width: 6),
            Text(
              o.label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: sel ? color : Colors.black87,
              ),
            ),
          ]),
        ),
      );
    }).toList();
  }

  // ---- Helpers for departments per faculty ----
  Set<String> _deptIdsForFaculty(FilterData data, String fid) {
    return (data.departmentsByFaculty[fid] ?? const <OptionItem>[]).map((e) => e.id).toSet();
  }

  bool _areAllDeptsSelectedForFaculty(FilterData data, String fid) {
    final all = _deptIdsForFaculty(data, fid);
    if (all.isEmpty) return false;
    return all.every(_deptSel.contains);
  }

  void _toggleSelectAllDeptsForFaculty(FilterData data, String fid) {
    final all = _deptIdsForFaculty(data, fid);
    if (all.isEmpty) return;
    final allSelected = _areAllDeptsSelectedForFaculty(data, fid);
    setState(() {
      if (allSelected) {
        _deptSel.removeAll(all);
      } else {
        _deptSel.addAll(all);
      }
      _current = _TabId.roles;
      _currentRolesSub = _RolesSub.faculty;
    });
  }
}

/// ---------- Mock API loader (replace with real API) ----------
Future<FilterData> mockLoadFilters() async {
  await Future.delayed(const Duration(milliseconds: 300));

  final faculties = const [
    OptionItem('eng', 'Engineering'),
    OptionItem('sci', 'Science'),
    OptionItem('eco', 'Economics'),
    OptionItem('arch', 'Architecture'),
    OptionItem('bus', 'Business Administration'),
  ];

  final departments = <String, List<OptionItem>>{
    'eng': [
      OptionItem('eng.comp', 'Computer Engineering'),
      OptionItem('eng.elec', 'Electrical Engineering'),
      OptionItem('eng.civ', 'Civil Engineering'),
      OptionItem('eng.me', 'Mechanical Engineering'),
    ],
    'sci': [
      OptionItem('sci.math', 'Mathematics'),
      OptionItem('sci.phys', 'Physics'),
      OptionItem('sci.chem', 'Chemistry'),
    ],
  };

  final clubs = const [
    OptionItem('music', 'Music Club'),
    OptionItem('film', 'Film Club'),
    OptionItem('coding', 'Coding Club'),
    OptionItem('vol', 'Volunteer Club'),
    OptionItem('sport', 'Sports Club'),
  ];

  final categories = const [
    OptionItem('market', 'Marketplace'),
    OptionItem('study', 'Study / Tutoring'),
    OptionItem('event', 'Events'),
    OptionItem('life', 'Lifestyle'),
    OptionItem('job', 'Jobs / Internships'),
  ];

  final rolesOthers = const [
    OptionItem('student', 'Student'),
    OptionItem('teacher', 'Teacher'),
    OptionItem('staff', 'Staff'),
  ];

  return FilterData(
    faculties: faculties,
    clubs: clubs,
    categories: categories,
    roles: rolesOthers,
    departmentsByFaculty: departments,
  );
}

/// ---------- Demo Scaffold (optional) ----------
/// ใช้ทดสอบในแอป: Navigator.of(context).push(...)
class FilterDemoPage extends StatelessWidget {
  const FilterDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Filter Demo')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Open Filter BottomSheet'),
          onPressed: () async {
            final result = await showModalBottomSheet<FilterSheetResult>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => FilterBottomSheet(loadFilters: mockLoadFilters),
            );
            debugPrint('Result: $result');
          },
        ),
      ),
    );
  }
}