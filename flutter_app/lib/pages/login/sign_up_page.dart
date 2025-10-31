import 'package:flutter/material.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/pages/login/otp_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _studentId = TextEditingController();
  final _confirmFocus = FocusNode();

  bool _busy = false;
  String? _error;
  bool _confirmBlurred = false;
  bool _submitted = false;

  String? _thaiPrefixValue; // required
  String? _gender;          // required: Male | Female | Other
  String? _typePerson;      // required: Student | Teacher | Staff

  @override
  void initState() {
    super.initState();
    _firstName.addListener(_onChanged);
    _lastName.addListener(_onChanged);
    _email.addListener(_onChanged);
    _password.addListener(_onChanged);
    _confirmPassword.addListener(_onChanged);
    _studentId.addListener(_onChanged);
    _confirmFocus.addListener(() {
      if (!_confirmFocus.hasFocus) {
        if (mounted) setState(() => _confirmBlurred = true);
      }
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _studentId.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final fn = _firstName.text.trim();
    final ln = _lastName.text.trim();
    final pw = _password.text;
    final cpw = _confirmPassword.text;

    if (fn.isEmpty || ln.isEmpty || email.isEmpty || pw.isEmpty ||
        _thaiPrefixValue == null || _thaiPrefixValue!.isEmpty ||
        _gender == null || _gender!.isEmpty ||
        _typePerson == null || _typePerson!.isEmpty ||
        _studentId.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in all required fields');
      return;
    }
    if (!email.endsWith('@ku.th')) {
      setState(() => _error = 'Email must be a @ku.th address');
      return;
    }
    if (pw != cpw) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() { _busy = true; _error = null; _submitted = true; });
    try {
      final payload = RegisterPayload(
        firstname: fn,
        lastname: ln,
        email: email,
        password: pw,
        thaiprefix: _thaiPrefixValue,
        gender: _gender,
        typePerson: _typePerson,
        studentId: _studentId.text.trim(),
      );
      await AuthService.I.register(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registered. Check email for OTP.')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpPage(email: email, payload: payload)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgTop = Color(0xFFECFDF5);    // emerald-50
    const bgBottom = Color(0xFFD1FAE5); // emerald-100
    const deepTeal = Color(0xFF116466);

    const thaiPrefixes = ['นาย', 'นางสาว', 'นาง', 'เด็กชาย', 'เด็กหญิง'];
    final emailText = _email.text.trim().toLowerCase();
    final emailOk = emailText.endsWith('@ku.th');
    final confirmMatches = _confirmPassword.text == _password.text;
    final showConfirmError = (_submitted || _confirmBlurred) &&
        _confirmPassword.text.isNotEmpty && !confirmMatches;
    final requiredFilled = _firstName.text.isNotEmpty &&
        _lastName.text.isNotEmpty &&
        _email.text.isNotEmpty &&
        _password.text.isNotEmpty &&
        _confirmPassword.text.isNotEmpty &&
        (_thaiPrefixValue != null && _thaiPrefixValue!.isNotEmpty) &&
        (_gender != null && _gender!.isNotEmpty) &&
        (_typePerson != null && _typePerson!.isNotEmpty) &&
        _studentId.text.isNotEmpty;
    final canSubmit = requiredFilled && emailOk && confirmMatches && !_busy;

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bgTop, bgBottom],
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Create Your KUCOM Account',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fill in your details below',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                value: thaiPrefixes.contains(_thaiPrefixValue) ? _thaiPrefixValue : null,
                                items: const [
                                  DropdownMenuItem(value: 'นาย', child: Text('นาย')),
                                  DropdownMenuItem(value: 'นางสาว', child: Text('นางสาว')),
                                  DropdownMenuItem(value: 'นาง', child: Text('นาง')),
                                  DropdownMenuItem(value: 'เด็กชาย', child: Text('เด็กชาย')),
                                  DropdownMenuItem(value: 'เด็กหญิง', child: Text('เด็กหญิง')),
                                ],
                                onChanged: (v) => setState(() => _thaiPrefixValue = v),
                                decoration: const InputDecoration(
                                  labelText: 'คำนำหน้า (ไทย)',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                  filled: true,
                                  fillColor: Color(0xFFF0FDF4),
                                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(14))),
                                ),
                                isExpanded: true,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _firstName,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'First name',
                                  prefixIcon: Icon(Icons.person_outline),
                                  filled: true,
                                  fillColor: Color(0xFFF0FDF4),
                                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(14))),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _lastName,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Last name',
                                  prefixIcon: Icon(Icons.person_outline),
                                  filled: true,
                                  fillColor: Color(0xFFF0FDF4),
                                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(14))),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _gender,
                                items: const [
                                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                                ],
                                onChanged: (v) => setState(() => _gender = v),
                                decoration: const InputDecoration(
                                  labelText: 'Gender',
                                  prefixIcon: Icon(Icons.wc_outlined),
                                  filled: true,
                                  fillColor: Color(0xFFF0FDF4),
                                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(14))),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _typePerson,
                                items: const [
                                  DropdownMenuItem(value: 'Student', child: Text('Student')),
                                  DropdownMenuItem(value: 'Teacher', child: Text('Teacher')),
                                  DropdownMenuItem(value: 'Staff', child: Text('Staff')),
                                ],
                                onChanged: (v) => setState(() => _typePerson = v),
                                decoration: const InputDecoration(
                                  labelText: 'Type',
                                  prefixIcon: Icon(Icons.school_outlined),
                                  filled: true,
                                  fillColor: Color(0xFFF0FDF4),
                                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(14))),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _studentId,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Student ID',
                                  prefixIcon: Icon(Icons.perm_identity_outlined),
                                  filled: true,
                                  fillColor: Color(0xFFF0FDF4),
                                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(14))),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: InputDecoration(
                                  labelText: 'Email (@ku.th)',
                                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                                  filled: true,
                                  fillColor: const Color(0xFFF0FDF4),
                                  border: const OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(14))),
                                  errorText: _email.text.isNotEmpty && !emailOk
                                      ? 'Use your @ku.th email'
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _password,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline_rounded),
                                  filled: true,
                                  fillColor: Color(0xFFF0FDF4),
                                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(14))),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _confirmPassword,
                                obscureText: true,
                                focusNode: _confirmFocus,
                                decoration: InputDecoration(
                                  labelText: 'Confirm password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  filled: true,
                                  fillColor: const Color(0xFFF0FDF4),
                                  border: const OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(14))),
                                  errorText: showConfirmError ? 'Passwords do not match' : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_error != null)
                                Text(_error!, style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 4,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 24, color: Color(0xFF424242)),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'We’ll send an OTP to your email',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deepTeal,
                    disabledBackgroundColor: deepTeal.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _busy
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
