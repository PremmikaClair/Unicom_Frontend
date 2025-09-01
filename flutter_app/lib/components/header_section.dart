import 'package:flutter/material.dart';
import 'app_colors.dart';

class HeaderSection extends StatelessWidget {
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSettingsTap;
  const HeaderSection({super.key, this.onAvatarTap, this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(                         // <-- keeps away from notch
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onAvatarTap,            // <-- navigate to profile
              child: const CircleAvatar(
                radius: 20,
                backgroundImage:
                    NetworkImage('https://i.pravatar.cc/150?img=3'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text.rich(
                    TextSpan(
                      children: const [
                        TextSpan(text: 'Welcome to '),
                        TextSpan(
                          text: 'KUCOM',
                          style: TextStyle(
                            color: AppColors.deepGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: ' 👋'),
                      ],
                    ),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,   // <-- no overflow
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your friendly space to share, connect, and thrive.',
                    style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: AppColors.deepGreen),
              onPressed: onSettingsTap,
              tooltip: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}