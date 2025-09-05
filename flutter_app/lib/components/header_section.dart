import 'package:flutter/material.dart';
import 'app_colors.dart';

class HeaderSection extends StatelessWidget {
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSettingsTap;
  const HeaderSection({super.key, this.onAvatarTap, this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        NetworkImage('https://i.pravatar.cc/150?img=3'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: AppColors.deepGreen),
                  iconSize: 24, 
                  onPressed: onSettingsTap,
                  tooltip: 'Settings',
                ),
              ],
            ),

            const SizedBox(height: 8), 

           
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text.rich(
                    TextSpan(
                      children: const [
                        TextSpan(
                          text: 'Welcome to ',
                          style: TextStyle(
                            color: AppColors.sage,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: 'KU',
                          style: TextStyle(
                            color: AppColors.deepGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: 'COM',
                          style: TextStyle(
                            color: AppColors.sage,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: '👋'),
                      ],
                    ),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      height: 1.15,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Tagline
                  Text(
                    'Your friendly space to share, connect, and thrive.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.sage,
                      fontSize: 14, 
                    ),
                    textAlign: TextAlign.center,
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
    );
  }
}
