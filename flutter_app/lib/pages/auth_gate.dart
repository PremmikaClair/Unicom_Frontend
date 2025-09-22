import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

/// Shows [LoginPage] until authenticated, then [child].
class AuthGate extends StatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _booting = true;
  bool _authed = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await AuthService.I.init();
    if (AuthService.I.isAuthed) {
      try {
        await AuthService.I.me();
        _authed = true;
      } catch (_) {
        await AuthService.I.logout();
        _authed = false;
      }
    }
    if (mounted) setState(() { _booting = false; });
  }

  void _onLoggedIn() {
    setState(() { _authed = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_authed) {
      return LoginPage(onLoggedIn: _onLoggedIn);
    }
    return widget.child;
  }
}

