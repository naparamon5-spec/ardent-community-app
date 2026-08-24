import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// A group / direct-message conversation. Loads and sends messages, and — for a
/// group the user hasn't joined — shows a join panel *inside* the screen instead
/// of the composer (join lives here, not on the groups list). Used by both the
/// Chats list and the Groups directory.
class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key, required this.group});
  final Group group;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _ChatMessage {
  _ChatMessage({required this.text, required this.author, required this.mine});
  final String text;
  final String author;
  final bool mine;
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<_ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _joining = false;
  String? _error;

  late bool _joined = widget.group.isDirect || widget.group.joined;
  late bool _pending = widget.group.pending;

  @override
  void initState() {
    super.initState();
    if (_joined) {
      _loadMessages();
    } else {
      _loading = false; // show the join panel
    }
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await Api.instance.groups.messages(widget.group.id, limit: 50);
      final mapped = raw.map(_map).toList().reversed.toList();
      if (!mounted) return;
      setState(() {
        _messages = mapped;
        _loading = false;
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;
      // Not a member yet → fall back to the join panel rather than an error.
      if (e.isForbidden) {
        setState(() {
          _joined = false;
          _loading = false;
        });
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final res = await Api.instance.groups.join(widget.group.id);
      final status = '${res['status'] ?? res['membershipStatus'] ?? ''}'.toLowerCase();
      final isMember = status == 'member' || status == 'active' || status.isEmpty;
      if (!mounted) return;
      if (isMember) {
        setState(() {
          _joined = true;
          _pending = false;
          _joining = false;
        });
        _loadMessages();
      } else {
        setState(() {
          _pending = true;
          _joining = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request sent')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
            _groupAvatar(g, 34),
            const SizedBox(width: ArdentSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  if (!g.isDirect)
                    Text('${g.members} members',
                        style: const TextStyle(fontSize: 11, color: ArdentColors.fg3)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          if (_joined) _composer(),
        ],
      ),
    );
  }

  Widget _groupAvatar(Group g, double size) {
    if (g.isDirect) {
      return DsAvatar(initials: initialsFrom(g.name), color: g.color, size: size);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: g.color,
        borderRadius: BorderRadius.circular(ArdentRadii.sm),
      ),
      child: Icon(Icons.groups_rounded, color: Colors.white, size: size * 0.55),
    );
  }

  Widget _body() {
    if (!_joined) return _joinPanel();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _CenteredMessage(icon: Icons.error_outline_rounded, message: _error!);
    }
    if (_messages.isEmpty) {
      return const _CenteredMessage(
          icon: Icons.waving_hand_outlined, message: 'No messages yet. Say hello!');
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(ArdentSpacing.s4),
      itemCount: _messages.length,
      itemBuilder: (context, i) =>
          _bubble(_messages[i], showAuthor: !widget.group.isDirect),
    );
  }

  Widget _joinPanel() {
    final g = widget.group;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(ArdentSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _groupAvatar(g, 88),
            const SizedBox(height: ArdentSpacing.s4),
            Text(g.name,
                textAlign: TextAlign.center,
                style: text.headlineMedium?.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text('${g.members} members',
                style: text.bodyMedium?.copyWith(color: ArdentColors.fg3)),
            if (g.desc.isNotEmpty) ...[
              const SizedBox(height: ArdentSpacing.s4),
              Text(g.desc,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(color: ArdentColors.fg2)),
            ],
            const SizedBox(height: ArdentSpacing.s6),
            if (_pending)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: ArdentColors.statusPendingBg,
                  borderRadius: BorderRadius.circular(ArdentRadii.md),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top_rounded,
                        size: 18, color: Color(0xFFC77700)),
                    SizedBox(width: 8),
                    Text('Join request pending',
                        style: TextStyle(
                            color: Color(0xFFC77700), fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _joining ? null : _join,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  icon: _joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.group_add_rounded, size: 18),
                  label: const Text('Join group'),
                ),
              ),
            const SizedBox(height: ArdentSpacing.s3),
            Text('Join to see the conversation and post messages.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: ArdentColors.fg3)),
          ],
        ),
      ),
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

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ArdentSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: ArdentColors.fg3),
            const SizedBox(height: ArdentSpacing.s3),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ArdentColors.fg3, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
