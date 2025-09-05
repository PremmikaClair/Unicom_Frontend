import 'package:flutter/material.dart';
import '../components/app_colors.dart';

/// ---------- Models ----------
class OptionItem {
  final String id;
  final String label;
  const OptionItem(this.id, this.label);
}

class FilterData {
  final List<OptionItem> faculties;
  final List<OptionItem> clubs;
  final List<OptionItem> categories;

  /// mapping คณะ -> ภาควิชา (รับจาก API เท่านั้น)
  final Map<String, List<OptionItem>> departmentsByFaculty;

  // [CHANGED] ไม่ใช้ const และไม่ตั้ง default เป็น const {}
  FilterData({
    required this.faculties,
    required this.clubs,
    required this.categories,
    Map<String, List<OptionItem>>? departmentsByFaculty,
  }) : departmentsByFaculty = departmentsByFaculty ?? {};

  /// merge base + จาก API (id ชนกันถือว่าอัปเดต label)
  FilterData mergeWith({
    List<OptionItem>? faculties,
    List<OptionItem>? clubs,
    List<OptionItem>? categories,
    Map<String, List<OptionItem>>? departmentsByFaculty,
  }) {
    List<OptionItem> _mergeList(List<OptionItem> base, List<OptionItem>? inc) {
      if (inc == null) return base;
      final byId = {for (final o in base) o.id: o};
      for (final o in inc) {
        byId[o.id] = o; // api ทับ base เมื่อ id ซ้ำ
      }
      return byId.values.toList();
    }

    Map<String, List<OptionItem>> _mergeMap(
      Map<String, List<OptionItem>> base,
      Map<String, List<OptionItem>>? inc,
    ) {
      if (inc == null) return base;
      final out = <String, List<OptionItem>>{...base};
      for (final entry in inc.entries) {
        final merged = _mergeList(base[entry.key] ?? <OptionItem>[], entry.value);
        out[entry.key] = merged;
      }
      return out;
    }

    return FilterData(
      faculties: _mergeList(this.faculties, faculties),
      clubs: _mergeList(this.clubs, clubs),
      categories: _mergeList(this.categories, categories),
      departmentsByFaculty: _mergeMap(this.departmentsByFaculty, departmentsByFaculty),
    );
  }
}

/// ผลลัพธ์ที่ส่งกลับไปหน้า caller
class FilterSheetResult {
  final Set<String> facultyIds;
  final Set<String> clubIds;
  final Set<String> categoryIds;
  final Set<String> departmentIds;

  const FilterSheetResult({
    this.facultyIds = const <String>{},
    this.clubIds = const <String>{},
    this.categoryIds = const <String>{},
    this.departmentIds = const <String>{},
  });

  FilterSheetResult copyWith({
    Set<String>? facultyIds,
    Set<String>? clubIds,
    Set<String>? categoryIds,
    Set<String>? departmentIds,
  }) {
    return FilterSheetResult(
      facultyIds: facultyIds ?? this.facultyIds,
      clubIds: clubIds ?? this.clubIds,
      categoryIds: categoryIds ?? this.categoryIds,
      departmentIds: departmentIds ?? this.departmentIds,
    );
  }
}

enum _TabId { faculty, club, category } // left tab

