import 'package:flutter/material.dart';
import 'components/app_colors.dart';
import 'pages/app_shell.dart';
import 'pages/auth_gate.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KUCOM',
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: AppColors.bg),
      home: const AuthGate(child: AppShell()),
      debugShowCheckedModeBanner: false,
    );
  }
}
