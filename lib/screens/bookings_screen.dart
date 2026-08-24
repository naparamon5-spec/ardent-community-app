import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

/// Bookings — vans & rooms plus the caller's own bookings
/// (`GET /bookings/resources`, `GET /bookings/mine`). Requires
/// `module:bookings.view`.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  int _tab = 0; // 0 = Resources, 1 = My bookings
  String _type = 'van';

  Future<List<dynamic>> _loadResources() =>
      Api.instance.bookings.resources(type: _type);
  Future<List<dynamic>> _loadMine() => Api.instance.bookings.mine(scope: 'all');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Vans & rooms')),
                ButtonSegment(value: 1, label: Text('My bookings')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          if (_tab == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
              child: Row(
                children: [
                  _typeChip('Vans', 'van'),
                  const SizedBox(width: 8),
                  _typeChip('Rooms', 'room'),
                ],
              ),
            ),
          Expanded(child: _tab == 0 ? _resources() : _mine()),
        ],
      ),
    );
  }

  Widget _typeChip(String label, String value) {
    final active = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? ArdentColors.accent : ArdentColors.bgSubtle,
          borderRadius: BorderRadius.circular(ArdentRadii.pill),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: active ? Colors.white : ArdentColors.fg2)),
      ),
    );
  }

  Widget _resources() {
    return AsyncView<List<dynamic>>(
      key: ValueKey('res-$_type'),
      loader: _loadResources,
      builder: (context, items, reload) {
        if (items.isEmpty) {
          return const EmptyState(
              message: 'No resources available.',
              icon: Icons.directions_car_outlined);
        }
        final text = Theme.of(context).textTheme;
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView.separated(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: ArdentSpacing.s3),
            itemBuilder: (context, i) {
              final r = asMap(items[i]);
              final capacity = r['capacity'];
              return SurfaceCard(
                child: Row(
                  children: [
                    Icon(_type == 'van' ? Icons.directions_car_rounded : Icons.meeting_room_rounded,
                        color: ArdentColors.navy600),
                    const SizedBox(width: ArdentSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['name'] ?? 'Resource'}',
                              style: text.titleMedium?.copyWith(fontSize: 15)),
                          Text([
                            if (r['code'] != null) '${r['code']}',
                            if (r['location'] != null) '${r['location']}',
                            if (capacity != null) 'Seats $capacity',
                          ].join(' · '), style: text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _mine() {
    return AsyncView<List<dynamic>>(
      key: const ValueKey('mine'),
      loader: _loadMine,
      builder: (context, items, reload) {
        if (items.isEmpty) {
          return const EmptyState(
              message: "You have no bookings.", icon: Icons.event_note_outlined);
        }
        final text = Theme.of(context).textTheme;
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView.separated(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: ArdentSpacing.s3),
            itemBuilder: (context, i) {
              final b = asMap(items[i]);
              final status = '${b['status'] ?? ''}';
              return SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${b['reference'] ?? b['purpose'] ?? 'Booking'}',
                              style: text.titleMedium?.copyWith(fontSize: 15)),
                        ),
                        if (status.isNotEmpty)
                          DsChip(
                            label: status,
                            fg: status == 'cancelled'
                                ? ArdentColors.fg2
                                : ArdentColors.statusResolved,
                            bg: status == 'cancelled'
                                ? ArdentColors.bgSubtle
                                : ArdentColors.statusResolvedBg,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (b['purpose'] != null) Text('${b['purpose']}', style: text.bodyMedium),
                    Text(
                      [relativeTime(b['startsAt']), if (b['destination'] != null) '${b['destination']}']
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