enum _SugType { faculty, department, club, category }

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
  /// โหลดตัวเลือกจาก backend (ใส่ service จริงได้)
  final Future<FilterData> Function() loadFilters;

  /// ค่าเริ่มต้นที่เลือกไว้
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
  _TabId _current = _TabId.faculty;

  // selections
  late Set<String> _facultySel;
  late Set<String> _clubSel;
  late Set<String> _categorySel;
  late Set<String> _deptSel;

  // future cache
  late Future<FilterData> _filtersFuture;

  // scroll + section keys
  final ScrollController _rightScroll = ScrollController();
  final _facultyKey = GlobalKey();
  final _clubKey = GlobalKey();
  final _categoryKey = GlobalKey();

  // เปิด/ปิด “ภาควิชา” ต่อคณะ
  final Map<String, bool> _deptOpenByFaculty = {}; // fid -> isOpen

  // limit
  bool _expandClub = false;
  bool _expandCategory = false;
  static const int _showLimit = 8;

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

    _filtersFuture = _buildMergedFuture();

    _rightScroll.addListener(_onRightScroll);

    _searchCtl.addListener(() {
      setState(() {
        _globalQuery = _searchCtl.text.trim();
      });
    });
  }

  Future<FilterData> _buildMergedFuture() {
    // base (ไม่มี departmentsByFaculty ติดมาด้วย — รอ API)
    final base = FilterData(
      faculties: const [
        OptionItem('eng', 'วิศวกรรมศาสตร์'),
        OptionItem('sci', 'วิทยาศาสตร์'),
        OptionItem('eco', 'เศรษฐศาสตร์'),
        OptionItem('arch', 'สถาปัตยกรรม'),
      ],
      clubs: const [],
      categories: const [],
      // ไม่ส่งพารามิเตอร์ = จะได้ {} อัตโนมัติ (non-const)
    );

    return widget
        .loadFilters()
        .then((api) => base.mergeWith(
              faculties: api.faculties,
              clubs: api.clubs,
              categories: api.categories,
              departmentsByFaculty: api.departmentsByFaculty, // รับจาก API เท่านั้น
            ))
        .then((data) {
      for (final f in data.faculties) {
        _deptOpenByFaculty.putIfAbsent(f.id, () => false);
      }
      return data;
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

  void _openOnlyFaculty(String fid) {
    for (final key in _deptOpenByFaculty.keys) {
      _deptOpenByFaculty[key] = key == fid;
    }
  }

  // เลือกคณะ = เปิดคณะนั้น (โชว์ภาควิชา), ยกเลิกคณะ = พับ แต่ค่าภาควิชาคงอยู่
  void _onToggleFaculty(FilterData data, String facultyId) {
    final isSelected = _facultySel.contains(facultyId);
    if (isSelected) {
      setState(() {
        _facultySel.remove(facultyId);
        _deptOpenByFaculty[facultyId] = false;
        if (_current != _TabId.faculty) _current = _TabId.faculty;
      });
    } else {
      setState(() {
        _facultySel.add(facultyId);
        _openOnlyFaculty(facultyId);
        if (_current != _TabId.faculty) _current = _TabId.faculty;
      });
    }
  }

  void _onRightScroll() {
    // ระหว่างค้นหา: ไม่เปลี่ยนแถบซ้ายตามการเลื่อน
    if (_globalQuery.isNotEmpty) return;
    _maybeUpdateCurrent(_facultyKey, _TabId.faculty);
    _maybeUpdateCurrent(_clubKey, _TabId.club);
    _maybeUpdateCurrent(_categoryKey, _TabId.category);
  }

  void _maybeUpdateCurrent(GlobalKey key, _TabId tab) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < 140 && top > -box.size.height / 2) {
      if (_current != tab) {
        setState(() => _current = tab);
      }
    }
  }

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
              hintText: 'ค้นหาทั้งหมด (คณะ/ภาควิชา/ชมรม/หมวดหมู่)',
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
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
        if (_globalQuery.isNotEmpty) _buildSuggestions(data, _globalQuery),
      ],
    );
  }

  Widget _buildSuggestions(FilterData data, String queryRaw) {
    final q = queryRaw.toLowerCase();
    final suggestions = <_Suggestion>[];

    // Faculty suggestions
    for (final f in data.faculties) {
      if (f.label.toLowerCase().contains(q)) {
        suggestions.add(_Suggestion(type: _SugType.faculty, id: f.id, label: f.label));
      }
      // Department suggestions under each faculty
      final depts = data.departmentsByFaculty[f.id] ?? const <OptionItem>[];
      for (final d in depts) {
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

    // Club suggestions
    for (final c in data.clubs) {
      if (c.label.toLowerCase().contains(q)) {
        suggestions.add(_Suggestion(type: _SugType.club, id: c.id, label: c.label));
      }
    }

    // Category suggestions
    for (final c in data.categories) {
      if (c.label.toLowerCase().contains(q)) {
        suggestions.add(_Suggestion(type: _SugType.category, id: c.id, label: c.label));
      }
    }

    if (suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('ไม่พบคำที่ตรงกับในคณะ/ภาควิชา/ชมรม/หมวดหมู่',
            style: TextStyle(color: Colors.black54)),
      );
    }

    // กลุ่มตามแท็บซ้าย (แสดงเป็น suggestion ที่ “มีในแท็บซ้ายด้วย”)
    final fac = suggestions.where((s) => s.type == _SugType.faculty).toList();
    final dept = suggestions.where((s) => s.type == _SugType.department).toList();
    final club = suggestions.where((s) => s.type == _SugType.club).toList();
    final cat = suggestions.where((s) => s.type == _SugType.category).toList();

    Widget _group(String title, List<_Suggestion> items, Color color) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
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
                    ? Text('ภาควิชา · ${s.parentFacultyLabel}', style: const TextStyle(fontSize: 12))
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
            _group('Club', club, Colors.indigo),
            _group('Category', cat, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(_SugType t) {
    String text;
    Color color;
    switch (t) {
      case _SugType.faculty:
        text = 'Faculty'; color = Colors.teal;
        break;
      case _SugType.department:
        text = 'Dept.'; color = Colors.teal.shade700;
        break;
      case _SugType.club:
        text = 'Club'; color = Colors.indigo;
        break;
      case _SugType.category:
        text = 'Category'; color = Colors.orange;
        break;
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
          _onToggleFaculty(data, s.id);
          _scrollTo(_facultyKey);
          break;
        case _SugType.department:
          // ให้แน่ใจว่าเปิดคณะเจ้าของ และ toggle ภาควิชา
          final fid = s.parentFacultyId!;
          if (!_facultySel.contains(fid)) {
            _facultySel.add(fid);
          }
          _openOnlyFaculty(fid);
          if (_deptSel.contains(s.id)) {
            _deptSel.remove(s.id);
          } else {
            _deptSel.add(s.id);
          }
          _scrollTo(_facultyKey);
          break;
        case _SugType.club:
          _clubSel.contains(s.id) ? _clubSel.remove(s.id) : _clubSel.add(s.id);
          _scrollTo(_clubKey);
          break;
        case _SugType.category:
          _categorySel.contains(s.id) ? _categorySel.remove(s.id) : _categorySel.add(s.id);
          _scrollTo(_categoryKey);
          break;
      }
      // ไม่รีเซ็ต query เพื่อให้เลือกหลายรายการได้ต่อเนื่อง
    });
  }

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
                    const Text('โหลดข้อมูลไม่สำเร็จ'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _filtersFuture = _buildMergedFuture();
                      }),
                      child: const Text('ลองใหม่'),
                    ),
                  ],
                ),
              );
            } else {
              right = Column(
                children: [
                  _buildSearchBar(snap.data!),                 // แถบค้นหา + suggestions
                  const Divider(height: 1),
                  Expanded(child: _buildRightCombinedPanel(snap.data!)), // เนื้อหาปกติ
                ],
              );
            }

            return _sheetScaffold(left: left, right: right);
          },
        );
      },
    );
  }

  // โครงหน้า sheet
  Widget _sheetScaffold({required Widget left, required Widget right}) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 120, child: left),
                const VerticalDivider(width: 1),
                Expanded(child: right),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  color: Color(0x22000000),
                  offset: Offset(0, -2),
                )
              ],
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('ล้าง'),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('ตกลง'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // เมนูซ้าย + auto-highlight (ระหว่างค้นหา จะไม่เปลี่ยนตามเลื่อน)
  Widget _buildLeftMenu() {
    final tabs = <_TabId, String>{
      _TabId.faculty: 'Faculty',
      _TabId.club: 'Club',
      _TabId.category: 'Category',
    };

    return ListView(
      children: tabs.entries.map((e) {
        final active = (_globalQuery.isEmpty) && (e.key == _current);
        return InkWell(
          onTap: () {
            if (_globalQuery.isNotEmpty) return; // โหมดค้นหา: ไม่ต้องสลับส่วน/สกรอลตามแท็บ
            switch (e.key) {
              case _TabId.faculty:
                _scrollTo(_facultyKey);
                break;
              case _TabId.club:
                _scrollTo(_clubKey);
                break;
              case _TabId.category:
                _scrollTo(_categoryKey);
                break;
            }
            setState(() => _current = e.key);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: active ? Colors.white : const Color(0xFFF5F5F5),
              border: Border(
                left: BorderSide(
                  color: active ? AppColors.sage : Colors.transparent,
                  width: 3,
                ),
                bottom: const BorderSide(color: Color(0xFFEAEAEA), width: 1),
              ),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.sage : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // เนื้อหาขวา (รวมทุก Section)
  Widget _buildRightCombinedPanel(FilterData data) {
    return ListView(
      controller: _rightScroll,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        // Faculty
        _sectionHeader(key: _facultyKey, title: 'เลือกคณะ', color: Colors.teal),
        const SizedBox(height: 10),
        ...data.faculties.map((f) => _buildFacultyBlock(data, f)).toList(),

        const SizedBox(height: 24),

        // Club
        _sectionHeader(key: _clubKey, title: 'เลือกชมรม', color: Colors.indigo),
        const SizedBox(height: 10),
        _pillsWithLimit(
          items: data.clubs,
          selected: _clubSel,
          color: Colors.indigo,
          expanded: _expandClub,
          onToggle: (id) => setState(() {
            _clubSel.contains(id) ? _clubSel.remove(id) : _clubSel.add(id);
            if (_current != _TabId.club) _current = _TabId.club;
          }),
          onToggleExpand: () => setState(() => _expandClub = !_expandClub),
        ),

        const SizedBox(height: 24),

        // Category
        _sectionHeader(key: _categoryKey, title: 'เลือกหมวดหมู่', color: Colors.orange),
        const SizedBox(height: 10),
        _pillsWithLimit(
          items: data.categories,
          selected: _categorySel,
          color: Colors.orange,
          expanded: _expandCategory,
          onToggle: (id) => setState(() {
            _categorySel.contains(id) ? _categorySel.remove(id) : _categorySel.add(id);
            if (_current != _TabId.category) _current = _TabId.category;
          }),
          onToggleExpand: () => setState(() => _expandCategory = !_expandCategory),
        ),
      ],
    );
  }

  // 1 บล็อกคณะ: pill คณะ + รายการภาควิชาใต้คณะนั้น
  Widget _buildFacultyBlock(FilterData data, OptionItem faculty) {
    final fid = faculty.id;
    final isSelected = _facultySel.contains(fid);
    final isOpen = _deptOpenByFaculty[fid] ?? false;

    // pill คณะ
    final facultyPill = Wrap(
      spacing: 8,
      runSpacing: 10,
      children: _buildMultiPills(
        [faculty],
        _facultySel,
        Colors.teal,
        onToggle: (_) => _onToggleFaculty(data, fid),
      ),
    );

    // ภาควิชาของคณะนี้ (แสดงเมื่อ "เลือกคณะ" + คณะนี้ถูกเปิด)
    Widget deptArea = const SizedBox.shrink();
    if (isSelected && isOpen) {
      final depts = data.departmentsByFaculty[fid] ?? const <OptionItem>[];

      if (depts.isEmpty) {
        deptArea = const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('ไม่มีภาควิชาสำหรับคณะนี้', style: TextStyle(color: Colors.black54)),
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
              _subHeader('ภาควิชา (${faculty.label})', Colors.teal),
              const SizedBox(height: 8),

              // ปุ่ม "ทั้งหมด" สำหรับคณะนี้
              _buildSelectAllPillForFaculty(data, fid),

              const SizedBox(height: 8),

              // รายการภาควิชา
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _buildMultiPills(
                  visible,
                  _deptSel,
                  Colors.teal.shade700,
                  onToggle: (id) => setState(() {
                    _deptSel.contains(id) ? _deptSel.remove(id) : _deptSel.add(id);
                    if (_current != _TabId.faculty) _current = _TabId.faculty;
                  }),
                ),
              ),
              if (depts.length > showLimit) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () =>
                      setState(() => _deptOpenByFaculty[expandedKey] = !isExpanded),
                  child: Text(isExpanded ? 'ย่อ' : 'เพิ่มเติม'),
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
        children: [
          facultyPill,
          deptArea,
        ],
      ),
    );
  }

  // header
  Widget _sectionHeader({required Key key, required String title, required Color color}) {
    return Container(
      key: key,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _subHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration:
              BoxDecoration(color: color.withOpacity(.7), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ปุ่ม "ทั้งหมด" ต่อคณะ
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
          const Text('ทั้งหมด', style: TextStyle(fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  // pills + limit + ปุ่มเพิ่มเติม
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
          const Text('ไม่มีรายการ', style: TextStyle(color: Colors.black54))
        else
          Wrap(spacing: 8, runSpacing: 10, children: pills),
        if (items.length > _showLimit && !expanded) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onToggleExpand,
            child: const Text('เพิ่มเติม'),
          ),
        ],
      ],
    );
  }

  // Multi-pills UI
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

  /// ---- Helpers สำหรับ "ทั้งหมด" ของภาควิชาต่อคณะ ----
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
        _deptSel.removeAll(all); // ยกเลิกทั้งหมด
      } else {
        _deptSel.addAll(all); // เลือกทั้งหมด
      }
      if (_current != _TabId.faculty) _current = _TabId.faculty;
    });
  }
}

