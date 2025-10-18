// lib/pages/event/request_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/database_service.dart';

/// ===== THEME =====
const _bg = Color(0xFFF7F7F7);
const _cardBg = Color(0xFFFFFFFF);
const _textPrimary = Colors.black87;
const _textSecondary = Colors.black54;

const _danger = Color(0xFFCC3D3D);   // Reject
const _success = Color(0xFF3BA55C);  // Accept
const _chipGreenBg = Color(0xFFE9F6EE);
const _chipGreenFg = Color(0xFF1E7A45);

const _cardRadius = 14.0;
const _cardShadow = [
  BoxShadow(
    color: Color(0x11000000),
    blurRadius: 12,
    offset: Offset(0, 6),
  ),
];

/// ===== ตาราง: สัดส่วนคอลัมน์ =====
/// 1) ชื่อ
/// 2) ปี (อายุงาน)
/// 3) รายละเอียด (nickname + remark chip)
/// 4) สถานะ
const _colNameFlex = 6;
const _colYearsFlex = 2;
const _colDetailFlex = 4;
const _colStatusFlex = 3;
const _minTableWidth = 720.0;

/// ===== MODEL =====
enum RequestStatus { pending, accepted, rejected }

class RequestItem {
  final String id;
  final String fullName;
  final String nickname;
  final int years;
  final String? remark;
  RequestStatus status;

  RequestItem({
    required this.id,
    required this.fullName,
    required this.nickname,
    required this.years,
    this.remark,
    this.status = RequestStatus.pending,
  });

  factory RequestItem.fromJson(Map<String, dynamic> json) => RequestItem(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        nickname: json['nickname'] as String? ?? '',
        years: (json['years'] as num?)?.toInt() ?? 0,
        remark: json['remark'] as String?,
        status: _statusFrom(json['status'] as String?),
      );

  static RequestStatus _statusFrom(String? s) {
    switch (s) {
      case 'accepted':
        return RequestStatus.accepted;
      case 'rejected':
        return RequestStatus.rejected;
      default:
        return RequestStatus.pending;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'nickname': nickname,
        'years': years,
        'remark': remark,
        'status': status.name,
      };
}

/// ===== MOCK API =====
class _MockRequestApi {
  Future<List<RequestItem>> fetchPending() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      RequestItem(
        id: '1',
        fullName: 'อทิตยา จันทร์เพ็ญ',
        nickname: '',
        years: 24, // อายุ
        remark: 'อยากเจอเพื่อนในสายงานและฟังประสบการณ์จากวิทยากร',
      ),
      RequestItem(
        id: '2',
        fullName: 'ธนกร ศรีวิไล',
        nickname: '',
        years: 29,
        remark: 'กำลังเริ่มทำโปรเจกต์เกี่ยวกับชุมชน อยากได้คำแนะนำและพาร์ทเนอร์',
      ),
      RequestItem(
        id: '3',
        fullName: 'วริศรา เกตุแก้ว',
        nickname: '',
        years: 21,
        remark: 'สนใจหัวข้อเวิร์กช็อปด้านการออกแบบ อยากฝึกจากเคสจริง',
      ),
      RequestItem(
        id: '4',
        fullName: 'ปฏิพล ทองดี',
        nickname: '',
        years: 33,
        remark: 'อยากอัปสกิลและอัปเดตเทรนด์ล่าสุดของอุตสาหกรรม',
      ),
      RequestItem(
        id: '5',
        fullName: 'เกศรา อินทรสุข',
        nickname: '',
        years: 27,
        remark: 'ได้ยินว่าเน็ตเวิร์กดีมาก อยากขยายคอนเนคชันทางธุรกิจ',
      ),
      RequestItem(
        id: '6',
        fullName: 'นพดล ภูมิพัฒน์',
        nickname: '',
        years: 35,
        remark: 'อยากพาทีมไปดูงานต้นแบบ เพื่อนำไปปรับใช้ในองค์กร',
      ),
      RequestItem(
        id: '7',
        fullName: 'ศศิธร รัตนสกุล',
        nickname: '',
        years: 23,
        remark: 'กำลังหาหัวข้อทำวิทยานิพนธ์ อยากเก็บข้อมูลภาคสนาม',
      ),
      RequestItem(
        id: '8',
        fullName: 'ปรินทร์ ตั้งเจริญ',
        nickname: '',
        years: 31,
        remark: 'อยากลองนำเสนอไอเดียและรับฟีดแบ็กจากผู้เชี่ยวชาญ',
      ),
      RequestItem(
        id: '9',
        fullName: 'ชาลิสา ชื่นบุญ',
        nickname: '',
        years: 26,
        remark: 'อยากเข้าร่วมกิจกรรมอาสาและทำประโยชน์ให้ชุมชน',
      ),
      RequestItem(
        id: '10',
        fullName: 'ภูวเดช คเชนทร์',
        nickname: '',
        years: 28,
        remark: 'อยากเรียนรู้เครื่องมือใหม่ ๆ ที่ใช้ในโปรเจกต์เวิร์กช็อป',
      ),
      RequestItem(
        id: '11',
        fullName: 'ขวัญฤดี สวัสดิ์วงศ์',
        nickname: '',
        years: 22,
        remark: 'เพื่อนชวนมาลองร่วมกิจกรรม เผื่อได้แรงบันดาลใจเริ่มงานสายนี้',
      ),
      RequestItem(
        id: '12',
        fullName: 'อรุณชัย สุขสม',
        nickname: '',
        years: 40,
        remark: 'อยากแชร์ประสบการณ์และเมนเตอร์ให้คนรุ่นใหม่ในงาน',
      ),
    ];
  }

  Future<void> acceptMany(List<String> ids) async => Future.delayed(const Duration(milliseconds: 350));
  Future<void> rejectMany(List<String> ids) async => Future.delayed(const Duration(milliseconds: 350));
}


