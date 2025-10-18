// lib/pages/event/event_form_question.dart
import 'package:flutter/material.dart';
import '../../services/database_service.dart';

/// ===== THEME (Green / White) =====
const _bg = Colors.white;
const _accent = Color(0xFF7FAA3B);      // เขียวหลัก
const _accentDark = Color(0xFF1F3A2E);  // เขียวเข้ม
const _chip = Color(0xFFEFF4E5);        // เส้น/ฉากจางมาก
const _fieldBg = Color(0xFFF7F9F5);

class EventFormQuestionPage extends StatefulWidget {
  final String eventId;
  final String? eventTitle; // รับมาจากหน้า event_detail ได้
  const EventFormQuestionPage({super.key, required this.eventId, this.eventTitle});

  @override
  State<EventFormQuestionPage> createState() => _EventFormQuestionPageState();
}

class _EventFormQuestionPageState extends State<EventFormQuestionPage> {
  bool _loading = true;
  Object? _error;
  List<Map<String, dynamic>> _questions = const [];
  final Map<String, TextEditingController> _answers = {};
  bool _submitting = false;
  bool _disabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final q = await DatabaseService().getEventFormQuestionsFiber(widget.eventId);
      q.sort((a, b) {
        final ai = (a['order_index'] is int) ? a['order_index'] as int : 0;
        final bi = (b['order_index'] is int) ? b['order_index'] as int : 0;
        return ai.compareTo(bi);
      });
      setState(() { _questions = q; _loading = false; });
    } catch (e) {
      setState(() { _error = e; _loading = false; });
    }
  }

  @override
  void dispose() {
    for (final c in _answers.values) { c.dispose(); }
    super.dispose();
  }

  Future<bool> _confirmDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: _accentDark, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Please confirm your registration,\nYou’ll receive a confirmation\nnotification if accepted.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, height: 1.25, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Confirm", style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                      backgroundColor: const Color(0xFFEAEAEA),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Cancel", style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _submit() async {
    if (_disabled) return;

    for (final q in _questions) {
      final id = (q['id'] ?? q['_id'] ?? '').toString();
      final requiredQ = q['required'] == true;
      final txt = _answers[id]?.text.trim() ?? '';
      if (requiredQ && txt.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields')),
        );
        return;
      }
    }

    final confirmed = await _confirmDialog();
    if (!confirmed) return;

    final answers = <Map<String, dynamic>>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final id = (q['id'] ?? q['_id'] ?? '').toString();
      final order = (q['order_index'] is int) ? q['order_index'] as int : (i + 1);
      final val = _answers[id]?.text ?? '';
      answers.add({'answer_value': val, 'order_index': order, 'question_id': id});
    }

    setState(() => _submitting = true);
    try {
      await DatabaseService().submitEventFormAnswersFiber(widget.eventId, answers);
      try {
        final dynamic svc = DatabaseService();
        await svc.disableEventFormFiber(widget.eventId);
      } catch (_) { /* ignore if not available */ }
      if (!mounted) return;
      _disabled = true;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  /// ===== Question card with circular number on the left of first line =====
  Widget _questionCard({
    required int index,
    required String id,
    required String questionText,
    required bool requiredQ,
  }) {
    _answers[id] ??= TextEditingController();

    const double _ballSize = 26;

    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _chip),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // วงกลมเลขข้อ + คำถาม (ชิดซ้ายและตรงกับบรรทัดแรก)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 0),
                child: Container(
                  width: _ballSize,
                  height: _ballSize,
                  decoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: questionText,
                    style: const TextStyle(
                      color: _accentDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.25,
                    ),
                    children: [
                      if (requiredQ) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _answers[id],
            enabled: !_disabled,
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Your answer here',
              filled: true,
              fillColor: _fieldBg,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disabledOverlay = _disabled
        ? Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.6),
              alignment: Alignment.center,
              child: const Text('You have already submitted this form.',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('Register', style: TextStyle(color: _accentDark, fontWeight: FontWeight.w800)),
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Cancel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _accentDark)),
        ),
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Failed to load form: $_error')))
          else
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _questions.length, // ❌ ไม่มี header card อีกต่อไป
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                final q = _questions[i];
                final id = (q['id'] ?? q['_id'] ?? '').toString();
                final text = (q['question_text'] ?? '').toString();
                final requiredQ = q['required'] == true;
                return _questionCard(
                  index: i,
                  id: id,
                  questionText: text,
                  requiredQ: requiredQ,
                );
              },
            ),
          disabledOverlay,
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_submitting || _disabled) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Register', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }
}
