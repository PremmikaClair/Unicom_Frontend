import 'package:flutter/material.dart';
import 'app_colors.dart';

class HeaderSection extends StatelessWidget {
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSettingsTap;
  final bool greenBackground; // use green header like Events
  final String? greetingName; // shows "Hi, {name}!" next to avatar
  const HeaderSection({
    super.key,
    this.onAvatarTap,
    this.onSettingsTap,
    this.greenBackground = false,
    this.greetingName,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final content = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---------- แถวบน: Avatar ซ้าย + KU/COM ขวา ----------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left block: avatar + greeting stacked with welcome + tagline (left aligned)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile picture
                      GestureDetector(
                        onTap: onAvatarTap,
                        child: const CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Texts stacked to the right of avatar
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((greetingName ?? '').trim().isNotEmpty)
                              Text(
                                'Hi, ${greetingName!.trim()}!',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: greenBackground ? const Color(0xFFF1F4EA) : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Welcome to ',
                                    style: TextStyle(
                                      color: greenBackground ? const Color(0xFFF1F4EA) : AppColors.sage,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'KU',
                                    style: TextStyle(
                                      color: greenBackground ? Colors.white : AppColors.deepGreen,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'COM👋 ',
                                    style: TextStyle(
                                      color: greenBackground ? const Color(0xFFF1F4EA) : AppColors.sage,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: greenBackground ? Colors.white : Colors.black87,
                                fontSize: 18,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.left,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your friendly space to share, connect, and thrive.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: greenBackground ? const Color(0xFFF1F4EA) : AppColors.sage,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.left,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Right: KU/COM Logo
                Image.asset(
                  'assets/images/KU.png',
                  height: 45,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!greenBackground) return content;

    // Wrap with the same green tone as Events header
    const headerG1 = Color(0xFF7E9766);
    const headerG2 = Color(0xFF7E9766);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [headerG1, headerG2],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          const SizedBox(height: 6), // tighter bottom space within green area
        ],
      ),
    );
  }
}
