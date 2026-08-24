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

  Future<void> _showProgress(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await Api.instance.appraisalAdmin.cycleProgress(id);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _ProgressSheet(data: data),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
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
        _showProgress(id);
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
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'activate', child: Text('Activate')),
                      PopupMenuItem(value: 'lock', child: Text('Lock')),
                      PopupMenuItem(value: 'close', child: Text('Close')),
                      PopupMenuItem(value: 'generate', child: Text('Generate records')),
                      PopupMenuItem(value: 'release', child: Text('Release results')),
                      PopupMenuItem(value: 'progress', child: Text('View progress')),
                    ],
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

class _ProgressSheet extends StatelessWidget {
  const _ProgressSheet({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = <Widget>[];
    void kv(String k, String v) => rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(k, style: text.bodyMedium)),
              Text(v,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ));

    data.forEach((key, value) {
      if (value is Map) {
        value.forEach((k, v) => kv('$key · $k', '$v'));
      } else if (value is List) {
        kv(key, '${value.length}');
      } else {
        kv(_humanize(key), '$value');
      }
    });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            ArdentSpacing.s5, 0, ArdentSpacing.s5, ArdentSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Completion', style: text.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: ArdentSpacing.s3),
            if (rows.isEmpty)
              Text('No progress data.',
                  style: text.bodyMedium?.copyWith(color: ArdentColors.fg3))
            else
              ...rows,
          ],
        ),
      ),
    );
  }

  String _humanize(String k) =>
      k.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]!.toLowerCase()}').trim();
}
