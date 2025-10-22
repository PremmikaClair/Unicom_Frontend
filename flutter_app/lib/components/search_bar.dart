// lib/components/search_bar.dart
import 'package:flutter/material.dart';

// lib/components/search_bar.dart
class SearchBarField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final Color? fillColor;
  final bool readOnly;           // ⬅️ เพิ่ม
  final VoidCallback? onTap;     // ⬅️ เพิ่ม

  const SearchBarField({
    super.key,
    this.controller,
    this.focusNode,
    this.onSubmitted,
    this.hintText = 'Search',
    this.fillColor,
    this.readOnly = false,       // ⬅️ เพิ่ม
    this.onTap,                  // ⬅️ เพิ่ม
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = fillColor ?? const Color.fromARGB(255, 233, 232, 232);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,        // ⬅️
      onTap: onTap,              // ⬅️
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
