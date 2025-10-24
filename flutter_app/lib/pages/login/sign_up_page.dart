import 'package:flutter/material.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/pages/auth/otp_page.dart';

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
  final _confirmFocus = FocusNode();

  bool _busy = false;
  String? _error;
  bool _confirmBlurred = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Rebuild on input changes to update inline validation and button state
    _firstName.addListener(_onChanged);
    _lastName.addListener(_onChanged);
    _email.addListener(_onChanged);
    _password.addListener(_onChanged);
    _confirmPassword.addListener(_onChanged);
    _confirmFocus.addListener(() {
      if (!_confirmFocus.hasFocus) {
        // Mark as blurred so we only show error after the user leaves the field
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

    if (fn.isEmpty || ln.isEmpty || email.isEmpty || pw.isEmpty) {
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
      );
      await AuthService.I.register(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registered. Check email for OTP.')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpPage(email: email)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailText = _email.text.trim().toLowerCase();
    final emailOk = emailText.endsWith('@ku.th');
    final confirmMatches = _confirmPassword.text == _password.text;
    final showConfirmError = (_submitted || _confirmBlurred) &&
        _confirmPassword.text.isNotEmpty &&
        !confirmMatches;
    final requiredFilled = _firstName.text.isNotEmpty &&
        _lastName.text.isNotEmpty &&
        _email.text.isNotEmpty &&
        _password.text.isNotEmpty &&
        _confirmPassword.text.isNotEmpty;
    final canSubmit = requiredFilled && emailOk && confirmMatches && !_busy;

    // Friendly green palette
    const bgTop = Color(0xFFECFDF5);    // emerald-50
    const bgBottom = Color(0xFFD1FAE5); // emerald-100
    const accent = Color(0xFF22C55E);   // emerald-500
    const accentDark = Color(0xFF16A34A); // emerald-600
    const deepTeal = Color(0xFF116466); // match Login button color

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Background + content
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
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.favorite_rounded, color: accent, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Welcome',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF116466), // deepTeal to match Login button
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create Your KUCOM Account',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Just a few details and you’re in 💫',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable form (starts below the text)
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
                              TextField(
                                controller: _firstName,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'First name',
                                  prefixIcon: Icon(Icons.person_outline),
                                  filled: true,
                                  fillColor: Color(0xFFF0FDF4), // emerald-50
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

            // Floating back arrow (top-left) — dark grey, no background
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
      // Fixed bottom CTA that lifts with keyboard
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
