import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'user_profile_screen.dart';

/// Chats — port of the web chat dock (`components/chat/*`) as a full mobile
/// conversation list.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  static const _previews = <String>[
    'Sounds good — see you at the sportsfest! 🏸',
    'Can you review the onboarding doc?',
    'Thanks for the kudos 🙏',
    'Lunch poll is up, go vote!',
    'Sent the benefits form over.',
    'Great crit today, appreciate it.',
  ];

  static const _times = <String>['now', '5m', '20m', '1h', 'Yesterday', 'Tue'];
  static const _unread = <int>[2, 0, 1, 0, 0, 0];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: ArdentSpacing.s2),
      itemCount: Seed.people.length,
      separatorBuilder: (_, _) =>
          const Divider(indent: 72, height: 1, color: ArdentColors.border),
      itemBuilder: (context, i) {
        final p = Seed.people[i];
        final unread = _unread[i % _unread.length];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4, vertical: 4),
          leading: DsAvatar(
              initials: p.initials, color: p.color, size: 48, online: p.online),
          title: Text(p.name, style: text.titleMedium?.copyWith(fontSize: 15)),
          subtitle: Text(
            _previews[i % _previews.length],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(
              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
              color: unread > 0 ? ArdentColors.fg1 : ArdentColors.fg3,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_times[i % _times.length], style: text.bodySmall),
              const SizedBox(height: 6),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: ArdentColors.accent, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Text('$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                )
              else
                const SizedBox(height: 20),
            ],
          ),
          onTap: () => _openThread(context, p),
        );
      },
    );
  }

  void _openThread(BuildContext context, Person p) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ChatThread(person: p)));
  }
}

/// A single conversation view.
class _ChatThread extends StatefulWidget {
  const _ChatThread({required this.person});
  final Person person;

  @override
  State<_ChatThread> createState() => _ChatThreadState();
}

/// One chat message — text, or an image (rendered as a coloured placeholder
/// since there are no real assets), or a file attachment card.
class _Msg {
  _Msg.text(this.text, this.mine)
      : kind = _MsgKind.text,
        fileName = null,
        photo = null;
  _Msg.photo(this.photo, this.mine)
      : kind = _MsgKind.photo,
        text = null,
        fileName = null;
  _Msg.file(this.fileName, this.mine)
      : kind = _MsgKind.file,
        text = null,
        photo = null;

  final _MsgKind kind;
  final String? text;
  final List<Color>? photo;
  final String? fileName;
  final bool mine;
}

enum _MsgKind { text, photo, file }

