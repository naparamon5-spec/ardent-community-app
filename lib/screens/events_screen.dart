import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import 'create_event_screen.dart';

/// Events list — backed by `GET /events`, with live RSVP
/// (`PUT/DELETE /events/:id/rsvp`), creation (`POST /events`), and per-event
/// edit/delete (`PATCH`/`DELETE /events/:id`). Featured events get a hero card;
/// the rest are compact rows, mirroring the web layout.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _reloadTick = 0;
  final Map<String, String> _rsvp = {};

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

  String _statusFor(EventItem e) => _rsvp[e.id] ?? e.myRsvp;

  Future<void> _toggle(EventItem e, String status) async {
    final current = _statusFor(e);
    final next = current == status ? '' : status;
    setState(() => _rsvp[e.id] = next);
    try {
      if (next.isEmpty) {
        await Api.instance.events.clearRsvp(e.id);
      } else {
        await Api.instance.events.rsvp(e.id, status: next);
      }
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _rsvp[e.id] = current);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err.message)));
    }
  }

  Future<void> _openEdit(EventItem e) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateEventScreen(initial: e)),
    );
    if (saved == true && mounted) setState(() => _reloadTick++);
  }

  Future<void> _delete(EventItem e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('"${e.title}" will be removed. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: ArdentColors.accent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.events.delete(e.id);
      if (!mounted) return;
      setState(() => _reloadTick++);
      messenger.showSnackBar(const SnackBar(content: Text('Event deleted')));
    } on ApiException catch (err) {
      messenger.showSnackBar(SnackBar(
          content: Text(err.isForbidden
              ? 'Only the event creator can delete this.'
              : err.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.fromLTRB(ArdentSpacing.s4,
                  ArdentSpacing.s4, ArdentSpacing.s4, ArdentSpacing.s12),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: ArdentSpacing.s4),
              itemBuilder: (context, i) {
                final e = events[i];
                final common = _EventCallbacks(
                  status: _statusFor(e),
                  onRsvp: (s) => _toggle(e, s),
                  onEdit: () => _openEdit(e),
                  onDelete: () => _delete(e),
                );
                return e.featured
                    ? _FeaturedEventCard(event: e, cb: common)
                    : _CompactEventCard(event: e, cb: common);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Bundle of per-event state + callbacks passed to the card widgets.
class _EventCallbacks {
  _EventCallbacks({
    required this.status,
    required this.onRsvp,
    required this.onEdit,
    required this.onDelete,
  });
  final String status;
  final void Function(String status) onRsvp;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

Widget _dateBadge(EventItem e, TextTheme text, {double size = 58}) {
  return Container(
    width: size,
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: ArdentColors.accentSoft,
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      border: Border.all(color: ArdentColors.red100),
    ),
    child: Column(
      children: [
        Text(e.mon,
            style: text.labelSmall
                ?.copyWith(color: ArdentColors.accent, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(e.day,
            style: text.headlineMedium
                ?.copyWith(color: ArdentColors.accent, fontSize: 24, height: 1)),
      ],
    ),
  );
}

Widget _metaLine(IconData icon, String label, TextTheme text) {
  return Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: ArdentColors.fg3),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: text.bodySmall)),
      ],
    ),
  );
}

/// Three-dot overflow menu (Edit / Delete) shown at the top-right of each card.
Widget _menuButton(_EventCallbacks cb) {
  return SizedBox(
    height: 32,
    width: 32,
    child: PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz_rounded, color: ArdentColors.fg2),
      tooltip: 'More',
      onSelected: (v) => v == 'edit' ? cb.onEdit() : cb.onDelete(),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18, color: ArdentColors.fg1),
            SizedBox(width: 10),
            Text('Edit event'),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: ArdentColors.accent),
            SizedBox(width: 10),
            Text('Delete event', style: TextStyle(color: ArdentColors.accent)),
          ]),
        ),
      ],
    ),
  );
}

Widget _rsvpButtons(_EventCallbacks cb, {bool expanded = true}) {
  final going = _RsvpButton(
    active: cb.status == 'going',
    activeLabel: 'Going',
    idleLabel: "I'm going",
    activeIcon: Icons.check_circle_rounded,
    idleIcon: Icons.check_circle_outline_rounded,
    onTap: () => cb.onRsvp('going'),
  );
  final interested = _RsvpButton(
    active: cb.status == 'interested',
    activeLabel: 'Interested',
    idleLabel: 'Interested',
    activeIcon: Icons.star_rounded,
    idleIcon: Icons.star_border_rounded,
    onTap: () => cb.onRsvp('interested'),
  );
  if (!expanded) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      going,
      const SizedBox(width: ArdentSpacing.s2),
      interested,
    ]);
  }
  return Row(children: [
    Expanded(child: going),
    const SizedBox(width: ArdentSpacing.s3),
    Expanded(child: interested),
  ]);
}

