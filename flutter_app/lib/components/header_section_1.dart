import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ปุ่ม Avatar (ซ้าย)
class AvatarButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double radius;
  final ImageProvider image;

  const AvatarButton({
    super.key,
    this.onTap,
    this.radius = 20,
    this.image = const NetworkImage('https://i.pravatar.cc/150?img=3'),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(radius: radius, backgroundImage: image),
    );
  }
}

/// ปุ่ม Settings (ขวา)
class SettingsButton extends StatelessWidget {
  final VoidCallback? onTap;

  const SettingsButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings, color: AppColors.deepGreen),
      onPressed: onTap,
      tooltip: 'Settings',
    );
  }
}