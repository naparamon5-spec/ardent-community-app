import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

/// Admin — list/search users (`GET /admin/users`). Requires `module:admin.users`.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _load() =>
      Api.instance.admin.users(search: _search.isEmpty ? null : _search);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() => _search = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search users…',
                prefixIcon: const Icon(Icons.search_rounded, color: ArdentColors.fg3),
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
          ),
          Expanded(
            child: AsyncView<List<dynamic>>(
              key: ValueKey(_search),
              loader: _load,
              builder: (context, users, reload) {
                if (users.isEmpty) {
                  return const EmptyState(
                      message: 'No users found.', icon: Icons.people_outline_rounded);
                }
                return RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
                    itemCount: users.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: ArdentColors.border),
                    itemBuilder: (context, i) {
                      final u = asMap(users[i]);
                      final person = personFromJson(u);
                      final active = u['isActive'] != false;
                      final role = '${u['accessRole'] ?? ''}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => _showUserDetail(u, person, active, role),
                        leading: _AvatarWithStatus(
                          initials: person.initials,
                          color: person.color,
                          active: active,
                        ),
                        title: Text(person.name,
                            style: text.titleMedium?.copyWith(fontSize: 15)),
                        subtitle: Text(
                          '${u['email'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (role.isNotEmpty)
                              DsChip(
                                  label: role,
                                  fg: ArdentColors.navy600,
                                  bg: ArdentColors.statusOpenBg),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _StatusBadge(active: active),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet showing the tapped user's identity and status.
  void _showUserDetail(
      Map<String, dynamic> u, dynamic person, bool active, String role) {
    final text = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ArdentColors.bgSurface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ArdentRadii.xl)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              ArdentSpacing.s5, 0, ArdentSpacing.s5, ArdentSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _AvatarWithStatus(
                  initials: person.initials,
                  color: person.color,
                  active: active,
                  size: 64,
                ),
              ),
              const SizedBox(height: ArdentSpacing.s3),
              Text(person.name,
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(fontSize: 20)),
              if ('${u['email'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: ArdentSpacing.s1),
                Text('${u['email']}',
                    textAlign: TextAlign.center, style: text.bodySmall),
              ],
              const SizedBox(height: ArdentSpacing.s3),
              Center(child: _StatusBadge(active: active)),
              if (role.isNotEmpty) ...[
                const SizedBox(height: ArdentSpacing.s4),
                const Divider(height: 1, color: ArdentColors.border),
                const SizedBox(height: ArdentSpacing.s4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Access role', style: text.bodyMedium),
                    DsChip(
                        label: role,
                        fg: ArdentColors.navy600,
                        bg: ArdentColors.statusOpenBg),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar with a small green (active) / gray (inactive) status dot overlaid
/// on the bottom-right, mirroring the web "● ACTIVE" indicator.
class _AvatarWithStatus extends StatelessWidget {
  const _AvatarWithStatus({
    required this.initials,
    required this.color,
    required this.active,
    this.size = 42,
  });

  final String initials;
  final Color color;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.3;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DsAvatar(initials: initials, color: color, size: size),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: active ? ArdentColors.statusResolved : ArdentColors.gray400,
              shape: BoxShape.circle,
              border: Border.all(color: ArdentColors.bgSurface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill badge: green "Active" / gray "Inactive".
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return DsChip(
      label: active ? 'Active' : 'Inactive',
      icon: Icons.circle,
      fg: active ? ArdentColors.statusResolved : ArdentColors.fg3,
      bg: active ? ArdentColors.statusResolvedBg : ArdentColors.bgSubtle,
    );
  }
}
