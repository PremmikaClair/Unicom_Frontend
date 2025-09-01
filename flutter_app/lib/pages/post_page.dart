// lib/pages/post_page.dart
import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../models/post.dart';
import 'profile_page.dart';

class PostPage extends StatelessWidget {
  final Post post;
  const PostPage({super.key, required this.post});

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    final p = post;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(p.username.isNotEmpty ? '@${p.username}' : 'Post')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
                child: CircleAvatar(
                  radius: 26,
                  backgroundImage: p.profilePic.isNotEmpty ? NetworkImage(p.profilePic) : null,
                  child: p.profilePic.isEmpty ? const Icon(Icons.person) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.username, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (p.category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.cardGrey, borderRadius: BorderRadius.circular(12)),
                            child: Text(p.category, style: theme.textTheme.labelSmall),
                          ),
                        if (p.category.isNotEmpty) const SizedBox(width: 8),
                        Text(_timeAgo(p.timeStamp), style: theme.textTheme.labelSmall?.copyWith(color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(p.message, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          const Divider(),
          Row(
            children: [
              const Icon(Icons.thumb_up_alt_outlined, color: AppColors.deepGreen),
              const SizedBox(width: 6),
              Text('${p.likeCount}'),
              const SizedBox(width: 16),
              const Icon(Icons.chat_bubble_outline, color: AppColors.deepGreen),
              const SizedBox(width: 6),
              Text('${p.comment}'),
            ],
          ),
          const Divider(),
          const SizedBox(height: 12),
          Text('Comments', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.cardGrey, borderRadius: BorderRadius.circular(16)),
            child: const Text('No comments yet.'),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}