import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class ProfileApi {
  static String _myUsername = 'user123';
  static String _myPhoneNumber = '0123456789';
  static List<String> _myRoles = ['นิสิตวิศวกรรมศาสตร์', 'สมาชิกชมรม CPSK'];

  static final List<String> _availableRoles = [
    'นิสิตวิศวกรรมศาสตร์',
    'สมาชิกชมรม CPSK',
    'อาจารย์',
    'เจ้าหน้าที่'
  ];

  // --- Categories mock API ---
  static final List<String> _availableCategories = [
    'Marketplace',
    'Study',
    'Events',
    'Lifestyle',
    'Jobs',
  ];

  static Future<List<String>> fetchAvailableCategories() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List<String>.from(_availableCategories);
  }

  static Future<List<String>> fetchAvailableRoles() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List<String>.from(_availableRoles);
  }

  static Future<String> fetchMyUsername() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _myUsername;
  }

  static Future<String> fetchMyPhoneNumber() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _myPhoneNumber;
  }

  static Future<void> updateMyPhoneNumber(String newPhone) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _myPhoneNumber = newPhone;
  }

  static Future<List<String>> fetchMyRoles() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List<String>.from(_myRoles);
  }

  static Future<void> addMyRole(String role) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final r = role.trim();
    if (r.isNotEmpty && !_myRoles.contains(r)) {
      _myRoles.add(r);
    }
  }

  static Future<void> removeMyRole(String role) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _myRoles.remove(role);
  }

  static Future<void> createPost({
    required bool isPublic,
    required String content,
    required List<String> roles,
    required List<String> categories,
  }) async {
    // simulate network latency
    await Future.delayed(const Duration(milliseconds: 500));
    // In a real app, send HTTP POST here. For now, log to console.
    debugPrint('[POST] privacy=${isPublic ? 'public' : 'private'}');
    debugPrint('[POST] content="$content"');
    debugPrint('[POST] roles=$roles');
    debugPrint('[POST] categories=$categories');
  }
}

class MakePostPage extends StatefulWidget {
  const MakePostPage({super.key});

  @override
  State<MakePostPage> createState() => _MakePostPageState();
}

class _MakePostPageState extends State<MakePostPage> {
  late Future<List<String>> _rolesFut;
  final ValueNotifier<List<String>> _rolesNotifier =
      ValueNotifier<List<String>>(<String>[]);
  final ValueNotifier<List<String>> _categoriesNotifier =
      ValueNotifier<List<String>>(<String>[]);
  final TextEditingController _postController = TextEditingController();
  bool _isPublic = true;
  Map<String, String>? _postedAs; // { org_path, position_key, label }
  List<Map<String, dynamic>> _myMemberships = const [];
  // Visibility state
  String _visibilityAccess = 'public';
  final Set<String> _visibilityAudience = <String>{}; // org_path[] when private
  // Org nodes for visibility search
  List<Map<String, dynamic>> _orgNodesFlat = const [];

  // เก็บสถานะหมวดหมู่ที่เลือก (สำหรับซิงค์กับ notifier)
  // Selected category IDs
  final Set<String> _selectedCategories = {};
  // Categories fetched from API: [{ id, name, short }]
  List<Map<String, dynamic>> _categoriesApi = const [];
  // id -> display name
  final Map<String, String> _catNameById = {};

  // Image picker state
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _rolesFut = ProfileApi.fetchMyRoles();
    ProfileApi.fetchMyRoles().then((list) {
      if (mounted) _rolesNotifier.value = List<String>.from(list);
    });
    if (_selectedCategories.isNotEmpty) {
      _categoriesNotifier.value = _selectedCategories.map((id) => _catNameById[id] ?? id).toList();
    }