class _ChatThreadState extends State<_ChatThread> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final LayerLink _attachLink = LayerLink();
  OverlayEntry? _attachEntry;
  bool _attachOpen = false;

  late final List<_Msg> _messages = [
    _Msg.text('Hey! Are you joining the sportsfest?', false),
    _Msg.text('Definitely — Team Crimson all the way 🔥', true),
    _Msg.photo(const [ArdentColors.navy600, ArdentColors.navy900], false),
    _Msg.text('Nice! Here\'s the schedule 👇', false),
    _Msg.file('sportsfest_schedule.pdf', false),
    _Msg.text('Sounds good — see you there! 🏸', true),
  ];

  @override
  void dispose() {
    _attachEntry?.remove();
    _attachEntry = null;
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_Msg.text(t, true));
      _ctrl.clear();
    });
    _scrollToEnd();
  }

  void _sendPhoto() {
    setState(() => _messages.add(_Msg.photo(
        const [ArdentColors.crimson500, Color(0xFF8E2237)], true)));
    _scrollToEnd();
  }

  void _sendFile() {
    setState(() => _messages.add(_Msg.file('attachment.pdf', true)));
    _scrollToEnd();
  }

  void _toggleAttachMenu() {
    if (_attachEntry != null) {
      _closeAttachMenu();
      return;
    }
    setState(() => _attachOpen = true);
    _attachEntry = OverlayEntry(
      builder: (_) => _AttachMenuOverlay(
        link: _attachLink,
        onClose: _closeAttachMenu,
        onSelect: (v) {
          _closeAttachMenu();
          switch (v) {
            case 'photo':
            case 'camera':
              _sendPhoto();
            case 'file':
            case 'location':
              _sendFile();
          }
        },
      ),
    );
    Overlay.of(context).insert(_attachEntry!);
  }

  void _closeAttachMenu() {
    _attachEntry?.remove();
    _attachEntry = null;
    if (mounted) setState(() => _attachOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => _openProfile(context),
          child: Row(
            children: [
              DsAvatar(initials: p.initials, color: p.color, size: 34, online: p.online),
              const SizedBox(width: ArdentSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(p.online ? 'Active now' : p.lastActive,
                        style: const TextStyle(fontSize: 11, color: ArdentColors.fg3)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
              onPressed: () {}, icon: const Icon(Icons.call_outlined), color: ArdentColors.accent),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.videocam_outlined),
              color: ArdentColors.accent),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _bubble(_messages[i]),
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(ArdentRadii.lg),
      topRight: const Radius.circular(ArdentRadii.lg),
      bottomLeft: Radius.circular(m.mine ? ArdentRadii.lg : ArdentRadii.xs),
      bottomRight: Radius.circular(m.mine ? ArdentRadii.xs : ArdentRadii.lg),
    );
    final maxW = MediaQuery.of(context).size.width * 0.72;

    Widget content;
    switch (m.kind) {
      case _MsgKind.text:
        content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: m.mine ? ArdentColors.accent : ArdentColors.bgSubtle,
            borderRadius: radius,
          ),
          child: Text(m.text!,
              style: TextStyle(
                  fontSize: 14, color: m.mine ? Colors.white : ArdentColors.fg1, height: 1.35)),
        );
      case _MsgKind.photo:
        content = ClipRRect(
          borderRadius: radius,
          child: Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: m.photo!,
              ),
            ),
            child: const Center(
              child: Icon(Icons.image_outlined, color: Colors.white54, size: 34),
            ),
          ),
        );
      case _MsgKind.file:
        content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: m.mine ? ArdentColors.accent : ArdentColors.bgSubtle,
            borderRadius: radius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_rounded,
                  size: 26, color: m.mine ? Colors.white : ArdentColors.accent),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m.fileName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: m.mine ? Colors.white : ArdentColors.fg1)),
                    Text('PDF document',
                        style: TextStyle(
                            fontSize: 11,
                            color: m.mine ? Colors.white70 : ArdentColors.fg3)),
                  ],
                ),
              ),
            ],
          ),
        );
    }

    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: maxW),
        child: content,
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
            CompositedTransformTarget(
              link: _attachLink,
              // Same 48×48 footprint as the sibling IconButtons so the + lines
              // up horizontally with the camera / image icons.
              child: SizedBox(
                width: 48,
                height: 48,
                child: InkWell(
                  onTap: _toggleAttachMenu,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _attachOpen ? ArdentColors.accentSoft : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedRotation(
                        // 1/8 turn = 45°, so the + reads as an × while open.
                        turns: _attachOpen ? 0.125 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child:
                            const Icon(Icons.add_circle, size: 26, color: ArdentColors.accent),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _sendPhoto,
              icon: const Icon(Icons.photo_camera_rounded, size: 24),
              color: ArdentColors.accent,
            ),
            IconButton(
              onPressed: _sendPhoto,
              icon: const Icon(Icons.image_rounded, size: 24),
              color: ArdentColors.accent,
            ),
            // Rounded pill input with emoji + inline send.
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: ArdentColors.bgSubtle,
                  borderRadius: BorderRadius.circular(ArdentRadii.pill),
                ),
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Aa',
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const Icon(Icons.emoji_emotions_outlined,
                        size: 22, color: ArdentColors.fg3),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            // Send when typing, thumbs-up when empty (Messenger behaviour).
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _ctrl,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return IconButton(
                  onPressed: hasText ? _send : _sendLike,
                  icon: Icon(hasText ? Icons.send_rounded : Icons.thumb_up_alt_rounded, size: 24),
                  color: ArdentColors.accent,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendLike() {
    setState(() => _messages.add(_Msg.text('👍', true)));
    _scrollToEnd();
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(person: widget.person)),
    );
  }
}

/// Messenger-style attach popup: its bottom-left corner is pinned to the +
/// button via a [LayerLink], and it scales up from that corner. Tapping the
/// dimmed backdrop closes it.
class _AttachMenuOverlay extends StatefulWidget {
  const _AttachMenuOverlay({
    required this.link,
    required this.onClose,
    required this.onSelect,
  });

  final LayerLink link;
  final VoidCallback onClose;
  final void Function(String value) onSelect;

  @override
  State<_AttachMenuOverlay> createState() => _AttachMenuOverlayState();
}

class _AttachMenuOverlayState extends State<_AttachMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return Stack(
      children: [
        // Tap-away backdrop.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
          ),
        ),
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          // The menu's bottom-left corner attaches to the button's top-left,
          // lifted 8px so it sits just above the +.
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -8),
          child: FadeTransition(
            opacity: _c,
            child: ScaleTransition(
              scale: curved,
              alignment: Alignment.bottomLeft, // grow out of the button corner
              child: Material(
                color: ArdentColors.bgSurface,
                elevation: 8,
                borderRadius: BorderRadius.circular(ArdentRadii.lg),
                child: SizedBox(
                  width: 250,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      _row(Icons.photo_library_rounded, 'Photo & Video',
                          const Color(0xFF2FAE5C), 'photo'),
                      _row(Icons.photo_camera_rounded, 'Camera', ArdentColors.navy600,
                          'camera'),
                      _row(Icons.insert_drive_file_rounded, 'File', ArdentColors.accent,
                          'file'),
                      _row(Icons.location_on_rounded, 'Location', const Color(0xFFC77700),
                          'location'),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, Color color, String value) {
    return InkWell(
      onTap: () => widget.onSelect(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: ArdentColors.fg1)),
          ],
        ),
      ),
    );
  }
}
