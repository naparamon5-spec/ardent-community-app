import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import 'create_group_screen.dart';

/// Groups directory — backed by `GET /groups`, with join via
/// `PUT /groups/:id/join` and group creation via `POST /groups`.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  int _reloadTick = 0;

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
    if (created == true && mounted) setState(() => _reloadTick++);
  }

  Future<List<Group>> _load() async {
    final raw = await Api.instance.groups.list();
    return raw.map(groupFromJson).where((g) => !g.isDirect).toList();
  }

  Future<void> _join(Group g) async {
    try {
      await Api.instance.groups.join(g.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Requested to join ${g.name}')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create'),
      ),
      body: AsyncView<List<Group>>(
        key: ValueKey(_reloadTick),
        loader: _load,
        builder: (context, groups, reload) {
          if (groups.isEmpty) {
            return const EmptyState(message: 'No groups yet.', icon: Icons.groups_outlined);
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: ArdentSpacing.s4),
              itemBuilder: (context, i) => _groupCard(groups[i], text),
            ),
          );
        },
      ),
    );
  }

  Widget _groupCard(Group g, TextTheme text) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [g.color, g.color.withValues(alpha: 0.7)],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(ArdentRadii.md)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name, style: text.titleLarge?.copyWith(fontSize: 17)),
                const SizedBox(height: 2),
                Text('${g.members} members', style: text.bodySmall),
                if (g.desc.isNotEmpty) ...[
                  const SizedBox(height: ArdentSpacing.s2),
                  Text(g.desc, style: text.bodyMedium),
                ],
                const SizedBox(height: ArdentSpacing.s3),
                Row(
                  children: [
                    ElevatedButton(
                        onPressed: () => _join(g), child: const Text('Join')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
