import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Create or edit an event — backed by `POST /events` / `PATCH /events/:id`.
/// Pass [initial] to edit an existing event. Returns `true` on success so the
/// caller can refresh.
class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key, this.initial});

  final EventItem? initial;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _description = TextEditingController(text: widget.initial?.desc ?? '');
  late final _location = TextEditingController(text: widget.initial?.location ?? '');
  late DateTime? _start = widget.initial?.startAt;
  late DateTime? _end = widget.initial?.endAt;
  late bool _featured = widget.initial?.featured ?? false;
  bool _submitting = false;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_start ?? now) : (_end ?? _start ?? now);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 9,
      time?.minute ?? 0,
    );
    setState(() {
      if (isStart) {
        _start = picked;
        // Keep end at/after start.
        if (_end != null && _end!.isBefore(picked)) _end = null;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_start == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick a start date & time')));
      return;
    }
    if (_end != null && _end!.isBefore(_start!)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('End must be after the start')));
      return;
    }
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final fields = {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'location': _location.text.trim(),
      'startsAt': _start!.toUtc().toIso8601String(),
      if (_end != null) 'endsAt': _end!.toUtc().toIso8601String(),
      'featured': _featured,
    };
    try {
      if (_isEdit) {
        await Api.instance.events.update(widget.initial!.id, fields: fields);
      } else {
        await Api.instance.events.create(fields: fields);
      }
      navigator.pop(true);
      messenger.showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Event updated' : 'Event created')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(
          content: Text(e.isForbidden
              ? "You don't have permission to ${_isEdit ? 'edit' : 'create'} events."
              : e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit event' : 'Create event'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_isEdit ? 'Save' : 'Create'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(ArdentSpacing.s4),
          children: [
            _label('Title'),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. All-Hands Town Hall'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'A title is required' : null,
            ),
            const SizedBox(height: ArdentSpacing.s4),
            _label('Description'),
            TextFormField(
              controller: _description,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What is this event about?'),
            ),
            const SizedBox(height: ArdentSpacing.s4),
            _label('Location'),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(hintText: 'e.g. Main Auditorium + Zoom'),
            ),
            const SizedBox(height: ArdentSpacing.s4),
            _label('Starts'),
            _dateTile(_start, () => _pickDateTime(isStart: true), 'Pick start date & time'),
            const SizedBox(height: ArdentSpacing.s3),
            _label('Ends (optional)'),
            _dateTile(_end, () => _pickDateTime(isStart: false), 'Pick end date & time'),
            const SizedBox(height: ArdentSpacing.s4),
            _featureTile(),
            const SizedBox(height: ArdentSpacing.s6),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(_isEdit ? 'Save changes' : 'Create event'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Overline(text),
      );

  /// "Feature this event" — mirrors the web toggle. Note: the backend forces
  /// this to false unless the caller has the admin.users module.
  Widget _featureTile() {
    return InkWell(
      onTap: () => setState(() => _featured = !_featured),
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      child: Container(
        padding: const EdgeInsets.all(ArdentSpacing.s3),
        decoration: BoxDecoration(
          color: _featured ? ArdentColors.accentSoft : ArdentColors.bgSubtle,
          borderRadius: BorderRadius.circular(ArdentRadii.md),
          border: Border.all(
              color: _featured ? ArdentColors.red100 : ArdentColors.border),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _featured,
              onChanged: (v) => setState(() => _featured = v ?? false),
              activeColor: ArdentColors.accent,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: ArdentSpacing.s2),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Feature this event',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: ArdentColors.fg1)),
                  SizedBox(height: 2),
                  Text('Pin it to the top of the Events page as the highlight.',
                      style: TextStyle(fontSize: 12, color: ArdentColors.fg3)),
                ],
              ),
            ),
            const SizedBox(width: ArdentSpacing.s2),
            Icon(Icons.local_offer_rounded,
                size: 18,
                color: _featured ? ArdentColors.accent : ArdentColors.fg3),
          ],
        ),
      ),
    );
  }

  Widget _dateTile(DateTime? value, VoidCallback onTap, String hint) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: ArdentColors.bgSubtle,
          borderRadius: BorderRadius.circular(ArdentRadii.md),
          border: Border.all(color: ArdentColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_rounded, size: 18, color: ArdentColors.fg3),
            const SizedBox(width: ArdentSpacing.s3),
            Expanded(
              child: Text(
                value == null ? hint : _format(value),
                style: text.bodyLarge?.copyWith(
                    color: value == null ? ArdentColors.fg3 : ArdentColors.fg1),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: ArdentColors.fg3),
          ],
        ),
      ),
    );
  }

  String _format(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$m $ap';
  }
}
