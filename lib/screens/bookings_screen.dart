import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

/// Bookings — vans & rooms self-service: a day schedule of resources plus the
/// caller's own bookings (`GET /bookings/availability`, `GET /bookings/mine`),
/// and a booking sheet (`POST /bookings`). Requires `module:bookings.view`;
/// booking additionally needs `module:bookings.book`.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  static const int _startHour = 6;
  static const int _endHour = 20;

  String _type = 'van'; // 'van' | 'room'
  DateTime _day = _dateOnly(DateTime.now());
  int _reloadTick = 0;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isToday => _day == _dateOnly(DateTime.now());

  Future<Map<String, dynamic>> _loadAvailability() {
    final from = DateTime(_day.year, _day.month, _day.day, 0, 0);
    final to = DateTime(_day.year, _day.month, _day.day, 23, 59, 59);
    return Api.instance.bookings.availability(
      type: _type,
      from: from.toIso8601String(),
      to: to.toIso8601String(),
    );
  }

  void _reload() => setState(() => _reloadTick++);

  Future<void> _shiftDay(int days) async {
    setState(() => _day = _dateOnly(_day.add(Duration(days: days))));
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _day = _dateOnly(picked));
  }

  Future<void> _openBookSheet({
    Map<String, dynamic>? resource,
    DateTime? startsAt,
  }) async {
    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ArdentColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ArdentRadii.xl)),
      ),
      builder: (_) => _BookSheet(
        type: _type,
        day: _day,
        initialResourceId: resource == null ? null : '${resource['id']}',
        initialStart: startsAt,
      ),
    );
    if (booked == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vans & rooms'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ArdentSpacing.s3),
            child: FilledButton.icon(
              onPressed: () => _openBookSheet(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Book'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ArdentSpacing.s4),
        children: [
          Text(
            'A van or room is held for your whole booking — nobody else can take '
            'an overlapping slot.',
            style: text.bodyMedium?.copyWith(color: ArdentColors.fg3),
          ),
          const SizedBox(height: ArdentSpacing.s4),

          // Type toggle + date navigator.
          Row(
            children: [
              _typeChip('Vans', 'van', Icons.directions_car_rounded),
              const SizedBox(width: ArdentSpacing.s2),
              _typeChip('Rooms', 'room', Icons.meeting_room_rounded),
              const Spacer(),
              _roundIcon(Icons.chevron_left_rounded, () => _shiftDay(-1)),
              const SizedBox(width: 4),
              _roundIcon(Icons.chevron_right_rounded, () => _shiftDay(1)),
            ],
          ),
          const SizedBox(height: ArdentSpacing.s3),
          _DateButton(day: _day, isToday: _isToday, onTap: _pickDay),
          const SizedBox(height: ArdentSpacing.s4),

          // Day schedule.
          SurfaceCard(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            child: AsyncView<Map<String, dynamic>>(
              key: ValueKey('avail-$_type-$_day-$_reloadTick'),
              loader: _loadAvailability,
              builder: (context, data, reload) => _daySchedule(context, data),
            ),
          ),
          const SizedBox(height: ArdentSpacing.s5),

          // My bookings.
          const Overline('My bookings'),
          const SizedBox(height: ArdentSpacing.s2),
          AsyncView<List<dynamic>>(
            key: ValueKey('mine-$_reloadTick'),
            loader: () => Api.instance.bookings.mine(scope: 'upcoming'),
            builder: (context, items, reload) {
              if (items.isEmpty) {
                return Text('Nothing booked.',
                    style: text.bodyMedium?.copyWith(color: ArdentColors.fg3));
              }
              return Column(
                children: [
                  for (final raw in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: ArdentSpacing.s2),
                      child: _myBookingCard(context, asMap(raw)),
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

  Widget _daySchedule(BuildContext context, Map<String, dynamic> data) {
    final text = Theme.of(context).textTheme;
    final resources = asList(data['resources']);
    // Bookings may live top-level or nested per resource; support both.
    final topBookings = asList(data['bookings']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(_longDate(_day),
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (_isToday) ...[
              const SizedBox(width: ArdentSpacing.s2),
              const DsChip(
                  label: 'Today',
                  fg: ArdentColors.accent,
                  bg: ArdentColors.statusUrgentBg),
            ],
          ],
        ),
        const SizedBox(height: ArdentSpacing.s3),
        if (resources.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: ArdentSpacing.s4),
            child: Text('No ${_type == 'van' ? 'vans' : 'rooms'} available.',
                style: text.bodyMedium?.copyWith(color: ArdentColors.fg3)),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hourHeader(),
                for (final raw in resources)
                  _resourceRow(asMap(raw), topBookings),
              ],
            ),
          ),
        const SizedBox(height: ArdentSpacing.s2),
        Text('Tap an empty stretch to book that hour.',
            style: text.bodySmall?.copyWith(color: ArdentColors.fg3)),
      ],
    );
  }

  static const double _labelW = 132;
  static const double _cellW = 34;

  Widget _hourHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const SizedBox(width: _labelW),
          for (int h = _startHour; h <= _endHour; h++)
            SizedBox(
              width: _cellW,
              child: Text('$h',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, color: ArdentColors.fg3)),
            ),
        ],
      ),
    );
  }

  Widget _resourceRow(Map<String, dynamic> r, List<dynamic> topBookings) {
    final text = Theme.of(context).textTheme;
    final id = '${r['id']}';
    // Collect this resource's bookings from either source.
    final nested = asList(r['bookings']);
    final own = <Map<String, dynamic>>[
      for (final b in nested) asMap(b),
      for (final b in topBookings)
        if (_bookingResourceId(asMap(b)) == id) asMap(b),
    ];

    final capacity = r['capacity'];
    final meta = [
      if (r['capacity'] != null) '$capacity pax',
      if (r['code'] != null) '${r['code']}',
      if (r['plateNumber'] != null) '${r['plateNumber']}',
      if (r['location'] != null) '${r['location']}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _labelW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['name'] ?? 'Resource'}',
                    style: text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (meta.isNotEmpty)
                  Text(meta,
                      style: text.bodySmall?.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          for (int h = _startHour; h < _endHour; h++)
            _hourCell(r, own, h),
        ],
      ),
    );
  }

  Widget _hourCell(Map<String, dynamic> r, List<Map<String, dynamic>> bookings, int hour) {
    final slotStart = DateTime(_day.year, _day.month, _day.day, hour);
    final slotEnd = slotStart.add(const Duration(hours: 1));
    final busy = bookings.any((b) {
      final s = _parse(b['startsAt']);
      final e = _parse(b['endsAt']);
      if (s == null || e == null) return false;
      final cancelled = '${b['status'] ?? ''}' == 'cancelled';
      if (cancelled) return false;
      return s.isBefore(slotEnd) && e.isAfter(slotStart);
    });
    return GestureDetector(
      onTap: busy ? null : () => _openBookSheet(resource: r, startsAt: slotStart),
      child: Container(
        width: _cellW,
        height: 30,
        margin: const EdgeInsets.only(right: 1),
        decoration: BoxDecoration(
          color: busy ? ArdentColors.accent : ArdentColors.bgSubtle,
          borderRadius: BorderRadius.circular(ArdentRadii.xs),
        ),
      ),
    );
  }

  Widget _myBookingCard(BuildContext context, Map<String, dynamic> b) {
    final text = Theme.of(context).textTheme;
    final status = '${b['status'] ?? ''}';
    final start = _parse(b['startsAt']);
    final end = _parse(b['endsAt']);
    final when = start == null
        ? relativeTime(b['startsAt'])
        : '${_longDate(_dateOnly(start))} · ${_clock(start)}'
            '${end != null ? '–${_clock(end)}' : ''}';
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    '${b['reference'] ?? b['purpose'] ?? 'Booking'}',
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
          if (b['purpose'] != null && b['reference'] != null)
            Text('${b['purpose']}', style: text.bodyMedium),
          Text(
            [
              when,
              if (b['resourceName'] != null) '${b['resourceName']}',
              if (b['destination'] != null) '${b['destination']}',
            ].where((s) => s.isNotEmpty).join(' · '),
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String label, String value, IconData icon) {
    final active = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? ArdentColors.accent : ArdentColors.bgSurface,
          borderRadius: BorderRadius.circular(ArdentRadii.pill),
          border: Border.all(
              color: active ? ArdentColors.accent : ArdentColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : ArdentColors.fg2),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: active ? Colors.white : ArdentColors.fg2)),
          ],
        ),
      ),
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: ArdentColors.bgSurface,
          shape: BoxShape.circle,
          border: Border.all(color: ArdentColors.border),
        ),
        child: Icon(icon, size: 20, color: ArdentColors.fg2),
      ),
    );
  }

  static String _bookingResourceId(Map<String, dynamic> b) =>
      '${b['resourceId'] ?? b['resource_id'] ?? b['resource'] ?? ''}';

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toLocal();
    return DateTime.tryParse('$v')?.toLocal();
  }

  static String _clock(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  static String _longDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
}

