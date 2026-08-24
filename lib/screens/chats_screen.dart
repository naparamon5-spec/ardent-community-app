import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

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
                  MaterialPageRoute(builder: (_) => _ChatThread(group: g)),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// One conversation view — loads and sends messages for a group/DM thread.
class _ChatThread extends StatefulWidget {
  const _ChatThread({required this.group});
  final Group group;

  @override
  State<_ChatThread> createState() => _ChatThreadState();
}

class _ChatMessage {
  _ChatMessage({required this.text, required this.author, required this.mine});
  final String text;
  final String author;
  final bool mine;
}

class _ChatThreadState extends State<_ChatThread> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<_ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  _ChatMessage _map(dynamic raw) {
    final m = asMap(raw);
    final author = personFromJson(m['author'] ?? m['user'] ?? m['sender']);
    return _ChatMessage(
      text: (m['text'] ?? m['body'] ?? '').toString(),
      author: author.name,
      mine: author.id.isNotEmpty && author.id == AppSession.instance.me.id,
    );
  }

  Future<void> _loadMessages() async {
    try {
      final raw = await Api.instance.groups.messages(widget.group.id, limit: 50);
      // API returns newest-first via cursor; show oldest-first in the view.
      final mapped = raw.map(_map).toList().reversed.toList();
      if (!mounted) return;
      setState(() {
        _messages = mapped;
        _loading = false;
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _sending) return;
    final optimistic =
        _ChatMessage(text: t, author: AppSession.instance.me.name, mine: true);
    setState(() {
      _messages = [..._messages, optimistic];
      _ctrl.clear();
      _sending = true;
    });
    _scrollToEnd();
    try {
      await Api.instance.groups.sendMessage(widget.group.id, text: t);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _messages.remove(optimistic));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            g.isDirect
                ? DsAvatar(initials: initialsFrom(g.name), color: g.color, size: 34)
                : Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: g.color,
                      borderRadius: BorderRadius.circular(ArdentRadii.sm),
                    ),
                    child: const Icon(Icons.groups_rounded, color: Colors.white, size: 18),
                  ),
            const SizedBox(width: ArdentSpacing.s3),
            Expanded(
              child: Text(g.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          _composer(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(message: _error!, icon: Icons.error_outline_rounded);
    }
    if (_messages.isEmpty) {
      return const EmptyState(
          message: 'No messages yet. Say hello!',
          icon: Icons.waving_hand_outlined);
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(ArdentSpacing.s4),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _bubble(_messages[i], showAuthor: !widget.group.isDirect),
    );
  }

  Widget _bubble(_ChatMessage m, {required bool showAuthor}) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(ArdentRadii.lg),
      topRight: const Radius.circular(ArdentRadii.lg),
      bottomLeft: Radius.circular(m.mine ? ArdentRadii.lg : ArdentRadii.xs),
      bottomRight: Radius.circular(m.mine ? ArdentRadii.xs : ArdentRadii.lg),
    );
    final maxW = MediaQuery.of(context).size.width * 0.72;
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(
          crossAxisAlignment:
              m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showAuthor && !m.mine)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Text(m.author,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ArdentColors.fg3)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: m.mine ? ArdentColors.accent : ArdentColors.bgSubtle,
                borderRadius: radius,
              ),
              child: Text(m.text,
                  style: TextStyle(
                      fontSize: 14,
                      color: m.mine ? Colors.white : ArdentColors.fg1,
                      height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: const BoxDecoration(
        color: ArdentColors.bgSurface,
        border: Border(top: BorderSide(color: ArdentColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: ArdentColors.bgSubtle,
                  borderRadius: BorderRadius.circular(ArdentRadii.pill),
                ),
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Message…',
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _ctrl,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return IconButton(
                  onPressed: hasText && !_sending ? _send : null,
                  icon: const Icon(Icons.send_rounded, size: 24),
                  color: ArdentColors.accent,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
