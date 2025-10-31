import 'package:flutter/material.dart';
import '../../components/app_colors.dart';

class AllergiesPage extends StatefulWidget {
  const AllergiesPage({super.key});

  @override
  State<AllergiesPage> createState() => _AllergiesPageState();
}

class _AllergiesPageState extends State<AllergiesPage> {
  // Start empty by default per request
  List<String> _foodAllergies = const [];
  List<String> _healthAllergies = const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF7FA06B),
        surfaceTintColor: const Color(0xFF7FA06B),
        elevation: 0,
        centerTitle: true,
        title: const Text('Health', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _chipsSectionEditable(
            title: 'Food allergies',
            items: _foodAllergies,
            onAdd: () => _promptAdd((v) => setState(() => _foodAllergies = [..._foodAllergies, v])),
            onRemove: (v) => setState(() => _foodAllergies = _foodAllergies.where((e) => e != v).toList()),
          ),
          const SizedBox(height: 12),
          _chipsSectionEditable(
            title: 'Health allergies',
            items: _healthAllergies,
            onAdd: () => _promptAdd((v) => setState(() => _healthAllergies = [..._healthAllergies, v])),
            onRemove: (v) => setState(() => _healthAllergies = _healthAllergies.where((e) => e != v).toList()),
          ),
        ],
      ),
    );
  }

  // (removed old read-only section to keep page minimal and editable-only)

  // Editable section with + button and removable chips
  Widget _chipsSectionEditable({
    required String title,
    required List<String> items,
    required VoidCallback onAdd,
    required void Function(String) onRemove,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3F0E6)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add allergies',
                onPressed: onAdd,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (items.isEmpty)
            const Text('No items', style: TextStyle(color: Colors.black54))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((e) => InputChip(
                        label: Text(e),
                        onDeleted: () => onRemove(e),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _promptAdd(
    void Function(String) onValue, {
    String dialogTitle = 'Add allergies',
    String hintText = 'Add allergies',
  }) async {
    final ctrl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String text = '';
        return StatefulBuilder(
          builder: (ctx, setSB) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                dialogTitle,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              content: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.sage, width: 2),
                  ),
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: (val) => setSB(() => text = val.trim()),
                onSubmitted: (val) {
                  final trimmed = val.trim();
                  if (trimmed.isNotEmpty) Navigator.pop(ctx, trimmed);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: text.isEmpty ? null : () => Navigator.pop(ctx, text),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.sage),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    if ((v ?? '').isEmpty) return;
    onValue(v!.trim());
  }
}
