import 'package:flutter/material.dart';
import 'app_colors.dart';

class BottomDockItem {
  final IconData icon;
  final String label;
  const BottomDockItem({required this.icon, required this.label});
}

/// Bottom bar แบบมี notch โค้งรับปุ่มกลาง + ปรับช่องว่างได้
class BottomDockNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<BottomDockItem> items;
  final VoidCallback? onCenterTap;

  final String centerLabel;
  final IconData centerIcon;
  final Color barColor;
  final Color barShadowColor;
  final Color activeColor;
  final Color inactiveColor;
  final Color centerColor;

  /// จำนวนไอเท็มฝั่งซ้าย (ชัดเจนว่าอยากได้ซ้าย 2 ขวา 2)
  final int leftCount;

  /// ระยะห่างใต้ปุ่มกลาง (ยิ่งน้อยยิ่งชิด)
  final double centerGap;

  /// ระยะห่างแต่ละไอเท็ม
  final double itemSpacing;

  /// รัศมีมุมโค้งของแถบ
  final double barRadius;

  /// ขนาดปุ่มกลาง (ต้องตรงกับด้านล่าง)
  final double centerButtonSize;

  /// ความหนา “ขอบ” รอบปุ่มกลาง (ให้เนียนกับแถบ)
  final double centerButtonBorder;

  const BottomDockNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
    this.onCenterTap,
    this.centerLabel = 'Add Post',
    this.centerIcon = Icons.add,
    this.barColor = Colors.white,
    this.barShadowColor = const Color(0x1A000000),
    this.activeColor = Colors.black87,
    this.inactiveColor = Colors.black54,
    this.centerColor = const Color(0xFF9DAE7A),

    this.leftCount = 2,
    this.centerGap = 44,
    this.itemSpacing = 8,
    this.barRadius = 28,

    // ปุ่มกลาง: 64 + ขอบ 4 ตามดีไซน์ก่อนหน้า
    this.centerButtonSize = 50,
    this.centerButtonBorder = 4,
  });

  @override
  Widget build(BuildContext context) {
    final left = items.take(leftCount).toList();
    final right = items.skip(leftCount).toList();

    // รัศมี notch = (รัศมีปุ่ม + ขอบ) + margin เล็กน้อยให้ไม่ชน
    final double notchRadius =
        (centerButtonSize / 2) + centerButtonBorder + 2; // +2 margin

    // ความสูงตัวแถบ (ไม่รวม label ใต้ปุ่ม)
    const double barHeight = 58;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: SizedBox(
          height: 86,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // ----- พื้นหลังแถบที่ "บากโค้ง" รับปุ่มกลาง -----
              CustomPaint(
                size: const Size(double.infinity, barHeight),
                painter: _NotchedBarPainter(
                  color: barColor,
                  shadowColor: barShadowColor,
                  barRadius: barRadius,
                  notchRadius: notchRadius,
                  // เอาศูนย์กลางวงกลมยกขึ้นจากขอบบนของแถบเล็กน้อย
                  // เพื่อให้เป็นโค้งกินเข้ามาพอดี (ค่าประมาณจากภาพ)
                  notchCenterDyFromTop: -6,
                ),
                child: Container(
                  height: barHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SideTabs(
                        items: left,
                        baseIndex: 0,
                        currentIndex: index,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                        onTap: onTap,
                        itemSpacing: itemSpacing,
                      ),
                      SizedBox(width: centerGap),
                      _SideTabs(
                        items: right,
                        baseIndex: left.length,
                        currentIndex: index,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                        onTap: onTap,
                        itemSpacing: itemSpacing,
                      ),
                    ],
                  ),
                ),
              ),

              // ----- ปุ่มกลาง + label -----
              Positioned(
                bottom: 6,
                child: Column(
                  children: [
                    InkResponse(
                      onTap: onCenterTap,
                      radius: (centerButtonSize / 2) + 8,
                      child: Container(
                        width: centerButtonSize,
                        height: centerButtonSize,
                        decoration: BoxDecoration(
                          color: centerColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: barShadowColor,
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: barColor, // ให้ขอบกลืนกับแถบ
                            width: centerButtonBorder,
                          ),
                        ),
                        child: Icon(centerIcon, size: 34, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      centerLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideTabs extends StatelessWidget {
  final List<BottomDockItem> items;
  final int baseIndex;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<int> onTap;
  final double itemSpacing;

  const _SideTabs({
    required this.items,
    required this.baseIndex,
    required this.currentIndex,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    required this.itemSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(items.length, (i) {
        final it = items[i];
        final idx = baseIndex + i;
        final active = idx == currentIndex;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: itemSpacing),
          child: InkResponse(
            onTap: () => onTap(idx),
            radius: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(it.icon, size: 24, color: active ? activeColor : inactiveColor),
                const SizedBox(height: 2),
                Text(
                  it.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? activeColor : inactiveColor,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// วาดพื้นหลังแถบ และ "บากโค้ง" ให้ตามปุ่มกลาง
class _NotchedBarPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;
  final double barRadius;
  final double notchRadius;
  /// ระยะของจุดศูนย์กลางวงกลมจากขอบบนของแถบ (ค่าติดลบ = ยกวงกลมขึ้น)
  final double notchCenterDyFromTop;

  _NotchedBarPainter({
    required this.color,
    required this.shadowColor,
    required this.barRadius,
    required this.notchRadius,
    required this.notchCenterDyFromTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // กรอบแถบหลัก (โค้งมน)
    final rectPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(barRadius),
        ),
      );

    // วงกลมสำหรับ "บาก" ออก (อยู่กลางแนวนอน)
    final circleCenter = Offset(size.width / 2, notchCenterDyFromTop);
    final cutout = Path()..addOval(Rect.fromCircle(center: circleCenter, radius: notchRadius));

    // เอาวงกลมมาลบออกจากสี่เหลี่ยม → เกิดโค้งเว้า (notch)
    final notched = Path.combine(PathOperation.difference, rectPath, cutout);

    // วาดเงาให้นุ่ม (ใช้ path ที่เจาะแล้ว)
    canvas.drawShadow(notched, shadowColor.withOpacity(1.0), 14, false);

    // ลงสีตัวแถบ
    final paint = Paint()..color = color;
    canvas.drawPath(notched, paint);
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.notchCenterDyFromTop != notchCenterDyFromTop;
  }
}
