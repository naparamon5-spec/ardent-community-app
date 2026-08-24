import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'events_screen.dart';
import 'groups_screen.dart';
import 'marketplace_screen.dart';
import 'people_screen.dart';
import 'search_screen.dart';

/// Explore — a discovery hub surfacing shortcuts plus live upcoming events and
/// suggested groups (`GET /events`, `GET /groups`).
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.onOpenTab});

  /// Optional callback so tiles can jump to a bottom-nav tab.
  final void Function(int index)? onOpenTab;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late Future<List<EventItem>> _events;
  late Future<List<Group>> _groups;

  @override
  void initState() {
    super.initState();
    _events = Api.instance.events
        .list()
        .then((r) => r.map(eventFromJson).toList())
        .catchError((_) => <EventItem>[]);
    _groups = Api.instance.groups
        .list()
        .then((r) => r.map(groupFromJson).where((g) => !g.isDirect).toList())
        .catchError((_) => <Group>[]);
  }

  void _open(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: body),
    ));
  }

  /// Pushes a screen that provides its own Scaffold/AppBar (Events, Groups).
  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is coming soon')),
    );
  }

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
        GestureDetector(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SearchScreen())),
          child: AbsorbPointer(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Ardent Community…',
                prefixIcon: const Icon(Icons.search_rounded, color: ArdentColors.fg3),
              ),
            ),
          ),
        ),
        const SizedBox(height: ArdentSpacing.s5),
        const Overline('Shortcuts'),
        const SizedBox(height: ArdentSpacing.s3),
        _shortcutRow(
          _ShortcutTile(Icons.people_alt_rounded, 'People', ArdentColors.navy600,
              onTap: () => _open(context, 'People', const PeopleScreen())),
          _ShortcutTile(Icons.groups_rounded, 'Groups', ArdentColors.crimson500,
              onTap: () => _push(context, const GroupsScreen())),
        ),
        const SizedBox(height: ArdentSpacing.s3),
        _shortcutRow(
          _ShortcutTile(Icons.event_rounded, 'Events', ArdentColors.accent,
              onTap: () => _push(context, const EventsScreen())),
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
        FutureBuilder<List<EventItem>>(
          future: _events,
          builder: (context, snapshot) {
            final events = (snapshot.data ?? const <EventItem>[]).take(3).toList();
            if (events.isEmpty) {
              return _placeholder(snapshot, 'No upcoming events');
            }
            return Column(
              children: [for (final e in events) _eventRow(e, text)],
            );
          },
        ),
        const SizedBox(height: ArdentSpacing.s3),
        const Overline('Suggested groups'),
        const SizedBox(height: ArdentSpacing.s3),
        FutureBuilder<List<Group>>(
          future: _groups,
          builder: (context, snapshot) {
            final groups = (snapshot.data ?? const <Group>[]).take(3).toList();
            if (groups.isEmpty) {
              return _placeholder(snapshot, 'No groups to suggest');
            }
            return Column(
              children: [for (final g in groups) _groupRow(g, text)],
            );
          },
        ),
      ],
    );
  }

  Widget _placeholder(AsyncSnapshot snapshot, String emptyText) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(ArdentSpacing.s4),
        child: Center(
            child: SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return SurfaceCard(
      child: Text(emptyText,
          style: TextStyle(color: ArdentColors.fg3, fontSize: 13)),
    );
  }

  Widget _eventRow(EventItem e, TextTheme text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s3),
      child: SurfaceCard(
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
                  Text(e.day, style: text.titleLarge?.copyWith(color: ArdentColors.accent)),
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
    );
  }

  Widget _groupRow(Group g, TextTheme text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s3),
      child: SurfaceCard(
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
            OutlinedButton(
              onPressed: () => _push(context, const GroupsScreen()),
              child: const Text('View'),
            ),
          ],
        ),
      ),
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
