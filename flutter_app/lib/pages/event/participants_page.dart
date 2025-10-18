// lib/pages/event/register_event_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import '../../components/app_colors.dart';
import '../../services/database_service.dart';

/// ---- Page ----
class RegisterEventPage extends StatefulWidget {
  final String eventId;

  /// ชื่ออีเวนต์ (ใช้โชว์บนการ์ดข้อมูล)
  final String? eventTitle;

  /// ความจุทั้งหมดของอีเวนต์ (ไว้คำนวณ % donut)
  final int? capacity;

  /// (ถ้าอยากโชว์เวลาเช็คอินใต้ชื่ออีเวนต์)
  final String? checkinTimeLabel;

  const RegisterEventPage({
    super.key,
    required this.eventId,
    this.eventTitle,
    this.capacity,
    this.checkinTimeLabel,
  });

  @override
  State<RegisterEventPage> createState() => _RegisterEventPageState();
}

class _RegisterEventPageState extends State<RegisterEventPage> {
  // API status ที่จะดึง (ดีไซน์หน้าไม่มีปุ่มเปลี่ยนสถานะ จึงใช้ accept ตลอด)
  static const String _apiStatus = 'accept';

  // Raw & filtered
  List<_Participant> _all = [];
  List<_Participant> _view = [];

  // UI states
  final _searchCtrl = TextEditingController();
  DateTimeRange? _dateRange;

  // sorting (คอลัมน์: ชื่อ, อีเมล, เวลา)
  int _sortColumnIndex = 2; // registeredAt
  bool _sortAsc = false;

  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    final rows = await DatabaseService()
        .getEventParticipantsFiber(widget.eventId, status: _apiStatus);

    // map -> model ที่หน้า UI ใช้สะดวก
    _all = <_Participant>[
      for (int i = 0; i < rows.length; i++) _Participant.fromMap(rows[i], index: i),
    ];
    _applyFilters();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===== Filter / Sort =====
  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();

    _view = _all.where((r) {
      final matchDate = _dateRange == null ||
          (r.registeredAt == null) ||
          (r.registeredAt!.isAfter(_dateRange!.start.subtract(const Duration(seconds: 1))) &&
              r.registeredAt!.isBefore(_dateRange!.end.add(const Duration(seconds: 1))));

      bool matchQuery = true;
      if (q.isNotEmpty) {
        final answersText =
            r.answers.entries.map((e) => '${e.key}:${e.value}').join(' ');
        final hay =
            '${r.fullName} ${r.email ?? ''} ${r.phone ?? ''} $answersText'.toLowerCase();
        matchQuery = hay.contains(q);
      }
      return matchDate && matchQuery;
    }).toList();

