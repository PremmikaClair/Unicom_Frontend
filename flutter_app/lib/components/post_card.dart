// lib/components/post_card.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class PostCard extends StatelessWidget {
  final String avatarUrl;
  final String username;
  final String text;
  final VoidCallback? onAvatarTap; // NEW
  final VoidCallback? onCardTap;   // NEW

  const PostCard({
    super.key,
    required this.avatarUrl,
    required this.username,
    required this.text,
    this.onAvatarTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onCardTap, // tap anywhere on the card
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardGrey,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(blurRadius: 1.5, offset: Offset(0, 1), color: Colors.black12),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onAvatarTap, // tap only the avatar
                child: CircleAvatar(radius: 22, backgroundImage: NetworkImage(avatarUrl)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(text, style: textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Icon(Icons.thumb_up_alt_outlined, size: 22, color: AppColors.deepGreen),
                        SizedBox(width: 16),
                        Icon(Icons.chat_bubble_outline, size: 22, color: AppColors.deepGreen),
                      ],
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