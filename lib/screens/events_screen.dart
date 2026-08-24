import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import 'create_event_screen.dart';

/// Events list — backed by `GET /events`, with live RSVP via
/// `PUT /events/:id/rsvp` and event creation via `POST /events`.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _reloadTick = 0;

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateEventScreen()),
    );
    if (created == true && mounted) setState(() => _reloadTick++);
  }

  Future<List<EventItem>> _load() async {
    final raw = await Api.instance.events.list();
    return raw.map(eventFromJson).toList();
  }

  Future<void> _rsvp(EventItem e, String status) async {
    try {
      await Api.instance.events.rsvp(e.id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'going' ? "You're going 🎉" : 'Marked interested')),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create'),
      ),
      body: AsyncView<List<EventItem>>(
        key: ValueKey(_reloadTick),
        loader: _load,
        builder: (context, events, reload) {
          if (events.isEmpty) {
            return const EmptyState(
                message: 'No events yet.', icon: Icons.event_outlined);
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: ArdentSpacing.s4),
              itemBuilder: (context, i) => _eventCard(events[i], text),
            ),
          );
        },
      ),
    );
  }

  Widget _eventCard(EventItem e, TextTheme text) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.featured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: ArdentColors.accent,
                borderRadius: BorderRadius.vertical(top: Radius.circular(ArdentRadii.md)),
              ),
              child: Text('FEATURED',
                  textAlign: TextAlign.center,
                  style: text.labelSmall?.copyWith(color: Colors.white)),
            ),
          Padding(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dateBadge(e, text),
                const SizedBox(width: ArdentSpacing.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: text.titleMedium),
                      const SizedBox(height: 3),
                      if (e.time.isNotEmpty) _iconLine(Icons.schedule_rounded, e.time, text),
                      if (e.location.isNotEmpty)
                        _iconLine(Icons.place_outlined, e.location, text),
                      if (e.desc.isNotEmpty) ...[
                        const SizedBox(height: ArdentSpacing.s2),
                        Text(e.desc, style: text.bodyMedium),
                      ],
                      const SizedBox(height: ArdentSpacing.s3),
                      Text('${e.attendees} going · ${e.interested} interested',
                          style: text.bodySmall),
                      const SizedBox(height: ArdentSpacing.s3),
                      Row(
                        children: [
                          ElevatedButton(
                              onPressed: () => _rsvp(e, 'going'),
                              child: const Text("I'm going")),
                          const SizedBox(width: ArdentSpacing.s2),
                          OutlinedButton(
                              onPressed: () => _rsvp(e, 'interested'),
                              child: const Text('Interested')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateBadge(EventItem e, TextTheme text) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: ArdentColors.accentSoft,
        borderRadius: BorderRadius.circular(ArdentRadii.sm),
      ),
      child: Column(
        children: [
          Text(e.mon, style: text.labelSmall?.copyWith(color: ArdentColors.accent)),
          Text(e.day,
              style: text.headlineMedium?.copyWith(color: ArdentColors.accent, fontSize: 22)),
        ],
      ),
    );
  }

  Widget _iconLine(IconData icon, String label, TextTheme text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: ArdentColors.fg3),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: text.bodySmall)),
        ],
      ),
    );
  }
}
