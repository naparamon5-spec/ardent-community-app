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
                        leading: DsAvatar(
                            initials: person.initials, color: person.color, size: 42),
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
                            if (!active)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text('Inactive',
                                    style: TextStyle(
                                        color: ArdentColors.fg3, fontSize: 11)),
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
}
