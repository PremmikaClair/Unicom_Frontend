import 'package:flutter/material.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/pages/login/login_page.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key, required this.email, this.payload});
  final String email;
  final RegisterPayload? payload; // used to resend via /register

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _otp = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await AuthService.I.verifyOtp(email: widget.email, otp: _otp.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account verified. Please log in.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('otp expired')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP expired. Please log in.')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      } else if (msg.contains('user created successfully')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created. Please log in.')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      } else if (msg.contains('no otp') || msg.contains('no otp pending')) {
        if (!mounted) return;
        setState(() { _error = 'No OTP found. Please try again.'; });
      } else {
        if (!mounted) return;
        setState(() { _error = e.toString(); });
      }
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    if (widget.payload == null) {
      setState(() { _error = 'Missing registration data. Go back and sign up again.'; });
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await AuthService.I.register(widget.payload!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP re-sent to ${widget.email}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to resend OTP: ${e.toString()}'; });
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    const deepTeal = Color(0xFF116466);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: deepTeal,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Enter the 6-digit code sent to\n${widget.email}', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'OTP Code',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _busy ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: deepTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                ),
                child: _busy
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _busy ? null : _resend, child: const Text('Resend code')),
            ],
          ),
        ),
      ),
    );
  }
}
