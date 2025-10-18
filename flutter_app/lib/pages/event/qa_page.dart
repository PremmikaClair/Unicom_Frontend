import 'package:flutter/material.dart';
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
/// (ทำเป็น immutable + มี toJson/fromJson เพื่อพร้อมต่อ API)
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
      id: json['id'] as String,
      author: json['author'] as String,
      text: json['text'] as String,
      time: DateTime.parse(json['time'] as String),
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
    return QaQuestion(
      id: json['id'] as String,
      author: json['author'] as String,
      text: json['text'] as String,
      time: DateTime.parse(json['time'] as String),
      answered: json['answered'] as bool? ?? (json['answers'] != null && (json['answers'] as List).isNotEmpty),
      answers: (json['answers'] as List<dynamic>? ?? const [])
          .map((e) => QaAnswer.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
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
/// สร้าง interface สำหรับแหล่งข้อมูล (พร้อมสลับเป็น API ภายหลัง)
abstract class QaDataSource {
  Future<List<QaQuestion>> fetchQuestions();                 // GET /questions
  Future<QaQuestion> postQuestion({required String text});   // POST /questions
  Future<QaAnswer> postAnswer({required String qid, required String text}); // POST /questions/:id/answers
}

/// Mock/Fake data source สำหรับช่วงที่ยังไม่มี backend
class FakeQaDataSource implements QaDataSource {
  FakeQaDataSource({required this.organizerName}) {
    // seed mock
    _db = [
      QaQuestion(
        id: 'q1',
        author: 'นิสิตปี 2',
        text: 'ลงทะเบียนหน้างานได้ไหมคะ ถ้ายังไม่ได้สมัครล่วงหน้า?',
        time: DateTime.now().subtract(const Duration(hours: 3)),
        answered: true,
        answers: [
          QaAnswer(
            id: 'a1',
            author: organizerName,
            text:
                'ได้ค่ะ แต่มีโควต้า จำกัด แนะนำสมัครล่วงหน้าจะชัวร์กว่า และได้รับของที่ระลึกแน่นอนค่ะ',
            time: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
          ),
        ],
      ),
      QaQuestion(
        id: 'q2',
        author: 'Alumni',
        text: 'สาย UX/UI ควรเตรียมพอร์ตแบบไหนไปพูดคุยกับบริษัทบ้าง?',
        time: DateTime.now().subtract(const Duration(hours: 1, minutes: 40)),
        answered: true,
        answers: [
          QaAnswer(
            id: 'a2',
            author: organizerName,
            text:
                'เลือก 2–3 เคสที่เล่า process ชัด ๆ (Problem → Research → Wireframe → Test → Iterate) พร้อมลิงก์ Figma/Prototype ค่ะ',
            time: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
          ),
        ],
      ),
      QaQuestion(
        id: 'q3',
        author: 'นิสิตปี 1',
        text: 'มีที่จอดรถบริเวณงานไหมครับ?',
        time: DateTime.now().subtract(const Duration(minutes: 50)),
        answered: true,
        answers: [
          QaAnswer(
            id: 'a3',
            author: organizerName,
            text: 'มีลานจอดหน้าศูนย์กีฬา ~200 คัน แนะนำมารถสาธารณะช่วงเช้า สะดวกกว่าครับ',
            time: DateTime.now().subtract(const Duration(minutes: 35)),
          ),
        ],
      ),
      QaQuestion(
        id: 'q4',
        author: 'นิสิตปี 3',
        text: 'ถ้าฝนตกหนัก งานยังจัดตามปกติไหมคะ?',
        time: DateTime.now().subtract(const Duration(minutes: 25)),
        answered: false,
        answers: const [],
      ),
    ];
  }

  final String organizerName;
  late List<QaQuestion> _db;

  @override
  Future<List<QaQuestion>> fetchQuestions() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    // จำลองเรียงล่าสุดก่อน
    final list = [..._db]..sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  @override
  Future<QaQuestion> postQuestion({required String text}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final q = QaQuestion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: 'ฉัน',
      text: text,
      time: DateTime.now(),
      answers: const [],
      answered: false,
    );
    _db = [q, ..._db];
    return q;
  }

  @override
  Future<QaAnswer> postAnswer({required String qid, required String text}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final a = QaAnswer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: organizerName,
      text: text,
      time: DateTime.now(),
    );
    _db = _db.map((q) {
      if (q.id == qid) {
        return q.copyWith(answers: [...q.answers, a], answered: true);
      }
      return q;
    }).toList();
    return a;
  }
}

/// Backend-powered data source (partial):
/// - postQuestion uses POST /event/:eventId/qa
/// - fetchQuestions falls back to empty (no list endpoint yet)
/// - postAnswer not implemented (route not wired)
class EventQaApiDataSource implements QaDataSource {
  final String eventId;
  final String organizerName;
  EventQaApiDataSource({required this.eventId, required this.organizerName});

  @override
  Future<List<QaQuestion>> fetchQuestions() async {
    final list = await DatabaseService().getEventQaListFiber(eventId);
    return list.map((m) {
      final id = (m['id'] ?? m['_id'] ?? '').toString();
      final txt = (m['questionText'] ?? '').toString();
      final tsStr = (m['questionCreatedAt'] ?? DateTime.now().toIso8601String()).toString();
      final ts = DateTime.tryParse(tsStr) ?? DateTime.now();
      final ansText = m['answerText']?.toString();
      final answered = ansText != null && ansText.isNotEmpty;
      final answers = answered
          ? [QaAnswer(id: 'a_$id', author: organizerName, text: ansText!, time: ts)]
          : const <QaAnswer>[];
      return QaQuestion(id: id, author: 'Anonymous', text: txt, time: ts, answered: answered, answers: answers);
    }).toList(growable: false);
  }

