// lib/components/filter_pill.dart
import 'package:flutter/material.dart';
import '../components/app_colors.dart';


class FilterPill extends StatelessWidget {
  final String label;  // ข้อความที่จะโชว์ใน pill
  final bool selected; // true = ถูกเลือก, false = ปกติ
  final VoidCallback? onTap; // true = ถูกเลือก, false = ปกติ
  final IconData? leading; // ไอคอนด้านหน้า (option)
  final EdgeInsets padding; // ระยะขอบใน pill

  const FilterPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: padding,
          decoration: BoxDecoration(
            // Background: white as requested
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            // Border: deep green in all states
            border: Border.all(
              color: AppColors.deepGreen,
              width: 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      color: Colors.black.withOpacity(0.06),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                Icon(
                  leading,
                  size: 16,
                  color: Colors.black87,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: textStyle?.copyWith(
                  fontWeight: FontWeight.w500,
                  // Text: black
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
