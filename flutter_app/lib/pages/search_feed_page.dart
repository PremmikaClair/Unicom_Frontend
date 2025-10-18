import 'package:flutter/material.dart';
import '../components/search_bar.dart';

/// Search results page. Accepts an initial query and shows a simple list.
class SearchFeedPage extends StatefulWidget {
  final String initialQuery;

  const SearchFeedPage({super.key, required this.initialQuery});

  @override
  State<SearchFeedPage> createState() => _SearchFeedPageState();
}

class _SearchFeedPageState extends State<SearchFeedPage> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _doSearch(String q) {
    // For now just rebuild to reflect updated query.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final q = _ctrl.text.trim();
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: SearchBarField(
                        controller: _ctrl,
                        hintText: 'Search',
                        onSubmitted: _doSearch,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: q.isEmpty
                ? const Center(child: Text('Type something to search'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: 10,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _resultTile(q, i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _resultTile(String query, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.search, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Result ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Matched "$query"', style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
