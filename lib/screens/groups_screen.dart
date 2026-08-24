import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Groups directory — port of `pages/groups/index.vue`.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(ArdentSpacing.s4),
      children: [
        for (final g in Seed.groups) ...[
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [g.color, g.color.withValues(alpha: 0.7)],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(ArdentRadii.md)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(ArdentSpacing.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name, style: text.titleLarge?.copyWith(fontSize: 17)),
                      const SizedBox(height: 2),
                      Text('${g.members} members', style: text.bodySmall),
                      const SizedBox(height: ArdentSpacing.s2),
                      Text(g.desc, style: text.bodyMedium),
                      const SizedBox(height: ArdentSpacing.s3),
                      Row(
                        children: [
                          ElevatedButton(onPressed: () {}, child: const Text('Join')),
                          const SizedBox(width: ArdentSpacing.s2),
                          OutlinedButton(onPressed: () {}, child: const Text('View')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ArdentSpacing.s4),
        ],
      ],
    );
  }
}
