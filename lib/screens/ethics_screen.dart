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

class _FileReportScreenState extends State<_FileReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _category = 'other';
  bool _anonymous = false;
  bool _submitting = false;
  late Future<List<String>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = _loadCategories();
  }

  Future<List<String>> _loadCategories() async {
    try {
      final raw = await Api.instance.ethics.categories();
      return raw.map((e) => e.toString()).toList();
    } on ApiException {
      return const ['other'];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await Api.instance.ethics.fileComplaint({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category': _category,
        'isAnonymous': _anonymous,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('File a report'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(ArdentSpacing.s4),
          children: [
            const Overline('Title'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(hintText: 'Short summary'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'A title is required' : null,
            ),
            const SizedBox(height: ArdentSpacing.s4),
            const Overline('Category'),
            const SizedBox(height: 6),
            FutureBuilder<List<String>>(
              future: _categories,
              builder: (context, snapshot) {
                final cats = snapshot.data ?? const ['other'];
                if (!cats.contains(_category) && cats.isNotEmpty) _category = cats.first;
                return DropdownButtonFormField<String>(
                  initialValue: cats.contains(_category) ? _category : null,
                  items: [
                    for (final c in cats)
                      DropdownMenuItem(
                          value: c, child: Text(c.replaceAll('_', ' '))),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'other'),
                );
              },
            ),
            const SizedBox(height: ArdentSpacing.s4),
            const Overline('Description'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _description,
              maxLines: 6,
              decoration: const InputDecoration(
                  hintText: 'Describe what happened, when, and where.'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please describe the concern' : null,
            ),
            const SizedBox(height: ArdentSpacing.s4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: ArdentColors.accent,
              title: const Text('File anonymously',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Your identity is hidden from reviewers.'),
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
            ),
          ],
        ),
      ),
    );
  }
}
