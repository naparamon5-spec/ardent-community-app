import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

/// Ethics (reporter side) — the caller's complaints (`GET /ethics/mine`) and
/// filing a new one (`POST /ethics/complaints`). Requires `module:ethics.report`.
class EthicsScreen extends StatefulWidget {
  const EthicsScreen({super.key});

  @override
  State<EthicsScreen> createState() => _EthicsScreenState();
}

class _EthicsScreenState extends State<EthicsScreen> {
  int _reloadTick = 0;

  Future<List<dynamic>> _load() => Api.instance.ethics.mine();

  Future<void> _fileReport() async {
    final filed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _FileReportScreen()),
    );
    if (filed == true && mounted) setState(() => _reloadTick++);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ethics reports')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fileReport,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Report a concern'),
      ),
      body: AsyncView<List<dynamic>>(
        key: ValueKey(_reloadTick),
        loader: _load,
        builder: (context, items, reload) {
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: ArdentSpacing.s3),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: ArdentSpacing.s2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Raise a concern with HR — harassment, discrimination, fraud, "
                          "safety, or anything else that shouldn't be happening. You can "
                          "file anonymously.",
                          style: text.bodyMedium?.copyWith(color: ArdentColors.fg3),
                        ),
                        const SizedBox(height: ArdentSpacing.s3),
                        Container(
                          padding: const EdgeInsets.all(ArdentSpacing.s3),
                          decoration: BoxDecoration(
                            color: ArdentColors.bgSubtle,
                            borderRadius: BorderRadius.circular(ArdentRadii.md),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lock_outline_rounded,
                                  size: 18, color: ArdentColors.fg2),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Reports go only to the HR reviewers. Anyone named in a '
                                  'report can never see it — including an HR reviewer who '
                                  'is the subject of one.',
                                  style: text.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (items.isEmpty) ...[
                          const SizedBox(height: ArdentSpacing.s8),
                          Center(
                            child: Text("You haven't filed any reports.",
                                style:
                                    text.bodyLarge?.copyWith(color: ArdentColors.fg3)),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                final i = index - 1;
                final c = asMap(items[i]);
                final status = '${c['status'] ?? ''}'.replaceAll('_', ' ');
                return SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${c['title'] ?? 'Complaint'}',
                                style: text.titleMedium?.copyWith(fontSize: 15)),
                          ),
                          if (status.isNotEmpty)
                            DsChip(
                                label: status,
                                fg: ArdentColors.navy600,
                                bg: ArdentColors.statusOpenBg),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (c['caseCode'] != null) '${c['caseCode']}',
                          if (c['category'] != null) '${c['category']}',
                          relativeTime(c['createdAt']),
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FileReportScreen extends StatefulWidget {
  const _FileReportScreen();

  @override
  State<_FileReportScreen> createState() => _FileReportScreenState();
}

/// A complaint category with its stable [key] and human-readable [label].
class _Category {
  const _Category(this.key, this.label);
  final String key;
  final String label;
}

class _FileReportScreenState extends State<_FileReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _subjectFreeText = TextEditingController();
  String _category = 'other';
  DateTime? _incidentDate;
  bool _anonymous = false;
  bool _submitting = false;
  late Future<List<_Category>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = _loadCategories();
  }

  Future<List<_Category>> _loadCategories() async {
    try {
      final raw = await Api.instance.ethics.categories();
      final cats = <_Category>[];
      for (final e in raw) {
        if (e is Map) {
          final key = '${e['key'] ?? e['value'] ?? e['id'] ?? ''}'.trim();
          final label =
              '${e['label'] ?? e['name'] ?? key}'.replaceAll('_', ' ').trim();
          if (key.isNotEmpty) cats.add(_Category(key, label));
        } else {
          final key = '$e'.trim();
          if (key.isNotEmpty) cats.add(_Category(key, key.replaceAll('_', ' ')));
        }
      }
      return cats.isEmpty ? const [_Category('other', 'Something else')] : cats;
    } on ApiException {
      return const [_Category('other', 'Something else')];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _subjectFreeText.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _incidentDate = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final subject = _subjectFreeText.text.trim();
    final location = _location.text.trim();
    try {
      await Api.instance.ethics.fileComplaint({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category': _category,
        'isAnonymous': _anonymous,
        if (_incidentDate != null)
          'incidentDate': _incidentDate!.toIso8601String(),
        if (location.isNotEmpty) 'location': location,
        if (subject.isNotEmpty) 'subjectFreeText': subject,
      });
      navigator.pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('Report filed')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Report a concern')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(ArdentSpacing.s4),
          children: [
            Text('Report a concern',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text("This goes to HR's ethics reviewers and nobody else.",
                style: text.bodyMedium?.copyWith(color: ArdentColors.fg3)),
            const SizedBox(height: ArdentSpacing.s5),

            // ---- What kind of concern is this? ----
            const _FieldLabel('What kind of concern is this?'),
            const SizedBox(height: ArdentSpacing.s2),
            FutureBuilder<List<_Category>>(
              future: _categories,
              builder: (context, snapshot) {
                final cats =
                    snapshot.data ?? const [_Category('other', 'Something else')];
                if (!cats.any((c) => c.key == _category) && cats.isNotEmpty) {
                  _category = cats.first.key;
                }
                return Wrap(
                  spacing: ArdentSpacing.s2,
                  runSpacing: ArdentSpacing.s2,
                  children: [
                    for (final c in cats)
                      ChoiceChip(
                        label: Text(c.label),
                        selected: _category == c.key,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _category == c.key
                              ? Colors.white
                              : ArdentColors.fg1,
                        ),
                        selectedColor: ArdentColors.accent,
                        backgroundColor: ArdentColors.bgSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ArdentRadii.pill),
                          side: BorderSide(
                            color: _category == c.key
                                ? ArdentColors.accent
                                : ArdentColors.border,
                          ),
                        ),
                        onSelected: (_) => setState(() => _category = c.key),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: ArdentSpacing.s5),

            // ---- Short title ----
            const _FieldLabel('Short title'),
            const SizedBox(height: ArdentSpacing.s2),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  hintText: 'e.g. Repeated inappropriate remarks in team meetings'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'A title is required' : null,
            ),
            const SizedBox(height: ArdentSpacing.s5),

            // ---- What happened? ----
            const _FieldLabel('What happened?'),
            const SizedBox(height: ArdentSpacing.s2),
            TextFormField(
              controller: _description,
              maxLines: 6,
              decoration: const InputDecoration(
                  hintText: 'What happened, when, and who was involved. '
                      'Include anything that would help HR look into it.'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please describe the concern'
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              "If you're filing anonymously, take care not to identify yourself "
              'here — "as her only direct report, I saw…" names you as surely as '
              'a signature would.',
              style: text.bodySmall?.copyWith(color: ArdentColors.fg3),
            ),
            const SizedBox(height: ArdentSpacing.s5),

            // ---- When / Where ----
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('When did it happen?'),
                      const SizedBox(height: ArdentSpacing.s2),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(ArdentRadii.md),
                        child: InputDecorator(
                          decoration: const InputDecoration(),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _incidentDate == null
                                      ? 'mm/dd/yyyy'
                                      : _formatDate(_incidentDate!),
                                  style: text.bodyMedium?.copyWith(
                                    color: _incidentDate == null
                                        ? ArdentColors.fg3
                                        : ArdentColors.fg1,
                                  ),
                                ),
                              ),
                              const Icon(Icons.calendar_today_rounded,
                                  size: 18, color: ArdentColors.fg3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ArdentSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Where?'),
                      const SizedBox(height: ArdentSpacing.s2),
                      TextFormField(
                        controller: _location,
                        decoration: const InputDecoration(
                            hintText: 'e.g. Pasig office, 4th floor'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ArdentSpacing.s5),

            // ---- Who is this about? ----
            const _FieldLabel('Who is this about? (optional)'),
            const SizedBox(height: ArdentSpacing.s2),
            TextFormField(
              controller: _subjectFreeText,
              decoration: const InputDecoration(
                  hintText: 'Describe who, if they should be named.'),
            ),
            const SizedBox(height: ArdentSpacing.s5),

            // ---- File anonymously ----
            Container(
              padding: const EdgeInsets.all(ArdentSpacing.s3),
              decoration: BoxDecoration(
                color: ArdentColors.bgSubtle,
                borderRadius: BorderRadius.circular(ArdentRadii.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _anonymous,
                      activeColor: ArdentColors.accent,
                      onChanged: (v) => setState(() => _anonymous = v ?? false),
                    ),
                  ),
                  const SizedBox(width: ArdentSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('File this anonymously',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          _anonymous
                              ? 'Your identity is hidden from reviewers.'
                              : 'Your name will be visible to the HR reviewers '
                                  'handling this case. It is never shown to the '
                                  'person you\'re reporting.',
                          style: text.bodySmall?.copyWith(color: ArdentColors.fg3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ArdentSpacing.s5),

            // ---- Actions ----
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
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
                      : const Text('Submit report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}/${d.year}';
}

/// Bold field label matching the web form (`font-weight:600`).
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
