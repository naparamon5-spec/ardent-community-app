import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

/// Appraisal Admin ("Manage") — run cycles, generate records, advance status,
/// and release results (`/appraisal-admin/cycles`). Requires
/// `module:appraisal.manage`.
class AppraisalAdminScreen extends StatefulWidget {
  const AppraisalAdminScreen({super.key});

  @override
  State<AppraisalAdminScreen> createState() => _AppraisalAdminScreenState();
}

class _AppraisalAdminScreenState extends State<AppraisalAdminScreen> {
  int _reloadTick = 0;

  Future<List<dynamic>> _load() => Api.instance.appraisalAdmin.cycles();

  Future<void> _run(String label, Future<dynamic> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (!mounted) return;
      setState(() => _reloadTick++);
      messenger.showSnackBar(SnackBar(content: Text('$label done')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.isForbidden ? 'You need HR access for that.' : e.message)));
    }
  }

  void _showProgress(String id, String name) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ProgressScreen(cycleId: id, cycleName: name),
    ));
  }

  /// Actions valid for a cycle's current status, mirroring the web console.
  /// Lifecycle: draft → active → locked → closed. Only the transition that
  /// advances *from* the current status (plus the actions that make sense in it)
  /// is offered — e.g. a locked cycle can Release or Close, never Activate/Lock.
  List<PopupMenuEntry<String>> _actionsFor(String status) {
    const generate = PopupMenuItem(value: 'generate', child: Text('Generate records'));
    const release = PopupMenuItem(value: 'release', child: Text('Release results'));
    const progress = PopupMenuItem(value: 'progress', child: Text('View progress'));
    switch (status) {
      case 'draft':
        return const [
          generate,
          PopupMenuItem(value: 'activate', child: Text('Activate')),
          progress,
        ];
      case 'active':
        return const [
          generate,
          release,
          PopupMenuItem(value: 'lock', child: Text('Lock')),
          progress,
        ];
      case 'locked':
        return const [
          release,
          PopupMenuItem(value: 'close', child: Text('Close')),
          progress,
        ];
      default: // closed / unknown — terminal, view only
        return const [progress];
    }
  }

  void _onAction(String value, Map<String, dynamic> c) {
    final id = '${c['id'] ?? c['_id'] ?? ''}';
    switch (value) {
      case 'activate':
        _run('Activate', () => Api.instance.appraisalAdmin.activateCycle(id));
      case 'lock':
        _run('Lock', () => Api.instance.appraisalAdmin.lockCycle(id));
      case 'close':
        _run('Close', () => Api.instance.appraisalAdmin.closeCycle(id));
      case 'generate':
        _run('Generate', () => Api.instance.appraisalAdmin.generateCycle(id));
      case 'release':
        _run('Release', () => Api.instance.appraisalAdmin.releaseCycle(id));
      case 'progress':
        _showProgress(id, '${c['name'] ?? 'Cycle'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage appraisals')),
      body: AsyncView<List<dynamic>>(
        key: ValueKey(_reloadTick),
        loader: _load,
        builder: (context, cycles, reload) {
          if (cycles.isEmpty) {
            return const EmptyState(
                message: 'No appraisal cycles yet.',
                icon: Icons.workspace_premium_outlined);
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              children: [
                Text('Run cycles, track completion, and release results.',
                    style: text.bodyMedium?.copyWith(color: ArdentColors.fg3)),
                const SizedBox(height: ArdentSpacing.s4),
                const Overline('Cycles'),
                const SizedBox(height: ArdentSpacing.s2),
                for (final raw in cycles) _cycleCard(asMap(raw), text),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cycleCard(Map<String, dynamic> c, TextTheme text) {
    final status = '${c['status'] ?? 'draft'}';
    final period = [
      relativeDateOnly(c['periodStart']),
      relativeDateOnly(c['periodEnd']),
    ].where((s) => s.isNotEmpty).join(' → ');
    final weights =
        '${_num(c['weightSelf'])}/${_num(c['weightSupervisor'])}/${_num(c['weightHr'])}';
    return Padding(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s3),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${c['name'] ?? 'Cycle'}',
                      style: text.titleMedium?.copyWith(fontSize: 15)),
                ),
                _statusChip(status),
                SizedBox(
                  height: 32,
                  width: 32,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz_rounded, color: ArdentColors.fg2),
                    onSelected: (v) => _onAction(v, c),
                    itemBuilder: (_) => _actionsFor(status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [if (period.isNotEmpty) period, 'Weights $weights']
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final active = status == 'active';
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: DsChip(
        label: status,
        fg: active ? ArdentColors.statusResolved : ArdentColors.fg2,
        bg: active ? ArdentColors.statusResolvedBg : ArdentColors.bgSubtle,
      ),
    );
  }

  String _num(dynamic v) => v == null ? '0' : '${(v is num) ? v : v}';
}


/// Full-page progress dashboard for one appraisal cycle, mirroring the web
/// console: a headline count, a status chip row, a score-distribution
/// histogram, and a per-employee list.
class _ProgressScreen extends StatefulWidget {
  const _ProgressScreen({required this.cycleId, required this.cycleName});
  final String cycleId;
  final String cycleName;

  @override
  State<_ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<_ProgressScreen> {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cycle progress')),
      body: AsyncView<Map<String, dynamic>>(
        loader: () => Api.instance.appraisalAdmin.cycleProgress(widget.cycleId),
        builder: (context, data, reload) {
          final m = _ProgressModel.parse(data);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              children: [
                Text(widget.cycleName,
                    style: text.titleLarge
                        ?.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    '${m.total} appraisal${m.total == 1 ? '' : 's'}'
                    '${m.completed > 0 ? ' · ${m.completed} released' : ''}',
                    style: text.bodySmall?.copyWith(color: ArdentColors.fg3)),
                const SizedBox(height: ArdentSpacing.s4),

                if (m.statuses.isNotEmpty) _StatusChips(statuses: m.statuses),

                if (m.bands.isNotEmpty) ...[
                  const SizedBox(height: ArdentSpacing.s5),
                  const Overline('Score distribution'),
                  const SizedBox(height: ArdentSpacing.s2),
                  _ScoreDistribution(bands: m.bands),
                ],

                if (m.rows.isNotEmpty) ...[
                  const SizedBox(height: ArdentSpacing.s5),
                  const Overline('Appraisals'),
                  const SizedBox(height: ArdentSpacing.s2),
                  for (final r in m.rows) ...[
                    _AppraisalCard(row: r),
                    const SizedBox(height: ArdentSpacing.s2),
                  ],
                ],

                if (m.flags.isNotEmpty) ...[
                  const SizedBox(height: ArdentSpacing.s4),
                  const Overline('Attention'),
                  const SizedBox(height: ArdentSpacing.s2),
                  for (final f in m.flags) ...[
                    _FlagCard(flag: f),
                    const SizedBox(height: ArdentSpacing.s2),
                  ],
                ],

                if (m.details.isNotEmpty) ...[
                  const SizedBox(height: ArdentSpacing.s4),
                  const Overline('Details'),
                  const SizedBox(height: ArdentSpacing.s2),
                  _DetailsCard(details: m.details),
                ],

                if (m.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: ArdentSpacing.s8),
                    child: EmptyState(
                        message: 'No progress data yet.',
                        icon: Icons.insights_outlined),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---- Sub-widgets ------------------------------------------------------------

/// Wrap of status pills, e.g. "Supervisor reviewing: 1".
class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.statuses});
  final List<_StatusCount> statuses;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ArdentSpacing.s2,
      runSpacing: ArdentSpacing.s2,
      children: [
        for (final s in statuses)
          DsChip(label: '${s.label}: ${s.count}', fg: s.color, bg: s.bg),
      ],
    );
  }
}

/// Horizontal band histogram: label · bar · count, mirroring the web view.
class _ScoreDistribution extends StatelessWidget {
  const _ScoreDistribution({required this.bands});
  final List<_ScoreBand> bands;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxCount = bands.fold<int>(0, (a, b) => b.count > a ? b.count : a);
    return SurfaceCard(
      child: Column(
        children: [
          for (var i = 0; i < bands.length; i++) ...[
            if (i > 0) const SizedBox(height: ArdentSpacing.s3),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(bands[i].label,
                      style: text.bodySmall?.copyWith(color: ArdentColors.fg2)),
                ),
                const SizedBox(width: ArdentSpacing.s2),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ArdentRadii.pill),
                    child: LinearProgressIndicator(
                      value: maxCount == 0 ? 0 : bands[i].count / maxCount,
                      minHeight: 10,
                      backgroundColor: ArdentColors.bgSubtle,
                      valueColor:
                          const AlwaysStoppedAnimation(ArdentColors.accent),
                    ),
                  ),
                ),
                const SizedBox(width: ArdentSpacing.s3),
                SizedBox(
                  width: 28,
                  child: Text('${bands[i].count}',
                      textAlign: TextAlign.right,
                      style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800, color: ArdentColors.fg1)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One employee's appraisal: identity, overall status, self/supervisor
/// sub-status, and the current score.
class _AppraisalCard extends StatelessWidget {
  const _AppraisalCard({required this.row});
  final _AppraisalRow row;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (fg, bg) = _statusColors(row.status);
    return SurfaceCard(
      padding: const EdgeInsets.all(ArdentSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsAvatar(
                  initials: _initials(row.name),
                  color: ArdentColors.navy600,
                  size: 38),
              const SizedBox(width: ArdentSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.name.isEmpty ? 'Employee' : row.name,
                        style: text.titleMedium?.copyWith(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    if (row.department.isNotEmpty)
                      Text(row.department,
                          style: text.bodySmall
                              ?.copyWith(color: ArdentColors.fg3)),
                  ],
                ),
              ),
              if (row.score != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_fmtScore(row.score!),
                        style: text.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ArdentColors.fg1)),
                    Text('score',
                        style: text.labelSmall
                            ?.copyWith(color: ArdentColors.fg3)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: ArdentSpacing.s3),
          Wrap(
            spacing: ArdentSpacing.s2,
            runSpacing: ArdentSpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (row.status.isNotEmpty)
                DsChip(label: _humanize(row.status), fg: fg, bg: bg),
              if (row.self.isNotEmpty)
                _MiniStat(label: 'Self', value: _humanize(row.self)),
              if (row.supervisor.isNotEmpty)
                _MiniStat(
                    label: 'Supervisor', value: _humanize(row.supervisor)),
            ],
          ),
        ],
      ),
    );
  }

  static (Color, Color) _statusColors(String status) {
    final n = _norm(status);
    if (n.contains('reopen')) {
      return (ArdentColors.statusHigh, ArdentColors.statusHighBg);
    }
    if (n.contains('released') ||
        n.contains('acknowledged') ||
        n.contains('complete') ||
        n.contains('done')) {
      return (ArdentColors.statusResolved, ArdentColors.statusResolvedBg);
    }
    if (n.contains('notstarted') || n.contains('pending')) {
      return (ArdentColors.fg2, ArdentColors.bgSubtle);
    }
    if (n.contains('reviewing') ||
        n.contains('submitted') ||
        n.contains('supervisor') ||
        n.contains('hr')) {
      return (ArdentColors.statusOpen, ArdentColors.statusOpenBg);
    }
    // self review / in progress and anything else
    return (ArdentColors.statusPending, ArdentColors.statusPendingBg);
  }

  static String _fmtScore(num v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(2);

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }
}

