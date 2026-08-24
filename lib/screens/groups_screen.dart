import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

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

  Future<void> _open(Group g) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupChatScreen(group: g)),
    );
    // Membership may have changed (joined from inside), so refresh the list.
    if (mounted) setState(() => _reloadTick++);
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
    return InkWell(
      onTap: () => _open(g),
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      child: SurfaceCard(
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
              alignment: Alignment.center,
              child: const Icon(Icons.groups_rounded, color: Colors.white70, size: 30),
            ),
            Padding(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.name, style: text.titleLarge?.copyWith(fontSize: 17)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text('${g.members} members', style: text.bodySmall),
                            if (g.joined) ...[
                              const SizedBox(width: 8),
                              const DsChip(
                                  label: 'Joined',
                                  fg: ArdentColors.statusResolved,
                                  bg: ArdentColors.statusResolvedBg),
                            ] else if (g.pending) ...[
                              const SizedBox(width: 8),
                              const DsChip(
                                  label: 'Pending',
                                  fg: Color(0xFFC77700),
                                  bg: ArdentColors.statusPendingBg),
                            ],
                          ],
                        ),
                        if (g.desc.isNotEmpty) ...[
                          const SizedBox(height: ArdentSpacing.s2),
                          Text(g.desc, style: text.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: ArdentColors.fg3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
