import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'user_profile_screen.dart';

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

class _ReplyInfo {
  const _ReplyInfo({required this.author, required this.text});
  final String author;
  final String text;
}

/// One @mention carried by a message. The chat payload gives mentions as either
/// full user objects or bare ids, so we keep whichever we got and resolve it to
/// a real [Person] (with an id to open the profile) against the group roster at
/// render time.
class _Mention {
  const _Mention({this.id, this.name});
  final String? id;
  final String? name;
}

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.author,
    required this.mine,
    this.id = '',
    this.time,
    this.media = const [],
    this.reactions = const {},
    this.myReaction,
    this.replyTo,
    this.mentions = const [],
    this.system = false,
  });
  final String id;
  final String text;
  final Person author;
  final bool mine;

  /// A server-generated activity line ("X added Y to the group", "X left…") —
  /// rendered as a centered notice, not a chat bubble.
  final bool system;
  final DateTime? time;
  final List<MediaItem> media;

  /// People @mentioned in [text] — used to bold those spans and make them tap
  /// through to the mentioned person's profile.
  final List<_Mention> mentions;

  /// Emoji → count, aggregated across everyone who reacted.
  final Map<String, int> reactions;

  /// The emoji the current user reacted with, if any.
  final String? myReaction;

  /// A short preview of the message this one replies to, if any.
  final _ReplyInfo? replyTo;

  bool get hasMedia => media.isNotEmpty;
  bool get hasReactions => reactions.isNotEmpty;

  _ChatMessage copyWith({Map<String, int>? reactions, String? myReaction, bool clearMyReaction = false}) {
    return _ChatMessage(
      id: id,
      text: text,
      author: author,
      mine: mine,
      time: time,
      media: media,
      reactions: reactions ?? this.reactions,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
      replyTo: replyTo,
      mentions: mentions,
      system: system,
    );
  }
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _attachKey = GlobalKey();
  List<_ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  _ChatMessage? _replyingTo;
  bool _joining = false;
  String? _error;

  late bool _joined = widget.group.isDirect || widget.group.joined;
  late bool _pending = widget.group.pending;

  /// The group's members, used to resolve @mentions to a full [Person] — both
  /// to render the name bold and to open their profile when tapped (the message
  /// text/payload may carry only a mention user id).
  List<Person> _members = const [];

  /// Group-chat socket events aren't pinned down in the API doc (only presence
  /// and calls are), so we listen on the common candidate names. An unmatched
  /// name is simply never delivered — harmless.
  static const _chatEvents = [
    'group:message',
    'group:messages',
    'group:activity',
    'group:update',
    'chat:message',
    'message:new',
    'message',
    'groupMessage',
  ];

  @override
  void initState() {
    super.initState();
    if (_joined) {
      _loadMessages();
      _loadMembers();
      _subscribeRealtime();
    } else {
      _loading = false; // show the join panel
    }
  }

  void _subscribeRealtime() {
    for (final e in _chatEvents) {
      Api.instance.realtime.on(e, _onRealtimeChat);
    }
  }

  void _unsubscribeRealtime() {
    for (final e in _chatEvents) {
      Api.instance.realtime.off(e);
    }
  }

  /// A chat/activity socket event arrived. Refresh only when it concerns this
  /// group (or carries no group id we can check).
  void _onRealtimeChat(dynamic data) {
    if (!mounted || !_joined) return;
    final map = asMap(data is Map ? (data['message'] ?? data) : data);
    final gid = '${map['groupId'] ?? map['group'] ?? map['conversationId'] ?? ''}';
    if (gid.isNotEmpty && gid != widget.group.id) return;
    _refreshMessages();
    // A membership change may also add/remove people we resolve mentions from.
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final raw = await Api.instance.groups.members(widget.group.id);
      final people = raw
          .map((e) {
            final map = asMap(e);
            // Members may arrive as bare users or as membership wrappers.
            return personFromJson(map['user'] ?? map['member'] ?? e);
          })
          .where((p) => p.name.trim().isNotEmpty && p.name != 'Unknown')
          .toList();
      if (!mounted) return;
      setState(() => _members = people);
    } catch (_) {
      // Non-fatal: mention bolding falls back to a generic @token match.
    }
  }

  @override
  void dispose() {
    _unsubscribeRealtime();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  _ChatMessage _map(dynamic raw) {
    final m = asMap(raw);
    final author = personFromJson(m['author'] ?? m['user'] ?? m['sender']);
    final t = m['createdAt'] ?? m['created_at'] ?? m['time'] ?? m['sentAt'];
    final (reactions, mine) = _parseReactions(m['reactions']);
    final type =
        '${m['type'] ?? m['messageType'] ?? m['kind'] ?? m['event'] ?? m['action'] ?? ''}'
            .toLowerCase();
    final rawText =
        (m['text'] ?? m['body'] ?? m['message'] ?? m['content'] ?? '').toString();
    // The backend labels activity lines by prefixing the text with "System:"
    // (e.g. "System: Dhariel added Ramon to the group."). Detect that too, and
    // strip the prefix so the centered notice reads cleanly.
    final systemPrefix = RegExp(r'^\s*system\s*:\s*', caseSensitive: false);
    final looksSystemText = systemPrefix.hasMatch(rawText);
    final system = m['system'] == true ||
        m['isSystem'] == true ||
        m['isActivity'] == true ||
        looksSystemText ||
        const {'system', 'event', 'notice', 'activity', 'announcement'}
            .contains(type) ||
        type.startsWith('member') ||
        type.contains('added') ||
        type.contains('removed') ||
        type.contains('invite') ||
        type.contains('promot') ||
        type.contains('join') ||
        type.contains('left') ||
        type.contains('leave');
    final cleanedText =
        looksSystemText ? rawText.replaceFirst(systemPrefix, '') : rawText;
    return _ChatMessage(
      id: '${m['id'] ?? m['_id'] ?? ''}',
      text: system && cleanedText.trim().isEmpty
          ? _composeSystemText(m, type)
          : cleanedText,
      author: author,
      mine: !system &&
          author.id.isNotEmpty &&
          author.id == AppSession.instance.me.id,
      time: parseManilaTime(t),
      media: mediaFromJson(m),
      reactions: reactions,
      myReaction: mine ?? (m['myReaction'] == null ? null : '${m['myReaction']}'),
      replyTo: _parseReply(m['replyTo'] ?? m['replyMessage'] ?? m['parent']),
      mentions: _parseMentions(m['mentions'] ?? m['mentionedUsers'] ?? m['mentionUsers']),
      system: system,
    );
  }

  /// Mentions carried by a message — either full user objects (name + id) or
  /// bare ids/names. A value with a space is treated as a display name;
  /// otherwise as an id/slug to resolve against the roster later.
  List<_Mention> _parseMentions(dynamic raw) {
    if (raw is! List) return const [];
    final out = <_Mention>[];
    for (final e in raw) {
      if (e is Map) {
        final p = personFromJson(e);
        out.add(_Mention(
          id: p.id.isEmpty ? null : p.id,
          name: p.name == 'Unknown' ? null : p.name,
        ));
      } else if (e != null) {
        final s = '$e'.trim();
        if (s.isEmpty) continue;
        out.add(s.contains(' ') ? _Mention(name: s) : _Mention(id: s));
      }
    }
    return out;
  }

  /// Builds a readable activity line ("Dhariel added Rachelle to the group")
  /// when the server sends a system message without ready-made text.
  String _composeSystemText(Map m, String type) {
    final actor = personFromJson(m['actor'] ?? m['author'] ?? m['user'] ?? m['sender']).name;
    final target = personFromJson(
            m['target'] ?? m['targetUser'] ?? m['member'] ?? m['subject'] ?? m['addedUser'] ?? m['to'])
        .name;
    final a = actor == 'Unknown' ? 'Someone' : actor;
    final hasTarget = target.isNotEmpty && target != 'Unknown';
    if (type.contains('add') || type.contains('invite')) {
      return hasTarget ? '$a added $target to the group.' : '$a added a member.';
    }
    if (type.contains('remove')) {
      return hasTarget ? '$a removed $target from the group.' : '$a removed a member.';
    }
    if (type.contains('promot')) {
      return hasTarget ? '$a made $target an admin.' : '$a updated an admin.';
    }
    if (type.contains('join')) return '$a joined the group.';
    if (type.contains('left') || type.contains('leave')) return '$a left the group.';
    return hasTarget ? '$a · $target' : a;
  }

  /// Aggregates reactions from either a list of `{emoji, count/users, mine}`
  /// objects or an `{emoji: count}` map, and finds the current user's emoji.
  (Map<String, int>, String?) _parseReactions(dynamic raw) {
    final counts = <String, int>{};
    String? mine;
    final meId = AppSession.instance.me.id;
    if (raw is List) {
      for (final e in raw) {
        final r = asMap(e);
        final emoji = '${r['emoji'] ?? r['type'] ?? ''}';
        if (emoji.isEmpty) continue;
        final users = r['users'] ?? r['userIds'] ?? r['by'];
        final count = r['count'] != null
            ? int.tryParse('${r['count']}') ?? 0
            : (users is List ? users.length : 1);
        counts[emoji] = (counts[emoji] ?? 0) + count;
        final byMe = r['reactedByMe'] == true ||
            r['mine'] == true ||
            r['byMe'] == true ||
            (users is List &&
                users.any((u) => u is Map
                    ? '${u['id'] ?? u['_id']}' == meId
                    : '$u' == meId));
        if (byMe) mine = emoji;
      }
    } else if (raw is Map) {
      raw.forEach((k, v) {
        final emoji = '$k';
        if (v is List) {
          counts[emoji] = v.length;
          if (v.any((u) => u is Map
              ? '${u['id'] ?? u['_id']}' == meId
              : '$u' == meId)) {
            mine = emoji;
          }
        } else {
          counts[emoji] = int.tryParse('$v') ?? 0;
        }
      });
    }
    return (counts, mine);
  }

  _ReplyInfo? _parseReply(dynamic raw) {
    if (raw == null) return null;
    final r = asMap(raw);
    final author = personFromJson(r['author'] ?? r['user'] ?? r['sender']);
    final text = '${r['text'] ?? r['body'] ?? ''}';
    if (author.name.isEmpty && text.isEmpty) return null;
    return _ReplyInfo(
      author: author.name.isEmpty ? 'Message' : author.name,
      text: text.isEmpty ? 'Attachment' : text,
    );
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await Api.instance.groups.messages(widget.group.id, limit: 50);
      // Oldest → newest so the most recent message sits at the bottom,
      // regardless of the order the API returns.
      final mapped = raw.map(_map).toList()
        ..sort((a, b) {
          if (a.time == null && b.time == null) return 0;
          if (a.time == null) return -1;
          if (b.time == null) return 1;
          return a.time!.compareTo(b.time!);
        });
      if (!mounted) return;
      setState(() {
        _messages = mapped;
        _loading = false;
      });
      _scrollToEnd(animate: false);
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

  /// Re-fetches messages *without* the full-screen spinner — used for live
  /// socket updates (new messages, "X added Y to the group" activity) so the
  /// thread refreshes in place instead of flashing a loader.
  Future<void> _refreshMessages() async {
    if (!_joined) return;
    try {
      final raw = await Api.instance.groups.messages(widget.group.id, limit: 50);
      final mapped = raw.map(_map).toList()
        ..sort((a, b) {
          if (a.time == null && b.time == null) return 0;
          if (a.time == null) return -1;
          if (b.time == null) return 1;
          return a.time!.compareTo(b.time!);
        });
      if (!mounted) return;
      final wasAtBottom = !_scroll.hasClients ||
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 120;
      setState(() => _messages = mapped);
      if (wasAtBottom) _scrollToEnd();
    } catch (_) {
      // Non-fatal: the next manual load or reconnect will reconcile.
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
        _loadMembers();
        _subscribeRealtime();
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

  void _scrollToEnd({bool animate = true}) {
    void toBottom() {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (animate) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        // On open, land at the bottom immediately, then correct again once
        // late layout (e.g. images) has settled.
        toBottom();
        WidgetsBinding.instance.addPostFrameCallback((_) => toBottom());
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) toBottom();
        });
      }
    });
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _sending) return;
    final replyToId = _replyingTo?.id;
    final optimistic = _ChatMessage(
        text: t,
        author: AppSession.instance.me,
        mine: true,
        time: manilaNow(),
        replyTo: _replyingTo == null
            ? null
            : _ReplyInfo(
                author: _replyingTo!.mine ? 'You' : _replyingTo!.author.name,
                text: _replyingTo!.text.isEmpty
                    ? 'Attachment'
                    : _replyingTo!.text));
    setState(() {
      _messages = [..._messages, optimistic];
      _ctrl.clear();
      _sending = true;
      _replyingTo = null;
    });
    _scrollToEnd();
    try {
      await Api.instance.groups.sendMessage(widget.group.id,
          text: t, replyToId: (replyToId?.isEmpty ?? true) ? null : replyToId);
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
                        style: const TextStyle(fontSize: 11, color: ArdentColors.fg3))
                  else if (g.online || g.lastActive.isNotEmpty)
                    Text(g.online ? 'Active now' : g.lastActive,
                        style: TextStyle(
                            fontSize: 11,
                            color: g.online
                                ? const Color(0xFF2FAE5C)
                                : ArdentColors.fg3)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call_rounded),
            onPressed: _startCall,
          ),
          IconButton(
            tooltip: 'Shared content',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: _openSharedContent,
          ),
        ],
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
      return DsAvatar(
          initials: initialsFrom(g.name),
          color: g.color,
          size: size,
          imageUrl: g.photoUrl);
    }
    if (g.photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(ArdentRadii.sm),
        child: Image.network(
          g.photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _groupAvatarFallback(g, size),
        ),
      );
    }
    return _groupAvatarFallback(g, size);
  }

  Widget _groupAvatarFallback(Group g, double size) {
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
    return Container(
      color: ArdentColors.bgApp,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
            ArdentSpacing.s3, ArdentSpacing.s4, ArdentSpacing.s3, ArdentSpacing.s4),
        itemCount: _messages.length,
        itemBuilder: (context, i) {
          final m = _messages[i];
          final prev = i > 0 ? _messages[i - 1] : null;
          final next = i < _messages.length - 1 ? _messages[i + 1] : null;

          final newDay = prev == null || !_sameDay(prev.time, m.time);

          // System activity lines render as a centered notice, not a bubble.
          if (m.system) {
            return Column(
              children: [
                if (newDay) _daySeparator(m.time),
                _systemMessage(m),
              ],
            );
          }

          // Group consecutive messages by the same sender within ~5 minutes.
          final firstInGroup = prev == null ||
              prev.mine != m.mine ||
              prev.author.id != m.author.id ||
              prev.system ||
              _gap(prev.time, m.time);
          final lastInGroup = next == null ||
              next.mine != m.mine ||
              next.author.id != m.author.id ||
              next.system ||
              _gap(m.time, next.time);

          return Column(
            children: [
              if (newDay) _daySeparator(m.time),
              _bubble(
                m,
                showAuthor: !widget.group.isDirect && firstInGroup,
                showAvatar: !m.mine && lastInGroup,
                firstInGroup: firstInGroup,
                lastInGroup: lastInGroup,
                isLast: next == null,
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _gap(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return b.difference(a).inMinutes.abs() >= 5;
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Centered gray notice for server activity ("X added Y to the group").
  Widget _systemMessage(_ChatMessage m) {
    final label = m.text.trim();
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ArdentSpacing.s2),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ArdentColors.bgSubtle,
            borderRadius: BorderRadius.circular(ArdentRadii.pill),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, height: 1.3, color: ArdentColors.fg3),
          ),
        ),
      ),
    );
  }

  Widget _daySeparator(DateTime? t) {
    final label = _dayLabel(t);
    if (label.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ArdentSpacing.s3),
      child: Row(
        children: [
          const Expanded(child: Divider(color: ArdentColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ArdentColors.fg3)),
          ),
          const Expanded(child: Divider(color: ArdentColors.border)),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime? t) {
    if (t == null) return '';
    final now = manilaNow();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}${t.year == now.year ? '' : ', ${t.year}'}';
  }

  static String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
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

  Widget _bubble(
    _ChatMessage m, {
    required bool showAuthor,
    required bool showAvatar,
    required bool firstInGroup,
    required bool lastInGroup,
    bool isLast = false,
  }) {
    const big = Radius.circular(ArdentRadii.lg);
    const small = Radius.circular(ArdentRadii.xs);
    // Round the outer corners fully; flatten the "stacked" side within a group.
    final radius = m.mine
        ? BorderRadius.only(
            topLeft: big,
            bottomLeft: big,
            topRight: firstInGroup ? big : small,
            bottomRight: lastInGroup ? big : small,
          )
        : BorderRadius.only(
            topRight: big,
            bottomRight: big,
            topLeft: firstInGroup ? big : small,
            bottomLeft: lastInGroup ? big : small,
          );
    final maxW = MediaQuery.of(context).size.width * 0.72;

    final bubble = Column(
      crossAxisAlignment:
          m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showAuthor && !m.mine)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 3),
            child: Text(m.author.name,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: m.author.color)),
          ),
        if (m.replyTo != null) _replyPreview(m),
        // Keep the react affordance on the same row as the bubble body so it
        // stays vertically centered against the message, not dropped down to
        // the timestamp beneath it.
        if (!m.mine && isLast)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _bubbleWithBadge(m, radius)),
              _reactButton(m),
            ],
          )
        else
          _bubbleWithBadge(m, radius),
        if (m.hasReactions) const SizedBox(height: 12),
        if (lastInGroup && m.time != null)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Text(_clock(m.time!),
                style: const TextStyle(fontSize: 10.5, color: ArdentColors.fg3)),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: lastInGroup ? 10 : 2),
      child: Row(
        mainAxisAlignment:
            m.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Incoming: reserve avatar gutter so grouped bubbles stay aligned.
          if (!m.mine) ...[
            SizedBox(
              width: 30,
              child: showAvatar
                  ? DsAvatar(
                      initials: m.author.initials,
                      color: m.author.color,
                      size: 28,
                      imageUrl: m.author.avatarUrl)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Builder(
                builder: (bctx) => GestureDetector(
                  onLongPressStart: (_) => _showMessageMenu(bctx, m),
                  child: bubble,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A small "react" smiley beside the latest message — tinted to match the
  /// bubble so it reads as an affordance (Messenger-style). Opens the quick
  /// reactions pill anchored to itself.
  Widget _reactButton(_ChatMessage m) {
    final tint = m.mine ? ArdentColors.accent : m.author.color;
    return Builder(
      builder: (bctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkResponse(
          radius: 20,
          onTap: () => _showQuickReact(bctx, m),
          child: Icon(Icons.add_reaction_outlined,
              size: 18, color: tint.withValues(alpha: 0.75)),
        ),
      ),
    );
  }

  /// The inner content of a bubble: image/file attachments, a link chip, or a
  /// plain text bubble.
  Widget _bubbleBody(_ChatMessage m, BorderRadius radius) {
    if (m.hasMedia) {
      return Column(
        crossAxisAlignment:
            m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          for (final item in m.media)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _mediaTile(m, item, radius),
            ),
          if (m.text.trim().isNotEmpty) _textBubble(m, radius),
        ],
      );
    }
    if (_isUrl(m.text.trim())) return _linkBubble(m, radius);
    return _textBubble(m, radius);
  }

  Widget _textBubble(_ChatMessage m, BorderRadius radius) {
    final base = TextStyle(
        fontSize: 14.5,
        color: m.mine ? Colors.white : ArdentColors.fg1,
        height: 1.35);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: m.mine ? ArdentColors.accent : ArdentColors.bgSurface,
        borderRadius: radius,
        border: m.mine ? null : Border.all(color: ArdentColors.border),
      ),
      child: _MentionText(
        text: m.text,
        baseStyle: base,
        mentionStyle: base.copyWith(
          fontWeight: FontWeight.w800,
          color: m.mine ? Colors.white : ArdentColors.fg1,
        ),
        mentions: [
          for (final men in m.mentions) ?_personForMention(men),
        ],
        roster: _members,
        onTapUser: _openPerson,
      ),
    );
  }

  /// Resolves a parsed [_Mention] to a real [Person] — by id or name against
  /// the group roster, falling back to a minimal person built from whatever the
  /// mention carried (so bolding still works before the roster loads).
  Person? _personForMention(_Mention men) {
    for (final p in _members) {
      if (men.id != null && p.id == men.id) return p;
    }
    if (men.name != null) {
      final lower = men.name!.toLowerCase();
      for (final p in _members) {
        if (p.name.toLowerCase() == lower) return p;
      }
      return Person(
        id: men.id ?? '',
        name: men.name!,
        initials: initialsFrom(men.name!),
        role: '',
        color: avatarColorFor(men.id ?? men.name!),
      );
    }
    return null;
  }

  /// Opens a member's profile from a tapped @mention.
  void _openPerson(Person p) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(person: p)),
    );
  }

  Widget _linkBubble(_ChatMessage m, BorderRadius radius) {
    final onAccent = m.mine ? Colors.white : ArdentColors.accent;
    return InkWell(
      borderRadius: radius,
      onTap: () => _openUrl(m.text.trim()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: m.mine ? ArdentColors.accent : ArdentColors.bgSurface,
          borderRadius: radius,
          border: m.mine ? null : Border.all(color: ArdentColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_rounded, size: 18, color: onAccent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(m.text.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      decoration: TextDecoration.underline,
                      color: onAccent)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaTile(_ChatMessage m, MediaItem item, BorderRadius radius) {
    if (item.isImage) {
      return GestureDetector(
        onTap: () => _openImage(item),
        child: ClipRRect(
          borderRadius: radius,
          child: Image.network(
            item.url,
            fit: BoxFit.cover,
            width: 220,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 220,
                height: 180,
                color: ArdentColors.bgSubtle,
                child: const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            },
            errorBuilder: (context, _, _) => Container(
              width: 220,
              height: 120,
              color: ArdentColors.bgSubtle,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined,
                  color: ArdentColors.fg3, size: 28),
            ),
          ),
        ),
      );
    }
    // File / document card.
    final name = item.fileName?.isNotEmpty == true
        ? item.fileName!
        : item.url.split('/').last;
    return InkWell(
      borderRadius: radius,
      onTap: () => _openUrl(item.url),
      child: Container(
        constraints: const BoxConstraints(minWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: m.mine ? ArdentColors.accent : ArdentColors.bgSurface,
          borderRadius: radius,
          border: m.mine ? null : Border.all(color: ArdentColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_rounded,
                size: 26, color: m.mine ? Colors.white : ArdentColors.accent),
            const SizedBox(width: 10),
            Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: m.mine ? Colors.white : ArdentColors.fg1)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download_rounded,
                size: 18,
                color: m.mine ? Colors.white70 : ArdentColors.fg3),
          ],
        ),
      ),
    );
  }

  static bool _isUrl(String s) =>
      s.isNotEmpty &&
      !s.contains(' ') &&
      (s.startsWith('http://') || s.startsWith('https://'));

  static const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  Widget _replyPreview(_ChatMessage m) {
    final r = m.replyTo!;
    final onAccent = m.mine ? Colors.white : ArdentColors.fg1;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: m.mine
            ? Colors.white.withValues(alpha: 0.18)
            : ArdentColors.bgSubtle,
        borderRadius: BorderRadius.circular(ArdentRadii.sm),
        border: Border(
          left: BorderSide(
              color: m.mine ? Colors.white : ArdentColors.accent, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(r.author,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: onAccent)),
          Text(r.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  color: onAccent.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  /// The bubble body with a Messenger-style reaction badge overlapping its
  /// lower-right corner.
  Widget _bubbleWithBadge(_ChatMessage m, BorderRadius radius) {
    final body = _bubbleBody(m, radius);
    if (!m.hasReactions) return body;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        body,
        Positioned(
          right: 6,
          bottom: -11,
          child: _reactionBadge(m),
        ),
      ],
    );
  }

  Widget _reactionBadge(_ChatMessage m) {
    final emojis = m.reactions.keys.take(3).join();
    final total = m.reactions.values.fold<int>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: ArdentColors.bgSurface,
        borderRadius: BorderRadius.circular(ArdentRadii.pill),
        border: Border.all(color: ArdentColors.bgApp, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emojis, style: const TextStyle(fontSize: 12)),
          if (total > 1) ...[
            const SizedBox(width: 2),
            Text('$total',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ArdentColors.fg2)),
          ],
        ],
      ),
    );
  }

  /// Messenger-style long-press: dims the thread, lifts the pressed message,
  /// floats the reaction pill above it and the Reply/Delete actions below it.
  void _showMessageMenu(BuildContext bctx, _ChatMessage m) {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final box = bctx.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final rect = topLeft & box.size;

    final size = overlayBox.size;
    final pad = MediaQuery.of(context).padding;
    const gap = 10.0;
    const pillH = 56.0;
    // Reaction pill sits above the message; clamp to stay on-screen.
    var pillTop = rect.top - pillH - gap;
    if (pillTop < pad.top + 8) pillTop = pad.top + 8;
    // Actions card sits below the message; clamp to stay on-screen.
    final actionCount = (m.mine && m.id.isNotEmpty) ? 2 : 1;
    final menuH = 12.0 + actionCount * 52.0;
    var menuTop = rect.bottom + gap;
    if (menuTop + menuH > size.height - pad.bottom - 8) {
      menuTop = size.height - pad.bottom - 8 - menuH;
    }

    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Message actions',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, a, b) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, a, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(
          opacity: anim,
          child: Stack(
            children: [
              // The highlighted (lifted) message, at its original spot.
              Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                child: IgnorePointer(child: _spotlightMessage(m)),
              ),
              // Reaction pill above.
              Positioned(
                top: pillTop,
                left: m.mine ? null : rect.left,
                right: m.mine ? size.width - rect.right : null,
                child: ScaleTransition(
                  scale: curved,
                  alignment:
                      m.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: _reactionsPill(ctx, m),
                ),
              ),
              // Reply / Delete actions below.
              Positioned(
                top: menuTop,
                left: m.mine ? null : rect.left,
                right: m.mine ? size.width - rect.right : null,
                child: ScaleTransition(
                  scale: curved,
                  alignment: Alignment.topCenter,
                  child: _actionsCard(ctx, m),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Quick-react: just the reaction pill, anchored to the react button.
  void _showQuickReact(BuildContext anchorCtx, _ChatMessage m) {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final box = anchorCtx.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final rect = topLeft & box.size;
    final size = overlayBox.size;
    final pad = MediaQuery.of(context).padding;
    const pillH = 56.0;
    const pillW = 264.0;
    const gap = 8.0;

    var top = rect.top - pillH - gap;
    if (top < pad.top + 8) top = rect.bottom + gap;
    var left = rect.center.dx - pillW / 2;
    left = left.clamp(8.0, size.width - pillW - 8);

    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'React',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, a, b) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, a, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(
          children: [
            Positioned(
              top: top,
              left: left,
              child: FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: curved,
                  child: _reactionsPill(ctx, m),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// A clean copy of the message shown lifted above the dimmed background.
  Widget _spotlightMessage(_ChatMessage m) {
    final radius = BorderRadius.circular(ArdentRadii.lg);
    return Column(
      crossAxisAlignment:
          m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (m.replyTo != null) _replyPreview(m),
        _bubbleBody(m, radius),
      ],
    );
  }

  Widget _reactionsPill(BuildContext ctx, _ChatMessage m) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: ArdentColors.bgSurface,
          borderRadius: BorderRadius.circular(ArdentRadii.pill),
          border: Border.all(color: ArdentColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in _quickReactions)
              InkWell(
                borderRadius: BorderRadius.circular(ArdentRadii.pill),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _react(m, emoji);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: m.myReaction == emoji
                        ? ArdentColors.accentSoft
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionsCard(BuildContext ctx, _ChatMessage m) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 210,
        decoration: BoxDecoration(
          color: ArdentColors.bgSurface,
          borderRadius: BorderRadius.circular(ArdentRadii.lg),
          border: Border.all(color: ArdentColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuAction(ctx, Icons.reply_rounded, 'Reply', () {
              setState(() => _replyingTo = m);
            }),
            if (m.mine && m.id.isNotEmpty) ...[
              const Divider(height: 1, color: ArdentColors.border),
              _menuAction(ctx, Icons.delete_outline_rounded, 'Delete',
                  () => _confirmDelete(m),
                  danger: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _menuAction(BuildContext ctx, IconData icon, String label,
      VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? ArdentColors.crimson500 : ArdentColors.fg1;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(ctx).pop();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 21, color: color),
              const SizedBox(width: 14),
              Text(label,
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  void _react(_ChatMessage m, String emoji) {
    final idx = _messages.indexOf(m);
    if (idx < 0) return;
    final counts = Map<String, int>.from(m.reactions);
    String? mine = m.myReaction;
    if (mine == emoji) {
      final c = (counts[emoji] ?? 1) - 1;
      if (c <= 0) {
        counts.remove(emoji);
      } else {
        counts[emoji] = c;
      }
      mine = null;
    } else {
      if (mine != null) {
        final c = (counts[mine] ?? 1) - 1;
        if (c <= 0) {
          counts.remove(mine);
        } else {
          counts[mine] = c;
        }
      }
      counts[emoji] = (counts[emoji] ?? 0) + 1;
      mine = emoji;
    }
    setState(() => _messages[idx] = m.copyWith(
        reactions: counts, myReaction: mine, clearMyReaction: mine == null));
    if (m.id.isEmpty) return;
    Api.instance.groups
        .reactToMessage(widget.group.id, m.id, emoji)
        .catchError((_) {
      if (mounted) _loadMessages();
      return <String, dynamic>{};
    });
  }

  Future<void> _confirmDelete(_ChatMessage m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be removed for everyone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ArdentColors.crimson500),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || m.id.isEmpty) return;
    final backup = List<_ChatMessage>.from(_messages);
    setState(() => _messages.remove(m));
    try {
      await Api.instance.groups.deleteMessage(widget.group.id, m.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _messages = backup);
      _snack(e.message);
    }
  }

  void _startCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling ${widget.group.name}…')),
    );
  }

  void _openSharedContent() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _SharedContentScreen(group: widget.group, messages: _messages),
      ),
    );
  }

  void _showAttachSheet() {
    // Anchor a floating popup just above the plus icon.
    final box = _attachKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final anchor = box.localToGlobal(box.size.topCenter(Offset.zero),
        ancestor: overlay);

    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Attach',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.08),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, a, b) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, a, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(
          children: [
            Positioned(
              left: 12,
              bottom: overlay.size.height - anchor.dy + 8,
              child: FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: curved,
                  alignment: Alignment.bottomLeft,
                  child: _attachMenu(ctx),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _attachMenu(BuildContext ctx) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 232,
        decoration: BoxDecoration(
          color: ArdentColors.bgSurface,
          borderRadius: BorderRadius.circular(ArdentRadii.lg),
          border: Border.all(color: ArdentColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _attachItem(ctx, 'Link', Icons.link_rounded,
                const Color(0xFF3B82F6), _attachLink),
            _attachItem(ctx, 'Image', Icons.image_rounded,
                const Color(0xFF10B981), _attachImage),
            _attachItem(ctx, 'File', Icons.attach_file_rounded,
                const Color(0xFFF59E0B), _attachFile),
          ],
        ),
      ),
    );
  }

  Widget _attachItem(BuildContext ctx, String label, IconData icon, Color tint,
      Future<void> Function() action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ArdentRadii.md),
        onTap: () {
          Navigator.of(ctx).pop();
          action();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ArdentRadii.md),
                ),
                child: Icon(icon, size: 20, color: tint),
              ),
              const SizedBox(width: ArdentSpacing.s3),
              Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ArdentColors.fg1)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _attachImage() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await _sendAttachment(
        bytes: bytes,
        filename: picked.name,
        contentType: 'image/${_ext(picked.name, fallback: 'jpeg')}',
      );
    } catch (e) {
      _snack('Could not attach image');
    }
  }

  Future<void> _attachFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      final file = res?.files.singleOrNull;
      if (file == null || file.bytes == null) return;
      await _sendAttachment(
        bytes: file.bytes!,
        filename: file.name,
        contentType: null,
      );
    } catch (e) {
      _snack('Could not attach file');
    }
  }

  Future<void> _attachLink() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add link'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://example.com',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (url == null || url.isEmpty) return;
    final normalized =
        url.startsWith('http://') || url.startsWith('https://') ? url : 'https://$url';
    _ctrl.text = normalized;
    await _send();
  }

  /// Uploads a single file attachment, then appends the server's message.
  Future<void> _sendAttachment({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    if (_sending) return;
    final replyToId = _replyingTo?.id;
    setState(() {
      _sending = true;
      _replyingTo = null;
    });
    try {
      final raw = await Api.instance.groups.sendMessage(
        widget.group.id,
        file: (bytes: bytes, filename: filename, contentType: contentType),
        replyToId: (replyToId?.isEmpty ?? true) ? null : replyToId,
      );
      if (!mounted) return;
      setState(() => _messages = [..._messages, _map(raw)]);
      _scrollToEnd();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _ext(String name, {required String fallback}) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return fallback;
    return name.substring(i + 1).toLowerCase();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('Could not open link');
  }

  void _openImage(MediaItem m) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ImageViewer(url: m.url)),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null) _replyBanner(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  key: _attachKey,
                  tooltip: 'Attach',
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 26),
                  color: ArdentColors.fg3,
                  onPressed: _showAttachSheet,
                ),
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
          ],
        ),
      ),
    );
  }

  Widget _replyBanner() {
    final r = _replyingTo!;
    final who = r.mine ? 'yourself' : r.author.name;
    final preview = r.text.trim().isNotEmpty
        ? r.text.trim()
        : (r.hasMedia ? 'Attachment' : '');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: ArdentColors.bgSubtle,
        borderRadius: BorderRadius.circular(ArdentRadii.sm),
        border: const Border(
            left: BorderSide(color: ArdentColors.accent, width: 3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 18, color: ArdentColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Replying to $who',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ArdentColors.accent)),
                if (preview.isNotEmpty)
                  Text(preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: ArdentColors.fg2)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: ArdentColors.fg3,
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom viewer for a chat image.
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, _, _) => const Icon(
                Icons.broken_image_outlined, color: Colors.white54, size: 48),
          ),
        ),
      ),
    );
  }
}

