import 'package:flutter/material.dart';

class HealthAllergiesPage extends StatelessWidget {
  const HealthAllergiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Allergies"),
      ),
      body: const Center(
        child: Text("นี่คือหน้ารายการข้อมูลสุขภาพและอาการแพ้"),
      ),
    );
  }
}