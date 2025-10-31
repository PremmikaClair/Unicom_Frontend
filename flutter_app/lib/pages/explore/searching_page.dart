import 'package:flutter/material.dart';
import '../../components/search_bar.dart';
import '../../shared/page_transitions.dart';
import 'search_feed_page.dart';

class SearchingPage extends StatefulWidget {
  final bool autoFocus;

  const SearchingPage({super.key, this.autoFocus = true});

  @override
  State<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends State<SearchingPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // โฟกัสอัตโนมัติเปิดคีย์บอร์ดเมื่อเข้าหน้านี้
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _goSearch() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    Navigator.of(context).push(
      instantRoute(SearchFeedPage(initialQuery: q)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header: ← Back | [ Search ]
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
                        focusNode: _focus,
                        hintText: 'Search',
                        onSubmitted: (_) => _goSearch(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // เนื้อหา: hint ตรงกลางหน้าจอ
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Try searching for topics, hashtag, or keywords',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
