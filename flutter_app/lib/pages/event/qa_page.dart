import 'dart:async';
import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import 'package:flutter_app/components/app_colors.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

/// ===== THEME =====
const _bg = AppColors.bg;
const _brand = Color(0xFF3E6B3E);
const _brandSoft = Color(0xFFE9F2EA);
const _textPrimary = Colors.black87;
const _textSecondary = Colors.black54;
const _accent = Color(0xFF7FAA3B);

/// ========================= MODELS =========================
class QaAnswer {
  final String id;
  final String author;
  final String text;
  final DateTime time;

  const QaAnswer({
    required this.id,
    required this.author,
    required this.text,
    required this.time,
  });

  QaAnswer copyWith({
    String? id,
    String? author,
    String? text,
    DateTime? time,
  }) {
    return QaAnswer(
      id: id ?? this.id,
      author: author ?? this.author,
      text: text ?? this.text,
      time: time ?? this.time,
    );
  }

  factory QaAnswer.fromJson(Map<String, dynamic> json) {
    return QaAnswer(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      author: (json['author'] ?? 'Organizer').toString(),
      text: (json['text'] ?? '').toString(),
      time: DateTime.tryParse((json['time'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'text': text,
        'time': time.toIso8601String(),
      };
}

class QaQuestion {
  final String id;
  final String author;
  final String text;
  final DateTime time;
  final List<QaAnswer> answers;
  final bool answered;

  const QaQuestion({
    required this.id,
    required this.author,
    required this.text,
    required this.time,
    this.answers = const [],
    this.answered = false,
  });

  QaQuestion copyWith({
    String? id,
    String? author,
    String? text,
    DateTime? time,
    List<QaAnswer>? answers,
    bool? answered,
  }) {
    return QaQuestion(
      id: id ?? this.id,
      author: author ?? this.author,
      text: text ?? this.text,
      time: time ?? this.time,
      answers: answers ?? this.answers,
      answered: answered ?? this.answered,
    );
  }

  factory QaQuestion.fromJson(Map<String, dynamic> json) {
    final answers = (json['answers'] as List<dynamic>? ?? const [])
        .map((e) => QaAnswer.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    final answeredFlag = json['answered'] as bool?;
    final answered = answeredFlag ?? answers.isNotEmpty;

    return QaQuestion(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      author: (json['author'] ?? json['user'] ?? 'Anonymous').toString(),
      text: (json['text'] ?? json['question'] ?? json['questionText'] ?? '').toString(),
      time: DateTime.tryParse((json['time'] ?? json['createdAt'] ?? json['questionCreatedAt'] ?? '').toString()) ??
          DateTime.now(),
      answered: answered,
      answers: answers,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'text': text,
        'time': time.toIso8601String(),
        'answered': answered,
        'answers': answers.map((e) => e.toJson()).toList(),
      };
}

/// ========================= DATA SOURCE =========================
abstract class QaDataSource {
  Future<List<QaQuestion>> fetchQuestions(); // GET list
  Future<QaQuestion> postQuestion({required String text}); // POST question
  Future<QaAnswer> postAnswer({required String qid, required String text}); // PATCH/POST answer
}

/// --- Mock source (สำหรับ dev/offline) ---
// Mock data source removed — use EventQaApiDataSource only


/// --- Backend source (ใช้งานจริง) ---
class EventQaApiDataSource implements QaDataSource {
  final String eventId;
  final String organizerName;
  EventQaApiDataSource({required this.eventId, required this.organizerName});

  bool _isAnswered(Map m) {
    final s = (m['status'] ?? '').toString().toLowerCase();
    final hasTextSnake = (m['answer_text'] ?? '').toString().isNotEmpty;
    final hasTextCamel = (m['answerText'] ?? '').toString().isNotEmpty;
    final answeredFlag = (m['answered'] == true) ||
        (m['isAnswered'] == true) ||
        ((m['status'] ?? '').toString().toLowerCase() == 'answered');
    return answeredFlag || hasTextSnake || hasTextCamel || s == 'answered';
  }

  DateTime _parseTime(dynamic v, {DateTime? fallback}) {
    final s = v?.toString() ?? '';
    return DateTime.tryParse(s) ?? (fallback ?? DateTime.now());
    // รองรับรูปแบบ ISO ที่มี timezone เช่น 2025-11-01T00:46:20.139+00:00
  }

  QaQuestion _fromDb(Map<String, dynamic> m) {
    final id = (m['_id'] ?? m['id'] ?? '').toString();
    final qText = ((m['question_text'] ?? m['questionText'] ?? m['question']) ?? '').toString();
    final qTime = _parseTime(m['question_created_at'] ?? m['questionCreatedAt'] ?? m['createdAt']);
    final answered = _isAnswered(m);

    // ถ้ามีคำตอบ ให้สร้างเป็น 1 answer จากช่อง answer_text / answer_created_at
    final answers = answered
        ? [
            QaAnswer(
              id: 'a_$id',
              author: organizerName, // ถ้าต้องการชื่อจริงของผู้ตอบ ดึงเพิ่มจาก answerer_id ได้
              text: ((m['answer_text'] ?? m['answerText']) ?? '').toString(),
              time: _parseTime(m['answer_created_at'] ?? m['answerCreatedAt'], fallback: qTime),
            ),
          ]
        : const <QaAnswer>[];

    return QaQuestion(
      id: id,
      author: 'Anonymous', // ถ้าจะโชว์ชื่อคนถาม ให้แมปจาก questioner_id -> โปรไฟล์
      text: qText,
      time: qTime,
      answered: answered,
      answers: answers,
    );
  }

  @override
  Future<List<QaQuestion>> fetchQuestions() async {
    await AuthService.I.init();
    // คาดว่า endpoint คืนลิสต์ของ doc สคีมานี้
    final raw = await DatabaseService().getEventQaListFiber(eventId);
    final list = raw.map<QaQuestion>((m) => _fromDb(Map<String, dynamic>.from(m))).toList(growable: false);
    // จัดเรียงล่าสุดก่อน
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  @override
  Future<QaQuestion> postQuestion({required String text}) async {
    await AuthService.I.init();
    // ให้ backend สร้าง doc ใหม่ ตามสคีมาเดียวกัน (คืนค่าเป็น docเดียว)
    final res = await DatabaseService().postEventQuestionFiber(eventId, text);
    final q = _fromDb(Map<String, dynamic>.from(res));
    return q;
  }

  @override
  Future<QaAnswer> postAnswer({required String qid, required String text}) async {
    await AuthService.I.init();
    // ให้ backend บันทึกคำตอบ (โดยปกติจะคืน doc หลังอัปเดต)
    final res = await DatabaseService().answerEventQaFiber(qid, text);
    final m = Map<String, dynamic>.from(res);

    final id = (m['_id'] ?? m['id'] ?? qid).toString();
    final aText = ((m['answer_text'] ?? m['answerText']) ?? text).toString();
    final aTime = _parseTime(m['answer_created_at'] ?? m['answerCreatedAt']);
    return QaAnswer(id: 'a_$id', author: organizerName, text: aText, time: aTime);
  }
}

/// ========================= PAGE =========================
class QaPage extends StatefulWidget {
  final String title;
  final String organizerName;

  final QaDataSource dataSource;

  const QaPage({
    super.key,
    required this.title,
    required this.organizerName,
    required this.dataSource,
  });

  @override
  State<QaPage> createState() => _QaPageState();
}

enum _Filter { all, organizerAnswered, noAnswer }

class _QaPageState extends State<QaPage> {
  final _searchCtl = TextEditingController();
  late final QaDataSource _ds = widget.dataSource;

  List<QaQuestion> _all = const [];
  bool _canAnswer = false; // เฉพาะ organizer ของอีเวนต์นี้
  bool _loading = true;
  _Filter _filter = _Filter.all;

  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _load();
    _evalOrganizerPermission();
    // Poll ข้อมูลทุก 15s (แค่ตอนใช้ backend)
    if (_ds is EventQaApiDataSource) {
      _poller = Timer.periodic(const Duration(seconds: 15), (_) => _silentReload());
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_ds is EventQaApiDataSource) {
        await AuthService.I.init();
      }
      final data = await _ds.fetchQuestions();
      if (!mounted) return;
      setState(() {
        _all = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลด Q&A ไม่สำเร็จ: $e')),
      );
    }
  }

  Future<void> _silentReload() async {
    try {
      final data = await _ds.fetchQuestions();
      if (!mounted) return;
      setState(() => _all = data);
    } catch (_) {
      // เงียบ ๆ ไม่ต้องเด้ง error ตอนเบื้องหลัง
    }
  }

  Future<void> _evalOrganizerPermission() async {
    try {
      if (_ds is! EventQaApiDataSource) {
        setState(() => _canAnswer = false);
        return;
      }
      final eid = (_ds as EventQaApiDataSource).eventId;
      await AuthService.I.init();
      final me = await DatabaseService().getMeFiber();
      final myId = (me['_id'] ?? me['id'] ?? '').toString();
      if (myId.isEmpty) {
        setState(() => _canAnswer = false);
        return;
      }
      final orgs = await DatabaseService().getEventParticipantsFiber(eid, role: 'organizer');
      final ok = orgs.any((m) => (m['user_id'] ?? '').toString() == myId);
      setState(() => _canAnswer = ok);
    } catch (_) {
      if (mounted) setState(() => _canAnswer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _applyView(_all);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0.6,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Q&A',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18.0,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAskSheet,
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.help_outline),
        label: const Text('ถามคำถาม'),
      ),
      body: Column(
        children: [
          _toolbar(),
          const Divider(height: 1.0),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 100.0),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10.0),
                          itemBuilder: (_, i) => _QaCard(
                            q: items[i],
                            organizerName: widget.organizerName,
                            canAnswer: _canAnswer,
                            onAddAnswer: (text) => _addAnswer(items[i].id, text),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// แถบเครื่องมือ: ค้นหา + ตัวกรอง
  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchCtl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ค้นหาคำถาม…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
              ),
            ),
          ),
          const SizedBox(height: 10.0),
          Row(
            children: [
              _segmented(
                options: const {
                  _Filter.all: 'ทั้งหมด',
                  _Filter.organizerAnswered: 'มีคำตอบผู้จัด',
                  _Filter.noAnswer: 'ยังไม่มีคำตอบ',
                },
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segmented<T>({
    required Map<T, String> options,
    required T value,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.grey.shade300, width: 1.0),
      ),
      child: Row(
        children: options.entries.map((e) {
          final selected = e.key == value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: InkWell(
              onTap: () => onChanged(e.key),
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: selected ? _brandSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: selected ? _brand : _textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.0,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.forum_outlined, size: 48.0, color: _textSecondary),
            SizedBox(height: 10.0),
            Text('ยังไม่มีคำถามที่ตรงกับตัวกรอง', style: TextStyle(color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  // ======== ACTIONS ========
  void _openAskSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.0)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
            left: 16.0,
            right: 16.0,
            top: 16.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ถามคำถามถึงผู้จัด', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.0)),
              const SizedBox(height: 12.0),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'เขียนคำถามของคุณให้ชัดเจน…',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;

                        try {
                          // สร้างคำถาม
                          await _ds.postQuestion(text: text);

                          // ดึงข้อมูล “ล่าสุดจาก DB” แทนการแค่แทรกในลิสต์
                          await _load();

                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ส่งคำถามแล้ว')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('ส่งคำถามไม่สำเร็จ: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('โพสต์คำถาม'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addAnswer(String qid, String text) async {
    try {
      // ส่งคำตอบขึ้น backend
      await _ds.postAnswer(qid: qid, text: text);

      // ดึงข้อมูลล่าสุดจาก DB เพื่อ sync กับคนอื่นและค่าเวลา/สถานะจริง
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ส่งคำตอบไม่สำเร็จ: $e')),
      );
    }
  }

  // ======== VIEW PIPELINE ========
  List<QaQuestion> _applyView(List<QaQuestion> src) {
    var list = List<QaQuestion>.from(src);

    final q = _searchCtl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        final hay = '${e.text} ${e.author} ${e.answers.map((a) => a.text).join(" ")}'.toLowerCase();
        return hay.contains(q);
      }).toList();
    }

    switch (_filter) {
      case _Filter.all:
        break;
      case _Filter.organizerAnswered:
        list = list.where((e) => e.answered).toList();
        break;
      case _Filter.noAnswer:
        list = list.where((e) => e.answers.isEmpty).toList();
        break;
    }

    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }
}

/// ========================= CARD =========================
class _QaCard extends StatefulWidget {
  final QaQuestion q;
  final String organizerName;
  final bool canAnswer;
  final Future<void> Function(String) onAddAnswer;
  const _QaCard({
    required this.q,
    required this.organizerName,
    required this.canAnswer,
    required this.onAddAnswer,
  });

  @override
  State<_QaCard> createState() => _QaCardState();
}

class _QaCardState extends State<_QaCard> {
  bool _expanded = false;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final answers = q.answers;

    return Material(
      color: Colors.white,
      elevation: 0.0,
      borderRadius: BorderRadius.circular(14.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(color: Colors.grey.shade300, width: 1.0),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14.0, 12.0, 14.0, 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.text,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            height: 1.35,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text('${q.author} • ${_relTimeTh(q.time)}',
                            style: const TextStyle(color: _textSecondary, fontSize: 12.0)),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            _statusChip(
                              icon: q.answered ? Icons.check_circle : Icons.hourglass_empty,
                              label: q.answered ? 'มีคำตอบแล้ว' : 'รอคำตอบ',
                              color: q.answered ? _accent : Colors.grey.shade500,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => setState(() => _expanded = !_expanded),
                              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                              tooltip: _expanded ? 'ย่อ' : 'ดูคำตอบ',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_expanded && answers.isNotEmpty) const Divider(height: 1.0),
            if (_expanded) _answersList(answers),
            if (_expanded && widget.canAnswer) _answerComposer(),
          ],
        ),
      ),
    );
  }

  Widget _statusChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: color, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14.0, color: color),
          const SizedBox(width: 6.0),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.0)),
        ],
      ),
    );
  }

