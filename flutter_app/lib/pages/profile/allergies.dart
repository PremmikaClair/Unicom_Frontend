import 'package:flutter/material.dart';
import '../../components/app_colors.dart';
import '../../services/database_service.dart';

class AllergiesPage extends StatefulWidget {
  const AllergiesPage({super.key});

  @override
  State<AllergiesPage> createState() => _AllergiesPageState();
}

class _AllergiesPageState extends State<AllergiesPage> {
  // Start empty by default per request
  List<String> _foodAllergies = const [];
  List<String> _healthAllergies = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await DatabaseService().getMeFiber();
      List<String> _asList(dynamic v) {
        if (v == null) return const [];
        if (v is List) {
          return v.map((e) => e?.toString() ?? '').where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();
        }
        final s = v.toString().trim();
        if (s.isEmpty) return const [];
        // split by comma/semicolon/newline
        return s.split(RegExp(r'[;,\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      final disease = me['disease'] ?? me['Disease'];
      final allergy = me['allergy'] ?? me['Allergy'] ?? me['allergies'];
      setState(() {
        _healthAllergies = _asList(disease);
        _foodAllergies = _asList(allergy);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; });
    }
  }

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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _chipsSectionEditable(
            title: 'Food allergies',
            items: _foodAllergies,
          ),
          const SizedBox(height: 12),
          _chipsSectionEditable(
            title: 'Health allergies',
            items: _healthAllergies,
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 4),
          if (items.isEmpty)
            const Text('No items', style: TextStyle(color: Colors.black54))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((e) => Chip(
                        label: Text(
                          e,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                        backgroundColor: AppColors.sage.withOpacity(0.18),
                        shape: StadiumBorder(
                          side: BorderSide(color: AppColors.sage.withOpacity(0.5)),
                        ),
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
