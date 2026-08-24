import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// People directory — port of `pages/people/index.vue`.
class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(ArdentSpacing.s4),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search people…',
            prefixIcon: const Icon(Icons.search_rounded, color: ArdentColors.fg3),
          ),
        ),
        const SizedBox(height: ArdentSpacing.s4),
        Overline('${Seed.people.length} people'),
        const SizedBox(height: ArdentSpacing.s3),
        for (final p in Seed.people) ...[
          SurfaceCard(
            child: Row(
              children: [
                DsAvatar(
                    initials: p.initials, color: p.color, size: 46, online: p.online),
                const SizedBox(width: ArdentSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: text.titleMedium?.copyWith(fontSize: 15)),
                      Text(p.role, style: text.bodyMedium),
                      Text(
                        p.lastActive,
                        style: text.bodySmall?.copyWith(
                            color: p.online ? const Color(0xFF2FAE5C) : ArdentColors.fg3),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Message'),
                ),
              ],
            ),
          ),
          const SizedBox(height: ArdentSpacing.s3),
        ],
      ],
    );
  }
}
