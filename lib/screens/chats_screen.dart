import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import 'group_chat_screen.dart';

/// Chats — the caller's direct-message threads and groups
/// (`GET /groups/direct`, `GET /groups`), opening into a live message thread.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  Future<List<Group>> _load() async {
    final results = await Future.wait([
      Api.instance.groups.directThreads().catchError((_) => <dynamic>[]),
      Api.instance.groups.list().catchError((_) => <dynamic>[]),
    ]);
    final dms = results[0].map(groupFromJson).toList();
    final groups = results[1].map(groupFromJson).where((g) => !g.isDirect).toList();
    return [...dms, ...groups];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AsyncView<List<Group>>(
      loader: _load,
      builder: (context, threads, reload) {
        if (threads.isEmpty) {
          return const EmptyState(
              message: 'No conversations yet.',
              icon: Icons.chat_bubble_outline_rounded);
        }
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: ArdentSpacing.s2),
            itemCount: threads.length,
            separatorBuilder: (_, _) =>
                const Divider(indent: 72, height: 1, color: ArdentColors.border),
            itemBuilder: (context, i) {
              final g = threads[i];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4, vertical: 4),
                leading: g.isDirect
                    ? DsAvatar(initials: initialsFrom(g.name), color: g.color, size: 48)
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: g.color,
                          borderRadius: BorderRadius.circular(ArdentRadii.sm),
                        ),
                        child: const Icon(Icons.groups_rounded, color: Colors.white),
                      ),
                title: Text(g.name, style: text.titleMedium?.copyWith(fontSize: 15)),
                subtitle: Text(
                  g.isDirect ? 'Direct message' : '${g.members} members',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: ArdentColors.fg3),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GroupChatScreen(group: g)),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

