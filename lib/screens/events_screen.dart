import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Events list — port of `pages/events.vue`.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(ArdentSpacing.s4),
      children: [
        for (final e in Seed.events) ...[
          SurfaceCard(
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
                            _iconLine(Icons.schedule_rounded, e.time, text),
                            _iconLine(Icons.place_outlined, e.location, text),
                            const SizedBox(height: ArdentSpacing.s2),
                            Text(e.desc, style: text.bodyMedium),
                            const SizedBox(height: ArdentSpacing.s3),
                            Row(
                              children: [
                                Text('${e.attendees} going · ${e.interested} interested',
                                    style: text.bodySmall),
                              ],
                            ),
                            const SizedBox(height: ArdentSpacing.s3),
                            Row(
                              children: [
                                ElevatedButton(onPressed: () {}, child: const Text("I'm going")),
                                const SizedBox(width: ArdentSpacing.s2),
                                OutlinedButton(onPressed: () {}, child: const Text('Interested')),
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
          ),
          const SizedBox(height: ArdentSpacing.s4),
        ],
      ],
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
