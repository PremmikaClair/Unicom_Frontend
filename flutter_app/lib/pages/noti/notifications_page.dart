import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.notifications_none_rounded, size: 48),
              SizedBox(height: 12),
              Text('Notifications (placeholder)'),
            ],
          ),
        ),
      ),
    );
  }
}