  @override
  Future<QaQuestion> postQuestion({required String text}) async {
    final res = await DatabaseService().postEventQuestionFiber(eventId, text);
    final id = (res['id'] ?? res['_id'] ?? '').toString();
    final qText = (res['questionText'] ?? text).toString();
    final tsStr = (res['questionCreatedAt'] ?? DateTime.now().toIso8601String()).toString();
    final ts = DateTime.tryParse(tsStr) ?? DateTime.now();
    final ans = res['answerText']?.toString();
    final answered = ans != null && ans.isNotEmpty;
    final answers = answered
        ? [
            QaAnswer(
              id: 'a_${id}',
              author: organizerName,
              text: ans,
              time: ts,
            )
          ]
        : const <QaAnswer>[];
    return QaQuestion(
      id: id,
      author: 'You',
      text: qText,
      time: ts,
      answered: answered,
      answers: answers,
    );
  }

  @override
  Future<QaAnswer> postAnswer({required String qid, required String text}) async {
    // Attempt to answer via PATCH /qa/:qaId/answer (may require organizer rights)
    final res = await DatabaseService().answerEventQaFiber(qid, text);
    final id = (res['id'] ?? res['_id'] ?? '').toString();
    final tsStr = (res['answerCreatedAt'] ?? DateTime.now().toIso8601String()).toString();
    final ts = DateTime.tryParse(tsStr) ?? DateTime.now();
    final author = organizerName;
    final ansText = (res['answerText'] ?? text).toString();
    return QaAnswer(id: 'a_${id}', author: author, text: ansText, time: ts);
  }
}

/// ========================= PAGE =========================
class QaPage extends StatefulWidget {
  final String title;
  final String organizerName;

  /// สามารถ inject data source มาด้วยได้ (ถ้าไม่ส่งจะใช้ FakeQaDataSource)
  final QaDataSource? dataSource;

  const QaPage({
    super.key,
    required this.title,
    required this.organizerName,
    this.dataSource,
  });

  @override
  State<QaPage> createState() => _QaPageState();
}

enum _Filter { all, organizerAnswered, noAnswer }

class _QaPageState extends State<QaPage> {
  final _searchCtl = TextEditingController();
  late final QaDataSource _ds =
      widget.dataSource ?? FakeQaDataSource(organizerName: widget.organizerName);

  List<QaQuestion> _all = const [];
  bool _canAnswer = false; // only organizers of this event can answer
  bool _loading = true;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
    _evalOrganizerPermission();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _ds.fetchQuestions();
    if (!mounted) return;
    setState(() {
      _all = data;
      _loading = false;
    });
  }

  Future<void> _evalOrganizerPermission() async {
    try {
      // Only applicable when using backend data source (has eventId)
      if (_ds is! EventQaApiDataSource) {
        setState(() => _canAnswer = false);
        return;
      }
      final eid = (_ds as EventQaApiDataSource).eventId;
      await AuthService.I.init();
      // Fetch my profile to get _id
      final me = await DatabaseService().getMeFiber();
      final myId = (me['_id'] ?? me['id'] ?? '').toString();
      if (myId.isEmpty) { setState(() => _canAnswer = false); return; }
      // Fetch organizers for this event
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
        titleSpacing: 0.0,
        title: Text(
          widget.title,
          style: const TextStyle(
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
                        final newQ = await _ds.postQuestion(text: text); // ใช้ data source
                        if (!mounted) return;
                        setState(() => _all = [newQ, ..._all]);
                        Navigator.pop(context);
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
    final ans = await _ds.postAnswer(qid: qid, text: text); // ใช้ data source
    if (!mounted) return;
    setState(() {
      _all = _all.map((q) {
        if (q.id == qid) {
          return q.copyWith(answers: [...q.answers, ans], answered: true);
        }
        return q;
      }).toList();
    });
  }

  // ======== VIEW PIPELINE (เรียงล่าสุดก่อนเสมอ) ========
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
/// (ตัด “จำนวนคำตอบ” ออก)
class _QaCard extends StatefulWidget {
  final QaQuestion q;
  final String organizerName;
  final bool canAnswer;
  final ValueChanged<String> onAddAnswer;
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

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final meta = '${q.author} • ${_relTime(q.time)}';
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
                  // (ไม่มี vote/จำนวนคำตอบ/ปักหมุด)
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
                        Text(meta, style: const TextStyle(color: _textSecondary, fontSize: 12.0)),
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
              Text(a.author, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.0, color: _textSecondary)),
              const SizedBox(height: 4.0),
              Text(a.text, style: const TextStyle(color: _textPrimary, height: 1.4)),
              const SizedBox(height: 6.0),
              Text(_relTime(a.time), style: const TextStyle(color: _textSecondary, fontSize: 11.0)),
            ],
          ),
        );
      },
    );
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
            onPressed: () {
              final t = ctl.text.trim();
              if (t.isEmpty) return;
              widget.onAddAnswer(t);
            },
            child: const Icon(Icons.send, size: 18.0),
          ),
        ],
      ),
    );
  }

  static String _relTime(DateTime time) {
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'เมื่อสักครู่';
    if (d.inMinutes < 60) return '${d.inMinutes} นาทีที่แล้ว';
    if (d.inHours < 24) return '${d.inHours} ชม.ที่แล้ว';
    return '${d.inDays} วันที่แล้ว';
  }
}
