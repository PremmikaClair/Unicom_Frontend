import 'package:flutter/material.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key, required this.email});
  final String email;

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
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() { _busy = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP verification not implemented yet.')),
    );
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() { _busy = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resend OTP not implemented yet.')),
    );
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

