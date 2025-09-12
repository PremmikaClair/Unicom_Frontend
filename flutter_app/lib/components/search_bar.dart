import 'package:flutter/material.dart';

class SearchBarField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final Color? fillColor;

  const SearchBarField({
    super.key,
    this.controller,
    this.onSubmitted,
    this.hintText = 'Search',
    this.fillColor, // ส่งสีเข้ามาเองได้ ถ้าไม่ส่งจะใช้ theme
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = fillColor ?? const Color(0xFFF5F5F5);

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: bg, // 🎨 เปลี่ยนสีได้ที่นี่ หรือส่งผ่านพารามิเตอร์
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30), // โค้งแบบในภาพ
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}