    _loadPostedAs();
    _loadOrgNodes();
    _loadCategories();
  }

  Future<void> _onPickImage() async {
    try {
      final x = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (x != null) {
        final bytes = await x.readAsBytes();
        setState(() {
          _pickedImage = x;
          _pickedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เลือกรูปไม่สำเร็จ: $e')),
      );
    }
  }

  void _removePickedImage() {
    setState(() {
      _pickedImage = null;
      _pickedImageBytes = null;
    });
  }

  Widget _buildImagePickerRow() {
    if (_pickedImage == null) {
      return Row(
        children: [
          _addCircle(onTap: _onPickImage),
          const SizedBox(width: 10),
          const Text('Add a picture',
              style: TextStyle(fontSize: 14, color: Color(0xFF111827), fontWeight: FontWeight.w600)),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Preview selected image
          AspectRatio(
            aspectRatio: 4 / 3,
            child: _pickedImageBytes != null
                ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                : const SizedBox.shrink(),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _removePickedImage,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPostedAs() async {
    try {
      await AuthService.I.init();
      final db = DatabaseService();
      final mems = await db.getMyMembershipsFiber();
      if (mounted) {
        setState(() {
          _myMemberships = mems;
          if (mems.isNotEmpty) {
            final m0 = mems.first;
            String _formatOrgLabel(String? orgPath) {
              final p = (orgPath ?? '').toString();
              if (p.isEmpty) return '';
              final parts = p.split('/')..removeWhere((e) => e.isEmpty);
              if (parts.isEmpty) return '';
              // ใช้ 1–2 segment สุดท้ายเป็น label (ตัวพิมพ์ใหญ่) เพื่อให้ได้รูปแบบคล้าย "ENG • CPSK"
              final tail = parts.length >= 2 ? parts.sublist(parts.length - 2) : parts.sublist(parts.length - 1);
              return tail.map((s) => s.toUpperCase()).join(' • ');
            }
            final computedLabel = ((m0['label'] ?? '').toString().isNotEmpty)
                ? (m0['label'] as String)
                : _formatOrgLabel(m0['org_path']);
            _postedAs = {
              'org_path': (m0['org_path'] ?? '').toString(),
              'position_key': (m0['position_key'] ?? '').toString(),
              'label': computedLabel,
            };
            if (_visibilityAccess == 'private' && _visibilityAudience.isEmpty) {
              _visibilityAudience.add(_postedAs!['org_path'] ?? '/');
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load memberships: $e')),
      );
    }
  }

  Future<void> _loadOrgNodes() async {
    try {
      final db = DatabaseService();
      final list = await db.getOrgTreeFiber(start: '/', depth: 99, lang: null);
      final flat = <Map<String, dynamic>>[];
      void walk(Map<String, dynamic> n) {
        final path = (n['org_path'] ?? n['path'] ?? '').toString();
        final label = (n['short_name'] ?? n['label'] ?? n['name'] ?? '').toString();
        if (path.isNotEmpty) flat.add({'org_path': path, 'label': label});
        final children = n['children'];
        if (children is List) {
          for (final c in children) {
            if (c is Map<String, dynamic>) walk(c);
          }
        }
      }
      for (final it in list) {
        if (it is Map<String, dynamic>) walk(it);
      }
      if (mounted) setState(() => _orgNodesFlat = flat);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadCategories() async {
    try {
      final db = DatabaseService();
      final list = await db.getCategoriesFiber();
      // Normalize backend shape ({ _id, category_name, short_name })
      // into UI-friendly shape ({ id, name, short }) and build name lookup.
      final map = <String, String>{};
      final normalized = <Map<String, dynamic>>[];
      for (final m in list) {
        if (m is! Map) continue;
        final mm = Map<String, dynamic>.from(m as Map);
        final id = (mm['id'] ?? mm['_id'] ?? '').toString();
        final name = (mm['name'] ?? mm['short'] ?? mm['short_name'] ?? mm['category_name'] ?? '').toString();
        final short = (mm['short'] ?? mm['short_name'] ?? '').toString();
        if (id.isEmpty) continue;
        final display = name.isNotEmpty ? name : id;
        map[id] = display;
        normalized.add({'id': id, 'name': display, 'short': short});
      }
      if (!mounted) return;
      setState(() {
        _categoriesApi = normalized;
        _catNameById
          ..clear()
          ..addAll(map);
        // Refresh selected label list if had selections
        if (_selectedCategories.isNotEmpty) {
          _categoriesNotifier.value = _selectedCategories.map((id) => _catNameById[id] ?? id).toList();
        }
      });
    } catch (e) {
      // silently ignore; UI will still work without categories
    }
  }

  Future<void> _addRole() async {
    final current = await ProfileApi.fetchMyRoles();
    final all = await ProfileApi.fetchAvailableRoles();

    final Set<String> selected = {...current};

    final TextEditingController _roleSearchCtrl = TextEditingController();
    String _roleQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Center(
            child: Container(
              width: media.size.width * 0.94,
              margin: const EdgeInsets.symmetric(vertical: 20),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 20,
                    color: Color(0x14000000),
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: StatefulBuilder(
                builder: (ctx, setSB) {
                  final filtered = _roleQuery.isEmpty
                      ? all
                      : all
                          .where((r) => r
                              .toLowerCase()
                              .contains(_roleQuery.toLowerCase()))
                          .toList();

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // title + count
                      Row(
                        children: [
                          const Text(
                            'Choose role',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${selected.length}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Done',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),

                      // search box
                      TextField(
                        controller: _roleSearchCtrl,
                        onChanged: (v) => setSB(() => _roleQuery = v),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาบทบาท...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF6F6F6),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E5EA)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // selected preview chips
                      if (selected.isNotEmpty) ...[
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: selected
                              .map((r) => _pillChip(
                                    text: r,
                                    onRemove: () async {
                                      setSB(() => selected.remove(r));
                                      _rolesNotifier.value =
                                          selected.toList();
                                      await ProfileApi.removeMyRole(r);
                                      if (mounted) {
                                        setState(() => _rolesFut =
                                            ProfileApi.fetchMyRoles());
                                      }
                                    },
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // list
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: media.size.height * 0.45,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final r = filtered[i];
                            final isOn = selected.contains(r);
                            return InkWell(
                              onTap: () async {
                                setSB(() {
                                  if (isOn) {
                                    selected.remove(r);
                                  } else {
                                    selected.add(r);
                                  }
                                });
                                _rolesNotifier.value = selected.toList();
                                if (isOn) {
                                  await ProfileApi.removeMyRole(r);
                                } else {
                                  await ProfileApi.addMyRole(r);
                                }
                                if (mounted) {
                                  setState(() => _rolesFut =
                                      ProfileApi.fetchMyRoles());
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE5E5EA)),
                                  color: isOn
                                      ? const Color(0xFFF5FFF8)
                                      : Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isOn
                                          ? const Color(0xFF0E4E3A)
                                          : const Color(0xFFEAEAEA),
                                      child: Icon(
                                        isOn
                                            ? Icons.check_rounded
                                            : Icons.person_outline,
                                        size: 16,
                                        color: isOn
                                            ? Colors.white
                                            : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(r,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      child: isOn
                                          ? const Icon(Icons.check_circle,
                                              color: Color(0xFF0E4E3A))
                                          : const Icon(
                                              Icons.radio_button_unchecked,
                                              color: Color(0xFFB9B9C3)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Category Picker ---
  Future<void> _openCategoryPicker() async {
    // Ensure categories loaded
    if (_categoriesApi.isEmpty) {
      await _loadCategories();
    }
    final all = _categoriesApi; // list of maps {id,name,short}
    // Work on a copy of selected IDs
    final Set<String> selected = <String>{..._selectedCategories};

    final TextEditingController _catSearchCtrl = TextEditingController();
    String _catQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Center(
            child: Container(
              width: media.size.width * 0.94,
              margin: const EdgeInsets.symmetric(vertical: 20),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 20,
                    color: Color(0x14000000),
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: StatefulBuilder(
                builder: (ctx, setSB) {
                  final filtered = _catQuery.isEmpty
                      ? all
                      : all.where((m) {
                          final name = (m['name'] ?? m['short'] ?? '').toString();
                          return name.toLowerCase().contains(_catQuery.toLowerCase());
                        }).toList();

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Text('Choose category',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${selected.length}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Done',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _catSearchCtrl,
                        onChanged: (v) => setSB(() => _catQuery = v),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาหมวดหมู่...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF6F6F6),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E5EA)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (selected.isNotEmpty) ...[
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: selected.map<Widget>((id) => _pillChip(
                                text: _catNameById[id] ?? id,
                                onRemove: () {
                                  setSB(() => selected.remove(id));
                                  _categoriesNotifier.value = selected.map((e) => _catNameById[e] ?? e).toList();
                                  setState(() {
                                    _selectedCategories
                                      ..clear()
                                      ..addAll(selected);
                                  });
                                },
                              ))
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: media.size.height * 0.45),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final m = filtered[i];
                            final id = (m['id'] ?? '').toString();
                            final name = (m['name'] ?? m['short'] ?? id).toString();
                            final isOn = selected.contains(id);
                            return InkWell(
                              onTap: () async {
                                setSB(() {
                                  if (isOn) {
                                    selected.remove(id);
                                  } else {
                                    selected.add(id);
                                  }
                                });
                                _categoriesNotifier.value = selected.map((e) => _catNameById[e] ?? e).toList();
                                setState(() {
                                  _selectedCategories
                                    ..clear()
                                    ..addAll(selected);
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE5E5EA)),
                                  color: isOn
                                      ? const Color(0xFFF5FFF8)
                                      : Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: isOn
                                          ? const Color(0xFF0E4E3A)
                                          : const Color(0xFFEAEAEA),
                                      child: Icon(
                                        isOn
                                            ? Icons.check_rounded
                                            : Icons.category_outlined,
                                        size: 16,
                                        color: isOn
                                            ? Colors.white
                                            : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(name,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      child: isOn
                                          ? const Icon(Icons.check_circle,
                                              color: Color(0xFF0E4E3A))
                                          : const Icon(
                                              Icons.radio_button_unchecked,
                                              color: Color(0xFFB9B9C3)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeRole(String r) async {
    _rolesNotifier.value =
        List<String>.from(_rolesNotifier.value..remove(r));
    await ProfileApi.removeMyRole(r);
    setState(() => _rolesFut = ProfileApi.fetchMyRoles());
  }

  void _post() async {
    final content = _postController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาพิมพ์ข้อความก่อนโพสต์')),
      );
      return;
    }
    if (_postedAs == null || (_postedAs!['org_path']?.isEmpty ?? true) || (_postedAs!['position_key']?.isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือก Posted as (บทบาทของคุณ)')),
      );
      return;
    }

    final privacy = _visibilityAccess == 'public' ? 'Public' : 'Private';
    try {
      await AuthService.I.init();
      final db = DatabaseService();

      final postedAs = {
        'org_path': _postedAs!['org_path'],
        'position_key': _postedAs!['position_key'],
        // สร้าง label ถ้ายังว่าง ให้ได้ฟอร์แมตแบบ "ENG • CPSK" จาก org_path
        'label': (() {
          final lbl = (_postedAs!['label'] ?? '').toString();
          if (lbl.isNotEmpty) return lbl;
          final path = (_postedAs!['org_path'] ?? '').toString();
          final parts = path.split('/')..removeWhere((e) => e.isEmpty);
          if (parts.isEmpty) return '';
          final tail = parts.length >= 2 ? parts.sublist(parts.length - 2) : parts.sublist(parts.length - 1);
          return tail.map((s) => s.toUpperCase()).join(' • ');
        })(),
      };

      final visibility = _visibilityAccess == 'public'
          ? {'access': 'public'}
          : {
              'access': 'private',
              'audience': _visibilityAudience.isEmpty
                  ? [(_postedAs!['org_path'] ?? '')]
                  : _visibilityAudience.toList(),
            };

      await db.createPostFiber(
        uid: '',
        name: '',
        username: '',
        message: content,
        postedAs: postedAs,
        visibility: visibility,
        orgOfContent: _postedAs!['org_path'],
        status: null,
        imagePath: kIsWeb ? null : _pickedImage?.path,
        imageBytes: _pickedImageBytes,
        imageFilename: _pickedImage?.name,
        categoryIds: _selectedCategories.isEmpty ? null : _selectedCategories.toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โพสต์แบบ $privacy เรียบร้อย')),
      );

      _postController.clear();
      setState(() {
        _isPublic = true;
        _visibilityAccess = 'public';
        _visibilityAudience.clear();
        _selectedCategories.clear();
        _categoriesNotifier.value = <String>[];
        _pickedImage = null;
      });
      Navigator.maybePop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โพสต์ไม่สำเร็จ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Cancel | Public / Private | Post
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF3B3B3B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _scopeChip(
                    label: 'Public',
                    icon: Icons.public,
                    selected: _visibilityAccess == 'public',
                    selectedBg: const Color(0xFF0E4E3A),
                    unselectedBg: const Color(0x1A204D3F),
                    light: false,
                    onTap: () => setState(() {
                      _isPublic = true;
                      _visibilityAccess = 'public';
                    }),
                  ),
                  const SizedBox(width: 12),
                  _scopeChip(
                    label: 'Private',
                    icon: Icons.lock_outline,
                    selected: _visibilityAccess == 'private',
                    selectedBg: const Color(0xFFDB2777),
                    unselectedBg: const Color(0xFFF2ECFF),
                    light: true,
                    onTap: () => setState(() {
                      _isPublic = false;
                      _visibilityAccess = 'private';
                      if (_postedAs != null && _visibilityAudience.isEmpty) {
                        _visibilityAudience.add(_postedAs!['org_path'] ?? '/');
                      }
                    }),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _post,
                    child: const Text(
                      'Post',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF3B3B3B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),


              const SizedBox(height: 16),

              // Posted-as selector (from memberships)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF374151)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _postedAs == null
                            ? 'เลือกบทบาท (Posted as)'
                            : (((_postedAs!['label'] ?? '').toString().isNotEmpty)
                                ? _postedAs!['label'] as String
                                : '${_postedAs!['position_key']} • ${_postedAs!['org_path']}'),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF111827), fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _openPostedAsPicker,
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Composer card with avatar + textfield
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE9ECEB),
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(
                        'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=200&auto=format&fit=crop',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _postController,
                        maxLines: 6,
                        minLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Typing....',
                          hintStyle: TextStyle(color: Color(0xFFB1A8A8)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Picture picker + preview
              const _SectionHeader(text: 'Picture'),
              const SizedBox(height: 10),
              _buildImagePickerRow(),

              const SizedBox(height: 28),

              // Category section
              const _SectionHeader(text: 'Category :'),
              const SizedBox(height: 10),
              ValueListenableBuilder<List<String>>(
                valueListenable: _categoriesNotifier,
                builder: (context, cats, _) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...cats.map((c) => _pillChip(
                            text: c,
                            onRemove: () {
                              final next = List<String>.from(cats)..remove(c);
                              _categoriesNotifier.value = next;
                              // Map names back to IDs
                              final Set<String> ids = {};
                              for (final name in next) {
                                String? idMatch;
                                _catNameById.forEach((id, nm) { if (nm == name) idMatch = idMatch ?? id; });
                                ids.add(idMatch ?? name);
                              }
                              setState(() {
                                _selectedCategories
                                  ..clear()
                                  ..addAll(ids);
                              });
                            },
                          )),
                      _addCircle(onTap: _openCategoryPicker),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // Visibility section
              const _SectionHeader(text: 'Visibility'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(_visibilityAccess == 'public' ? Icons.public : Icons.lock_outline, size: 18, color: const Color(0xFF374151)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _visibilityAccess == 'public'
                            ? 'Public'
                            : (_visibilityAudience.isEmpty
                                ? 'Private to selected orgs (none selected)'
                                : 'Private: ${_visibilityAudience.length} org(s) selected'),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF111827), fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(onPressed: _openVisibilityPicker, child: const Text('Change')),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPostedAsPicker() async {
    if (_myMemberships.isEmpty) {
      await _loadPostedAs();
      if (_myMemberships.isEmpty) return;
    }
    final selectedId = _postedAs == null ? null : '${_postedAs!['org_path']}::${_postedAs!['position_key']}';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Center(
          child: Container(
            width: media.size.width * 0.94,
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(blurRadius: 20, color: Color(0x14000000), offset: Offset(0, 8)),
              ],
            ),
            child: StatefulBuilder(builder: (ctx, setSB) {
              String q = '';
              List<Map<String, dynamic>> filtered = _myMemberships;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2))),
                  const Text('เลือกบทบาท (Posted as)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) {
                      setSB(() {
                        q = v.trim().toLowerCase();
                        filtered = _myMemberships.where((m) {
                          final a = (m['org_path'] ?? '').toString().toLowerCase();
                          final b = (m['position_key'] ?? '').toString().toLowerCase();
                          final lbl = (m['label'] ?? '').toString().toLowerCase();
                          return a.contains(q) || b.contains(q) || lbl.contains(q);
                        }).toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'ค้นหา org/position...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF6F6F6),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: media.size.height * 0.45),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final m = filtered[i];
                        final id = '${m['org_path']}::${m['position_key']}';
                        final on = id == selectedId;
                        String _fmtOrgLabel(String? path) {
                          final p = (path ?? '').toString();
                          if (p.isEmpty) return '';
                          final parts = p.split('/')..removeWhere((e) => e.isEmpty);
                          if (parts.isEmpty) return '';
                          final tail = parts.length >= 2 ? parts.sublist(parts.length - 2) : parts.sublist(parts.length - 1);
                          return tail.map((s) => s.toUpperCase()).join(' • ');
                        }
                        final label = ((m['label'] ?? '').toString().isNotEmpty)
                            ? m['label'].toString()
                            : _fmtOrgLabel((m['org_path'] ?? '').toString());
                        final sub = ((m['org_short'] ?? '').toString().isNotEmpty)
                            ? m['org_short'].toString()
                            : (m['org_path'] ?? '').toString();
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _postedAs = {
                                'org_path': (m['org_path'] ?? '').toString(),
                                'position_key': (m['position_key'] ?? '').toString(),
                                'label': label,
                              };
                            });
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E5EA)),
                              color: on ? const Color(0xFFF0F9FF) : Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20, color: on ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(sub, style: const TextStyle(color: Color(0xFF6B7280))),
                                      ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _openVisibilityPicker() async {
    String access = _visibilityAccess;
    final Set<String> sel = {..._visibilityAudience};
    String query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Center(
            child: Container(
              width: media.size.width * 0.94,
              margin: const EdgeInsets.symmetric(vertical: 20),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(blurRadius: 20, color: Color(0x14000000), offset: Offset(0, 8)),
                ],
              ),
              child: StatefulBuilder(builder: (ctx, setSB) {
                List<Map<String, dynamic>> filtered = _orgNodesFlat.where((n) {
                  if (query.isEmpty) return true;
                  final p = (n['org_path'] ?? '').toString().toLowerCase();
                  final l = (n['label'] ?? '').toString().toLowerCase();
                  return p.contains(query) || l.contains(query);
                }).toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const Text('Visibility', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Public'),
                          selected: access == 'public',
                          onSelected: (_) => setSB(() => access = 'public'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Private'),
                          selected: access == 'private',
                          onSelected: (_) => setSB(() => access = 'private'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _visibilityAccess = access;
                              _isPublic = access == 'public';
                              _visibilityAudience
                                ..clear()
                                ..addAll(sel);
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (access == 'private') ...[
                      TextField(
                        onChanged: (v) => setSB(() => query = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'ค้นหา org...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF6F6F6),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: media.size.height * 0.45),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (ctx, i) {
                            final n = filtered[i];
                            final path = (n['org_path'] ?? '').toString();
                            final label = (n['label'] ?? '').toString();
                            final on = sel.contains(path);
                            return InkWell(
                              onTap: () => setSB(() {
                                if (on) sel.remove(path); else sel.add(path);
                              }),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE5E5EA)),
                                  color: on ? const Color(0xFFF0F9FF) : Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      size: 20,
                                      color: on ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        label.isNotEmpty ? '$label  •  $path' : path,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _scopeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color selectedBg,
    required Color unselectedBg,
    required bool light,
    required VoidCallback onTap,
  }) {
    final bg = selected ? selectedBg : unselectedBg;
    final fg = selected ? Colors.white : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(label,
                style:
                    TextStyle(color: fg, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _pillChip({required String text, required VoidCallback onRemove}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDDDCE2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 18, color: Colors.black87),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 16, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _addCircle({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDDCE2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add, size: 18, color: Colors.black87),
      ),
    );
  }

  Future<String?> _promptAdd(String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: 'พิมพ์${title.toLowerCase()}...'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('เพิ่ม')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Color(0xFF492A07),
        letterSpacing: 0.2,
      ),
    );
  }
}