/// A single link shared in the conversation, with the author who posted it.
class _SharedLink {
  const _SharedLink({required this.url, required this.author});
  final String url;
  final Person author;
}

/// A file shared in the conversation, with the author who posted it.
class _SharedFile {
  const _SharedFile({required this.item, required this.author});
  final MediaItem item;
  final Person author;
}

/// Shared content for a conversation, split across Images / Files / Links tabs.
///
/// Scans the loaded [messages] and surfaces every image attachment, file/video
/// attachment, and link (URLs found in message text) — newest first — the way a
/// web chat's shared-media panel does.
class _SharedContentScreen extends StatelessWidget {
  const _SharedContentScreen({required this.group, required this.messages});
  final Group group;
  final List<_ChatMessage> messages;

  /// Matches http(s) URLs anywhere inside a message body.
  static final _urlRegExp = RegExp(r'https?://[^\s]+', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final images = <MediaItem>[];
    final files = <_SharedFile>[];
    final links = <_SharedLink>[];

    // Walk newest → oldest so each tab lists the most recent content first.
    for (final m in messages.reversed) {
      for (final item in m.media) {
        if (item.isImage) {
          images.add(item);
        } else {
          files.add(_SharedFile(item: item, author: m.author));
        }
      }
      for (final match in _urlRegExp.allMatches(m.text)) {
        links.add(_SharedLink(url: match.group(0)!, author: m.author));
      }
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(group.name),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Images'),
              Tab(text: 'Files'),
              Tab(text: 'Links'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ImagesTab(images: images),
            _FilesTab(files: files),
            _LinksTab(links: links),
          ],
        ),
      ),
    );
  }
}

