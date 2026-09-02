import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'group_chat_screen.dart';
import 'group_posts_screen.dart';

/// The landing screen for a group opened from the Explore → Groups directory.
/// It shows the group header and lets the user choose between the group's
/// **Posts** feed and its **Chat**. (Opening a group straight from the Chats
/// tab skips this and goes directly to the chat.)
class GroupHomeScreen extends StatelessWidget {
  const GroupHomeScreen({super.key, required this.group});
  final Group group;

  void _openPosts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupPostsScreen(group: group)),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(group.name)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _cover(),
          Padding(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(group.name,
                          style: text.headlineSmall?.copyWith(fontSize: 22)),
                    ),
                    if (group.joined)
                      const DsChip(
                          label: 'Joined',
                          fg: ArdentColors.statusResolved,
                          bg: ArdentColors.statusResolvedBg)
                    else if (group.pending)
                      const DsChip(
                          label: 'Pending',
                          fg: Color(0xFFC77700),
                          bg: ArdentColors.statusPendingBg),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${group.members} member${group.members == 1 ? '' : 's'}',
                    style: text.bodyMedium?.copyWith(color: ArdentColors.fg3)),
                if (group.desc.isNotEmpty) ...[
                  const SizedBox(height: ArdentSpacing.s3),
                  Text(group.desc,
                      style: text.bodyMedium?.copyWith(color: ArdentColors.fg2)),
                ],
                const SizedBox(height: ArdentSpacing.s6),
                _optionCard(
                  context,
                  icon: Icons.dynamic_feed_rounded,
                  color: ArdentColors.navy600,
                  title: 'Posts',
                  subtitle: "The group's shared updates and announcements",
                  onTap: () => _openPosts(context),
                ),
                const SizedBox(height: ArdentSpacing.s3),
                _optionCard(
                  context,
                  icon: Icons.forum_rounded,
                  color: ArdentColors.crimson500,
                  title: 'Chat',
                  subtitle: 'Message the group in real time',
                  onTap: () => _openChat(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cover() {
    final banner = group.photoUrl.isNotEmpty
        ? Image.network(
            group.photoUrl,
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _coverFallback(),
          )
        : _coverFallback();
    return SizedBox(height: 140, width: double.infinity, child: banner);
  }

  Widget _coverFallback() => Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [group.color, group.color.withValues(alpha: 0.7)],
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.groups_rounded, color: Colors.white70, size: 44),
      );

  Widget _optionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(ArdentSpacing.s4),
        decoration: BoxDecoration(
          color: ArdentColors.bgSurface,
          borderRadius: BorderRadius.circular(ArdentRadii.lg),
          border: Border.all(color: ArdentColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(ArdentRadii.md),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: ArdentSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: ArdentColors.fg1)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12.5, color: ArdentColors.fg3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: ArdentColors.fg3),
          ],
        ),
      ),
    );
  }
}
