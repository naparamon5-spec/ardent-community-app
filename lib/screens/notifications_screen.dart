import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Notifications — port of the web header notifications panel
/// (`store/notifications.js`) as a full page.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _items = <({String action, IconData icon, Color color, String time, bool unread})>[
    (action: 'reacted to your Sportsfest announcement', icon: Icons.thumb_up_alt_rounded, color: ArdentColors.accent, time: '5m', unread: true),
    (action: 'gave you kudos 🎉', icon: Icons.emoji_events_rounded, color: Color(0xFFC77700), time: '1h', unread: true),
    (action: 'commented on your post', icon: Icons.mode_comment_rounded, color: ArdentColors.navy600, time: '3h', unread: true),
    (action: 'mentioned you in a comment', icon: Icons.alternate_email_rounded, color: ArdentColors.crimson500, time: 'Yesterday', unread: false),
    (action: 'started following you', icon: Icons.person_add_alt_1_rounded, color: ArdentColors.navy500, time: 'Yesterday', unread: false),
    (action: 'invited you to All-Hands Town Hall', icon: Icons.event_rounded, color: ArdentColors.accent, time: 'Tue', unread: false),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All notifications marked as read')),
              );
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: ArdentSpacing.s2),
        itemCount: _items.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 72, color: ArdentColors.border),
        itemBuilder: (context, i) {
          final n = _items[i];
          final person = Seed.people[i % Seed.people.length];
          return Container(
            color: n.unread ? ArdentColors.accentSoft.withValues(alpha: 0.5) : null,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4, vertical: 4),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  DsAvatar(initials: person.initials, color: person.color, size: 46),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: n.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(n.icon, size: 11, color: Colors.white),
                    ),
                  ),
                ],
              ),
              title: RichText(
                text: TextSpan(
                  style: text.bodyLarge?.copyWith(color: ArdentColors.fg1, height: 1.35),
                  children: [
                    TextSpan(
                        text: person.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: ' '),
                    TextSpan(text: n.action),
                  ],
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('${n.time} ago', style: text.bodySmall),
              ),
              trailing: n.unread
                  ? Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                          color: ArdentColors.accent, shape: BoxShape.circle),
                    )
                  : null,
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}
