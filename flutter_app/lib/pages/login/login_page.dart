import 'package:flutter/material.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/pages/login/sign_up_page.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onLoggedIn;
  const LoginPage({super.key, this.onLoggedIn});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await AuthService.I.login(_email.text, _password.text);
      // Optional: verify
      try { await AuthService.I.me(); } catch (_) {}
      if (!mounted) return;
      widget.onLoggedIn?.call();
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    const brandGreen = Color(0xFF84A98C); // background arc
    const deepTeal = Color(0xFF116466);   // title + buttons

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Bottom rounded green background
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: size.height * 0.58,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: brandGreen,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(180),
                    topRight: Radius.circular(180),
                  ),
                ),
              ),
            ),

            // Big title
            const Positioned(
              top: 90,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'KUCOM',
                  style: TextStyle(
                    fontSize: 76,
                    fontWeight: FontWeight.w600,
                    color: deepTeal,
                  ),
                ),
              ),
            ),

            // Foreground content
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 180),

                      // Hero image
                      SizedBox(
                        height: 320,
                        width: 320,
                        child: Image.asset('assets/images/login_image.png', fit: BoxFit.contain),
                      ),

                      // Email/password panel (keeps existing functionality)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(blurRadius: 12, color: Color(0x14000000), offset: Offset(0, 4)),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_error != null)
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Email submit button (calls existing _submit)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deepTeal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Login', style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Sign up button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const SignUpPage()),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deepTeal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Sign up', style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
