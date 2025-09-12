import 'package:flutter/material.dart';

class FoodAllergiesPage extends StatelessWidget {
  const FoodAllergiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Allergies')),
      body: const Center(
        child: Text('นี่คือหน้ารายการอาการแพ้อาหาร'),
      ),
    );
  }
}
