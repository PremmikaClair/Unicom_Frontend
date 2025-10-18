// create_event_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/database_service.dart';

void main() => runApp(const CreateEventApp());

class CreateEventApp extends StatelessWidget {
  const CreateEventApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Create Event',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F7F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4D96),
          brightness: Brightness.light,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFFF4D96)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
      home: const CreateEventPage(),
    );
  }
}

/* ---------- Model ---------- */
class DayPlan {
  DateTime date;
  TimeOfDay start;
  TimeOfDay end;
  String location;
  String note;
  bool sameAsDay1;

  DayPlan({
    required this.date,
    required this.start,
    required this.end,
    this.location = '',
    this.note = '',
    this.sameAsDay1 = false,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'startTime': DateTime(date.year, date.month, date.day, start.hour, start.minute).toIso8601String(),
        'endTime': DateTime(date.year, date.month, date.day, end.hour, end.minute).toIso8601String(),
        'location': location,
        'note': note,
        'sameAsDay1': sameAsDay1,
      };
}

/* ---------- Page ---------- */
class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});
  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();

  // Basics
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _organizer = TextEditingController();
  final _capacity = TextEditingController(text: '200'); // Max Registrants

  // Categories removed

  // Roles (multi) — NEW
  final List<String> _allRoles = const [
    'Student','Teacher','Staff','Alumni','Guest'
  ];
  final Set<String> _selectedRoles = {};

  // Cover photo (16:9 เหมือน event_detail_page)
  final ImagePicker _picker = ImagePicker();
  Uint8List? _coverBytes;

  // Days
  final List<DayPlan> _days = [];

  // Organizer org dropdown (manageable orgs)
  List<Map<String, dynamic>> _manageableOrgs = const [];
  String? _selectedOrganizerPath;

  // Visibility audience selection
  final Set<String> _selectedAudience = <String>{};
  List<Map<String, String>> _orgNodesCache = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _name.text = 'Open House ${now.year + 1}';
    _description.text = 'Campus tour and activities';
    _organizer.text = 'KU PR';
    _selectedRoles.add('Student'); // ค่าเริ่มต้นอย่างน้อย 1 role
    _days.add(DayPlan(
      date: DateTime(now.year + 1, 1, 15),
      start: const TimeOfDay(hour: 11, minute: 0),
      end: const TimeOfDay(hour: 15, minute: 0),
      location: 'Sports Center',
      note: 'Registration desk at the left entrance.',
    ));

    _loadManageableOrgs();
    // preload manageable orgs; audience picker loads on demand
  }

  // ---- Utils (no intl) ----
  String _fmtDate(DateTime d) =>
      '${['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d.weekday - 1]}, ${d.day} '
      '${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month - 1]}, ${d.year}';
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  int _toInt(String s, {int fallback = 0}) => int.tryParse(s.trim()) ?? fallback;

  // ---- Cover picker ----
  Future<void> _pickCover() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _coverBytes = bytes);
  }

  // ---- Date/Time pickers ----
  Future<void> _pickDate(int i) async {
    final picked = await showDatePicker(
      context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _days[i].date);
    if (picked != null) setState(() => _days[i].date = picked);
  }

  Future<void> _pickTime(int i, {required bool start}) async {
    final t = await showTimePicker(context: context, initialTime: start ? _days[i].start : _days[i].end);
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

  Future<void> _openAudiencePicker() async {
    final temp = _selectedAudience.toSet();
    // Load all org nodes once, then do client-side search
    if (_orgNodesCache.isEmpty) {
      try {
        final tree = await DatabaseService().getOrgTreeFiber(start: '/');
        _orgNodesCache = _flattenOrgTree(tree);
      } catch (_) {}
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        String search = '';
        List<Map<String, String>> results = List<Map<String, String>>.from(_orgNodesCache);

        return StatefulBuilder(
          builder: (context, setS) {
            void doSearch(String q) {
              final qq = q.trim().toLowerCase();
              setS(() {
                if (qq.isEmpty) {
                  results = List<Map<String, String>>.from(_orgNodesCache);
                } else {
                  results = _orgNodesCache.where((m) {
                    final label = (m['label'] ?? '').toLowerCase();
                    final shortn = (m['shortname'] ?? '').toLowerCase();
                    final path = (m['org_path'] ?? '').toLowerCase();
                    return label.contains(qq) || shortn.contains(qq) || path.contains(qq);
                  }).toList(growable: false);
                }
              });
            }
            return SafeArea(
              child: SizedBox(
                height: 420,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Audience (Visibility)', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(hintText: 'Search org units'),
                            onChanged: (v) { search = v; },
                            onSubmitted: (v) { doSearch(v); },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(onPressed: () => doSearch(search), child: const Text('Search')),
                      ]),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final m = results[i];
                            final path = m['org_path'] ?? '';
                            final label = (m['shortname'] ?? m['label'] ?? path);
                            final selected = temp.contains(path);
                            return ListTile(
                              dense: true,
                              leading: Checkbox(
                                value: selected,
                                onChanged: (_) => setS(() {
                                  if (selected) temp.remove(path); else temp.add(path);
                                }),
                              ),
                              title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => setS(() {
                                if (selected) temp.remove(path); else temp.add(path);
                              }),
                            );
                          },
                        ),
                      ),
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                        const SizedBox(width: 8),
                        Expanded(child: FilledButton(onPressed: () { setState(() { _selectedAudience
                          ..clear()
                          ..addAll(temp);
                        }); Navigator.pop(context); }, child: const Text('Apply'))),
                      ]),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, String>> _flattenOrgTree(dynamic root) {
    final out = <Map<String, String>>[];
    void walk(dynamic node) {
      if (node is Map) {
        final path = (node['org_path'] ?? '').toString();
        final label = (node['label'] ?? '').toString();
        final shortn = (node['short_name'] ?? '').toString();
        if (path.isNotEmpty) {
          out.add({'org_path': path, 'label': label, 'shortname': shortn});
        }
        final children = node['children'];
        if (children is List) {
          for (final c in children) { walk(c); }
        }
      }
      if (node is List) {
        for (final c in node) { walk(c); }
      }
    }
    walk(root);
    return out;
  }

  // Category picker removed

  // ---- Role picker (เหมือน category) ----
  Future<void> _openRolePicker() async {
    final temp = _selectedRoles.toSet();
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _multiSelectSheet(
        title: 'Who can register?',
        subtitle: 'Select one or more roles',
        options: _allRoles,
        initial: temp,
        onDone: (result) => setState(() {
          _selectedRoles
            ..clear()
            ..addAll(result);
        }),
      ),
    );
  }

  // ---- Generic multi-select bottom sheet ----
  Widget _multiSelectSheet({
    required String title,
    String? subtitle,
    required List<String> options,
    required Set<String> initial,
    required ValueChanged<Set<String>> onDone,
  }) {
    final temp = initial.toSet();
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: options.map((opt) {
                final sel = temp.contains(opt);
                return CheckboxListTile(
                  value: sel,
                  onChanged: (v) => setState(() => v! ? temp.add(opt) : temp.remove(opt)),
                  title: Text(opt),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    onDone(temp);
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Questionnaire nav (navigate เปล่า ๆ; รอคุณสร้างไฟล์ .dart และ route) ----
  void _goQuestionnaire() {
    try {
      Navigator.of(context).pushNamed('/questionnaire');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TODO: add route /questionnaire และไฟล์หน้าแบบสอบถาม')),
      );
    }
  }

  // ---- Submit ----
  void _submit() {
    // ต้องกรอกครบทุกช่อง ยกเว้น date/time ต้องมี >= 1 วัน
    String? err;
    if (_name.text.trim().isEmpty) err ??= 'Please enter Event Name';
    if (_description.text.trim().isEmpty) err ??= 'Please enter Event Description';
    if (_organizer.text.trim().isEmpty) err ??= 'Please enter Organizer';
    // categories removed
    if (_selectedRoles.isEmpty) err ??= 'Please select at least one Role';
    if (_capacity.text.trim().isEmpty || int.tryParse(_capacity.text.trim()) == null) {
      err ??= 'Please provide a valid number for Max Registrants';
    }
    if (_days.isEmpty) err ??= 'Please add at least one day';

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    // กระจายค่า Same as Day 1
    final first = _days.first;
    for (var i = 1; i < _days.length; i++) {
      final d = _days[i];
      if (d.sameAsDay1) {
        d.location = first.location;
        d.note = first.note;
        d.start = first.start;
        d.end = first.end;
      }
    }

    () async {
      // Build backend payload (dto.EventRequestDTO)
      try {
        final orgPath = _selectedOrganizerPath ?? '';
        if (orgPath.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Organizer org unit')));
          return;
        }

        // Resolve node_id from manageable orgs list (backend now includes node_id)
        String? nodeId;
        for (final m in _manageableOrgs) {
          if ((m['org_path'] ?? '') == orgPath) { nodeId = (m['node_id'] ?? m['id'] ?? m['_id'])?.toString(); break; }
        }
        if (nodeId == null || nodeId!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Organizer node_id not found; reload Manageable Orgs')));
          return;
        }

        // Pick a role (position_key) from my memberships matching orgPath
        final myMems = await DatabaseService().getMyMembershipsFiber();
        String? posKey;
        for (final m in myMems) {
          if ((m['org_path'] ?? '') == orgPath && (m['position_key'] ?? '').toString().isNotEmpty) {
            posKey = m['position_key'].toString();
            break;
          }
        }
        posKey ??= (myMems.isNotEmpty ? (myMems.first['position_key']?.toString()) : null);
        if (posKey == null || posKey!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No eligible role found to post as organizer')));
          return;
        }

        // Visibility mapping
        Map<String, dynamic> visibility;
        if (_selectedAudience.isEmpty) {
          visibility = {'access': 'public'};
        } else {
          visibility = {
            'access': 'org',
            'audience': _selectedAudience.map((p) => {'org_path': p, 'scope': 'exact'}).toList(),
          };
        }

        // Schedules mapping
        final schedules = _days.map((d) {
          final dateOnly = DateTime(d.date.year, d.date.month, d.date.day).toUtc();
          final tStart = DateTime(d.date.year, d.date.month, d.date.day, d.start.hour, d.start.minute).toUtc();
          final tEnd   = DateTime(d.date.year, d.date.month, d.date.day, d.end.hour, d.end.minute).toUtc();
          return {
            'date': dateOnly.toIso8601String(),
            'time_start': tStart.toIso8601String(),
            'time_end': tEnd.toIso8601String(),
            'location': d.location,
            'description': d.note,
          };
        }).toList();

        final payload = {
          'node_id': nodeId,
          'topic': _name.text.trim(),
          'description': _description.text.trim(),
          'max_participation': _toInt(_capacity.text),
          'posted_as': { 'org_path': orgPath, 'position_key': posKey },
          'visibility': visibility,
          'org_of_content': orgPath,
          'status': 'active',
          'have_form': false,
          'schedules': schedules,
        };

        final res = await DatabaseService().createEventFiber(
          payload,
          imageBytes: _coverBytes,
          imageFilename: 'cover.jpg',
          postedAs: {'org_path': orgPath, 'position_key': posKey},
          nodeId: nodeId,
        );
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Event created'),
              content: Text('ID: ${(res['event']?['id'] ?? res['event']?['_id'] ?? res['id'] ?? '')}'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
      }
    }();
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            // Add Photos
            _titleRow('Add Photos', Icons.photo_library_outlined, const Color(0xFFFF4D96)),
            const SizedBox(height: 8),
            _coverPickerBox(),
            const SizedBox(height: 16),

            // Event Name
            _titleRow('Event Name', Icons.badge_outlined, const Color(0xFF7C4DFF)),
            const SizedBox(height: 8),
            TextFormField(controller: _name, decoration: const InputDecoration(hintText: 'e.g. Tech Event')),
            const SizedBox(height: 16),

            // Event Description
            _titleRow('Event Description', Icons.description_outlined, const Color(0xFF43A047)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Describe your event...'),
            ),
            const SizedBox(height: 16),

            // Categories section removed

            // Roles (NEW)
            _titleRow('Who can register?', Icons.verified_user_outlined, const Color(0xFF9C27B0)),
            const SizedBox(height: 8),
            if (_selectedRoles.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: -4,
                children: _selectedRoles
                    .map((r) => Chip(
                          label: Text(r),
                          onDeleted: () => setState(() => _selectedRoles.remove(r)),
                        ))
                    .toList(),
              ),
            if (_selectedRoles.isNotEmpty) const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _openRolePicker,
                icon: const Icon(Icons.add),
                label: const Text('Add role'),
              ),
            ),
            const SizedBox(height: 16),

            // Organizer (dropdown, manageable orgs)
            _titleRow('Organizer', Icons.apartment_outlined, const Color(0xFFFF9800)),
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

            // Visibility (Audience) — dropdown-like launcher with fixed-height scrollable sheet
            _titleRow('Visibility (Audience)', Icons.lock_open_outlined, const Color(0xFF6D4C41)),
            const SizedBox(height: 8),
            _ghostButton(
              onTap: _openAudiencePicker,
              child: Row(children: [
                const Icon(Icons.groups_2_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedAudience.isEmpty
                      ? 'Select audience org units'
                      : 'Selected: ${_selectedAudience.length} orgs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down_rounded),
              ]),
            ),
            if (_selectedAudience.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: -4,
                children: _selectedAudience.map((p) => Chip(
                  label: Text(p),
                  onDeleted: () => setState(() => _selectedAudience.remove(p)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 16),

            // Max Registrants
            _titleRow('Max Registrants', Icons.people_alt_outlined, const Color(0xFF4FC3F7)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Number of people that can register'),
            ),
            const SizedBox(height: 16),

            // Date & Time
            _titleRow('Date & Time', Icons.event_outlined, const Color(0xFF8BC34A)),
            const SizedBox(height: 8),
            _dateTimeSection(),

            const SizedBox(height: 16),
            _titleRow('Questionnaire', Icons.ballot_outlined, const Color(0xFF9C27B0)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _goQuestionnaire, // navigate เปล่า ๆ
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Create questionnaire for this event'),
            ),
            const SizedBox(height: 20),

            // Footer buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelDialog,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Create Event'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /* --- UI Pieces --- */
  Widget _titleRow(String text, IconData icon, Color color) {
    return Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
        Icon(icon, color: color),
      ],
    );
  }

  // กล่องเลือกรูป 16:9 ตรงกลางมี icon image + ปุ่ม "+ Add Photo" มุมขวาล่าง
  Widget _coverPickerBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9, // เท่ากับใน event_detail_page.dart
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: _pickCover,
                child: Container(
                  color: const Color(0xFFF8F3F7),
                  child: _coverBytes == null
                      ? const Center(
                          child: Icon(Icons.image_outlined, size: 56, color: Colors.black26),
                        )
                      : Image.memory(_coverBytes!, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: ElevatedButton.icon(
              onPressed: _pickCover,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFF4D96),
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Photo', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
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

  Widget _dayCard(int i) {
    final d = _days[i];
    final disabled = i > 0 && d.sameAsDay1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Day ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            if (i > 0)
              Row(
                children: [
                  const Text('Same as Day 1', style: TextStyle(fontSize: 12)),
                  Switch(value: d.sameAsDay1, onChanged: (v) => setState(() => d.sameAsDay1 = v)),
                ],
              ),
            if (_days.length > 1)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _days.removeAt(i)),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _ghostButton(
                onTap: () => _pickDate(i),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(_fmtDate(d.date)),
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
                  const Icon(Icons.access_time_filled_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text('Start: ${_fmtTime(d.start)}'),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ghostButton(
                onTap: () => _pickTime(i, start: false),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text('End: ${_fmtTime(d.end)}'),
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
                  _titleRow('Location', Icons.location_on_outlined, const Color(0xFFEC407A)),
                  const SizedBox(height: 6),
                  TextField(
                    decoration: const InputDecoration(hintText: 'Add location'),
                    controller: TextEditingController(text: d.location)
                      ..selection = TextSelection.collapsed(offset: d.location.length),
                    onChanged: (v) => d.location = v,
                  ),
                  const SizedBox(height: 10),
                  _titleRow('Notes', Icons.sticky_note_2_outlined, const Color(0xFF26A69A)),
                  const SizedBox(height: 6),
                  TextField(
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Additional notes'),
                    controller: TextEditingController(text: d.note)
                      ..selection = TextSelection.collapsed(offset: d.note.length),
                    onChanged: (v) => d.note = v,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addDay() {
    final now = DateTime.now();
    setState(() {
      _days.add(DayPlan(
        date: DateTime(now.year, now.month, now.day),
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 10, minute: 0),
      ));
    });
  }

  Widget _ghostButton({required Widget child, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }

  void _cancelDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel'),
        content: const Text('Discard all changes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );
    if (ok == true) Navigator.pop(context);
  }

  String _prettyJson(Map<String, dynamic> map, [int indent = 2]) {
    final sp = ' ' * indent;
    String enc(dynamic v, int lv) {
      if (v is Map) {
        final ks = v.keys.toList();
        final b = StringBuffer()..writeln('{');
        for (var i = 0; i < ks.length; i++) {
          final k = ks[i];
          b.write('${sp * (lv + 1)}"$k": ${enc(v[k], lv + 1)}');
          if (i != ks.length - 1) b.writeln(',');
        }
        b.writeln();
        b.write('${sp * lv}}');
        return b.toString();
      } else if (v is List) {
        final b = StringBuffer()..writeln('[');
        for (var i = 0; i < v.length; i++) {
          b.write('${sp * (lv + 1)}${enc(v[i], lv + 1)}');
          if (i != v.length - 1) b.writeln(',');
        }
        b.writeln();
        b.write('${sp * lv}]');
        return b.toString();
      } else if (v is String) {
        return '"${v.replaceAll('"', '\\"')}"';
      } else {
        return v.toString();
      }
    }
    return enc(map, 0);
  }
}