/// The date pill under the toggle row (mm/dd/yyyy, tap to pick).
class _DateButton extends StatelessWidget {
  const _DateButton(
      {required this.day, required this.isToday, required this.onTap});
  final DateTime day;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${day.month.toString().padLeft(2, '0')}/'
        '${day.day.toString().padLeft(2, '0')}/${day.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ArdentColors.bgSurface,
          borderRadius: BorderRadius.circular(ArdentRadii.md),
          border: Border.all(color: ArdentColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: ArdentColors.fg3),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: ArdentColors.fg1)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Book sheet
// ---------------------------------------------------------------------------

class _Occupant {
  _Occupant({this.userId, required this.name});
  final String? userId;
  final String name;
}

class _BookSheet extends StatefulWidget {
  const _BookSheet({
    required this.type,
    required this.day,
    this.initialResourceId,
    this.initialStart,
  });

  final String type;
  final DateTime day;
  final String? initialResourceId;
  final DateTime? initialStart;

  @override
  State<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<_BookSheet> {
  final _purpose = TextEditingController();
  final _notes = TextEditingController();
  final _guest = TextEditingController();
  final _colleague = TextEditingController();

  late Future<List<dynamic>> _resources;
  String? _resourceId;
  bool _allDay = false;
  late DateTime _from;
  late DateTime _to;
  final List<_Occupant> _occupants = [];
  bool _submitting = false;

  List<dynamic> _searchResults = const [];
  bool _searching = false;

  bool get _isVan => widget.type == 'van';

  @override
  void initState() {
    super.initState();
    _resourceId = widget.initialResourceId;
    final start = widget.initialStart ??
        DateTime(widget.day.year, widget.day.month, widget.day.day, 9);
    _from = start;
    _to = start.add(const Duration(hours: 1));
    _resources = Api.instance.bookings.resources(type: widget.type);
    _loadSelf();
  }

  Future<void> _loadSelf() async {
    try {
      final me = await Api.instance.auth.me();
      final name = '${me['name'] ?? me['fullName'] ?? 'Me'}';
      final id = me['id'] == null ? null : '${me['id']}';
      if (mounted) {
        setState(() => _occupants.add(_Occupant(userId: id, name: name)));
      }
    } catch (_) {
      // Booker is added server-side anyway; ignore.
    }
  }

  @override
  void dispose() {
    _purpose.dispose();
    _notes.dispose();
    _guest.dispose();
    _colleague.dispose();
    super.dispose();
  }

  Future<void> _searchColleagues(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await Api.instance.users.list(search: q.trim());
      if (mounted) setState(() => _searchResults = res);
    } catch (_) {
      if (mounted) setState(() => _searchResults = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addColleague(Map<String, dynamic> u) {
    final id = '${u['id']}';
    if (_occupants.any((o) => o.userId == id)) return;
    setState(() {
      _occupants.add(_Occupant(userId: id, name: '${u['name'] ?? 'Colleague'}'));
      _colleague.clear();
      _searchResults = const [];
    });
  }

  void _addGuest() {
    final name = _guest.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _occupants.add(_Occupant(name: name));
      _guest.clear();
    });
  }

  Future<void> _pickDateTime({required bool isFrom}) async {
    final base = isFrom ? _from : _to;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isFrom) {
        _from = picked;
        if (!_to.isAfter(_from)) _to = _from.add(const Duration(hours: 1));
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_resourceId == null) {
      messenger.showSnackBar(
          SnackBar(content: Text('Pick a ${_isVan ? 'van' : 'room'} first.')));
      return;
    }
    if (_purpose.text.trim().isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Say what it\'s for.')));
      return;
    }
    final DateTime startsAt;
    final DateTime endsAt;
    if (_allDay) {
      startsAt = DateTime(_from.year, _from.month, _from.day, 0, 0);
      endsAt = DateTime(_from.year, _from.month, _from.day, 23, 59);
    } else {
      startsAt = _from;
      endsAt = _to;
      if (!endsAt.isAfter(startsAt)) {
        messenger.showSnackBar(
            const SnackBar(content: Text('End time must be after the start.')));
        return;
      }
    }
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    try {
      await Api.instance.bookings.create({
        'resourceId': _resourceId,
        'purpose': _purpose.text.trim(),
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        if (_occupants.isNotEmpty)
          'occupants': [
            for (final o in _occupants)
              {if (o.userId != null) 'userId': o.userId, 'name': o.name},
          ],
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
      navigator.pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('Booked')));
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
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(ArdentSpacing.s5),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Book a ${_isVan ? 'van' : 'room'}',
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

            // Which one?
            _FieldLabel(_isVan ? 'Which one?' : 'Which room?'),
            const SizedBox(height: ArdentSpacing.s2),
            FutureBuilder<List<dynamic>>(
              future: _resources,
              builder: (context, snapshot) {
                final res = snapshot.data ?? const [];
                if (res.isEmpty) {
                  return Text('No ${_isVan ? 'vans' : 'rooms'} available.',
                      style: text.bodyMedium
                          ?.copyWith(color: ArdentColors.fg3));
                }
                return Wrap(
                  spacing: ArdentSpacing.s2,
                  runSpacing: ArdentSpacing.s2,
                  children: [
                    for (final raw in res)
                      _resourceChoice(asMap(raw)),
                  ],
                );
              },
            ),
            const SizedBox(height: ArdentSpacing.s4),

            // What's it for?
            const _FieldLabel("What's it for?"),
            const SizedBox(height: ArdentSpacing.s2),
            TextField(
              controller: _purpose,
              decoration: const InputDecoration(
                  hintText: 'e.g. Client visit — Acme'),
            ),
            const SizedBox(height: ArdentSpacing.s4),

            // All day
            InkWell(
              onTap: () => setState(() => _allDay = !_allDay),
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _allDay,
                      activeColor: ArdentColors.accent,
                      onChanged: (v) => setState(() => _allDay = v ?? false),
                    ),
                  ),
                  const SizedBox(width: ArdentSpacing.s2),
                  const Text('All day',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: ArdentSpacing.s3),

            // From / To
            _FieldLabel('From'),
            const SizedBox(height: ArdentSpacing.s2),
            _dateTimeField(_from, () => _pickDateTime(isFrom: true)),
            if (!_allDay) ...[
              const SizedBox(height: ArdentSpacing.s3),
              const _FieldLabel('To'),
              const SizedBox(height: ArdentSpacing.s2),
              _dateTimeField(_to, () => _pickDateTime(isFrom: false)),
            ],
            const SizedBox(height: ArdentSpacing.s4),

            // Passengers / occupants
            _FieldLabel(_isVan ? 'Passengers' : 'Attendees'),
            const SizedBox(height: ArdentSpacing.s2),
            for (final o in _occupants) _occupantRow(o),
            const SizedBox(height: ArdentSpacing.s2),
            TextField(
              controller: _colleague,
              onChanged: _searchColleagues,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: 'Add a colleague…',
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: ArdentColors.border),
                  borderRadius: BorderRadius.circular(ArdentRadii.md),
                ),
                child: Column(
                  children: [
                    for (final raw in _searchResults.take(6))
                      _searchResultRow(asMap(raw)),
                  ],
                ),
              ),
            const SizedBox(height: ArdentSpacing.s2),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _guest,
                    onSubmitted: (_) => _addGuest(),
                    decoration: const InputDecoration(
                        hintText: "…or a guest's name"),
                  ),
                ),
                const SizedBox(width: ArdentSpacing.s2),
                OutlinedButton(onPressed: _addGuest, child: const Text('Add')),
              ],
            ),
            const SizedBox(height: ArdentSpacing.s4),

            // Notes
            const _FieldLabel('Notes (optional)'),
            const SizedBox(height: ArdentSpacing.s2),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: ArdentSpacing.s5),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: ArdentSpacing.s2),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Book it'),
                ),
              ],
            ),
            const SizedBox(height: ArdentSpacing.s4),
          ],
        ),
      ),
    );
  }

  Widget _resourceChoice(Map<String, dynamic> r) {
    final id = '${r['id']}';
    final selected = _resourceId == id;
    final capacity = r['capacity'];
    final label =
        '${r['name'] ?? 'Resource'}${capacity != null ? ' · $capacity' : ''}';
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : ArdentColors.fg1,
      ),
      selectedColor: ArdentColors.accent,
      backgroundColor: ArdentColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ArdentRadii.pill),
        side: BorderSide(
            color: selected ? ArdentColors.accent : ArdentColors.border),
      ),
      onSelected: (_) => setState(() => _resourceId = id),
    );
  }

  Widget _dateTimeField(DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Text(_fmtDateTime(value),
                  style: const TextStyle(color: ArdentColors.fg1)),
            ),
            const Icon(Icons.event_rounded, size: 18, color: ArdentColors.fg3),
          ],
        ),
      ),
    );
  }

  Widget _occupantRow(_Occupant o) {
    final isSelf = _occupants.first == o;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded,
              size: 18, color: ArdentColors.fg3),
          const SizedBox(width: ArdentSpacing.s2),
          Expanded(child: Text(o.name)),
          if (!isSelf)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _occupants.remove(o)),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _searchResultRow(Map<String, dynamic> u) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.person_outline_rounded, size: 20),
      title: Text('${u['name'] ?? 'Colleague'}'),
      subtitle: u['role'] != null || u['department'] != null
          ? Text([
              if (u['role'] != null) '${u['role']}',
              if (u['department'] != null) '${u['department']}',
            ].join(' · '))
          : null,
      onTap: () => _addColleague(u),
    );
  }

  static String _fmtDateTime(DateTime d) {
    final date = '${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}/${d.year}';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$date  $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// Bold field label matching the web forms (`font-weight:600`).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: ArdentColors.fg1));
  }
}
