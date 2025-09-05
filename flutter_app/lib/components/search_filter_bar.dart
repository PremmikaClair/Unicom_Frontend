// lib/components/search_filter_bar.dart
import 'dart:async';
import 'package:flutter/material.dart';

class FilterOption {
  final String id;
  final String label;
  final IconData? icon;
  const FilterOption({required this.id, required this.label, this.icon});
}

class DropdownSpec {
  final String id;             // e.g. "category" or "role"
  final String label;          // UI label
  final List<FilterOption> items; // options
  final String? selectedId;    // currently selected
  const DropdownSpec({
    required this.id,
    required this.label,
    required this.items,
    this.selectedId,
  });
}

class SearchFilterBar extends StatefulWidget {
  final String hintText;
  final String initialQuery;

  // Multi-select chips
  final List<FilterOption> chipOptions;
  final Set<String> selectedChipIds;

  // One or more dropdowns
  final List<DropdownSpec> dropdowns;

  // Events
  final ValueChanged<String>? onQueryChanged;          // debounced
  final ValueChanged<String>? onQuerySubmitted;        // enter
  final void Function(Set<String> ids)? onChipsChanged;
  final void Function(String groupId, String? valueId)? onDropdownChanged;

  // Extra
  final VoidCallback? onOpenAdvanced;
  final EdgeInsets padding;
  final bool condensed;

  const SearchFilterBar({
    super.key,
    this.hintText = 'Search…',
    this.initialQuery = '',
    this.chipOptions = const [],
    this.selectedChipIds = const {},
    this.dropdowns = const [],
    this.onQueryChanged,
    this.onQuerySubmitted,
    this.onChipsChanged,
    this.onDropdownChanged,
    this.onOpenAdvanced,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    this.condensed = false,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  late final TextEditingController _ctrl;
  Timer? _debounce;
  late Set<String> _selectedChips;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    _selectedChips = {...widget.selectedChipIds};
  }

  @override
  void didUpdateWidget(covariant SearchFilterBar old) {
    super.didUpdateWidget(old);
    // Keep local in sync if parent changes
    if (old.selectedChipIds != widget.selectedChipIds) {
      _selectedChips = {...widget.selectedChipIds};
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onQueryChanged?.call(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _ctrl,
      onChanged: _onTextChanged,
      onSubmitted: widget.onQuerySubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
    );

    final chipWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.chipOptions.map((opt) {
        final sel = _selectedChips.contains(opt.id);
        return FilterChip(
          label: Text(opt.label),
          avatar: opt.icon != null ? Icon(opt.icon, size: 18) : null,
          selected: sel,
          onSelected: (val) {
            setState(() {
              val ? _selectedChips.add(opt.id) : _selectedChips.remove(opt.id);
            });
            widget.onChipsChanged?.call(_selectedChips);
          },
        );
      }).toList(),
    );

    // แทนตัวเดิมทั้งบล็อก dropdownRow
    final dropdownRow = LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;        // ช่องว่างระหว่างกล่อง
        const perRow = 2;        // อยากได้ 2 กล่องต่อแถว (Category, Role)
        final itemWidth = (constraints.maxWidth - (perRow - 1) * gap) / perRow;

        return Wrap(
          spacing: gap,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: widget.dropdowns.map((d) {
            return SizedBox(
              width: itemWidth, // <-- คำนวณจากพื้นที่จริง
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: d.label,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isDense: true,
                    value: d.selectedId, // อนุญาต null
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Any'),
                      ),
                      ...d.items.map((it) => DropdownMenuItem<String?>(
                            value: it.id,
                            child: Text(it.label),
                          )),
                    ],
                    onChanged: (val) => widget.onDropdownChanged?.call(d.id, val),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );

    final tuneBtn = widget.onOpenAdvanced == null
        ? const SizedBox.shrink()
        : IconButton(icon: const Icon(Icons.tune), onPressed: widget.onOpenAdvanced);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Expanded(child: field), tuneBtn]),
            if (!widget.condensed && widget.dropdowns.isNotEmpty) ...[
              const SizedBox(height: 8), dropdownRow,
            ],
            if (!widget.condensed && widget.chipOptions.isNotEmpty) ...[
              const SizedBox(height: 8), chipWrap,
            ],
          ],
        ),
      ),
    );
  }
}