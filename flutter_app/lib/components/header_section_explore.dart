// lib/components/header_section_explore.dart
import 'package:flutter/material.dart';
import 'search_bar.dart';

class HeaderSectionExplore extends StatelessWidget {
  final VoidCallback? onAvatarTap;

  // โหมดทำงานของ search
  final bool searchEditable;                 // true = เปิดคีย์บอร์ด, false = readOnly+tap
  final VoidCallback? onSearchTap;           // แตะ search ในโหมด readOnly
  final TextEditingController? controller;   // ใช้ตอนโหมด editable
  final ValueChanged<String>? onSubmitted;   // กดค้นหาบนคีย์บอร์ด
  final VoidCallback? onCancel;              // กด Cancel (โชว์เฉพาะโหมด editable)

  const HeaderSectionExplore({
    super.key,
    this.onAvatarTap,
    this.searchEditable = false,
    this.onSearchTap,
    this.controller,
    this.onSubmitted,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            GestureDetector(
              onTap: onAvatarTap,
              child: const CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'),
              ),
            ),

            const SizedBox(width: 12),

            // Search
            Expanded(
              child: SizedBox(
                height: 36,
                // โหมด editable: ใช้ SearchBarField ตรงๆ
                // โหมด readOnly: ซ้อน InkWell โปร่งใสทับ เพื่อ intercept tap -> onSearchTap
                child: searchEditable
                    ? SearchBarField(
                        controller: controller,
                        hintText: 'Search',
                        onSubmitted: onSubmitted,
                      )
                    : Stack(
                        children: [
                          // แสดงหน้าตา search เดิม แต่ไม่รับอินพุต
                          IgnorePointer(
                            ignoring: true,
                            child: SearchBarField(
                              controller: TextEditingController(),
                              hintText: 'Search',
                              onSubmitted: (_) {},
                            ),
                          ),
                          // ชั้นโปร่งใส รับ tap แล้วเรียก onSearchTap
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: onSearchTap,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(width: 12),

            // โหมด Search: ปุ่ม Cancel
            if (searchEditable && onCancel != null)
              TextButton(onPressed: onCancel, child: const Text('Cancel'))
            else
              Image.asset('assets/images/KU.png', height: 45, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }
}
