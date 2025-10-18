// lib/pages/event/event_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_app/components/app_colors.dart';
import '../../services/database_service.dart';
import '../../models/event.dart';
import 'qa_page.dart'; // ✅ เส้นทางที่ถูก (จาก pages/event ไป pages)
import 'event_form_question.dart'; // ✅ เพิ่ม import เพื่อนำทางไปหน้าฟอร์ม

/// ===== THEME =====
const _bg = AppColors.bg;
const _cardRadius = 26.0;
const _sheetRadius = 26.0;

// เขียวหลัก (ปกติ)
const _accent = Color(0xFF7FAA3B);
const _accentDark = Color(0xFF6C8F31);

// 🔴 สีแดงตอน Cancel Request
const _danger = Color(0xFFE53935);
const _dangerDark = Color(0xFFC62828);

const _textPrimary = Colors.black87;
const _textSecondary = Colors.black54;

const _titleSize = 24.0;
const _bodySize = 16.0;

/// ===== Registration modes/status =====
enum EventRegMode { registerNow, requestToJoin }
enum EventRegStatus { notJoined, awaitingConfirmation, joined }

/// วัน/รอบจัดงาน (เวลาอย่างเดียว – ใช้เป็นฐาน)
class EventDaySchedule {
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  EventDaySchedule({
    required this.date,
    required this.startTime,
    required this.endTime,
  });
}

/// รายละเอียดต่อวัน/รอบ (สืบทอดเวลา + ข้อมูลเฉพาะรอบ)
class EventDayDetail extends EventDaySchedule {
  final String? title;        // ชื่อรอบ เช่น "Workshop/Opening/Closing"
  final String? location;     // สถานที่ของรอบ (ต่างจาก event-level ได้)
  final String? description;  // คำอธิบายของรอบ
  final String? notes;        // โน้ตย่อย
  final String? mapUrl;       // ลิงก์แผนที่เฉพาะรอบ (ไม่แสดงปุ่ม)
  final bool? isFree;         // ถ้าต้องการ override ฟรี/ไม่ฟรี ในบางรอบ

  EventDayDetail({
    required super.date,
    required super.startTime,
    required super.endTime,
    this.title,
    this.location,
    this.description,
    this.notes,
    this.mapUrl,
    this.isFree,
  });
}

class EventDetailPage extends StatefulWidget {
  const EventDetailPage.fromListItem({
    super.key,
    required this.event,
    this.commentCount = 0,
    this.overrideMode,
    this.schedules,            // เดิม: เวลาอย่างเดียว
    this.dayDetails,           // ใหม่: รายละเอียดรายวัน (ถ้ามีจะใช้ข้อมูลนี้แสดง)
  });

  final AppEvent event;
  final int commentCount;
  final EventRegMode? overrideMode;
  final List<EventDaySchedule>? schedules;
  final List<EventDayDetail>? dayDetails; // ✅ เพิ่มก่อนหน้า

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late final EventRegMode _mode = widget.overrideMode ??
      ((widget.event.isFree ?? false)
          ? EventRegMode.registerNow
          : EventRegMode.requestToJoin);

  EventRegStatus _status = EventRegStatus.notJoined;
  bool _submitting = false;
  int? _joined;
  int? _capacity;
  bool _loadingCounts = true;
  bool _changed = false;

  // ===== สร้างข้อมูลรอบ/วัน =====
  late final List<EventDayDetail> _details = _buildDetails(); // รายการที่ใช้จริงในหน้า
  int _selected = 0;
  final _tabScroll = ScrollController();

