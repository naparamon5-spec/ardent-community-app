import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import 'create_group_screen.dart';
import 'group_home_screen.dart';

/// Groups directory — backed by `GET /groups`, with join via
/// `PUT /groups/:id/join` and group creation via `POST /groups`.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  int _reloadTick = 0;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(Group g) {
    if (_search.isEmpty) return true;
    final q = _search.toLowerCase();
    return g.name.toLowerCase().contains(q) || g.desc.toLowerCase().contains(q);
  }

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
    // From the Explore → Groups directory, land on the group's home screen so
    // the user can choose Posts or Chat. (The Chats tab still opens chat directly.)
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupHomeScreen(group: g)),
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
      body: Column(
        children: [
          _searchField(),
          Expanded(
            child: AsyncView<List<Group>>(
              key: ValueKey(_reloadTick),
              loader: _load,
              builder: (context, groups, reload) {
                if (groups.isEmpty) {
                  return const EmptyState(
                      message: 'No groups yet.', icon: Icons.groups_outlined);
                }
                final filtered = groups.where(_matches).toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                      message: 'No groups match your search.',
                      icon: Icons.search_off_rounded);
                }
                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(ArdentSpacing.s4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: ArdentSpacing.s4),
                    itemBuilder: (context, i) => _groupCard(filtered[i], text),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ArdentSpacing.s4, ArdentSpacing.s3, ArdentSpacing.s4, ArdentSpacing.s2),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v.trim()),
        decoration: InputDecoration(
          hintText: 'Search groups',
          filled: true,
          fillColor: ArdentColors.bgSubtle,
          prefixIcon: const Icon(Icons.search_rounded, color: ArdentColors.fg3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ArdentRadii.pill),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ArdentRadii.pill),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ArdentRadii.pill),
            borderSide: const BorderSide(color: ArdentColors.accent),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _search = '';
                  }),
                ),
        ),
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
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(ArdentRadii.md)),
              child: g.photoUrl.isNotEmpty
                  ? Image.network(
                      g.photoUrl,
                      height: 72,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _coverFallback(g),
                    )
                  : _coverFallback(g),
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

  /// Gradient banner shown when a group has no cover photo (or it fails to load).
  Widget _coverFallback(Group g) => Container(
        height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [g.color, g.color.withValues(alpha: 0.7)],
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.groups_rounded, color: Colors.white70, size: 30),
      );
}
