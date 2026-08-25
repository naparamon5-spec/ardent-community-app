import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

/// Manage bookings (admin) — the fleet, the rooms, and every booking on record
/// (`/booking-admin/*`). Requires `module:bookings.manage`.
class BookingAdminScreen extends StatefulWidget {
  const BookingAdminScreen({super.key});

  @override
  State<BookingAdminScreen> createState() => _BookingAdminScreenState();
}

class _BookingAdminScreenState extends State<BookingAdminScreen> {
  int _reloadTick = 0;
  String _logFilter = 'van'; // 'van' | 'room' | 'cancelled'

  void _reload() => setState(() => _reloadTick++);

  Future<void> _openResourceForm(String type, {Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ArdentColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ArdentRadii.xl)),
      ),
      builder: (_) => _ResourceForm(type: type, existing: existing),
    );
    if (saved == true) _reload();
  }

  Future<void> _toggleService(Map<String, dynamic> r) async {
    final id = '${r['id']}';
    final active = r['isActive'] != false;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (active) {
        // Preview impact, then confirm deactivation.
        int affected = 0;
        try {
          final impact = await Api.instance.bookingAdmin.resourceImpact(id);
          affected = _int(impact['count'] ?? impact['affected'] ?? asList(impact['bookings']).length);
        } catch (_) {}
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Take out of service?'),
            content: Text(affected > 0
                ? '$affected upcoming booking(s) will be kept, and their occupants notified.'
                : 'It will no longer be bookable. Existing bookings are kept.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: ArdentColors.accent),
                child: const Text('Take out of service'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await Api.instance.bookingAdmin.deactivateResource(id);
      } else {
        // Return to service = reactivate.
        await Api.instance.bookingAdmin.updateResource(id, fields: {'isActive': 'true'});
      }
      _reload();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final id = '${r['id']}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text('"${r['name'] ?? 'Resource'}" will be removed. If it has '
            'booking history you\'ll need to take it out of service instead.'),
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
      await Api.instance.bookingAdmin.deleteResource(id);
      _reload();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> b) async {
    final id = '${b['id']}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text('${b['reference'] ?? b['purpose'] ?? 'Booking'} will be '
            'cancelled and the occupants notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep it')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: ArdentColors.accent),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.bookingAdmin.cancelBooking(id);
      _reload();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage bookings')),
      body: ListView(
        padding: const EdgeInsets.all(ArdentSpacing.s4),
        children: [
          Text('The fleet, the rooms, and every booking on record.',
              style: text.bodyMedium?.copyWith(color: ArdentColors.fg3)),
          const SizedBox(height: ArdentSpacing.s4),

          // ---- Vans ----
          _sectionHeader('Vans', () => _openResourceForm('van')),
          const SizedBox(height: ArdentSpacing.s2),
          AsyncView<List<dynamic>>(
            key: ValueKey('vans-$_reloadTick'),
            loader: () => Api.instance.bookingAdmin.resources(type: 'van'),
            builder: (context, items, reload) => _resourceList(items, 'van'),
          ),
          const SizedBox(height: ArdentSpacing.s5),

          // ---- Rooms ----
          _sectionHeader('Rooms', () => _openResourceForm('room')),
          const SizedBox(height: ArdentSpacing.s2),
          AsyncView<List<dynamic>>(
            key: ValueKey('rooms-$_reloadTick'),
            loader: () => Api.instance.bookingAdmin.resources(type: 'room'),
            builder: (context, items, reload) => _resourceList(items, 'room'),
          ),
          const SizedBox(height: ArdentSpacing.s5),

          // ---- All bookings ----
          const Overline('All bookings'),
          const SizedBox(height: ArdentSpacing.s2),
          Row(
            children: [
              _logChip('Vans', 'van'),
              const SizedBox(width: ArdentSpacing.s2),
              _logChip('Rooms', 'room'),
              const SizedBox(width: ArdentSpacing.s2),
              _logChip('Cancelled', 'cancelled'),
            ],
          ),
          const SizedBox(height: ArdentSpacing.s3),
          AsyncView<List<dynamic>>(
            key: ValueKey('log-$_logFilter-$_reloadTick'),
            loader: () => Api.instance.bookingAdmin.bookings(
              type: _logFilter == 'cancelled' ? null : _logFilter,
              status: _logFilter == 'cancelled' ? 'cancelled' : 'booked',
            ),
            builder: (context, items, reload) {
              if (items.isEmpty) {
                return Text('Nothing to show.',
                    style: text.bodyMedium?.copyWith(color: ArdentColors.fg3));
              }
              return Column(
                children: [
                  for (final raw in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: ArdentSpacing.s2),
                      child: _bookingRow(asMap(raw)),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: ArdentSpacing.s8),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, VoidCallback onAdd) {
    return Row(
      children: [
        Expanded(child: Overline(title)),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add'),
        ),
      ],
    );
  }

  Widget _resourceList(List<dynamic> items, String type) {
    final text = Theme.of(context).textTheme;
    if (items.isEmpty) {
      return Text('No ${type == 'van' ? 'vans' : 'rooms'} yet.',
          style: text.bodyMedium?.copyWith(color: ArdentColors.fg3));
    }
    return Column(
      children: [
        for (final raw in items)
          Padding(
            padding: const EdgeInsets.only(bottom: ArdentSpacing.s2),
            child: _resourceRow(asMap(raw), type),
          ),
      ],
    );
  }

  Widget _resourceRow(Map<String, dynamic> r, String type) {
    final text = Theme.of(context).textTheme;
    final active = r['isActive'] != false;
    final capacity = r['capacity'];
    final facilities = asList(r['facilities']).map((e) => '$e').join(', ');
    final meta = [
      if (capacity != null)
        '$capacity ${type == 'van' ? 'passenger seats' : 'seats'}',
      if (r['plateNumber'] != null) '${r['plateNumber']}',
      if (r['location'] != null) '${r['location']}',
      if (facilities.isNotEmpty) facilities,
    ].join(' · ');

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(type == 'van' ? Icons.directions_car_rounded : Icons.meeting_room_rounded,
                  size: 20, color: active ? ArdentColors.navy600 : ArdentColors.fg3),
              const SizedBox(width: ArdentSpacing.s2),
              Expanded(
                child: Text('${r['name'] ?? 'Resource'}',
                    style: text.titleMedium?.copyWith(
                      fontSize: 15,
                      color: active ? ArdentColors.fg1 : ArdentColors.fg3,
                    )),
              ),
              if (!active)
                const DsChip(
                    label: 'Out of service',
                    fg: ArdentColors.fg2,
                    bg: ArdentColors.bgSubtle),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(meta, style: text.bodySmall),
            ),
          ],
          const SizedBox(height: ArdentSpacing.s2),
          Row(
            children: [
              TextButton(
                onPressed: () => _openResourceForm(type, existing: r),
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: () => _toggleService(r),
                style: TextButton.styleFrom(foregroundColor: ArdentColors.fg2),
                child: Text(active ? 'Take out of service' : 'Return to service'),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _delete(r),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: ArdentColors.fg3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bookingRow(Map<String, dynamic> b) {
    final text = Theme.of(context).textTheme;
    final status = '${b['status'] ?? ''}';
    final cancelled = status == 'cancelled';
    final start = DateTime.tryParse('${b['startsAt']}')?.toLocal();
    final end = DateTime.tryParse('${b['endsAt']}')?.toLocal();
    final when = start == null
        ? relativeTime(b['startsAt'])
        : '${_shortDate(start)} · ${_clock(start)}'
            '${end != null ? '–${_clock(end)}' : ''}';
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
                  fg: cancelled ? ArdentColors.fg2 : ArdentColors.statusResolved,
                  bg: cancelled
                      ? ArdentColors.bgSubtle
                      : ArdentColors.statusResolvedBg,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              when,
              if (b['resourceName'] != null) '${b['resourceName']}',
              if (b['bookedByName'] != null) 'by ${b['bookedByName']}',
            ].where((s) => s.isNotEmpty).join(' · '),
            style: text.bodySmall,
          ),
          if (!cancelled) ...[
            const SizedBox(height: ArdentSpacing.s1),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _cancelBooking(b),
                style: TextButton.styleFrom(foregroundColor: ArdentColors.accent),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _logChip(String label, String value) {
    final active = _logFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _logFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? ArdentColors.accent : ArdentColors.bgSurface,
          borderRadius: BorderRadius.circular(ArdentRadii.pill),
          border: Border.all(
              color: active ? ArdentColors.accent : ArdentColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: active ? Colors.white : ArdentColors.fg2)),
      ),
    );
  }

  static String _clock(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  static String _shortDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}/${d.year}';
}

// ---------------------------------------------------------------------------
// Add / edit resource form
// ---------------------------------------------------------------------------

class _ResourceForm extends StatefulWidget {
  const _ResourceForm({required this.type, this.existing});
  final String type; // 'van' | 'room'
  final Map<String, dynamic>? existing;

  @override
  State<_ResourceForm> createState() => _ResourceFormState();
}

class _ResourceFormState extends State<_ResourceForm> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _capacity;
  late final TextEditingController _location;
  late final TextEditingController _plate; // van
  late final TextEditingController _facilities; // room
  late final TextEditingController _notes;
  bool _submitting = false;

  bool get _isVan => widget.type == 'van';
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? const {};
    _name = TextEditingController(text: '${e['name'] ?? ''}');
    _code = TextEditingController(text: '${e['code'] ?? ''}');
    _capacity = TextEditingController(
        text: e['capacity'] == null ? '' : '${e['capacity']}');
    _location = TextEditingController(text: '${e['location'] ?? ''}');
    _plate = TextEditingController(text: '${e['plateNumber'] ?? ''}');
    _facilities = TextEditingController(
        text: asList(e['facilities']).map((x) => '$x').join(', '));
    _notes = TextEditingController(text: '${e['description'] ?? ''}');
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _capacity.dispose();
    _location.dispose();
    _plate.dispose();
    _facilities.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_name.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Name is required.')));
      return;
    }
    final fields = <String, dynamic>{
      'type': widget.type,
      'name': _name.text.trim(),
      'code': _code.text.trim(),
      'capacity': _capacity.text.trim(), // blank = unlimited
      'location': _location.text.trim(),
      'description': _notes.text.trim(),
      if (_isVan) 'plateNumber': _plate.text.trim(),
      if (!_isVan) 'facilities': _facilities.text.trim(),
    };
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    try {
      if (_isEdit) {
        await Api.instance.bookingAdmin
            .updateResource('${widget.existing!['id']}', fields: fields);
      } else {
        await Api.instance.bookingAdmin.createResource(fields: fields);
      }
      navigator.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final title = '${_isEdit ? 'Edit' : 'Add'} ${_isVan ? 'van' : 'room'}';
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(ArdentSpacing.s5),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: ArdentSpacing.s3),

            const _FieldLabel('Name'),
            const SizedBox(height: ArdentSpacing.s2),
            TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'e.g. Van 2 — Hiace'),
            ),
            const SizedBox(height: ArdentSpacing.s3),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Short code'),
                      const SizedBox(height: ArdentSpacing.s2),
                      TextField(
                        controller: _code,
                        decoration: const InputDecoration(hintText: 'V2'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ArdentSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(_isVan
                          ? 'Passenger seats (excluding the driver)'
                          : 'Seats'),
                      const SizedBox(height: ArdentSpacing.s2),
                      TextField(
                        controller: _capacity,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(hintText: 'Blank = unlimited'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ArdentSpacing.s3),

            const _FieldLabel('Where is it?'),
            const SizedBox(height: ArdentSpacing.s2),
            TextField(
              controller: _location,
              decoration:
                  InputDecoration(hintText: _isVan ? 'HQ garage' : '3F, HQ'),
            ),
            const SizedBox(height: ArdentSpacing.s3),

            if (_isVan) ...[
              const _FieldLabel('Plate number'),
              const SizedBox(height: ArdentSpacing.s2),
              TextField(
                controller: _plate,
                decoration: const InputDecoration(hintText: 'ABC 1234'),
              ),
            ] else ...[
              const _FieldLabel('Facilities'),
              const SizedBox(height: ArdentSpacing.s2),
              TextField(
                controller: _facilities,
                decoration: const InputDecoration(
                    hintText: 'Projector, Whiteboard, Video conferencing'),
              ),
            ],
            const SizedBox(height: ArdentSpacing.s3),

            const _FieldLabel('Notes (optional)'),
            const SizedBox(height: ArdentSpacing.s2),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: ArdentSpacing.s5),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: ArdentSpacing.s2),
                FilledButton(
                  onPressed: _submitting ? null : _save,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: ArdentSpacing.s4),
          ],
        ),
      ),
    );
  }
}

/// Bold field label matching the web forms.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: ArdentColors.fg1));
  }
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}
