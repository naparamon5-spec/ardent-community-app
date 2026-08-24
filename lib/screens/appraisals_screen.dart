import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import 'appraisal_admin_screen.dart';

/// My appraisals — own appraisals + those the caller rates (`GET /appraisals/mine`).
/// Requires `module:appraisal.view`.
class AppraisalsScreen extends StatelessWidget {
  const AppraisalsScreen({super.key});

  Future<({List<dynamic> mine, List<dynamic> toRate})> _load() async {
    final data = await Api.instance.appraisals.mine();
    return (
      mine: asList(data['mine'] ?? data['appraisals'] ?? (data is List ? data : const [])),
      toRate: asList(data['toRate'] ?? data['assigned']),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appraisals')),
      body: AsyncView<({List<dynamic> mine, List<dynamic> toRate})>(
        loader: _load,
        builder: (context, data, reload) {
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              children: [
                if (data.mine.isEmpty && data.toRate.isEmpty)
                  const SurfaceCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: ArdentSpacing.s5),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.workspace_premium_outlined,
                                size: 36, color: ArdentColors.fg3),
                            SizedBox(height: ArdentSpacing.s2),
                            Text(
                              "No appraisals yet. You'll see one here when HR opens a cycle.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ArdentColors.fg3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (data.mine.isNotEmpty) ...[
                  const Overline('Your appraisals'),
                  const SizedBox(height: ArdentSpacing.s2),
                  for (final a in data.mine) _card(context, a, own: true),
                ],
                if (data.toRate.isNotEmpty) ...[
                  const SizedBox(height: ArdentSpacing.s4),
                  const Overline('To rate'),
                  const SizedBox(height: ArdentSpacing.s2),
                  for (final a in data.toRate) _card(context, a, own: false),
                ],
                const SizedBox(height: ArdentSpacing.s4),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AppraisalAdminScreen()),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Manage appraisal cycles'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, dynamic raw, {required bool own}) {
    final a = asMap(raw);
    final text = Theme.of(context).textTheme;
    final title = (a['title'] ??
            a['cycleName'] ??
            a['templateName'] ??
            a['name'] ??
            'Appraisal')
        .toString();
    final status = (a['status'] ?? '').toString().replaceAll('_', ' ');
    final subject = asMap(a['subject'] ?? a['employee']);
    final subjectName = (subject['name'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s3),
      child: SurfaceCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ArdentColors.statusPendingBg,
                borderRadius: BorderRadius.circular(ArdentRadii.sm),
              ),
              child: const Icon(Icons.assignment_outlined,
                  color: Color(0xFFC77700), size: 22),
            ),
            const SizedBox(width: ArdentSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium?.copyWith(fontSize: 14)),
                  if (!own && subjectName.isNotEmpty)
                    Text('For $subjectName', style: text.bodySmall),
                ],
              ),
            ),
            if (status.isNotEmpty)
              DsChip(
                  label: status,
                  fg: ArdentColors.navy600,
                  bg: ArdentColors.statusOpenBg),
          ],
        ),
      ),
    );
  }
}
