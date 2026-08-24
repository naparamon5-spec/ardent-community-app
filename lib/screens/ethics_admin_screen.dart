import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

/// Ethics review (HR/reviewer side) — cases raised by employees
/// (`GET /ethics-admin/cases`, `/ethics-admin/stats`). Requires
/// `module:ethics.manage`. Cases naming or filed by the reviewer are hidden
/// server-side.
class EthicsAdminScreen extends StatefulWidget {
  const EthicsAdminScreen({super.key});

  @override
  State<EthicsAdminScreen> createState() => _EthicsAdminScreenState();
}

class _EthicsAdminScreenState extends State<EthicsAdminScreen> {
  String? _status; // null = all
  late Future<Map<String, dynamic>> _stats;

  static const _filters = <(String, String)>[
    ('Submitted', 'submitted'),
    ('Being triaged', 'being_triaged'),
    ('Under investigation', 'under_investigation'),
    ('Waiting on you', 'awaiting_info'),
    ('Resolved', 'resolved'),
    ('Closed', 'closed'),
    ('Withdrawn', 'withdrawn'),
  ];

  @override
  void initState() {
    super.initState();
    _stats = _loadStats();
  }

  Future<Map<String, dynamic>> _loadStats() async {
    try {
      final data = await Api.instance.ethicsAdmin.stats();
      return asMap(data);
    } on ApiException {
      return {};
    }
  }

  Future<List<dynamic>> _loadCases() =>
      Api.instance.ethicsAdmin.cases(status: _status);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ethics review')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(ArdentSpacing.s4, ArdentSpacing.s3,
                ArdentSpacing.s4, ArdentSpacing.s2),
            child: Text('Complaints raised by employees. Handle these confidentially.',
                style: text.bodyMedium?.copyWith(color: ArdentColors.fg3)),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _stats,
            builder: (context, snapshot) {
              final s = snapshot.data ?? const {};
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
                child: Row(
                  children: [
                    _stat('${_pick(s, ['open', 'openCount']) ?? 0}', 'Open'),
                    const SizedBox(width: ArdentSpacing.s3),
                    _stat('${_pick(s, ['awaitingTriage', 'triage', 'awaiting']) ?? 0}',
                        'Awaiting triage'),
                    const SizedBox(width: ArdentSpacing.s3),
                    _stat('${_pick(s, ['total', 'all', 'allTime']) ?? 0}', 'All time'),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: ArdentSpacing.s3),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
              children: [
                _filterChip('All', null),
                for (final f in _filters) _filterChip(f.$1, f.$2),
              ],
            ),
          ),
          const SizedBox(height: ArdentSpacing.s2),
          Expanded(
            child: AsyncView<List<dynamic>>(
              key: ValueKey(_status ?? 'all'),
              loader: _loadCases,
              builder: (context, cases, reload) {
                if (cases.isEmpty) {
                  return const EmptyState(
                      message: 'No cases.', icon: Icons.shield_outlined);
                }
                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(ArdentSpacing.s4),
                    itemCount: cases.length,
                    separatorBuilder: (_, _) => const SizedBox(height: ArdentSpacing.s3),
                    itemBuilder: (context, i) => _caseCard(asMap(cases[i]), text),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  dynamic _pick(Map m, List<String> keys) {
    for (final k in keys) {
      if (m[k] != null) return m[k];
    }
    return null;
  }

  Widget _stat(String value, String label) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: SurfaceCard(
        child: Column(
          children: [
            Text(value, style: text.titleLarge?.copyWith(fontSize: 20)),
            Text(label,
                textAlign: TextAlign.center,
                style: text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final active = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _status = value),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? ArdentColors.accent : ArdentColors.bgSurface,
            borderRadius: BorderRadius.circular(ArdentRadii.pill),
            border: Border.all(color: active ? ArdentColors.accent : ArdentColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : ArdentColors.fg2)),
        ),
      ),
    );
  }

  Widget _caseCard(Map<String, dynamic> c, TextTheme text) {
    final status = '${c['status'] ?? ''}'.replaceAll('_', ' ');
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${c['title'] ?? 'Case'}',
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
              if (c['category'] != null)
                '${c['category']}'.replaceAll('_', ' '),
              relativeTime(c['createdAt']),
            ].where((s) => s.isNotEmpty).join(' · '),
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
