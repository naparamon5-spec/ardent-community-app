import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'events_screen.dart';
import 'groups_screen.dart';
import 'marketplace_screen.dart';
import 'people_screen.dart';

/// Explore — a discovery hub surfacing shortcuts, upcoming events, groups to
/// join, and the marketplace, echoing the web app's right-rail content.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key, this.onOpenTab});

  /// Optional callback so tiles can jump to a bottom-nav tab.
  final void Function(int index)? onOpenTab;

  void _open(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: body),
    ));
  }

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is coming soon')),
    );
  }

  /// Two shortcut tiles side by side at a fixed height.
  Widget _shortcutRow(Widget left, Widget right) {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Expanded(child: left),
          const SizedBox(width: ArdentSpacing.s3),
          Expanded(child: right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(ArdentSpacing.s4),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search Ardent Community…',
            prefixIcon: const Icon(Icons.search_rounded, color: ArdentColors.fg3),
          ),
        ),
        const SizedBox(height: ArdentSpacing.s5),
        const Overline('Shortcuts'),
        const SizedBox(height: ArdentSpacing.s3),
        // Plain fixed-height rows — no GridView, so the tiles can never stretch
        // vertically with screen width (which was leaving a big gap).
        _shortcutRow(
          _ShortcutTile(Icons.people_alt_rounded, 'People', ArdentColors.navy600,
              onTap: () => _open(context, 'People', const PeopleScreen())),
          _ShortcutTile(Icons.groups_rounded, 'Groups', ArdentColors.crimson500,
              onTap: () => _open(context, 'Groups', const GroupsScreen())),
        ),
        const SizedBox(height: ArdentSpacing.s3),
        _shortcutRow(
          _ShortcutTile(Icons.event_rounded, 'Events', ArdentColors.accent,
              onTap: () => _open(context, 'Events', const EventsScreen())),
          _ShortcutTile(Icons.storefront_rounded, 'Mall of Ardent', const Color(0xFFC77700),
              onTap: () => _open(context, 'Mall of Ardent', const MarketplaceScreen())),
        ),
        const SizedBox(height: ArdentSpacing.s3),
        _shortcutRow(
          _ShortcutTile(Icons.workspace_premium_rounded, 'Appraisals', ArdentColors.navy700,
              onTap: () => _soon(context, 'Appraisals')),
          _ShortcutTile(Icons.bookmark_rounded, 'Saved', ArdentColors.navy500,
              onTap: () => _soon(context, 'Saved')),
        ),
        const SizedBox(height: ArdentSpacing.s6),
        const Overline('Upcoming events'),
        const SizedBox(height: ArdentSpacing.s3),
        for (final e in Seed.events.take(3)) ...[
          SurfaceCard(
            child: Row(
              children: [
                Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: ArdentColors.accentSoft,
                    borderRadius: BorderRadius.circular(ArdentRadii.sm),
                  ),
                  child: Column(
                    children: [
                      Text(e.mon, style: text.labelSmall?.copyWith(color: ArdentColors.accent)),
                      Text(e.day,
                          style: text.titleLarge?.copyWith(color: ArdentColors.accent)),
                    ],
                  ),
                ),
                const SizedBox(width: ArdentSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(fontSize: 14)),
                      Text('${e.time} · ${e.attendees} going', style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ArdentSpacing.s3),
        ],
        const SizedBox(height: ArdentSpacing.s3),
        const Overline('Suggested groups'),
        const SizedBox(height: ArdentSpacing.s3),
        for (final g in Seed.groups.take(3)) ...[
          SurfaceCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: g.color,
                    borderRadius: BorderRadius.circular(ArdentRadii.sm),
                  ),
                ),
                const SizedBox(width: ArdentSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name, style: text.titleMedium?.copyWith(fontSize: 14)),
                      Text('${g.members} members', style: text.bodySmall),
                    ],
                  ),
                ),
                OutlinedButton(onPressed: () {}, child: const Text('Join')),
              ],
            ),
          ),
          const SizedBox(height: ArdentSpacing.s3),
        ],
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile(this.icon, this.label, this.color, {this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      child: SurfaceCard(
        padding: const EdgeInsets.all(ArdentSpacing.s3),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(ArdentRadii.sm),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: ArdentSpacing.s3),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, color: ArdentColors.fg1)),
            ),
          ],
        ),
      ),
    );
  }
}