  List<EventDayDetail> _buildDetails() {
    // 1) ถ้าผู้เรียกส่ง dayDetails มาก็ใช้เลย
    if (widget.dayDetails != null && widget.dayDetails!.isNotEmpty) {
      return widget.dayDetails!;
    }

    // 2) ถ้าส่ง schedules (เวลาอย่างเดียว) มา ให้ทำ detail จาก event-level
    if (widget.schedules != null && widget.schedules!.isNotEmpty) {
      return widget.schedules!.map((s) {
        return EventDayDetail(
          date: s.date,
          startTime: s.startTime,
          endTime: s.endTime,
          title: null, // ไม่มีชื่อรอบ ก็ไม่แสดง
          location: widget.event.location,
          description: widget.event.description,
          notes: null,
          mapUrl: null,
          isFree: widget.event.isFree,
        );
      }).toList();
    }

    // 3) fallback เดิม: แปลงจาก event-level (วันเดียว)
    final start = widget.event.startTime;
    final end = widget.event.endTime ?? start.add(const Duration(hours: 1));
    return [
      EventDayDetail(
        date: DateTime(start.year, start.month, start.day),
        startTime: start,
        endTime: end,
        title: null,
        location: widget.event.location,
        description: widget.event.description,
        notes: null,
        mapUrl: null,
        isFree: widget.event.isFree,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _fetchCounts();
    _fetchMyStatus();
  }

  Future<void> _fetchCounts() async {
    try {
      final db = DatabaseService();
      final d = await db.getEventDetailFiber(widget.event.id);
      final jp = d['current_participation'];
      final cp = d['max_participation'];
      setState(() {
        _joined = jp is int ? jp : int.tryParse('$jp');
        _capacity = cp is int ? cp : int.tryParse('$cp');
        _loadingCounts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  Future<void> _fetchMyStatus() async {
    try {
      final s = await DatabaseService().getMyEventStatusFiber(widget.event.id);
      if (!mounted) return;
      if (s == null) return;
      setState(() {
        switch (s) {
          case 'accept':
            _status = EventRegStatus.joined;
            break;
          case 'stall':
            _status = EventRegStatus.awaitingConfirmation;
            break;
          case 'reject':
          default:
            _status = EventRegStatus.notJoined;
        }
      });
    } catch (_) {}
  }

  // ===== Labels =====
  String _primaryLabel() {
    switch (_mode) {
      case EventRegMode.registerNow:
        return _status == EventRegStatus.joined ? "YOU'RE IN" : "REGISTER NOW";
      case EventRegMode.requestToJoin:
        if (_status == EventRegStatus.joined) return "YOU'RE IN";
        if (_status == EventRegStatus.awaitingConfirmation) return "CANCEL REQUEST";
        return "REQUEST TO JOIN";
    }
  }

  // ===== Dynamic colors =====
  Color _primaryBgColor() {
    if (_mode == EventRegMode.requestToJoin &&
        _status == EventRegStatus.awaitingConfirmation) {
      return _danger;
    }
    return _accent;
  }

  Color _primaryOverlayColor() {
    if (_mode == EventRegMode.requestToJoin &&
        _status == EventRegStatus.awaitingConfirmation) {
      return _dangerDark.withOpacity(.12);
    }
    return _accentDark.withOpacity(.12);
  }

  // ===== Enabled/Disabled =====
  bool _isPrimaryDisabled() {
    if (_submitting) return true;
    if (_status == EventRegStatus.joined) return true;
    return false;
  }

  // ===== Action =====
  Future<void> _onPrimaryTap() async {
    if (_isPrimaryDisabled()) return;
    setState(() => _submitting = true);

    await Future.delayed(const Duration(milliseconds: 250));

    String toast;
    if (_mode == EventRegMode.registerNow) {
      // Join directly (no form)
      try {
        await DatabaseService().joinEventNoFormFiber(widget.event.id);
        _status = EventRegStatus.joined;
        if (_joined != null) _joined = (_joined ?? 0) + 1;
        toast = "You're in!";
        _changed = true;
      } catch (e) {
        toast = 'Join failed: $e';
      }
    } else {
      if (_status == EventRegStatus.awaitingConfirmation) {
        // No cancel API yet
        toast = "Cancel not available";
      } else {
        // ✅ เปลี่ยนจาก bottom sheet -> นำทางไปหน้าใหม่
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EventFormQuestionPage(eventId: widget.event.id),
          ),
        );
        if (ok == true) {
          _status = EventRegStatus.awaitingConfirmation;
          toast = "Request sent";
          _changed = true;
        } else {
          toast = "Form not submitted";
        }
      }
    }

    setState(() => _submitting = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(_changed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final current = _details[_selected];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () {
            Navigator.of(context).pop(_changed);
          },
        ),
        title: const Text(
          'Event  Details',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),

      bottomNavigationBar: _bottomPrimaryButton(),

      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Container(
                width: 900,
                height: constraints.maxHeight - 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_cardRadius),
                  color: Colors.black,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _heroHeaderWithImage(e),

                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(_sheetRadius),
                            topRight: Radius.circular(_sheetRadius),
                          ),
                        ),
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _dateTabsBar(),                 // 👈 แท็บวัน/รอบ
                                const SizedBox(height: 8),
                                _timeRow(current.startTime, current.endTime),
                                const SizedBox(height: 14),

                                _titleBlock(e.title),          // ชื่ออีเวนต์หลัก
                                if ((current.title ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  _sessionTitlePill(current.title!.trim()), // ชื่อรอบ (ถ้ามี)
                                ],

                                const SizedBox(height: 10),
                                _locationRow((current.location ?? e.location)),
                                const SizedBox(height: 10),
                                _organizerRow(e.organizer),
                                _participantsRow(),
                                const SizedBox(height: 18),
                                _descriptionSection(
                                  (current.description ?? e.description),
                                  notes: current.notes,
                                ),
                              ],
                            ),
                          ),
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
      ),
    );
  }

  // ===== HERO (Image + Q&A pill เขียว) =====
  Widget _heroHeaderWithImage(AppEvent e) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: (e.imageUrl == null || e.imageUrl!.isEmpty)
              ? Container(
                  color: const Color(0xFF1D242A),
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined, color: Colors.white60, size: 42),
                  ),
                )
              : Image.network(
                  e.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1D242A),
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined, color: Colors.white60, size: 42),
                    ),
                  ),
                ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Material(
            color: _accent,
            elevation: 3,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                // ✅ นำทางไปหน้า Q&A
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QaPage(
                      title: 'Q&A • ${e.title}',
                      organizerName: (e.organizer == null || e.organizer!.trim().isEmpty)
                          ? 'Organizer'
                          : e.organizer!.trim(),
                      dataSource: EventQaApiDataSource(
                        eventId: widget.event.id,
                        organizerName: (e.organizer == null || e.organizer!.trim().isNotEmpty)
                            ? e.organizer!.trim()
                            : 'Organizer',
                      ),
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Text(
                  'Q&A',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===== ปุ่มหลักด้านล่าง (สีเปลี่ยนตามสถานะ) =====
  Widget _bottomPrimaryButton() {
    final bg = _primaryBgColor();
    final overlay = _primaryOverlayColor();

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isPrimaryDisabled() ? null : _onPrimaryTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: Colors.black26,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(overlay),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_submitting) ...[
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  _primaryLabel(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== Tabs วันที่แบบแนวนอน (แท็บที่เลือกเป็นสีเขียว) =====
  Widget _dateTabsBar() {
    return Row(
      children: [
        _arrowBtn(icon: Icons.chevron_left_rounded, onTap: () {
          _tabScroll.animateTo(
            (_tabScroll.offset - 220).clamp(0, _tabScroll.position.maxScrollExtent),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }),
        const SizedBox(width: 6),
        Expanded(
          child: SingleChildScrollView(
            controller: _tabScroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < _details.length; i++) ...[
                  _dateChip(
                    i,
                    label: _dateChipLabel(_details[i].date),
                    selected: i == _selected,
                    onTap: () => setState(() => _selected = i),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        _arrowBtn(icon: Icons.chevron_right_rounded, onTap: () {
          _tabScroll.animateTo(
            (_tabScroll.offset + 220).clamp(0, _tabScroll.position.maxScrollExtent),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }),
      ],
    );
  }

  Widget _arrowBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFF2F2F2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 36, height: 36, child: Icon(icon, color: _textPrimary)),
      ),
    );
  }

  String _dateChipLabel(DateTime d) =>
      '${_weekdayShortEN(d.weekday)}, ${d.day.toString().padLeft(2, '0')} ${_monthShortEN(d.month)}';

  Widget _dateChip(int index,
      {required String label, required bool selected, required VoidCallback onTap}) {
    return Material(
      color: selected ? _accent : const Color(0xFFF2F2F2),
      borderRadius: BorderRadius.circular(12),
      elevation: selected ? 2 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : _textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ===== Header rows =====
  Widget _timeRow(DateTime start, DateTime end) {
    return Row(
      children: [
        const Icon(Icons.access_time_rounded, size: 18, color: _textSecondary),
        const SizedBox(width: 8),
        Text('${_hhmm(start)} - ${_hhmm(end)}',
            style: const TextStyle(fontSize: _bodySize, color: _textPrimary)),
      ],
    );
  }

  Widget _sessionTitlePill(String title) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6E9),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
          color: _textPrimary,
        ),
      ),
    );
  }

  Widget _titleBlock(String title) {
    return Text(
      title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: _titleSize,
        height: 1.12,
        letterSpacing: .3,
        color: _textPrimary,
      ),
    );
  }

  // ⚠️ ปรับให้ไม่มีปุ่ม View Map แล้ว
  Widget _locationRow(String? location) {
    if ((location ?? '').isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on_outlined, size: 18, color: _textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            location!,
            style: const TextStyle(fontSize: _bodySize, color: _textPrimary, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _organizerRow(String? organizer) {
    if ((organizer ?? '').isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.mic_none_rounded, size: 18, color: _textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Organized by: ${organizer!}',
              style: const TextStyle(fontSize: _bodySize, color: _textPrimary)),
        ),
      ],
    );
  }

  Widget _participantsRow() {
    if (_loadingCounts) return const SizedBox.shrink();
    if (_joined == null && _capacity == null) return const SizedBox.shrink();
    final j = _joined ?? 0;
    final c = _capacity ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        children: [
          const Icon(Icons.people_outline, size: 18, color: _textSecondary),
          const SizedBox(width: 8),
          Text('$j/$c participants', style: const TextStyle(fontSize: _bodySize, color: _textPrimary)),
        ],
      ),
    );
  }

  // ===== รายละเอียดงาน =====
  Widget _descriptionSection(String? description, {String? notes}) {
    final text = (description == null || description.trim().isEmpty) ? '-' : description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        const Text(
          'Event Description',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _ExpandableText(
          text: text,
          textStyle: const TextStyle(
            fontSize: _bodySize,
            height: 1.45,
            color: _textPrimary,
          ),
        ),
        if ((notes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Notes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            notes!.trim(),
            style: const TextStyle(fontSize: _bodySize, height: 1.45, color: _textPrimary),
          ),
        ],
      ],
    );
  }

  // ===== Helpers =====
  String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  String _weekdayShortEN(int w) =>
      const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][(w + 6) % 7];
  String _monthShortEN(int m) =>
      const ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'][m - 1];
}

// ========= Expandable text =========
class _ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines;
  final TextStyle? textStyle;
  const _ExpandableText({
    required this.text,
    this.trimLines = 3,
    this.textStyle,
  });

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ??
        const TextStyle(fontSize: _bodySize, height: 1.45, color: _textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : widget.trimLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: style,
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'less' : 'more',
            style: const TextStyle(
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
