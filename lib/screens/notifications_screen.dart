import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import 'calls_screen.dart';
import 'group_chat_screen.dart';
import 'post_detail_screen.dart';

/// Notifications — backed by `GET /notifications`, with `read-all` and
/// per-item `:id/read`.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _viewKey = GlobalKey();
  int _reloadTick = 0;

  Future<List<NotificationItem>> _load() async {
    final data = await Api.instance.notifications.list(limit: 50);
    final items = asList(data['items'] ??
        data['notifications'] ??
        data['results'] ??
        data['data']);
    final parsed = items.map(notificationFromJson).toList();
    final rawCount = data['unreadCount'] ?? data['unread_count'] ?? data['count'];
    final unreadCount = rawCount is num
        ? rawCount.toInt()
        : parsed.where((n) => n.unread).length;
    AppSession.instance.setUnreadNotifications(unreadCount);
    return parsed;
  }

  Future<void> _markAll() async {
    try {
      await Api.instance.notifications.markAllRead();
      AppSession.instance.setUnreadNotifications(0);
      if (!mounted) return;
      setState(() => _reloadTick++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _markOne(NotificationItem n) async {
    if (!n.unread) return;
    try {
      await Api.instance.notifications.markRead(n.id);
      AppSession.instance.decrementUnreadNotifications(1);
      if (mounted) setState(() => _reloadTick++);
    } on ApiException {
      // Non-critical; ignore.
    }
  }

  /// Marks the notification read and opens whatever it points at, routing on
  /// the backend's `entityType`/`entityId` pair — the same mapping the web
  /// client uses. Notifications with no navigable target just mark read.
  Future<void> _open(NotificationItem n) async {
    _markOne(n);
    switch (n.entityType) {
      case 'post':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: n.entityId),
        ));
      case 'group':
        await _openGroupChat(n.entityId);
      case 'call':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const CallsScreen(),
        ));
      default:
        // Other entity types (event, ethics, booking, follow, …) have no
        // dedicated push target here yet — the row is simply marked read.
        break;
    }
  }

  /// Resolves a group by id and opens its chat. The notification only carries
  /// the group id, so fetch the full record first.
  Future<void> _openGroupChat(String groupId) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final raw = await Api.instance.groups.get(groupId);
      if (!mounted) return;
      navigator.push(MaterialPageRoute(
        builder: (_) => GroupChatScreen(group: groupFromJson(raw)),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: _markAll, child: const Text('Mark all read')),
        ],
      ),
      body: AsyncView<List<NotificationItem>>(
        key: ValueKey(_reloadTick),
        loader: _load,
        builder: (context, items, reload) {
          if (items.isEmpty) {
            return const EmptyState(
                message: "You're all caught up.",
                icon: Icons.notifications_none_rounded);
          }
          return RefreshIndicator(
            key: _viewKey,
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: ArdentSpacing.s2),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 72, color: ArdentColors.border),
              itemBuilder: (context, i) => _tile(items[i], text),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(NotificationItem n, TextTheme text) {
    return Container(
      color: n.unread ? ArdentColors.accentSoft.withValues(alpha: 0.5) : null,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4, vertical: 4),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            DsAvatar(initials: n.actor.initials, color: n.actor.color, size: 46, imageUrl: n.actor.avatarUrl),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: n.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(n.icon, size: 11, color: Colors.white),
              ),
            ),
          ],
        ),
        title: RichText(
          text: TextSpan(
            style: text.bodyLarge?.copyWith(color: ArdentColors.fg1, height: 1.35),
            children: [
              TextSpan(
                  text: n.actor.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: ' '),
              TextSpan(text: n.action),
            ],
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(n.time, style: text.bodySmall),
        ),
        trailing: n.unread
            ? Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                    color: ArdentColors.accent, shape: BoxShape.circle),
              )
            : null,
        onTap: () => _open(n),
      ),
    );
  }
}
