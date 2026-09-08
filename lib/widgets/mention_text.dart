import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/people_directory.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';

/// Renders free text with `@Full Name` mentions in bold, tapping through to the
/// mentioned person. Mirrors the web client's `MentionText`: a token is bolded
/// only when the name after `@` matches a real person — either one the item
/// explicitly [mentions] or anyone in the shared [PeopleDirectory]. The `@` is
/// dropped from the rendered name, which keeps the surrounding text's colour and
/// is shown at weight 700.
class MentionText extends StatefulWidget {
  const MentionText({
    super.key,
    required this.text,
    required this.baseStyle,
    this.mentions = const [],
    this.onTapUser,
  });

  final String text;
  final TextStyle baseStyle;

  /// People the item explicitly mentions (may be empty — the directory still
  /// resolves names written in the text).
  final List<Person> mentions;

  final void Function(Person)? onTapUser;

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    // Ensure the directory is loaded, then rebuild so names resolve.
    PeopleDirectory.instance.addListener(_onDirectory);
    PeopleDirectory.instance.ensureLoaded();
  }

  void _onDirectory() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PeopleDirectory.instance.removeListener(_onDirectory);
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
    _disposeRecognizers();
    final text = widget.text;

    // Candidate people: explicit mentions first, then directory people not
    // already covered — exactly the web client's set.
    final byName = <String, Person>{};
    for (final p in widget.mentions) {
      if (p.name.trim().isNotEmpty) byName.putIfAbsent(p.name, () => p);
    }
    if (text.contains('@')) {
      for (final p in PeopleDirectory.instance.people) {
        if (p.name.trim().isNotEmpty) byName.putIfAbsent(p.name, () => p);
      }
    }

    if (byName.isEmpty || !text.contains('@')) {
      return Text(text, style: widget.baseStyle);
    }

    // Longest names first so multi-word names win over any prefix.
    final names = byName.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = '@(${names.map(RegExp.escape).join('|')})';
    final re = RegExp(pattern);

    // Montserrat Black (w900) in strong near-black so a mention clearly stands
    // out. Built via GoogleFonts so the heavy weight variant actually loads.
    final mentionStyle = GoogleFonts.montserrat(
      textStyle: widget.baseStyle,
      fontWeight: FontWeight.w700,
      color: ArdentColors.fg1,
    );
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in re.allMatches(text)) {
      final start = match.start;
      if (start > last) {
        spans.add(TextSpan(text: text.substring(last, start)));
      }
      final name = match.group(1)!;
      final person = byName[name];
      TapGestureRecognizer? rec;
      if (person != null && widget.onTapUser != null) {
        rec = TapGestureRecognizer()..onTap = () => widget.onTapUser!(person);
        _recognizers.add(rec);
      }
      // Render the name without the leading '@', bold — matching the web.
      spans.add(TextSpan(text: name, style: mentionStyle, recognizer: rec));
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return Text.rich(TextSpan(style: widget.baseStyle, children: spans));
  }
}