/// ---------- Mock API loader (เปลี่ยนเป็น API จริงได้) ----------
Future<FilterData> mockLoadFilters() async {
  await Future.delayed(const Duration(milliseconds: 400));

  // faculties / clubs / categories (mock)
  final apiFaculties = const [
    OptionItem('eng', 'คณะวิศวกรรมศาสตร์'),
    OptionItem('sci', 'คณะวิทยาศาสตร์'),
    OptionItem('eco', 'คณะเศรษฐศาสตร์'),
    OptionItem('arch', 'คณะสถาปัตยกรรมศาสตร์'),
    OptionItem('bus', 'คณะบริหารธุรกิจ'),
    OptionItem('med', 'คณะแพทยศาสตร์'),
    OptionItem('art', 'คณะศิลปศาสตร์'),
  ];

  // [CHANGED] departmentsByFaculty ไม่ใช้ const — สมมติว่า API ส่งมา runtime
  final apiDepartments = <String, List<OptionItem>>{
    'eng': [
      OptionItem('eng.comp', 'วิศวกรรมคอมพิวเตอร์'),
      OptionItem('eng.chem', 'วิศวกรรมเคมี'),
      OptionItem('eng.elec', 'วิศวกรรมไฟฟ้า'),
      OptionItem('eng.civ', 'วิศวกรรมโยธา'),
      OptionItem('eng.me', 'วิศวกรรมเครื่องกล'),
      OptionItem('eng.indu', 'วิศวกรรมอุตสาหการ'),
      OptionItem('eng.env', 'วิศวกรรมสิ่งแวดล้อม'),
    ],
    'sci': [
      OptionItem('sci.math', 'คณิตศาสตร์'),
      OptionItem('sci.phys', 'ฟิสิกส์'),
      OptionItem('sci.chem', 'เคมี'),
      OptionItem('sci.bio', 'ชีววิทยา'),
      OptionItem('sci.stat', 'สถิติ'),
    ],
    'eco': [
      OptionItem('eco.macro', 'เศรษฐศาสตร์มหภาค'),
      OptionItem('eco.micro', 'เศรษฐศาสตร์จุลภาค'),
      OptionItem('eco.dev', 'เศรษฐศาสตร์การพัฒนา'),
    ],
    'arch': [
      OptionItem('arch.arch', 'สถาปัตยกรรม'),
      OptionItem('arch.plan', 'ผังเมือง'),
    ],
    'bus': [
      OptionItem('bus.acc', 'บัญชี'),
      OptionItem('bus.mkt', 'การตลาด'),
      OptionItem('bus.mgmt', 'การจัดการ'),
    ],
    'med': [
      OptionItem('med.surg', 'ศัลยศาสตร์'),
      OptionItem('med.int', 'อายุรศาสตร์'),
      OptionItem('med.ped', 'กุมารเวชศาสตร์'),
    ],
    'art': [
      OptionItem('art.lang', 'ภาษา'),
      OptionItem('art.hist', 'ประวัติศาสตร์'),
      OptionItem('art.phil', 'ปรัชญา'),
    ],
  };

  return FilterData(
    faculties: apiFaculties,
    clubs: const [
      OptionItem('music', 'ชมรมดนตรี'),
      OptionItem('film', 'ชมรมภาพยนตร์'),
      OptionItem('coding', 'ชมรมโปรแกรมมิง'),
      OptionItem('vol', 'ชมรมอาสา'),
      OptionItem('sport', 'ชมรมกีฬา'),
      OptionItem('photo', 'ชมรมถ่ายภาพ'),
      OptionItem('lang', 'ชมรมภาษา'),
      OptionItem('game', 'ชมรมเกม'),
      OptionItem('chess', 'ชมรมหมากกระดาน'),
    ],
    categories: const [
      OptionItem('market', 'ตลาดนัด'),
      OptionItem('study', 'ติว/เรียน'),
      OptionItem('event', 'กิจกรรม'),
      OptionItem('life', 'ไลฟ์สไตล์'),
      OptionItem('job', 'งาน/ฝึกงาน'),
      OptionItem('art', 'ศิลปะ/ดนตรี'),
      OptionItem('health', 'สุขภาพ/กีฬา'),
    ],
    departmentsByFaculty: apiDepartments, // runtime จาก API (mock)
  );
}