/// Grid of every image attachment in the conversation.
class _ImagesTab extends StatelessWidget {
  const _ImagesTab({required this.images});
  final List<MediaItem> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const _CenteredMessage(
          icon: Icons.photo_library_outlined, message: 'No images yet.');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: images.length,
      itemBuilder: (context, i) {
        final item = images[i];
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _ImageViewer(url: item.url)),
          ),
          child: Container(
            color: ArdentColors.bgSubtle,
            child: Image.network(
              item.url,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: ArdentColors.fg3,
                  size: 28),
            ),
          ),
        );
      },
    );
  }
}

/// List of every file / video attachment in the conversation.
class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.files});
  final List<_SharedFile> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const _CenteredMessage(
          icon: Icons.insert_drive_file_outlined, message: 'No files yet.');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: ArdentSpacing.s2),
      itemCount: files.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: ArdentColors.border),
      itemBuilder: (context, i) {
        final f = files[i];
        final item = f.item;
        final name = item.fileName?.isNotEmpty == true
            ? item.fileName!
            : item.url.split('/').last;
        return ListTile(
          leading: Icon(
            item.isVideo
                ? Icons.play_circle_outline_rounded
                : Icons.insert_drive_file_rounded,
            color: ArdentColors.accent,
          ),
          title: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: ArdentColors.fg1)),
          subtitle: Text(f.author.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ArdentColors.fg3)),
          trailing:
              const Icon(Icons.download_rounded, color: ArdentColors.fg3),
          onTap: () => _launch(context, item.url),
        );
      },
    );
  }
}