/// ===== PAGE =====
class RequestPage extends StatefulWidget {
  final String? eventId; // If provided, loads real requests for this event
  const RequestPage({super.key, this.eventId});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  final _api = _MockRequestApi();
  late Future<List<RequestItem>> _future;

  final Map<String, RequestItem> _items = <String, RequestItem>{};
  final Set<String> _selected = <String>{};
  bool _loadingAction = false;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _future = widget.eventId == null ? _api.fetchPending() : _fetchRemote();
  }

  Future<List<RequestItem>> _fetchRemote() async {
    final id = widget.eventId!;
    final db = DatabaseService();
    final matrix = await db.getFormMatrixFiber(id);
    // matrix: { message?, data?: {form_id, questions, responses} } or flat
    final data = (matrix['data'] ?? matrix) as Map<String, dynamic>;
    final responses = (data['responses'] as List?) ?? const [];
    final list = <RequestItem>[];
    for (final r in responses) {
      if (r is! Map) continue;
      final status = (r['status'] ?? '').toString();
      final userId = (r['user_id'] ?? '').toString();
      final full = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
      final remark = (r['answers'] is List && (r['answers'] as List).isNotEmpty)
          ? ((r['answers'] as List).first?.toString() ?? '')
          : null;
      list.add(RequestItem(
        id: userId,
        fullName: full.isEmpty ? userId : full,
        nickname: '',
        years: 0,
        remark: remark,
        status: RequestItem._statusFrom(status == 'stall' ? 'pending' : status == 'accept' ? 'accepted' : status == 'reject' ? 'rejected' : 'pending'),
      ));
    }
    return list;
  }

  void _applyFetched(List<RequestItem> list) {
    _items
      ..clear()
      ..addEntries(list.map((e) => MapEntry(e.id, e)));
  }

  int get _pendingCount =>
      _items.values.where((e) => e.status == RequestStatus.pending).length;

  void _toggleAll(bool v) {
    setState(() {
      _selectAll = v;
      _selected.clear();
      if (v) {
        _selected.addAll(
          _items.values.where((e) => e.status == RequestStatus.pending).map((e) => e.id),
        );
      }
    });
  }

  void _toggleRow(String id) {
    final it = _items[id];
    if (it == null || it.status != RequestStatus.pending) return;
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      final selectableIds = _items.values
          .where((e) => e.status == RequestStatus.pending)
          .map((e) => e.id)
          .toSet();
      _selectAll = _selected.isNotEmpty &&
          _selected.length == selectableIds.length &&
          _selected.difference(selectableIds).isEmpty;
    });
  }

  Future<void> _onReject() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    setState(() => _loadingAction = true);
    try {
      if (widget.eventId == null) {
        await _api.rejectMany(ids);
      } else {
        final db = DatabaseService();
        for (final id in ids) {
          await db.updateParticipantStatusFiber(userId: id, eventId: widget.eventId!, status: 'reject');
        }
      }
      for (final id in ids) { final it = _items[id]; if (it != null) it.status = RequestStatus.rejected; }
      _selected.clear();
      _selectAll = false;
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject ${ids.length} คน'), backgroundColor: _danger),
      );
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _onAccept() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    setState(() => _loadingAction = true);
    try {
      if (widget.eventId == null) {
        await _api.acceptMany(ids);
      } else {
        final db = DatabaseService();
        for (final id in ids) {
          await db.updateParticipantStatusFiber(userId: id, eventId: widget.eventId!, status: 'accept');
        }
      }
      for (final id in ids) { final it = _items[id]; if (it != null) it.status = RequestStatus.accepted; }
      _selected.clear();
      _selectAll = false;
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept ${ids.length} คน'), backgroundColor: _success),
      );
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'คำขอเข้าร่วม (${_pendingCount} คน)',
          style: const TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<RequestItem>>(
        future: _future,
        builder: (context, snapshot) {
          final hasLocalData = _items.isNotEmpty;

          if (snapshot.connectionState == ConnectionState.waiting && !hasLocalData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('โหลดข้อมูลล้มเหลว', style: TextStyle(color: _textSecondary)));
          }
          if (snapshot.hasData && !hasLocalData) {
            _applyFetched(snapshot.data!);
          }

          if (_items.isEmpty) {
            return const Center(child: Text('ไม่มีคำขอค้างอยู่'));
          }

          final rows = _items.values.toList()
            ..sort((a, b) => a.fullName.compareTo(b.fullName));

          // ===== ตารางแนวนอนหน้าตาแบบบล็อก =====
          return Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8),
              child: Builder(
                builder: (context) {
                  final screenW = MediaQuery.of(context).size.width;
                  final tableWidth = math.max(_minTableWidth, screenW);

                  return SizedBox(
                    width: tableWidth,
                    child: ListView.separated(
                      primary: false,
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                      physics: const ClampingScrollPhysics(),
                      itemCount: rows.length + 1, // + header
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // ===== Header (ชื่อ / ปี / รายละเอียด / สถานะ) =====
                          return Container(
                            decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(_cardRadius),
                              boxShadow: _cardShadow,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                _CircleCheck(
                                  selected: _selectAll,
                                  enabled: true,
                                  onTap: () => _toggleAll(!_selectAll),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  flex: _colNameFlex,
                                  child: Text('ชื่อ',
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                const Expanded(
                                  flex: _colYearsFlex,
                                  child: Text('อายุ',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  flex: _colDetailFlex,
                                  child: Text('รายละเอียด',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  flex: _colStatusFlex,
                                  child: Text('สถานะ',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          );
                        }

                        final e = rows[index - 1];
                        final selected = _selected.contains(e.id);
                        final selectable = e.status == RequestStatus.pending;

                        // ===== Row (บล็อก) =====
                        return Opacity(
                          opacity: selectable ? 1 : 0.6,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(_cardRadius),
                            onTap: selectable ? () => _toggleRow(e.id) : null,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(_cardRadius),
                                boxShadow: _cardShadow,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _CircleCheck(
                                    selected: selected,
                                    enabled: selectable,
                                    onTap: () => _toggleRow(e.id),
                                  ),
                                  const SizedBox(width: 12),

                                  // Col 1: ชื่อ (อย่างเดียว)
                                  Expanded(
                                    flex: _colNameFlex,
                                    child: Text(
                                      e.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: _textPrimary,
                                      ),
                                    ),
                                  ),

                                  // Col 2: ปี
                                  Expanded(
                                    flex: _colYearsFlex,
                                    child: Text(
                                      '${e.years} ปี',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: _textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Col 3: รายละเอียด (nickname + remark chip)
                                  Expanded(
                                    flex: _colDetailFlex,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          if (e.nickname.isNotEmpty)
                                            Text(
                                              e.nickname,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: _textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          if (e.remark != null) _GreenChip(text: e.remark!),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Col 4: สถานะ
                                  Expanded(
                                    flex: _colStatusFlex,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _StatusDot(status: e.status),
                                          const SizedBox(width: 6),
                                          Text(
                                            _labelFromStatus(e.status),
                                            style: TextStyle(
                                              color: e.status == RequestStatus.pending
                                                  ? Colors.orange
                                                  : (e.status == RequestStatus.accepted
                                                      ? _success
                                                      : _danger),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),

      // ===== Bottom actions: Accept / Reject =====
      bottomSheet: _selected.isEmpty
          ? null
          : _FloatingActionBar(
              selectedCount: _selected.length,
              loading: _loadingAction,
              onReject: _onReject,
              onAccept: _onAccept,
            ),
    );
  }
}

/// ===== Circle Check (multi-select) =====
class _CircleCheck extends StatelessWidget {
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _CircleCheck({
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: enabled ? onTap : null,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? _success : Colors.transparent,
          border: Border.all(
            color: selected ? _success : const Color(0xFF315A2C),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// ===== Misc Widgets =====
class _GreenChip extends StatelessWidget {
  final String text;
  const _GreenChip({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _chipGreenBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _chipGreenFg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final RequestStatus status;
  const _StatusDot({required this.status});
  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case RequestStatus.accepted:
        c = _success;
        break;
      case RequestStatus.rejected:
        c = _danger;
        break;
      case RequestStatus.pending:
      default:
        c = Colors.orangeAccent;
        break;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}

class _FloatingActionBar extends StatelessWidget {
  final int selectedCount;
  final bool loading;
  final VoidCallback onReject;
  final VoidCallback onAccept;

  const _FloatingActionBar({
    required this.selectedCount,
    required this.loading,
    required this.onReject,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Color(0x22000000),
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _BarButton.outlined(
                color: _danger,
                label: 'Reject $selectedCount คน',
                loading: loading,
                onPressed: loading ? null : onReject,
                leading: const Icon(Icons.cancel_outlined, color: _danger),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BarButton.filled(
                color: _success,
                label: 'Accept $selectedCount คน',
                loading: loading,
                onPressed: loading ? null : onAccept,
                leading: const Icon(Icons.person_add_alt_1, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final bool loading;
  final VoidCallback? onPressed;
  final Widget? leading;

  const _BarButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.loading,
    required this.onPressed,
    this.leading,
  });

  factory _BarButton.filled({
    required String label,
    required Color color,
    required bool loading,
    required VoidCallback? onPressed,
    Widget? leading,
  }) =>
      _BarButton(
        label: label,
        color: color,
        filled: true,
        loading: loading,
        onPressed: onPressed,
        leading: leading,
      );

  factory _BarButton.outlined({
    required String label,
    required Color color,
    required bool loading,
    required VoidCallback? onPressed,
    Widget? leading,
  }) =>
      _BarButton(
        label: label,
        color: color,
        filled: false,
        loading: loading,
        onPressed: onPressed,
        leading: leading,
      );

  @override
  Widget build(BuildContext context) {
    final style = filled
        ? ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          );

    final child = loading
        ? const SizedBox(
            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );

    return filled
        ? ElevatedButton(onPressed: onPressed, style: style as ButtonStyle, child: child)
        : OutlinedButton(onPressed: onPressed, style: style as ButtonStyle, child: child);
  }
}

/// ===== Helpers =====
String _labelFromStatus(RequestStatus s) {
  switch (s) {
    case RequestStatus.pending:
      return 'รอยืนยัน';
    case RequestStatus.accepted:
      return 'รับเข้าร่วมแล้ว';
    case RequestStatus.rejected:
      return 'ปฏิเสธแล้ว';
  }
}