    _sort();
    setState(() {});
  }

  void _sort({int? columnIndex, bool? ascending}) {
    if (columnIndex != null) _sortColumnIndex = columnIndex;
    if (ascending != null) _sortAsc = ascending;
    int cmp<T extends Comparable>(T a, T b) =>
        _sortAsc ? a.compareTo(b) : b.compareTo(a);

    switch (_sortColumnIndex) {
      case 0:
        _view.sort((a, b) => cmp(
            (a.fullName).toLowerCase(), (b.fullName).toLowerCase()));
        break;
      case 1:
        _view.sort((a, b) => cmp(
            (a.email ?? '').toLowerCase(), (b.email ?? '').toLowerCase()));
        break;
      case 2:
      default:
        _view.sort((a, b) {
          final A = a.registeredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final B = b.registeredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return cmp(A, B);
        });
        break;
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
      helpText: 'ช่วงวันที่ลงทะเบียน',
      saveText: 'ใช้ช่วงวันที่',
    );
    if (res != null) {
      setState(() => _dateRange = res);
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _dateRange = null;
      _searchCtrl.clear();
    });
    _applyFilters();
  }

  // ===== Export CSV =====
  void _exportCsv() {
    final rows = <List<String>>[];
    final baseHeaders = ['Name', 'Email', 'Phone', 'RegisteredAt'];

    // สะสมคีย์ของ answers ทั้งหมดให้ครบก่อน
    final formKeys = <String>{};
    for (final r in _view) {
      formKeys.addAll(r.answers.keys);
    }
    final headers = [...baseHeaders, ...formKeys];
    rows.add(headers);

    for (final r in _view) {
      final base = [
        r.fullName,
        r.email ?? '',
        r.phone ?? '',
        (r.registeredAt ?? DateTime(1970)).toIso8601String(),
      ];
      final formVals =
          formKeys.map((k) => _csvEscape('${r.answers[k] ?? ''}')).toList();
      rows.add([...base, ...formVals]);
    }

    final csv = rows.map((r) => r.join(',')).join('\n');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export CSV (ตัวอย่าง)'),
        content: SingleChildScrollView(child: SelectableText(csv)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
        ],
      ),
    );
  }

  String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"' + s.replaceAll('"', '""') + '"';
    }
    return s;
  }

  // ===== Answers Sheet =====
  void _showAnswers(_Participant r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final answers = r.answers;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('คำตอบฟอร์มของ\n${r.fullName}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close))
                  ]),
                  const SizedBox(height: 8),
                  Expanded(
                    child: answers.isEmpty
                        ? const Center(child: Text('ไม่มีคำตอบฟอร์ม'))
                        : ListView.separated(
                            controller: controller,
                            itemCount: answers.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final k = answers.keys.elementAt(i);
                              final v = answers[k];
                              return ListTile(
                                title: Text(k),
                                subtitle: Text(_formatAnswer(v)),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatAnswer(dynamic v) {
    if (v == null) return '-';
    if (v is List) return v.join(', ');
    return '$v';
  }

  // ===== BUILD (คงดีไซน์เดิม) =====
  @override
  Widget build(BuildContext context) {
    const headerG1 = Color(0xFF7E9766);
    const headerG2 = Color(0xFF7E9766);

    final w = MediaQuery.sizeOf(context).width;
    final isWide = w >= 800;

    final total = _view.length; // accepted เท่านั้น
    final cap = widget.capacity ?? 0;
    final double? percent = cap > 0 ? (total / cap).clamp(0.0, 1.0) : null;

    return Scaffold(
      backgroundColor: headerG1,
      body: FutureBuilder<void>(
        future: _future,
        builder: (context, snap) {
          // header spacer
          final topSpacer = SliverToBoxAdapter(
            child: Container(
              height: MediaQuery.of(context).padding.top + 6,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [headerG1, headerG2],
                ),
              ),
            ),
          );

          if (snap.connectionState == ConnectionState.waiting) {
            return CustomScrollView(slivers: [
              topSpacer,
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            ]);
          }
          if (snap.hasError) {
            return CustomScrollView(slivers: [
              topSpacer,
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('โหลดข้อมูลไม่สำเร็จ'),
                      const SizedBox(height: 8),
                      Text('${snap.error}', style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => setState(() => _future = _load()),
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                ),
              ),
            ]);
          }

          return CustomScrollView(
            slivers: [
              topSpacer,

              // ===== เนื้อหาหลัก =====
              SliverToBoxAdapter(
                child: Material(
                  color: const Color(0xFFEDEDED),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(32)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // KPI donut + ชื่ออีเวนต์ + เวลาเช็คอิน
                      if (percent != null ||
                          widget.eventTitle != null ||
                          widget.checkinTimeLabel != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (percent != null)
                                _KpiProgressCard(
                                  title: 'TOTAL REGISTERED',
                                  percent: percent,
                                  label: '$total / $cap',
                                ),
                              if (widget.eventTitle != null ||
                                  widget.checkinTimeLabel != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (widget.eventTitle != null)
                                        _InfoCard(
                                          icon: Icons.event_note_outlined,
                                          text: widget.eventTitle!,
                                        ),
                                      if (widget.checkinTimeLabel != null)
                                        const SizedBox(height: 12),
                                      if (widget.checkinTimeLabel != null)
                                        _InfoCard(
                                          icon: Icons.schedule_outlined,
                                          text: widget.checkinTimeLabel!,
                                          trailing: const Icon(Icons.qr_code_2,
                                              color: Colors.black45),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Search + Date + Export
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 42,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.search,
                                        size: 20, color: Colors.black45),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchCtrl,
                                        decoration: const InputDecoration(
                                          hintText: 'Search participants',
                                          hintStyle:
                                              TextStyle(color: Colors.black45),
                                          border: InputBorder.none,
                                          isCollapsed: true,
                                        ),
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: (_) => _applyFilters(),
                                        onChanged: (_) => _applyFilters(),
                                      ),
                                    ),
                                    if (_searchCtrl.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchCtrl.clear();
                                          _applyFilters();
                                        },
                                        child: const Icon(Icons.close_rounded,
                                            size: 18, color: Colors.black38),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: _pickDateRange,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.filter_list,
                                        size: 20, color: Colors.black45),
                                    const SizedBox(width: 6),
                                    Text(
                                      _dateRange == null
                                          ? 'date'
                                          : '${_fmt(_dateRange!.start)} - ${_fmt(_dateRange!.end)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black45,
                                      ),
                                    ),
                                    if (_dateRange != null) ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: _clearFilters,
                                        child: const Icon(Icons.clear,
                                            size: 16, color: Colors.black38),
                                      )
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Tooltip(
                              message: 'Export CSV',
                              child: IconButton(
                                style: ButtonStyle(
                                  backgroundColor:
                                      WidgetStateProperty.all<Color>(
                                          Colors.white),
                                  shape: WidgetStateProperty.all(
                                      const CircleBorder()),
                                ),
                                onPressed: _view.isEmpty ? null : _exportCsv,
                                icon: const Icon(Icons.download_outlined,
                                    color: AppColors.sage),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // รายการ / ตาราง
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child:
                            isWide ? _buildTableSection() : _buildListSection(),
                      ),
                    ],
                  ),
                ),
              ),

              SliverFillRemaining(
                hasScrollBody: false,
                child: const ColoredBox(color: Color(0xFFEDEDED)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== Sections =====
  Widget _buildTableSection() {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: const MaterialStatePropertyAll(Colors.white),
            dataRowColor: const MaterialStatePropertyAll(Colors.white),
            dividerThickness: 0.4,
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAsc,
            columns: [
              DataColumn(
                label: const Text('# / ชื่อ'),
                onSort: (i, asc) =>
                    setState(() => _sort(columnIndex: i, ascending: asc)),
              ),
              DataColumn(
                label: const Text('อีเมล'),
                onSort: (i, asc) =>
                    setState(() => _sort(columnIndex: i, ascending: asc)),
              ),
              DataColumn(
                label: const Text('ลงทะเบียนเมื่อ'),
                onSort: (i, asc) =>
                    setState(() => _sort(columnIndex: i, ascending: asc)),
              ),
              const DataColumn(label: Text('คำตอบฟอร์ม')),
            ],
            rows: List<DataRow>.generate(_view.length, (i) {
              final r = _view[i];
              return DataRow(cells: [
                DataCell(Row(
                  children: [
                    _NumberDot(n: i + 1),
                    const SizedBox(width: 8),
                    Expanded(child: _NameCell(r: r)),
                  ],
                )),
                DataCell(Text(r.email ?? '-')),
                DataCell(Text(_formatDateTime(r.registeredAt))),
                DataCell(TextButton.icon(
                  onPressed: () => _showAnswers(r),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('ดูคำตอบ'),
                )),
              ]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildListSection() {
    if (_view.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('ไม่พบผู้ลงทะเบียนตามเงื่อนไข')),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _view.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = _view[i];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NumberDot(n: i + 1),
              const SizedBox(width: 10),
              Expanded(child: _NameCell(r: r)),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showAnswers(r),
                icon: const Icon(Icons.description_outlined),
                tooltip: 'ดูคำตอบ',
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== Utils =====
  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}\n${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// ===== UI pieces =====
class _NumberDot extends StatelessWidget {
  final int n;
  const _NumberDot({required this.n});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFFE9EFDF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text('$n',
          style:
              const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF506245))),
    );
  }
}

class _KpiProgressCard extends StatelessWidget {
  final String title;
  final double percent; // 0..1
  final String label;
  const _KpiProgressCard(
      {required this.title, required this.percent, required this.label});

  @override
  Widget build(BuildContext context) {
    final p =
        (percent.isNaN || percent.isInfinite) ? 0.0 : percent.clamp(0.0, 1.0);
    return Container(
      width: 168,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            width: 92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: p,
                  strokeWidth: 10,
                  backgroundColor: const Color(0xFFEFEFEF),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(p * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(label,
                          style:
                              const TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;
  const _InfoCard({required this.icon, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  final _Participant r;
  const _NameCell({required this.r});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Row(children: [
          if ((r.phone ?? '').isNotEmpty) ...[
            const Icon(Icons.phone, size: 14, color: Colors.black45),
            const SizedBox(width: 4),
            Text(r.phone!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.alternate_email, size: 14, color: Colors.black45),
          const SizedBox(width: 4),
          Text(r.email ?? '-', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      ],
    );
  }
}

/// ===== Local model (แปลงจาก Map ที่ได้จาก DatabaseService) =====
class _Participant {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final DateTime? registeredAt;
  final Map<String, dynamic> answers;

  _Participant({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.registeredAt,
    required this.answers,
  });

  factory _Participant.fromMap(Map<String, dynamic> m, {int? index}) {
    final first = (m['first_name'] ?? m['firstname'] ?? '').toString().trim();
    final last = (m['last_name'] ?? m['lastname'] ?? '').toString().trim();
    final full = [first, last]
        .where((s) => s.isNotEmpty)
        .join(' ')
        .trim();
    final email = (m['email'] ?? m['user_email'] ?? m['contact_email'])?.toString();
    final phone = (m['phone'] ?? m['tel'] ?? m['mobile'])?.toString();

    // เดา key วันที่ที่พบบ่อย
    final dt = _parseDate(m['registered_at']) ??
        _parseDate(m['created_at']) ??
        _parseDate(m['submit_time']) ??
        _parseDate(m['timestamp']) ??
        _parseDate(m['updated_at']);

    // ซ่อนคีย์พื้นฐานออกจาก answers
    const known = {
      'id','user_id','first_name','firstname','last_name','lastname',
      'email','user_email','contact_email','phone','tel','mobile',
      'status','registered_at','created_at','submit_time','timestamp','updated_at'
    };
    final ans = <String, dynamic>{};
    m.forEach((k, v) {
      if (!known.contains(k)) ans[k.toString()] = v;
    });

    return _Participant(
      id: (m['id'] ?? m['user_id'] ?? index ?? '').toString(),
      fullName: full.isEmpty ? (m['user_id']?.toString() ?? 'Unknown') : full,
      email: email,
      phone: phone,
      registeredAt: dt,
      answers: ans,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }
}
