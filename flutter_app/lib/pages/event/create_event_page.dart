// lib/pages/event/create_event_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/database_service.dart';
import '../../components/visibility_selector.dart';
import '../../components/app_colors.dart'; 

/* ---------- Models ---------- */
class DayPlan {
  DateTime date;
  TimeOfDay start;
  TimeOfDay end;
  String location;
  String description;
  bool sameAsDay1;

  DayPlan({
    required this.date,
    required this.start,
    required this.end,
    this.location = '',
    this.description = '',
    this.sameAsDay1 = false,
  });
}

// แบบฟอร์ม (inline ที่ Step 2)
class _FormQuestion {
  String title;
  bool isRequired;
  _FormQuestion({this.title = '', this.isRequired = false});

  Map<String, dynamic> toJson(int index) => {
        'order_index': index,
        'question_text': title.trim(),
        'required': isRequired,
      };
}

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});
  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  int _step = 0;
  String get _stepTitle =>
      const ['Basic information', 'Details', 'Questionnaire', 'Preview'][_step];

  // Basics
  final _name = TextEditingController();
  final _capacity = TextEditingController();

  // Cover photo
  final ImagePicker _picker = ImagePicker();
  Uint8List? _coverBytes;

  // Days
  final List<DayPlan> _days = [];
  // Preview selection
  int _previewDayIndex = 0;

  // Manageable orgs
  List<Map<String, dynamic>> _manageableOrgs = const [];
  String? _selectedOrganizerPath;

  // Questions
  final List<_FormQuestion> _questions = [];

  // Visibility
  VisibilityAccess _access = VisibilityAccess.public;
  Set<String> _facultyPaths = {};
  Set<String> _clubPaths = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final startLocal = _roundUpToHour(now.add(const Duration(hours: 0)));
    final endLocal = startLocal.add(const Duration(hours: 2));

    _days.add(DayPlan(
      date: DateTime(startLocal.year, startLocal.month, startLocal.day),
      start: TimeOfDay(hour: startLocal.hour, minute: startLocal.minute),
      end: TimeOfDay(hour: endLocal.hour, minute: endLocal.minute),
    ));

    _loadManageableOrgs();
  }                     

  DateTime _roundUpToHour(DateTime t) {
    if (t.minute == 0 && t.second == 0 && t.millisecond == 0 && t.microsecond == 0) return t;
    return DateTime(t.year, t.month, t.day, t.hour + 1);
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    super.dispose();
  }

  // ---- Utils ----
  String _fmtDate(DateTime d) =>
      '${['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][(d.weekday + 6) % 7]}, '
      '${d.day.toString().padLeft(2, '0')} '
      '${['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][d.month - 1]}';
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  int _toInt(String s, {int fallback = 0}) => int.tryParse(s.trim()) ?? fallback;

  Future<void> _pickCover() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _coverBytes = bytes);
  }

  Future<void> _pickDate(int i) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _days[i].date,
    );
    if (picked != null) setState(() => _days[i].date = picked);
  }

  Future<void> _pickTime(int i, {required bool start}) async {
    final t = await showTimePicker(
      context: context,
      initialTime: start ? _days[i].start : _days[i].end,
    );
    if (t != null) setState(() => start ? _days[i].start = t : _days[i].end = t);
  }

  Future<void> _loadManageableOrgs() async {
    try {
      final list = await DatabaseService().getManageableOrgsFiber();
      setState(() {
        _manageableOrgs = list;
        if (list.isNotEmpty) {
          _selectedOrganizerPath ??= (list.first['org_path'] ?? '').toString();
        }
      });
    } catch (_) {}
  }

  // ---- Stepper Navigation ----
  void _nextStep() {
    if (_step == 0) {
      if (_name.text.trim().isEmpty ||
          _capacity.text.trim().isEmpty ||
          int.tryParse(_capacity.text.trim()) == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please fill Event Name and a valid Max Registrants.')));
        return;
      }
      if (_access == VisibilityAccess.custom &&
          _facultyPaths.isEmpty &&
          _clubPaths.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please choose at least one faculty or club.')));
        return;
      }
    }

    if (_step == 1) {
      if (_days.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Please add at least one day.')));
        return;
      }
      final invalidTime = _days.any((d) {
        final start =
            DateTime(d.date.year, d.date.month, d.date.day, d.start.hour, d.start.minute);
        final end =
            DateTime(d.date.year, d.date.month, d.date.day, d.end.hour, d.end.minute);
        return end.isBefore(start);
      });
      if (invalidTime) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('End time must be after start time.')));
        return;
      }
      final first = _days.first;
      final locMissing = _days.asMap().entries.any((e) {
        final i = e.key;
        final d = e.value;
        final loc = (i == 0 || !d.sameAsDay1) ? d.location.trim() : first.location.trim();
        return loc.isEmpty;
      });
      if (locMissing) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill Location for all days.')));
        return;
      }
    }

    setState(() => _step = (_step + 1).clamp(0, 3));
  }

  void _prevStep() => setState(() => _step = (_step - 1).clamp(0, 3));

  Map<String, dynamic> _buildVisibility(String postedOrgPath) {
    if (_access == VisibilityAccess.public) {
      return {
        'access': 'public',
        'audience': [],
        'allow_user_ids': [],
        'deny_user_ids': [],
        'include_positions': [],
        'exclude_positions': [],
      };
    }
    if (_access == VisibilityAccess.org) {
      return {
        'access': 'org',
        'audience': [
          {'org_path': postedOrgPath, 'scope': 'exact'}
        ],
        'allow_user_ids': [],
        'deny_user_ids': [],
        'include_positions': [],
        'exclude_positions': [],
      };
    }
    final audience = <Map<String, dynamic>>[];
    for (final p in _facultyPaths) {
      audience.add({'org_path': p, 'scope': 'subtree'});
    }
    for (final p in _clubPaths) {
      audience.add({'org_path': p, 'scope': 'exact'});
    }
    return {
      'access': 'org',
      'audience': audience,
      'allow_user_ids': [],
      'deny_user_ids': [],
      'include_positions': [],
      'exclude_positions': [],
    };
  }

  void _submit() {
    String? err;
    if (_name.text.trim().isEmpty) err ??= 'Please enter Event Name';
    if (_capacity.text.trim().isEmpty || int.tryParse(_capacity.text.trim()) == null) {
      err ??= 'Please provide a valid number for Max Registrants';
    }
    if (_days.isEmpty) err ??= 'Please add at least one day';
    if (_access == VisibilityAccess.custom && _facultyPaths.isEmpty && _clubPaths.isEmpty) {
      err ??= 'Please choose at least one faculty or club';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    // propagate Same as Day 1
    final first = _days.first;
    for (var i = 1; i < _days.length; i++) {
      final d = _days[i];
      if (d.sameAsDay1) {
        d.location = first.location;
        d.description = first.description;
        d.start = first.start;
        d.end = first.end;
      }
    }

    () async {
      try {
        final orgPath = _selectedOrganizerPath ?? '';
        if (orgPath.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select Organizer org unit')));
          return;
        }

        // Resolve node_id
        String? node_id;
        for (final m in _manageableOrgs) {
          if ((m['org_path'] ?? '') == orgPath) {
            node_id = (m['node_id'] ?? m['NodeID'] ?? m['nodeId'] ?? m['NodeId'] ?? m['id'] ?? m['_id'])?.toString();
            break;
          }
        }
        if (node_id == null || node_id!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Organizer node_id not found; reload Manageable Orgs')));
          return;
        }

        // Pick a role (position_key)
        final myMems = await DatabaseService().getMyMembershipsFiber();
        String? posKey;
        String? labelForPostedAs;
        for (final m in myMems) {
          if ((m['org_path'] ?? '') == orgPath &&
              (m['position_key'] ?? '').toString().isNotEmpty) {
            posKey = m['position_key'].toString();
            break;
          }
        }
        try {
          labelForPostedAs = _manageableOrgs
              .firstWhere((m) => (m['org_path'] ?? '') == orgPath, orElse: () => const {})['label']
              ?.toString();
        } catch (_) {}
        posKey ??=
            (myMems.isNotEmpty ? (myMems.first['position_key']?.toString()) : null);
        if (posKey == null || posKey!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No eligible role found to post as organizer')));
          return;
        }

        // Schedules mapping (UTC ISO8601)
        final schedules = _days.map((d) {
          final tStart = DateTime(d.date.year, d.date.month, d.date.day, d.start.hour, d.start.minute).toUtc();
          final tEnd   = DateTime(d.date.year, d.date.month, d.date.day, d.end.hour, d.end.minute).toUtc();
          final dateOnly = DateTime(d.date.year, d.date.month, d.date.day).toUtc();
          return {
            'date': dateOnly.toIso8601String(),
            'time_start': tStart.toIso8601String(),
            'time_end': tEnd.toIso8601String(),
            'location': d.location,
            'description': d.description,
          };
        }).toList();

        final visibility = _buildVisibility(orgPath);

        // --------- Payload: สร้างอีเวนต์แบบ DRAFT/inactive และมีฟอร์มหรือไม่ตามคำถามที่ใส่ ---------
        final payload = {
          'node_id': node_id,
          'NodeID': node_id,
          'topic': _name.text.trim(),
          'description': '',
          'max_participation': _toInt(_capacity.text),
          'posted_as': {'org_path': orgPath, 'position_key': posKey, 'label': labelForPostedAs ?? ''},
          'org_of_content': orgPath,
          'status': 'inactive',
          'have_form': _questions.isNotEmpty,
          'schedules': schedules,
          'visibility': visibility, 
        };

        final res = await DatabaseService().createEventFiber(
          payload,
          imageBytes: _coverBytes,                 
          imageFilename: 'cover.jpg',             
          postedAs: {'org_path': orgPath, 'position_key': posKey},
          nodeId: node_id,
        );
        if (!mounted) return;

        // Extract eventId robustly across various backend response shapes
        String _pickId(Map<String, dynamic> m) {
          for (final k in const [
            'event_id', 'eventId', 'EventID', 'EventId',
            'id', '_id'
          ]) {
            final v = m[k];
            if (v == null) continue;
            final s = v.toString();
            if (s.isNotEmpty) return s;
          }
          return '';
        }

        String eventId = '';
        try {
          if (res is Map<String, dynamic>) {
            // Prefer nested 'event' or 'data' object if present
            final Map<String, dynamic>? inner = (() {
              final ev = res['event'];
              if (ev is Map) return Map<String, dynamic>.from(ev);
              final data = res['data'];
              if (data is Map) return Map<String, dynamic>.from(data);
              return null;
            })();
            if (inner != null) {
              eventId = _pickId(inner);
            }
            if (eventId.isEmpty) {
              eventId = _pickId(res);
            }
          } else {
            eventId = '';
          }
        } catch (_) {
          eventId = '';
        }

        // Flow สร้างฟอร์มคำถาม: init + replace questions
        if (eventId.isNotEmpty && _questions.isNotEmpty) {
          try {
            await DatabaseService().initializeFormFiber(eventId); // POST /event/:id/form/initialize

            final List<Map<String, dynamic>> builtQuestions = _questions
                .asMap()
                .entries
                .map((e) => e.value.toJson(e.key + 1))
                .where((q) => (q['question_text'] as String).isNotEmpty)
                .toList();

            if (builtQuestions.isNotEmpty) {
              // POST /event/:id/form/questions (replace all)
              await DatabaseService().createFormQuestionsFiber(eventId, builtQuestions);
            }
          } catch (e) {
            // ไม่ fail ทั้ง flow แค่แจ้งเตือน
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Form setup warning: $e')),
            );
          }
        }

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Event created'),
            content: Text('ID: ${eventId.isEmpty ? '(unknown)' : eventId}'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
      }
    }();
  }

  // ===================== UI (Steps) =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          'Create Event',
          style: TextStyle(color: AppColors.deepGreen, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: AppColors.deepGreen),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        children: [
          Center(child: Text(_stepTitle, style: const TextStyle(color: AppColors.deepGreen, fontSize: 16, fontWeight: FontWeight.w700))),
          const SizedBox(height: 10),
          Center(child: _CenteredStepper(step: _step)),
          const SizedBox(height: 12),

          if (_step == 0) _stepBasic(),
          if (_step == 1) _stepDetails(),
          if (_step == 2) _stepQuestionnaireInline(),
          if (_step == 3) _stepPreview(),

          const SizedBox(height: 16),
          Row(
            children: [
              if (_step > 0)
                Expanded(child: OutlinedButton(onPressed: _prevStep, child: const Text('Back'))),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _step == 3 ? _submit : _nextStep,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.deepGreen, foregroundColor: AppColors.bg),
                  child: Text(_step == 3 ? 'Create Event' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== Step 0: Basic Info =====
  Widget _stepBasic() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Add Photos'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardGrey,
            border: Border.all(color: AppColors.chipGrey),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _coverBytes == null
                      ? Container(
                          color: AppColors.cardGrey,
                          child: const Center(
                            child: Icon(Icons.image_outlined, size: 56, color: AppColors.sage),
                          ),
                        )
                      : Image.memory(_coverBytes!, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.deepGreen,
                      foregroundColor: AppColors.bg,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _pickCover,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add photo'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        _sectionTitle('Event Name'),
        const SizedBox(height: 8),
        _boxedField(
          controller: _name, 
          hint: 'Your event name...', 
          suffixIcon: Icons.badge_outlined,
        ),
        const SizedBox(height: 16),

        _sectionTitle('Select who can register'),
        const SizedBox(height: 8),

        VisibilitySelector(
          value: _access,
          postedOrgPath: _selectedOrganizerPath,
          facultySelected: _facultyPaths,
          clubSelected: _clubPaths,
          onAccessChanged: (v) => setState(() => _access = v),
          onFacultyChanged: (set) => setState(() => _facultyPaths = set),
          onClubChanged: (set) => setState(() => _clubPaths = set),
        ),

        const SizedBox(height: 16),

        _sectionTitle('Organizer'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedOrganizerPath,
          hint: const Text('Select organizer org unit'),
          menuMaxHeight: 320,
          items: _manageableOrgs.map((m) {
            final path = (m['org_path'] ?? '').toString();
            final label = (m['short_name'] ?? m['shortname'] ?? m['name'] ?? path).toString();
            return DropdownMenuItem<String>(
              value: path,
              child: Text(label, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedOrganizerPath = v),
        ),

        const SizedBox(height: 16),

        _sectionTitle('Max Registrants'),
        const SizedBox(height: 8),
        _boxedField(
          controller: _capacity,
          hint: 'Number of people that can register',
          suffixIcon: Icons.people_alt_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }

  // ===== Step 1: Details =====
  Widget _stepDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Date & Time'),
        const SizedBox(height: 8),
        _dateTimeSection(),
      ],
    );
  }

  // ===== Step 2: Questionnaire =====
  Widget _stepQuestionnaireInline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Questionnaire'),
        const SizedBox(height: 8),
        for (int i = 0; i < _questions.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardGrey,
              border: Border.all(color: AppColors.chipGrey),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Q${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.deepGreen)),
                  const Spacer(),
                  const Text('Required', style: TextStyle(fontSize: 12, color: AppColors.deepGreen)),
                  Switch(
                    value: _questions[i].isRequired,
                    activeColor: AppColors.deepGreen,
                    onChanged: (v) => setState(() => _questions[i].isRequired = v),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _questions.removeAt(i)),
                    icon: const Icon(Icons.delete_outline, color: AppColors.sage),
                    tooltip: 'Remove',
                  ),
                ]),
                const SizedBox(height: 8),
                _boxedSmall(
                  child: TextFormField(
                    initialValue: _questions[i].title,
                    decoration: InputDecoration(
                      hintText: _questions[i].isRequired ? 'Question title *' : 'Question title',
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => _questions[i].title = v,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _questions.add(_FormQuestion())),
            icon: const Icon(Icons.add),
            label: const Text('Add question'),
          ),
        ),
      ],
    );
  }

  // ===== Step 3: Preview =====
  Widget _stepPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Preview'),
        const SizedBox(height: 8),
        _detailLikePreviewCard(),
      ],
    );
  }

  /* --- UI helpers --- */
  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.deepGreen),
      );

  Widget _boxedField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    IconData? suffixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color.fromARGB(0, 255, 255, 255),
            border: Border.all(color: AppColors.chipGrey),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: const InputDecoration(
              hintText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(right: 40),
            ).copyWith(hintText: hint),
          ),
        ),
        if (suffixIcon != null)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(suffixIcon, color: AppColors.sage),
          ),
      ],
    );
  }

  Widget _boxedSmall({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(0, 255, 255, 255),
        border: Border.all(color: AppColors.chipGrey),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: child,
    );
  }

  Widget _dateTimeSection() {
    final children = <Widget>[];
    for (var i = 0; i < _days.length; i++) {
      children.add(_dayCard(i));
      children.add(const SizedBox(height: 8));
    }
    children.add(
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _addDay,
          icon: const Icon(Icons.add),
          label: const Text('Add day'),
        ),
      ),
    );
    return Column(children: children);
  }

  void _addDay() {
    final base = _days.isEmpty ? DateTime.now() : _days.last.date.add(const Duration(days: 1));
    setState(() {
      _days.add(DayPlan(
        date: base,
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 10, minute: 0),
      ));
    });
  }

  Widget _dayCard(int i) {
    final d = _days[i];
    final disabled = i > 0 && d.sameAsDay1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chipGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Day ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.deepGreen)),
            const Spacer(),
            if (i > 0)
              Row(
                children: [
                  const Text('Same as Day 1', style: TextStyle(fontSize: 12, color: AppColors.deepGreen)),
                  Switch(
                    value: d.sameAsDay1,
                    activeColor: AppColors.deepGreen,
                    onChanged: (v) => setState(() => d.sameAsDay1 = v),
                  ),
                ],
              ),
            if (_days.length > 1 && i > 0)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.sage),
                onPressed: () => setState(() => _days.removeAt(i)),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _ghostButton(
                onTap: () => _pickDate(i),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.sage),
                  const SizedBox(width: 8),
                  Text(_fmtDate(d.date), style: const TextStyle(color: AppColors.deepGreen)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _ghostButton(
                onTap: () => _pickTime(i, start: true),
                child: Row(children: [
                  const Icon(Icons.access_time_filled_rounded, size: 18, color: AppColors.sage),
                  const SizedBox(width: 8),
                  Text('Start: ${_fmtTime(d.start)}', style: const TextStyle(color: AppColors.deepGreen)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ghostButton(
                onTap: () => _pickTime(i, start: false),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: AppColors.sage),
                  const SizedBox(width: 8),
                  Text('End: ${_fmtTime(d.end)}', style: const TextStyle(color: AppColors.deepGreen)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Opacity(
            opacity: disabled ? 0.5 : 1,
            child: IgnorePointer(
              ignoring: disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Location *'),
                  const SizedBox(height: 6),
                  _boxedSmall(
                    child: TextFormField(
                      initialValue: d.location,
                      decoration: const InputDecoration(hintText: 'Add location', border: InputBorder.none),
                      onChanged: (v) => d.location = v,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sectionTitle('Notes (optional)'),
                  const SizedBox(height: 6),
                  _boxedSmall(
                    child: TextFormField(
                      maxLines: 3,
                      initialValue: d.description,
                      decoration: const InputDecoration(
                          hintText: 'Additional notes (optional)', border: InputBorder.none),
                      onChanged: (v) => d.description = v,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ghostButton({required Widget child, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardGrey,
          border: Border.all(color: AppColors.chipGrey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }

  // ===== Preview card =====
  Widget _detailLikePreviewCard() {
    // Ensure selected index stays in range
    final int safeIndex = _days.isEmpty
        ? 0
        : _previewDayIndex.clamp(0, _days.length - 1);

    final pills = <Widget>[];
    for (int i = 0; i < _days.length; i++) {
      final d = _days[i];
      final bool selected = i == safeIndex;
      pills.add(Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _previewDayIndex = i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.deepGreen : AppColors.cardGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.chipGrey),
            ),
            child: Text(
              _fmtDate(d.date),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.bg : AppColors.deepGreen),
            ),
          ),
        ),
      ));
    }

    final first = _days.first;
    final selected = _days[safeIndex];
    final TimeOfDay shownStart = (safeIndex > 0 && selected.sameAsDay1) ? first.start : selected.start;
    final TimeOfDay shownEnd = (safeIndex > 0 && selected.sameAsDay1) ? first.end : selected.end;
    final String shownLocation = (safeIndex > 0 && selected.sameAsDay1)
        ? first.location.trim()
        : selected.location.trim();
    final timeText = '${_fmtTime(shownStart)} - ${_fmtTime(shownEnd)}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardGrey,
        border: Border.all(color: AppColors.chipGrey),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _coverBytes == null
                ? Container(
                    color: AppColors.cardGrey,
                    child: const Center(child: Icon(Icons.image, size: 40, color: AppColors.sage)),
                  )
                : Image.memory(_coverBytes!, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: pills)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: AppColors.sage),
                    const SizedBox(width: 8),
                    Text(timeText, style: const TextStyle(color: AppColors.deepGreen)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _name.text.trim().isEmpty ? 'Event Title' : _name.text.trim(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.deepGreen),
                ),
                const SizedBox(height: 12),
                if (shownLocation.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: AppColors.sage),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(shownLocation,
                            style: const TextStyle(color: AppColors.deepGreen, height: 1.35)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Centered Stepper =====
class _CenteredStepper extends StatelessWidget {
  final int step;
  const _CenteredStepper({required this.step});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const double dot = 34;
        const double gap = 12;

        final double maxW = c.maxWidth;
        final double line = ((maxW - (4 * dot) - (3 * gap * 2)) / 3).clamp(40.0, 160.0);

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(0, active: step >= 0, current: step == 0),
            const SizedBox(width: gap),
            _line(width: line, active: step >= 1),
            const SizedBox(width: gap),
            _dot(1, active: step >= 1, current: step == 1),
            const SizedBox(width: gap),
            _line(width: line, active: step >= 2),
            const SizedBox(width: gap),
            _dot(2, active: step >= 2, current: step == 2),
            const SizedBox(width: gap),
            _line(width: line, active: step >= 3),
            const SizedBox(width: gap),
            _dot(3, active: step >= 3, current: step == 3),
          ],
        );
      },
    );
  }

  Widget _line({required double width, required bool active}) {
    return Container(
      width: width,
      height: 3,
      decoration: BoxDecoration(
        color: active ? AppColors.deepGreen : AppColors.chipGrey,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _dot(int index, {required bool active, required bool current}) {
    return Container(
      height: 34,
      width: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: current ? AppColors.bg : (active ? AppColors.deepGreen : AppColors.sage),
        border: Border.all(color: AppColors.deepGreen, width: current ? 3 : 0),
        shape: BoxShape.circle,
      ),
      child: current
          ? Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.deepGreen))
          : (active
              ? const Icon(Icons.check, size: 18, color: AppColors.bg)
              : Text('${index + 1}', style: const TextStyle(color: AppColors.bg))),
    );
  }
}
