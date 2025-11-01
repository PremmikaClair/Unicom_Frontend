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
  final Color backgroundColor;

  const HeaderSection({
    super.key,
    this.onAvatarTap,
    this.onSettingsTap,
    this.showBackground = false,     // ค่าเริ่มต้น: ไม่มีพื้นหลัง
    this.greenBackground = false,
    this.greetingName,
    this.subtitle,
    this.backgroundColor = Colors.transparent,
  });

  String _firstName(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return 'there';
    return t.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleText = 'Hello ${_firstName(greetingName)}!';


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
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color.fromARGB(221, 13, 60, 30),
                          height: 1.0,
                        ) ??
                        const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          height: 1.0,
                        ),
                    ),
                  ],
                ),
              ),
            ),

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
    final wrappedContent = Container(
      color: backgroundColor,
      child: content,
    );

    if (!showBackground) return wrappedContent;

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
      color: backgroundColor,
      child: Container(
        width: double.infinity,
        decoration: bg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            content,
            if (greenBackground) const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// โลโก้ตัวอักษร "KUCOM" โทนเขียวเมทัลลิก (แนวเดียวกับภาพตัวอย่าง)
class KucomWordmarkGreen extends StatelessWidget {
  final double size; // ความสูงของโลโก้
  const KucomWordmarkGreen({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/ourlogo.png',
      height: size,
      fit: BoxFit.contain,
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
