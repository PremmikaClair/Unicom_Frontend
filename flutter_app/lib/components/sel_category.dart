import 'package:flutter/material.dart';
import 'app_colors.dart';

/* ─────────── Models ─────────── */
class OptionItem {
  final String id;
  final String label;
  const OptionItem(this.id, this.label);
}

class FilterData {
  final List<OptionItem> categories;
  const FilterData({required this.categories});
}

/* ─────────── Result ─────────── */
class FilterSheetResult {
  final Set<String> categoryIds;
  const FilterSheetResult({this.categoryIds = const <String>{}});

  @override
  String toString() => 'FilterSheetResult(cat=$categoryIds)';
}

/* ─────────── Bottom Sheet (Category only) ─────────── */
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
  // selections
  late Set<String> _categorySel;

  // data future
  late Future<FilterData> _filtersFuture;

  // search
  final _searchCtl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _categorySel = {...widget.initial.categoryIds};
    _filtersFuture = widget.loadFilters();
    _searchCtl.addListener(() {
      setState(() => _query = _searchCtl.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false, // กันช่องว่างบน
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true, // กัน padding ซ้ำชั้น
        child: DraggableScrollableSheet(
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
                  child = const Center(child: Text('Failed to load'));
                } else {
                  final data = snap.data!;
                  child = Column(
                    children: [
                      const SizedBox(height: 8),
                      _grabber(),
                      const SizedBox(height: 8),

                      // Title (แสดงว่าเป็น Category)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Category',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      _searchBar(),
                      const Divider(height: 1),

                      // Category list
                      Expanded(child: _categoryPanel(data, controller)),

                      _bottomButtons(),
                    ],
                  );
                }

                return Material(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: child,
                );
              },
            );
          },
        ),
      ),
    );
  }

  /* ─────────── UI helpers ─────────── */
  Widget _grabber() => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  // Search bar (ปรับขนาดได้)
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
            prefixIconConstraints: BoxConstraints(
              minWidth: height,
              minHeight: height,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  /* ─────────── Category panel ─────────── */
  Widget _categoryPanel(FilterData data, ScrollController controller) {
    final items = _filtered(data.categories);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: items
              .map((o) => _pill(
                    o,
                    _categorySel.contains(o.id),
                    const Color.fromARGB(255, 64, 80, 107),
                    onTap: () => setState(() {
                      _categorySel.contains(o.id)
                          ? _categorySel.remove(o.id)
                          : _categorySel.add(o.id);
                    }),
                  ))
              .toList(),
        ),
      ],
    );
  }

  /* ─────────── Pill (chip) ─────────── */
  Widget _pill(OptionItem o, bool selected, Color color,
      {required VoidCallback onTap}) {
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

  // helper: case-insensitive contains
  List<OptionItem> _filtered(List<OptionItem> xs) {
    if (_query.isEmpty) return xs;
    final q = _query.toLowerCase();
    return xs.where((e) => e.label.toLowerCase().contains(q)).toList();
  }

  /* ─────────── Bottom Buttons ─────────── */
  Widget _bottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() {
                _categorySel.clear();
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sage,
                side: const BorderSide(color: AppColors.sage),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(60),
                ),
              ),
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(
                  FilterSheetResult(categoryIds: _categorySel),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sage,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(60),
                ),
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

/* ─────────── Mock data (Category only) ─────────── */
Future<FilterData> mockLoadFilters() async {
  await Future.delayed(const Duration(milliseconds: 250));
  const categories = [
    OptionItem('market', 'Marketplace'),
    OptionItem('study', 'Study / Tutoring'),
    OptionItem('event', 'Events'),
    OptionItem('life', 'Lifestyle'),
    OptionItem('job', 'Jobs / Internships'),
  ];
  return const FilterData(categories: categories);
}