/// A tiny "label · value" pill used for self / supervisor sub-status.
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ArdentColors.bgInset,
        borderRadius: BorderRadius.circular(ArdentRadii.pill),
        border: Border.all(color: ArdentColors.border),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: ArdentColors.fg2),
          children: [
            TextSpan(
                text: '$label ',
                style: const TextStyle(
                    color: ArdentColors.fg3, fontWeight: FontWeight.w600)),
            TextSpan(
                text: value,
                style: const TextStyle(
                    color: ArdentColors.fg1, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _FlagCard extends StatelessWidget {
  const _FlagCard({required this.flag});
  final _Flag flag;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(ArdentSpacing.s3),
      decoration: BoxDecoration(
        color: ArdentColors.statusPendingBg,
        borderRadius: BorderRadius.circular(ArdentRadii.md),
        border:
            Border.all(color: ArdentColors.statusPending.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: ArdentColors.statusPending, size: 20),
          const SizedBox(width: ArdentSpacing.s3),
          Expanded(
            child: Text(flag.label,
                style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600, color: ArdentColors.fg1)),
          ),
          if (flag.count > 0)
            DsChip(
                label: '${flag.count}',
                fg: ArdentColors.statusPending,
                bg: Colors.white),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.details});
  final List<MapEntry<String, String>> details;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      child: Column(
        children: [
          for (var i = 0; i < details.length; i++) ...[
            if (i > 0)
              const Divider(
                  height: ArdentSpacing.s4, color: ArdentColors.border),
            Row(
              children: [
                Expanded(
                    child: Text(details[i].key,
                        style:
                            text.bodyMedium?.copyWith(color: ArdentColors.fg2))),
                Text(details[i].value,
                    style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: ArdentColors.fg1)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---- Model + parsing --------------------------------------------------------

class _StatusCount {
  const _StatusCount(this.label, this.count, this.color, this.bg);
  final String label;
  final int count;
  final Color color;
  final Color bg;
}

class _ScoreBand {
  const _ScoreBand(this.label, this.count);
  final String label;
  final int count;
}

class _AppraisalRow {
  const _AppraisalRow({
    required this.name,
    required this.department,
    required this.status,
    required this.self,
    required this.supervisor,
    required this.score,
  });
  final String name;
  final String department;
  final String status;
  final String self;
  final String supervisor;
  final num? score;
}

class _Flag {
  const _Flag(this.label, this.count);
  final String label;
  final int count;
}

String _norm(String k) => k.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _humanize(String k) => k
    .replaceAll(RegExp(r'[_\-]'), ' ')
    .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .trim()
    .replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());

dynamic _pick(Map map, List<String> keys) {
  for (final k in keys) {
    if (map.containsKey(k) && map[k] != null) return map[k];
  }
  final want = keys.map(_norm).toSet();
  for (final e in map.entries) {
    if (want.contains(_norm('${e.key}')) && e.value != null) return e.value;
  }
  return null;
}

String _pickStr(Map map, List<String> keys) {
  final v = _pick(map, keys);
  return v == null ? '' : '$v';
}

/// Resolve an employee/person field that may be a nested object or a string.
String _personName(dynamic v) {
  if (v is String) return v;
  if (v is Map) {
    final direct = _pickStr(v, ['name', 'fullName', 'displayName']);
    if (direct.isNotEmpty) return direct;
    final first = _pickStr(v, ['firstName', 'first']);
    final last = _pickStr(v, ['lastName', 'last']);
    return [first, last].where((s) => s.isNotEmpty).join(' ');
  }
  return '';
}

/// Resolve a sub-status that may be a string or a `{ status: ... }` object.
String _subStatus(dynamic v) {
  if (v is String) return v;
  if (v is Map) return _pickStr(v, ['status', 'state', 'value']);
  return '';
}

num? _asNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

class _ProgressModel {
  _ProgressModel({
    required this.total,
    required this.statuses,
    required this.bands,
    required this.rows,
    required this.flags,
    required this.details,
  });

  final int total;
  final List<_StatusCount> statuses;
  final List<_ScoreBand> bands;
  final List<_AppraisalRow> rows;
  final List<_Flag> flags;
  final List<MapEntry<String, String>> details;

  int get completed => statuses.where((s) {
        final n = _norm(s.label);
        return n.contains('released') || n.contains('acknowledged');
      }).fold(0, (a, s) => a + s.count);

  bool get isEmpty =>
      total == 0 &&
      statuses.isEmpty &&
      bands.isEmpty &&
      rows.isEmpty &&
      flags.isEmpty &&
      details.isEmpty;

  static (Color, Color) _statusColors(String status) =>
      _AppraisalCard._statusColors(status);

  static _ProgressModel parse(Map<String, dynamic> data) {
    final consumed = <String>{};

    // 1. Per-employee rows — the first list of appraisal-like objects.
    List<dynamic> rawRows = const [];
    for (final e in data.entries) {
      final n = _norm(e.key);
      if (e.value is List &&
          (e.value as List).isNotEmpty &&
          (e.value as List).first is Map &&
          (n.contains('appraisal') ||
              n.contains('record') ||
              n.contains('row') ||
              n.contains('item') ||
              n.contains('employee') ||
              n.contains('people'))) {
        rawRows = e.value as List;
        consumed.add(n);
        break;
      }
    }
    final rows = <_AppraisalRow>[];
    for (final raw in rawRows) {
      final r = asMap(raw);
      final person =
          _personName(_pick(r, ['employee', 'user', 'person', 'subject']));
      rows.add(_AppraisalRow(
        name: person.isNotEmpty
            ? person
            : _pickStr(r, ['employeeName', 'name', 'userName', 'fullName']),
        department: _pickStr(r, ['department', 'dept', 'team', 'division']),
        status: _pickStr(r, ['status', 'state', 'overallStatus']),
        self: _subStatus(_pick(r, ['self', 'selfStatus', 'selfReview'])),
        supervisor: _subStatus(
            _pick(r, ['supervisor', 'supervisorStatus', 'supervisorReview'])),
        score:
            _asNum(_pick(r, ['score', 'finalScore', 'overallScore', 'result'])),
      ));
    }

    // 2. Status counts — an explicit map if present, else derived from rows.
    Map<String, dynamic>? rawStatuses;
    for (final e in data.entries) {
      final n = _norm(e.key);
      if (e.value is Map &&
          (n.contains('status') || n.contains('breakdown') || n == 'counts')) {
        rawStatuses = Map<String, dynamic>.from(e.value as Map);
        consumed.add(n);
        break;
      }
    }
    final counts = <String, int>{};
    final labels = <String, String>{};
    if (rawStatuses != null) {
      rawStatuses.forEach((k, v) {
        if (v is num) {
          final key = _norm(k);
          counts[key] = v.toInt();
          labels[key] = _humanize(k);
        }
      });
    } else {
      for (final r in rows) {
        if (r.status.isEmpty) continue;
        final key = _norm(r.status);
        counts[key] = (counts[key] ?? 0) + 1;
        labels[key] = _humanize(r.status);
      }
    }
    final statuses = counts.entries
        .where((e) => e.value > 0)
        .map((e) {
      final (fg, bg) = _statusColors(e.key);
      return _StatusCount(labels[e.key] ?? _humanize(e.key), e.value, fg, bg);
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    // 3. Score distribution — explicit bands if present, else computed from
    //    scores using the same default bands as the web console.
    final bands = <_ScoreBand>[];
    dynamic rawDist;
    for (final e in data.entries) {
      final n = _norm(e.key);
      if ((e.value is List || e.value is Map) &&
          (n.contains('distribution') ||
              n.contains('bucket') ||
              n.contains('band') ||
              n.contains('histogram'))) {
        rawDist = e.value;
        consumed.add(n);
        break;
      }
    }
    if (rawDist is List) {
      for (final b in rawDist) {
        final bm = asMap(b);
        final label =
            _pickStr(bm, ['label', 'range', 'name', 'band']).replaceAll('-', '–');
        final count =
            _asNum(_pick(bm, ['count', 'value', 'total']))?.toInt() ?? 0;
        if (label.isNotEmpty) bands.add(_ScoreBand(label, count));
      }
    } else if (rawDist is Map) {
      rawDist.forEach((k, v) {
        if (v is num) bands.add(_ScoreBand('$k'.replaceAll('-', '–'), v.toInt()));
      });
    } else {
      final scored =
          rows.where((r) => r.score != null).map((r) => r.score!).toList();
      if (scored.isNotEmpty) {
        const ranges = [(0, 39), (40, 59), (60, 79), (80, 92), (93, 100)];
        for (final (lo, hi) in ranges) {
          final c = scored.where((s) => s >= lo && s <= hi).length;
          bands.add(_ScoreBand('$lo–$hi', c));
        }
      }
    }

    // 4. Total.
    int total = 0;
    for (final e in data.entries) {
      final n = _norm(e.key);
      if ((n == 'total' || n == 'count' || n == 'totalappraisals') &&
          e.value is num) {
        total = (e.value as num).toInt();
        consumed.add(n);
      }
    }
    if (total == 0) {
      total =
          rows.isNotEmpty ? rows.length : counts.values.fold(0, (a, b) => a + b);
    }

    // 5. Flags + leftover details.
    final flags = <_Flag>[];
    final details = <MapEntry<String, String>>[];
    data.forEach((key, value) {
      final n = _norm(key);
      if (consumed.contains(n)) return;
      if (value is num && (n.startsWith('missing') || n.contains('overdue'))) {
        if (value > 0) flags.add(_Flag(_humanize(key), value.toInt()));
      } else if (value is bool) {
        details.add(MapEntry(_humanize(key), value ? 'Yes' : 'No'));
      } else if (value is num || value is String) {
        details.add(MapEntry(_humanize(key), '$value'));
      }
    });

    return _ProgressModel(
      total: total,
      statuses: statuses,
      bands: bands,
      rows: rows,
      flags: flags,
      details: details,
    );
  }
}