/// List of every link shared in the conversation.
class _LinksTab extends StatelessWidget {
  const _LinksTab({required this.links});
  final List<_SharedLink> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const _CenteredMessage(
          icon: Icons.link_rounded, message: 'No links yet.');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: ArdentSpacing.s2),
      itemCount: links.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: ArdentColors.border),
      itemBuilder: (context, i) {
        final link = links[i];
        return ListTile(
          leading: const Icon(Icons.link_rounded, color: ArdentColors.accent),
          title: Text(link.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: ArdentColors.accent,
                  decoration: TextDecoration.underline)),
          subtitle: Text(link.author.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ArdentColors.fg3)),
          onTap: () => _launch(context, link.url),
        );
      },
    );
  }
}

/// Opens [url] in an external app, showing a snackbar if it can't be launched.
Future<void> _launch(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok = uri != null &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Could not open link')));
  }
}

/// Renders message text with @mentions in bold, each tapping through to the
/// mentioned person's profile. Only *resolved* mentions are styled — a
/// confirmed mention (carried by the message) matches with or without a leading
/// `@`, a roster member matches only when written as `@Name`, and anything else
/// (e.g. a stray `@m`) stays plain, mirroring the web client.
class _MentionText extends StatefulWidget {
  const _MentionText({
    required this.text,
    required this.baseStyle,
    required this.mentionStyle,
    required this.mentions,
    required this.roster,
    required this.onTapUser,
  });

