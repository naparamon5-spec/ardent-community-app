import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import 'ds.dart';

/// A text field with `@`-mention autocomplete, mirroring the web client's
/// shared `MentionInput`. Use it in edit boxes (posts, comments, replies) as
/// well as create flows.
///
/// The critical behaviour for editing: seed [initialMentions] with the mentions
/// the text already carries. The server resolves mentions from ids and a
/// `PATCH` **replaces** the stored list with whatever ids it receives, so an
/// editor that opened without knowing the existing mentions would send an empty
/// list and silently strip every `@Name` still spelled out in the text.
///
/// [onMentionsChanged] fires with the mentions whose `@Name` is still present in
/// the text — the parent stores this and, on save, sends `mentions` as the ids
/// of that list.
class MentionField extends StatefulWidget {
  const MentionField({
    super.key,
    required this.controller,
    this.initialMentions = const [],
    this.onMentionsChanged,
    this.hintText,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines,
    this.style,
    this.decoration,
    this.focusNode,
  });

  final TextEditingController controller;

  /// Mentions the text already carries when the editor opens.
  final List<Person> initialMentions;

  /// Fired with the mentions still spelled out in the text (parent keeps this).
  final ValueChanged<List<Person>>? onMentionsChanged;

  final String? hintText;
  final bool autofocus;
  final int minLines;
  final int? maxLines;
  final TextStyle? style;
  final InputDecoration? decoration;
  final FocusNode? focusNode;

  @override
  State<MentionField> createState() => _MentionFieldState();
}

class _MentionFieldState extends State<MentionField> {
  /// People inserted (or seeded) as mentions, so we can send their ids.
  final List<Person> _mentioned = [];

  /// The active `@…` query being typed (null when not mentioning).
  String? _mentionQuery;
  List<Person> _mentionResults = const [];
  int _mentionReqId = 0;

  TextEditingController get _text => widget.controller;

  @override
  void initState() {
    super.initState();
    _mentioned.addAll(widget.initialMentions);
    _text.addListener(_onTextChanged);
    // Report the seeded set once the first frame settles.
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitMentions());
  }

  @override
  void didUpdateWidget(MentionField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onTextChanged);
      _text.addListener(_onTextChanged);
    }
    // Re-seed only when the id set actually changes — comparing by content, not
    // reference, so a parent re-render doesn't wipe freshly picked mentions.
    if (!_sameIds(old.initialMentions, widget.initialMentions)) {
      _mentioned
        ..clear()
        ..addAll(widget.initialMentions);
      _emitMentions();
    }
  }

  bool _sameIds(List<Person> a, List<Person> b) {
    final sa = a.map((p) => p.id).toSet();
    final sb = b.map((p) => p.id).toSet();
    return sa.length == sb.length && sa.containsAll(sb);
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    super.dispose();
  }

  /// Detects an active `@…` token just before the caret and refreshes the
  /// mention suggestions.
  void _onTextChanged() {
    final sel = _text.selection;
    String? query;
    if (sel.isValid && sel.isCollapsed && sel.baseOffset >= 0) {
      final upToCaret = _text.text.substring(0, sel.baseOffset);
      final match = RegExp(r'(?:^|\s)@([\p{L}\p{N}._-]*)$', unicode: true)
          .firstMatch(upToCaret);
      if (match != null) query = match.group(1);
    }
    _emitMentions();
    if (query == _mentionQuery) {
      setState(() {});
      return;
    }
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
      final raw =
          await Api.instance.users.list(search: query.isEmpty ? null : query);
      if (!mounted || reqId != _mentionReqId) return;
      setState(() => _mentionResults = raw.map(personFromJson).take(6).toList());
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
    _emitMentions();
  }

  /// Mentions whose `@Name` tag still appears in the text (deduped by id).
  List<Person> _activeMentions() {
    final text = _text.text;
    final out = <Person>[];
    for (final p in _mentioned) {
      if (p.name.isNotEmpty &&
          text.contains('@${p.name}') &&
          !out.any((m) => m.id == p.id)) {
        out.add(p);
      }
    }
    return out;
  }

  void _emitMentions() => widget.onMentionsChanged?.call(_activeMentions());

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration ??
        InputDecoration(
          hintText: widget.hintText,
          isDense: true,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _text,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          minLines: widget.minLines,
          maxLines: widget.maxLines ?? widget.minLines,
          style: widget.style,
          decoration: decoration,
        ),
        if (_mentionQuery != null && _mentionResults.isNotEmpty)
          _mentionSuggestions(),
      ],
    );
  }

  /// Inline @mention picker shown under the field.
  Widget _mentionSuggestions() {
    final text = Theme.of(context).textTheme;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    DsAvatar(
                        initials: p.initials,
                        color: p.color,
                        size: 34,
                        imageUrl: p.avatarUrl),
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
}
