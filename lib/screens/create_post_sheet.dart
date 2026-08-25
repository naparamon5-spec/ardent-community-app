import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// A Facebook-style "Create post" sheet that slides up from the bottom, with a
/// compose area and Photo / Poll / Kudos options below. Returns the
/// `POST /posts` request payload (JSON fields), or null if cancelled.
Future<Map<String, dynamic>?> showCreatePostSheet(BuildContext context,
    {PostKind initialKind = PostKind.text}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ArdentColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ArdentRadii.xl)),
    ),
    builder: (_) => _CreatePostSheet(initialKind: initialKind),
  );
}

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({required this.initialKind});
  final PostKind initialKind;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  late PostKind _kind = widget.initialKind;
  final _text = TextEditingController();
  final _kudosTo = TextEditingController();
  final _optionA = TextEditingController();
  final _optionB = TextEditingController();
  bool _photoAttached = false;
  final _annTitle = TextEditingController();
  bool _pinned = true;

  // ---- @mention state ----
  /// The active `@…` query being typed (null when not mentioning).
  String? _mentionQuery;
  List<Person> _mentionResults = const [];
  int _mentionReqId = 0;

  /// People inserted as mentions, so we can send their ids to the backend.
  final List<Person> _mentioned = [];

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
    _annTitle.addListener(() => setState(() {}));
    if (_kind == PostKind.photo) _photoAttached = true;
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    _kudosTo.dispose();
    _optionA.dispose();
    _optionB.dispose();
    _annTitle.dispose();
    super.dispose();
  }

  /// Detects an active `@…` token just before the caret and refreshes the
  /// mention suggestions.
  void _onTextChanged() {
    setState(() {});
    final sel = _text.selection;
    String? query;
    if (sel.isValid && sel.isCollapsed && sel.baseOffset >= 0) {
      final upToCaret = _text.text.substring(0, sel.baseOffset);
      final match = RegExp(r'(?:^|\s)@([\p{L}\p{N}._-]*)$', unicode: true)
          .firstMatch(upToCaret);
      if (match != null) query = match.group(1);
    }
    if (query == _mentionQuery) return;
    setState(() => _mentionQuery = query);
    if (query == null) {
      setState(() => _mentionResults = const []);
    } else {
      _searchMentions(query);
    }
  }

  Future<void> _searchMentions(String query) async {
    final reqId = ++_mentionReqId;
    try {
      final raw = await Api.instance.users.list(search: query.isEmpty ? null : query);
      if (!mounted || reqId != _mentionReqId) return;
      setState(() =>
          _mentionResults = raw.map(personFromJson).take(6).toList());
    } catch (_) {
      if (mounted && reqId == _mentionReqId) {
        setState(() => _mentionResults = const []);
      }
    }
  }

  /// Replaces the active `@query` with `@Name ` and records the mention.
  void _insertMention(Person p) {
    final sel = _text.selection;
    if (!sel.isValid || !sel.isCollapsed) return;
    final caret = sel.baseOffset;
    final upToCaret = _text.text.substring(0, caret);
    final match =
        RegExp(r'@([\p{L}\p{N}._-]*)$', unicode: true).firstMatch(upToCaret);
    if (match == null) return;
    final newText = _text.text.replaceRange(match.start, caret, '@${p.name} ');
    final newCaret = match.start + p.name.length + 2;
    _text.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCaret),
    );
    if (!_mentioned.any((m) => m.id == p.id)) _mentioned.add(p);
    setState(() {
      _mentionQuery = null;
      _mentionResults = const [];
    });
  }

  /// Mentioned user ids whose `@Name` tag still appears in the text.
  List<String> _activeMentionIds() {
    final text = _text.text;
    final ids = <String>[];
    for (final p in _mentioned) {
      if (p.id.isNotEmpty && text.contains('@${p.name}') && !ids.contains(p.id)) {
        ids.add(p.id);
      }
    }
    return ids;
  }

  bool get _canPost {
    if (_kind == PostKind.announcement) {
      return _annTitle.text.trim().isNotEmpty && _text.text.trim().isNotEmpty;
    }
    if (_text.text.trim().isNotEmpty) return true;
    if (_kind == PostKind.photo && _photoAttached) return true;
    if (_kind == PostKind.poll &&
        _optionA.text.trim().isNotEmpty &&
        _optionB.text.trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  void _submit() {
    final text = _text.text.trim();
    // Map the composer state to the `POST /posts` payload documented in
    // docs/API_DOCUMENTATION.md. Photo posts need a real file (no image picker
    // wired yet), so a photo without an attachment is sent as a text post.
    final payload = <String, dynamic>{'text': text};
    final mentions = _activeMentionIds();
    if (mentions.isNotEmpty) payload['mentions'] = mentions;
    switch (_kind) {
      case PostKind.announcement:
        payload['type'] = 'announcement';
        payload['title'] = _annTitle.text.trim();
        payload['pinned'] = _pinned;
      case PostKind.kudos:
        payload['type'] = 'kudos';
        payload['kudosTo'] = _kudosTo.text.trim().isEmpty ? 'the team' : _kudosTo.text.trim();
      case PostKind.poll:
        payload['type'] = 'poll';
        payload['pollOptions'] = [_optionA.text.trim(), _optionB.text.trim()];
      case PostKind.photo:
      case PostKind.file:
      case PostKind.text:
        payload['type'] = 'text';
    }
    Navigator.of(context).pop(payload);
  }

  String get _hint => switch (_kind) {
        PostKind.kudos => 'Say why they deserve kudos…',
        PostKind.poll => 'Ask your question…',
        PostKind.photo => 'Say something about your photo…',
        PostKind.announcement => 'Write the announcement details…',
        _ => "What's on your mind, ${AppSession.instance.me.name.split(' ').first}?",
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Sit above the keyboard.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Grab handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ArdentColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // Header bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    Expanded(
                      child: Text('Create post',
                          textAlign: TextAlign.center,
                          style: text.titleLarge?.copyWith(fontSize: 16)),
                    ),
                    _canPost
                        ? ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            ),
                            child: const Text('Post'),
                          )
                        : const SizedBox(
                            width: 72,
                            child: Center(
                              child: Text('Post',
                                  style: TextStyle(
                                      color: ArdentColors.fg3, fontWeight: FontWeight.w600)),
                            ),
                          ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scrollable compose body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(ArdentSpacing.s4),
                  children: [
                    Row(
                      children: [
                        DsAvatar(
                            initials: AppSession.instance.me.initials,
                            color: AppSession.instance.me.color,
                            size: 44),
                        const SizedBox(width: ArdentSpacing.s3),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppSession.instance.me.name,
                                style: text.titleMedium?.copyWith(fontSize: 15)),
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ArdentColors.bgSubtle,
                                      borderRadius: BorderRadius.circular(ArdentRadii.sm),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.public,
                                            size: 12, color: ArdentColors.fg2),
                                        const SizedBox(width: 4),
                                        Text('Community',
                                            style: text.bodySmall
                                                ?.copyWith(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  if (_kind == PostKind.announcement) ...[
                                    const SizedBox(width: 6),
                                    _pinButton(text),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: ArdentSpacing.s3),
                    if (_kind == PostKind.kudos) _kudosToField(),
                    if (_kind == PostKind.announcement) _announcementTitleField(text),
                    TextField(
                      controller: _text,
                      autofocus: true,
                      minLines: 3,
                      maxLines: null,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w400),
                      decoration: InputDecoration(
                        hintText: _hint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (_mentionQuery != null && _mentionResults.isNotEmpty)
                      _mentionSuggestions(text),
                    if (_kind == PostKind.photo) _photoTile(),
                    if (_kind == PostKind.poll) _pollFields(),
                  ],
                ),
              ),
              // "Add to your post" options
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Add to your post',
                            style: text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600, color: ArdentColors.fg1)),
                      ),
                      _option(Icons.photo_library_rounded, const Color(0xFF2FAE5C), 'Photo',
                          PostKind.photo),
                      _option(Icons.bar_chart_rounded, ArdentColors.navy600, 'Poll',
                          PostKind.poll),
                      _option(Icons.emoji_events_rounded, const Color(0xFFC77700), 'Kudos',
                          PostKind.kudos),
                      _option(Icons.campaign_rounded, ArdentColors.accent, 'Announcement',
                          PostKind.announcement),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Inline @mention picker shown under the compose field.
  Widget _mentionSuggestions(TextTheme text) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: ArdentColors.bgSurface,
        borderRadius: BorderRadius.circular(ArdentRadii.md),
        border: Border.all(color: ArdentColors.border),
      ),
      child: Column(
        children: [
          for (final p in _mentionResults)
            InkWell(
              onTap: () => _insertMention(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    DsAvatar(initials: p.initials, color: p.color, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          if (p.role.isNotEmpty)
                            Text(p.role,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.alternate_email_rounded,
                        size: 16, color: ArdentColors.fg3),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _option(IconData icon, Color color, String tip, PostKind kind) {
    final active = _kind == kind;
    return IconButton(
      tooltip: tip,
      onPressed: () => setState(() {
        _kind = active ? PostKind.text : kind;
        if (_kind == PostKind.photo) _photoAttached = true;
      }),
      icon: Icon(icon, color: color),
      style: IconButton.styleFrom(
        backgroundColor: active ? color.withValues(alpha: 0.14) : Colors.transparent,
      ),
    );
  }

  Widget _kudosToField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _kudosTo,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.emoji_events_rounded, color: Color(0xFFC77700), size: 20),
          hintText: 'Kudos to… (name)',
        ),
      ),
    );
  }

  Widget _announcementTitleField(TextTheme text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _annTitle,
        style: text.titleLarge?.copyWith(fontSize: 18),
        decoration: const InputDecoration(
          hintText: 'Announcement title',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  /// Pin chip beside the audience — tap to toggle; lights up red when pinned.
  Widget _pinButton(TextTheme text) {
    return GestureDetector(
      onTap: () => setState(() => _pinned = !_pinned),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _pinned ? ArdentColors.accent : ArdentColors.bgSubtle,
          borderRadius: BorderRadius.circular(ArdentRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.push_pin_rounded,
                size: 12, color: _pinned ? Colors.white : ArdentColors.fg2),
            const SizedBox(width: 4),
            Text(
              _pinned ? 'Pinned' : 'Pin',
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: _pinned ? Colors.white : ArdentColors.fg2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoTile() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Container(
          decoration: BoxDecoration(
            color: ArdentColors.bgSubtle,
            borderRadius: BorderRadius.circular(ArdentRadii.md),
            border: Border.all(color: ArdentColors.border),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 34, color: ArdentColors.fg3),
              SizedBox(height: 6),
              Text('Tap to add photos', style: TextStyle(color: ArdentColors.fg3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pollFields() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          TextField(
            controller: _optionA,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Option 1'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _optionB,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Option 2'),
          ),
        ],
      ),
    );
  }
}
