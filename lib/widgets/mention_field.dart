import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import 'ds.dart';

/// A [TextEditingController] that renders resolved `@Name` mentions in **bold**
/// strong-foreground text inside the field, so a picked mention stands out from
/// the plain body text as you keep typing (mirroring how the posted content
/// shows mentions). Feed it the set of mention display names via [mentionNames];
/// [MentionField] keeps that in sync as mentions are inserted or removed.
class MentionTextEditingController extends TextEditingController {
  MentionTextEditingController({super.text});

  List<String> _mentionNames = const [];

  List<String> get mentionNames => _mentionNames;
  set mentionNames(List<String> value) {
    if (listEquals(_mentionNames, value)) return;
    _mentionNames = List.of(value);
    notifyListeners(); // repaint so the bold styling updates
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    if (_mentionNames.isEmpty || text.isEmpty) {
      return TextSpan(text: text, style: base);
    }
    final bold = GoogleFonts.montserrat(
      textStyle: base,
      fontWeight: FontWeight.w700,
      color: ArdentColors.fg1,
    );

    // Collect the [start, end) ranges of every `@Name` occurrence.
    final ranges = <List<int>>[];
    for (final name in _mentionNames) {
      if (name.isEmpty) continue;
      final needle = '@$name';
      var from = 0;
      while (true) {
        final at = text.indexOf(needle, from);
        if (at < 0) break;
        ranges.add([at, at + needle.length]);
        from = at + needle.length;
      }
    }
    if (ranges.isEmpty) return TextSpan(text: text, style: base);
    ranges.sort((a, b) => a[0].compareTo(b[0]));

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final r in ranges) {
      if (r[0] < cursor) continue; // overlapping match (e.g. name is a prefix)
      if (r[0] > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, r[0]), style: base));
      }
      spans.add(TextSpan(text: text.substring(r[0], r[1]), style: bold));
      cursor = r[1];
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: base));
    }
    return TextSpan(style: base, children: spans);
  }
}

/// A text field with `@`-mention autocomplete, mirroring the web client's
/// shared `MentionInput`. Use it in edit boxes (posts, comments, replies) as
/// well as create flows.
///
/// The suggestion list is rendered in an [Overlay] anchored under the field, so
/// the widget itself is a single-child (just a [TextField]) and never grows the
/// surrounding layout — safe inside tight rows (a comment "pill") and scrolling
/// bottom sheets alike.
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

  /// Anchors the floating suggestion list to the text field.
  final LayerLink _link = LayerLink();
  final OverlayPortalController _overlay = OverlayPortalController();
  final GlobalKey _fieldKey = GlobalKey();

  /// Max height the suggestion list is allowed to take.
  static const double _maxListHeight = 240;

  /// Width of the field, captured from layout so the overlay can match it.
  double _fieldWidth = 280;

  TextEditingController get _text => widget.controller;

  @override
  void initState() {
    super.initState();
    _mentioned.addAll(widget.initialMentions);
    _text.addListener(_onTextChanged);
    _syncMentionNames();
    // Report the seeded set once the first frame settles.
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitMentions());
  }

  /// Pushes the current mention display names into the controller (when it's a
  /// [MentionTextEditingController]) so `@Name` renders bold in the field.
  void _syncMentionNames() {
    final c = _text;
    if (c is MentionTextEditingController) {
      c.mentionNames = _mentioned.map((p) => p.name).toList();
    }
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
      _syncMentionNames();
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

  /// Shows/hides the overlay to match the current suggestion state. Called only
  /// from event handlers (never during build), so toggling is safe.
  void _syncOverlay() {
    final shouldShow = _mentionQuery != null && _mentionResults.isNotEmpty;
    if (shouldShow && !_overlay.isShowing) {
      _overlay.show();
    } else if (!shouldShow && _overlay.isShowing) {
      _overlay.hide();
    }
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
      _syncOverlay();
      return;
    }
    setState(() => _mentionQuery = query);
    if (query == null) {
      setState(() => _mentionResults = const []);
      _syncOverlay();
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
      _syncOverlay();
    } catch (_) {
      if (mounted && reqId == _mentionReqId) {
        setState(() => _mentionResults = const []);
        _syncOverlay();
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
    _syncMentionNames();
    setState(() {
      _mentionQuery = null;
      _mentionResults = const [];
    });
    _syncOverlay();
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
    return OverlayPortal(
      controller: _overlay,
      overlayChildBuilder: (context) => _overlaySuggestions(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
            _fieldWidth = constraints.maxWidth;
          }
          return CompositedTransformTarget(
            link: _link,
            child: TextField(
              key: _fieldKey,
              controller: _text,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              minLines: widget.minLines,
              maxLines: widget.maxLines ?? widget.minLines,
              style: widget.style,
              decoration: decoration,
            ),
          );
        },
      ),
    );
  }

  /// The top (dy) and bottom (dy + line height) of the line the caret is on,
  /// measured from the field's top with a [TextPainter] that mirrors the field's
  /// text and width — so the suggestion list can hug the current typing line.
  ({double top, double bottom}) _caretLine() {
    final text = _text.text;
    final sel = _text.selection;
    final offset = (sel.isValid ? sel.baseOffset : text.length)
        .clamp(0, text.length);
    final style = widget.style ??
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16);
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _fieldWidth);
    final caret =
        painter.getOffsetForCaret(TextPosition(offset: offset), Rect.zero);
    final top = caret.dy;
    final bottom = caret.dy + painter.preferredLineHeight;
    painter.dispose();
    return (top: top, bottom: bottom);
  }

  /// Floating `@mention` picker, anchored just under the current caret line in
  /// the [Overlay] so it never affects the surrounding layout. Height-bounded
  /// and scrollable.
  Widget _overlaySuggestions() {
    final textTheme = Theme.of(context).textTheme;
    final line = _caretLine();

    // Decide whether to drop the list below the caret line or flip it above —
    // so a field near the bottom of the screen (e.g. the chat composer) doesn't
    // hide the list behind the keyboard.
    var openUpward = false;
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final media = MediaQuery.of(context);
      final fieldTop = box.localToGlobal(Offset.zero).dy;
      final viewportBottom = media.size.height - media.viewInsets.bottom;
      final spaceBelow = viewportBottom - (fieldTop + line.bottom);
      openUpward = spaceBelow < _maxListHeight && fieldTop + line.top > _maxListHeight;
    }

    return Positioned(
      width: _fieldWidth,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        // Hug the caret line: drop down from its bottom, or (when there's no room
        // below) rise up from its top.
        targetAnchor: Alignment.topLeft,
        followerAnchor: openUpward ? Alignment.bottomLeft : Alignment.topLeft,
        offset: Offset(0, openUpward ? line.top - 6 : line.bottom + 6),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: ArdentColors.bgSurface,
              borderRadius: BorderRadius.circular(ArdentRadii.md),
              border: Border.all(color: ArdentColors.border),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            constraints: const BoxConstraints(maxHeight: _maxListHeight),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final p in _mentionResults)
                  InkWell(
                    onTap: () => _insertMention(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                if (p.role.isNotEmpty)
                                  Text(p.role,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall),
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
          ),
        ),
      ),
    );
  }
}