// ---------------------------------------------------------------------------
// Featured hero card
// ---------------------------------------------------------------------------

class _FeaturedEventCard extends StatelessWidget {
  const _FeaturedEventCard({required this.event, required this.cb});
  final EventItem event;
  final _EventCallbacks cb;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = event;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(ArdentRadii.md)),
            child: SizedBox(
              height: 168,
              width: double.infinity,
              child: e.coverUrl.isNotEmpty
                  ? Image.network(e.coverUrl, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _coverPlaceholder(e, text))
                  : _coverPlaceholder(e, text),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const DsChip(
                      label: 'Featured',
                      fg: ArdentColors.accent,
                      bg: ArdentColors.accentSoft,
                      icon: Icons.star_rounded,
                    ),
                    const Spacer(),
                    _menuButton(cb),
                  ],
                ),
                const SizedBox(height: ArdentSpacing.s3),
                Text(e.title, style: text.headlineMedium?.copyWith(fontSize: 20)),
                const SizedBox(height: 6),
                _metaRow(e, text),
                if (e.desc.isNotEmpty) ...[
                  const SizedBox(height: ArdentSpacing.s3),
                  Text(e.desc,
                      style:
                          text.bodyMedium?.copyWith(color: ArdentColors.fg2, height: 1.4)),
                ],
                const SizedBox(height: ArdentSpacing.s3),
                Text('${e.attendees} going · ${e.interested} interested',
                    style: text.bodySmall),
                const SizedBox(height: ArdentSpacing.s3),
                _rsvpButtons(cb),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(EventItem e, TextTheme text) {
    return Wrap(
      spacing: 14,
      runSpacing: 2,
      children: [
        if (e.time.isNotEmpty || e.date.isNotEmpty)
          _inlineMeta(Icons.schedule_rounded,
              [e.date, e.time].where((s) => s.isNotEmpty).join(' · '), text),
        if (e.location.isNotEmpty)
          _inlineMeta(Icons.place_outlined, e.location, text),
      ],
    );
  }

  Widget _inlineMeta(IconData icon, String label, TextTheme text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ArdentColors.fg3),
        const SizedBox(width: 6),
        Text(label, style: text.bodySmall),
      ],
    );
  }

  Widget _coverPlaceholder(EventItem e, TextTheme text) {
    return Container(
      color: ArdentColors.bgSubtle,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(ArdentSpacing.s5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_rounded, color: ArdentColors.fg3, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(e.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: ArdentColors.fg3)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact card
// ---------------------------------------------------------------------------

class _CompactEventCard extends StatelessWidget {
  const _CompactEventCard({required this.event, required this.cb});
  final EventItem event;
  final _EventCallbacks cb;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = event;
    return SurfaceCard(
      padding: const EdgeInsets.all(ArdentSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dateBadge(e, text),
              const SizedBox(width: ArdentSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title,
                        style: text.titleMedium?.copyWith(fontSize: 16, height: 1.25)),
                    const SizedBox(height: 6),
                    if (e.time.isNotEmpty)
                      _metaLine(Icons.schedule_rounded,
                          [e.date, e.time].where((s) => s.isNotEmpty).join(' · '), text),
                    if (e.location.isNotEmpty)
                      _metaLine(Icons.place_outlined, e.location, text),
                    if (e.desc.isNotEmpty) ...[
                      const SizedBox(height: ArdentSpacing.s2),
                      Text(e.desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(color: ArdentColors.fg2)),
                    ],
                    const SizedBox(height: 6),
                    Text('${e.attendees} going · ${e.interested} interested',
                        style: text.bodySmall),
                  ],
                ),
              ),
              _menuButton(cb),
            ],
          ),
          const SizedBox(height: ArdentSpacing.s3),
          const Divider(height: 1),
          const SizedBox(height: ArdentSpacing.s3),
          _rsvpButtons(cb),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

class _RsvpButton extends StatelessWidget {
  const _RsvpButton({
    required this.active,
    required this.activeLabel,
    required this.idleLabel,
    required this.activeIcon,
    required this.idleIcon,
    required this.onTap,
  });

  final bool active;
  final String activeLabel;
  final String idleLabel;
  final IconData activeIcon;
  final IconData idleIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(active ? activeIcon : idleIcon, size: 17);
    final label = Text(active ? activeLabel : idleLabel);
    if (active) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: icon,
        label: label,
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11)),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: icon,
      label: label,
      style: OutlinedButton.styleFrom(
        foregroundColor: ArdentColors.fg1,
        side: const BorderSide(color: ArdentColors.borderStrong),
        padding: const EdgeInsets.symmetric(vertical: 11),
      ),
    );
  }
}

