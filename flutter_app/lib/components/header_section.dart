import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../services/auth_service.dart';

class HeaderSection extends StatelessWidget {
  final VoidCallback? onAvatarTap;   // คงไว้เผื่อใช้งาน
  final VoidCallback? onSettingsTap; // แตะที่โลโก้

  /// true = มีพื้นหลัง, false = ไม่มีพื้นหลัง (ลอย)
  final bool showBackground;

  /// ใช้คู่กับ showBackground=true เท่านั้น
  /// true = เขียว/ขาว, false = ไล่ชมพู-ม่วงอ่อน
  final bool greenBackground;

  final String? greetingName;        // ชื่อผู้ใช้
  final String? subtitle;            // ข้อความใต้ชื่อ (optional)

  const HeaderSection({
    super.key,
    this.onAvatarTap,
    this.onSettingsTap,
    this.showBackground = false,     // ค่าเริ่มต้น: ไม่มีพื้นหลัง
    this.greenBackground = false,
    this.greetingName,
    this.subtitle,
  });

  String _firstName(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return 'there';
    return t.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleText = 'Hello ${_firstName(greetingName)},';
    final subText = subtitle ?? "Let's Elevate Your Skin's Health";

    // ---------- เนื้อหา ----------
    final content = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Title + Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          height: 1.0,
                        ) ??
                        const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          height: 1.0,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                          height: 1.2,
                        ) ??
                        const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.2,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Right: โลโก้ตัวอักษร "KUCOM" โทนเขียวเมทัลลิก (กดได้)
            GestureDetector(
              onTap: onSettingsTap,
              child: const KucomWordmarkGreen(size: 34), // ปรับขนาดตามต้องการ
            ),
          ],
        ),
      ),
    );

    // ---------- ไม่มีพื้นหลัง ----------
    if (!showBackground) return content;

    // ---------- พื้นหลัง (ใช้เมื่อ showBackground = true) ----------
    final BoxDecoration bg = greenBackground
        ? const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
            ),
          )
        : const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF6D9F2), Color(0xFFE6E0FF)],
            ),
          );

    return Container(
      width: double.infinity,
      decoration: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          if (greenBackground) const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// โลโก้ตัวอักษร "KUCOM" โทนเขียวเมทัลลิก (แนวเดียวกับภาพตัวอย่าง)
class KucomWordmarkGreen extends StatelessWidget {
  final double size; // ความสูงของตัวอักษร
  const KucomWordmarkGreen({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    // ไล่เฉดเขียวเมทัลลิก
    final LinearGradient metallicGreen = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFEFFAF1), // ไฮไลต์เกือบขาวอมเขียว
        Color(0xFFA8E6B5), // เขียวสว่าง
        Color(0xFF45A057), // เขียวกลาง
        Color(0xFF0F6D2A), // เขียวเข้มเมทัล
        Color(0xFFEFFAF1), // ไฮไลต์กลับปลาย
      ],
      stops: [0.0, 0.28, 0.55, 0.82, 1.0],
    );

    // สไตล์ตัวอักษร: ใช้ italic + serif fallback ให้ฟีลคล้ายฟอนต์ในภาพ
    TextStyle base(double strokeWidth, {bool stroke = false}) {
      final p = Paint()
        ..isAntiAlias = true
        ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = strokeWidth
        ..color = stroke ? Colors.white.withOpacity(0.95) : Colors.white;

      return TextStyle(
        fontSize: size,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        height: 1.0,
        fontFamilyFallback: const ['Times New Roman', 'Georgia', 'serif'],
        foreground: p,
      );
    }

    const text = 'KUCOM';

    return Transform(
      // เอียงเล็กน้อยให้ใกล้เคียงตัวอย่าง
      transform: Matrix4.skewX(-0.12),
      alignment: Alignment.centerRight,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // เงาเบา ๆ ใต้ตัวอักษรให้ดูนูน
          Positioned(
            top: 1.1,
            child: Text(
              text,
              style: base(0).copyWith(
                color: Colors.black.withOpacity(0.18),
                foreground: null,
              ),
            ),
          ),

          // เส้นขอบขาวบาง ๆ ตัดกับพื้นหลัง
          Text(text, style: base(1.6, stroke: true)),

          // เติมลำตัวด้วยกราเดียนต์เขียวเมทัลลิก
          ShaderMask(
            shaderCallback: (rect) => metallicGreen.createShader(rect),
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: base(0, stroke: false).copyWith(
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1.2),
                  ),
                ],
              ),
            ),
          ),

          // ไฮไลต์เส้นแววบาง ๆ ให้ความรู้สึกโลหะ
          IgnorePointer(
            child: ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment(-0.8, -1.0),
                end: Alignment(0.9, 1.0),
                colors: [Colors.white, Colors.transparent],
                stops: [0.0, 1.0],
              ).createShader(rect),
              child: Text(
                text,
                style: base(0).copyWith(
                  color: Colors.white.withOpacity(0.16),
                  foreground: null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final String? url;
  const _HeaderAvatar({this.url});

  ImageProvider? _providerFrom(String? src) {
    final s = (src ?? '').trim();
    if (s.isEmpty) return null;
    if (s.startsWith('assets/')) return AssetImage(s);
    if (s.startsWith('http://') || s.startsWith('https://')) return NetworkImage(s);
    if (s.startsWith('/')) return NetworkImage('${AuthService.I.apiBase}$s');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final prov = _providerFrom(url);
    return CircleAvatar(
      radius: 20,
      backgroundImage: prov,
      child: prov == null ? const Icon(Icons.person, color: Colors.white) : null,
      backgroundColor: AppColors.sage.withOpacity(.4),
    );
  }
}
