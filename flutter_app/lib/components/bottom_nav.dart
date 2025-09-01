import 'package:flutter/material.dart';
import 'app_colors.dart';

class BottomDockItem {
  final IconData icon;
  final String label;
  const BottomDockItem({required this.icon, required this.label});
}

class BottomDockNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<BottomDockItem> items;

  const BottomDockNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.sage,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final it = items[i];
              final active = i == index;
              return InkResponse(
                onTap: () => onTap(i),
                radius: 28,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(it.icon, size: 26,
                        color: active ? Colors.white : Colors.white70),
                    const SizedBox(height: 2),
                    Text(
                      it.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: active ? Colors.white : Colors.white70,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}