  final String text;
  final TextStyle baseStyle;
  final TextStyle mentionStyle;

  /// People the message explicitly mentions (matched with or without `@`).
  final List<Person> mentions;

  /// The full group roster (matched only when written as `@Name`).
  final List<Person> roster;

  final void Function(Person) onTapUser;

  @override
  State<_MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<_MentionText> {
  final List<TapGestureRecognizer> _recognizers = [];
  static final _word = RegExp(r'[\p{L}\p{N}_]', unicode: true);

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Recognizers are recreated every build; drop the previous batch first.
    _disposeRecognizers();
    final text = widget.text;

    // name(lowercase) → person. Confirmed mentions match with/without '@';
    // roster names only match when prefixed with '@'.
    final confirmed = <String, Person>{};
    for (final p in widget.mentions) {
      if (p.name.trim().isNotEmpty) confirmed[p.name.toLowerCase()] = p;
    }
    final rosterOnly = <String, Person>{};
    for (final p in widget.roster) {
      final k = p.name.toLowerCase();
      if (p.name.trim().isNotEmpty && !confirmed.containsKey(k)) rosterOnly[k] = p;
    }

    if (confirmed.isEmpty && rosterOnly.isEmpty) {
      return Text.rich(TextSpan(text: text, style: widget.baseStyle));
    }

    // Original-case display names, longest first so multi-word names win.
    final originalByLower = <String, String>{};
    for (final p in [...widget.mentions, ...widget.roster]) {
      originalByLower.putIfAbsent(p.name.toLowerCase(), () => p.name);
    }
    final confirmedNames = confirmed.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final rosterNames = rosterOnly.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final alts = <String>[
      for (final n in confirmedNames) '@?${RegExp.escape(originalByLower[n]!)}',
      for (final n in rosterNames) '@${RegExp.escape(originalByLower[n]!)}',
    ];
    final re = RegExp(alts.join('|'), unicode: true, caseSensitive: false);

    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in re.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      final raw = match.group(0)!;
      final stripped = raw.startsWith('@') ? raw.substring(1) : raw;
      final person = confirmed[stripped.toLowerCase()] ?? rosterOnly[stripped.toLowerCase()];
      if (person == null) continue;

      // Don't match inside a larger word (e.g. an email local-part).
      final before = start > 0 ? text[start - 1] : '';
      final after = end < text.length ? text[end] : '';
      final bounded = (before.isEmpty || (!_word.hasMatch(before) && before != '@')) &&
          (after.isEmpty || !_word.hasMatch(after));
      if (!bounded) continue;

      if (start > last) spans.add(TextSpan(text: text.substring(last, start)));
      final rec = TapGestureRecognizer()..onTap = () => widget.onTapUser(person);
      _recognizers.add(rec);
      spans.add(TextSpan(text: stripped, style: widget.mentionStyle, recognizer: rec));
      last = end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return Text.rich(TextSpan(style: widget.baseStyle, children: spans));
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