  Widget _answersList(List<QaAnswer> answers) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 10.0),
      itemCount: answers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8.0),
      itemBuilder: (_, i) {
        final a = answers[i];
        final short = _shortOrganizer(widget.organizerName);
        final authorLabel = (() {
          final auth = a.author.trim();
          final org = widget.organizerName.trim();
          if (auth.isEmpty) return short;
          if (auth.toLowerCase() == org.toLowerCase()) return short;
          return a.author;
        })();
        return Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: Colors.grey.shade300, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(authorLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.0, color: _textSecondary)),
              const SizedBox(height: 4.0),
              Text(a.text, style: const TextStyle(color: _textPrimary, height: 1.4)),
              const SizedBox(height: 6.0),
              Text(_relTimeTh(a.time), style: const TextStyle(color: _textSecondary, fontSize: 11.0)),
            ],
          ),
        );
      },
    );
  }

  String _shortOrganizer(String name) {
    final t = name.trim();
    if (t.isEmpty) return 'Organizer';
    // Prefer text inside parentheses as short label, if concise
    final paren = RegExp(r"\(([^)]+)\)");
    final m = paren.firstMatch(t);
    if (m != null) {
      final inside = m.group(1)!.trim();
      if (inside.length <= 10) return inside.toUpperCase();
    }
    // Build initials from words (skip very short connectors)
    final words = t.split(RegExp(r"\s+")).where((w) => w.trim().isNotEmpty).toList();
    final connectors = {'of', 'and', 'the', 'for', 'in', 'at'};
    final initials = words
        .where((w) => !connectors.contains(w.toLowerCase()))
        .map((w) => w.characters.first.toUpperCase())
        .join();
    if (initials.length >= 2 && initials.length <= 6) return initials;
    // Fallback to first word (uppercased, truncated if long)
    final first = words.first.toUpperCase();
    return first.length > 12 ? '${first.substring(0, 12)}…' : first;
  }

  Widget _answerComposer() {
    final ctl = TextEditingController();
    return Container(
      padding: const EdgeInsets.fromLTRB(14.0, 0.0, 14.0, 14.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctl,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'พิมพ์คำตอบในนามผู้จัด…',
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
            onPressed: _sending
                ? null
                : () async {
                    final t = ctl.text.trim();
                    if (t.isEmpty) return;
                    setState(() => _sending = true);
                    try {
                      await widget.onAddAnswer(t);
                      ctl.clear();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ส่งคำตอบแล้ว')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _sending = false);
                    }
                  },
            child: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18.0),
          ),
        ],
      ),
    );
  }

  /// ภาษาไทยอ่านง่าย
  static String _relTimeTh(DateTime time) {
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'เมื่อสักครู่';
    if (d.inMinutes < 60) return '${d.inMinutes} นาทีที่แล้ว';
    if (d.inHours < 24) return '${d.inHours} ชั่วโมงที่แล้ว';
    return '${d.inDays} วันที่แล้ว';
  }
}


