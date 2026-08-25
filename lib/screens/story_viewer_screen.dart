import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Full-screen story viewer — pages through a story's media (images/videos) with
/// the author header and caption overlaid. Tap the right/left edge to advance or
/// go back; tap the ✕ (or swipe past the end) to close.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  /// Convenience for opening a single story.
  StoryViewerScreen.single(Story story, {Key? key})
      : this(key: key, stories: [story], initialIndex: 0);

  /// All stories in the row, so the viewer can advance to the next person.
  final List<Story> stories;
  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  PageController _controller = PageController();
  int _index = 0; // media index within the current story
  late int _storyIndex; // which person's story

  /// Story keys the viewer has seen, returned to the feed to grey their rings.
  final Set<String> _viewed = {};

  @override
  void initState() {
    super.initState();
    _storyIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _markViewed();
    _onMediaShown();
  }

  Story get story => widget.stories[_storyIndex];
  List<MediaItem> get _media => story.media;
  MediaItem? get _currentMedia =>
      (_index >= 0 && _index < _media.length) ? _media[_index] : null;

  /// Whether this is the signed-in user's own My Day.
  bool get _isMine =>
      story.isMine ||
      (story.authorId.isNotEmpty &&
          story.authorId == AppSession.instance.me.id);

  /// Records a view for the current item (someone else's story only).
  void _onMediaShown() {
    if (_isMine) return;
    final m = _currentMedia;
    if (m == null || story.id.isEmpty || m.id.isEmpty) return;
    Api.instance.stories.recordMediaView(story.id, m.id);
  }

  String _storyKey(Story s) =>
      s.id.isNotEmpty ? s.id : '${s.name}|${s.initials}';

  void _markViewed() => _viewed.add(_storyKey(story));

  /// Jumps to another person's story, resetting media paging.
  void _goToStory(int i) {
    _controller.dispose();
    _controller = PageController();
    setState(() {
      _storyIndex = i;
      _index = 0;
    });
    _markViewed();
    _onMediaShown();
  }

  /// Quick reactions offered when viewing someone else's story — the exact set
  /// the API accepts.
  static const _quickReactions = ['👍', '❤️', '😆', '😮', '😢', '🙏'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop(_viewed);

  /// A circular arrow button for jumping between people's My Day.
  Widget _navArrow(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 26, color: ArdentColors.navy900),
        ),
      ),
    );
  }

  void _next() {
    if (_index < _media.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else if (_storyIndex < widget.stories.length - 1) {
      _goToStory(_storyIndex + 1); // advance to the next person's My Day
    } else {
      _close();
    }
  }

  void _prev() {
    if (_index > 0) {
      _controller.previousPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else if (_storyIndex > 0) {
      _goToStory(_storyIndex - 1); // back to the previous person's My Day
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = this.story;
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Media pages.
          Positioned.fill(
            child: _media.isEmpty
                ? _captionOnly(story.caption)
                : PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) {
                      setState(() => _index = i);
                      _onMediaShown();
                    },
                    itemCount: _media.length,
                    itemBuilder: (context, i) => _page(_media[i]),
                  ),
          ),
          // Tap zones: left third = previous, right two-thirds = next.
          Positioned.fill(
            child: Row(
              children: [
                SizedBox(
                    width: width / 3,
                    child: GestureDetector(
                        behavior: HitTestBehavior.translucent, onTap: _prev)),
                Expanded(
                    child: GestureDetector(
                        behavior: HitTestBehavior.translucent, onTap: _next)),
              ],
            ),
          ),
          // Previous / next PERSON arrows (Facebook My Day style).
          if (_storyIndex > 0)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _navArrow(Icons.chevron_left_rounded,
                    () => _goToStory(_storyIndex - 1)),
              ),
            ),
          if (_storyIndex < widget.stories.length - 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _navArrow(Icons.chevron_right_rounded,
                    () => _goToStory(_storyIndex + 1)),
              ),
            ),
          // Progress segments — only shown when this person has multiple media.
          if (_media.length > 1)
            Positioned(
              top: 0,
              left: 8,
              right: 8,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      for (var i = 0; i < _media.length; i++)
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i <= _index ? Colors.white : Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          // Header: author + close.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 8, 8),
                child: Row(
                  children: [
                    DsAvatar(
                        initials: story.initials, color: story.color, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(story.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: _close,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Caption + "Seen by" / reactions footer.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentCaption().isNotEmpty) ...[
                      Text(_currentCaption(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, height: 1.35)),
                      const SizedBox(height: 14),
                    ],
                    if (_isMine) _seenBy(story) else _reactionRow(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Owner footer: "Seen by N" → tappable viewers list.
  // -------------------------------------------------------------------------

  Widget _seenBy(Story story) {
    final seen = _currentMedia?.viewCount ?? 0;
    return InkWell(
      onTap: seen == 0 ? null : _openViewers,
      borderRadius: BorderRadius.circular(ArdentRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.remove_red_eye_rounded,
                color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(
              seen == 0
                  ? 'No views yet'
                  : 'Seen by $seen ${seen == 1 ? 'person' : 'people'}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (seen > 0) ...[
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white70, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  /// Fetches and shows who watched the current item (author-only endpoint).
  void _openViewers() {
    final m = _currentMedia;
    if (m == null || m.id.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ArdentColors.bgSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ArdentRadii.xl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, controller) => FutureBuilder<List<dynamic>>(
          future: Api.instance.stories.mediaViewers(story.id, m.id),
          builder: (context, snap) {
            final loading =
                snap.connectionState == ConnectionState.waiting;
            final rows = snap.data ?? const [];
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ArdentColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_red_eye_rounded,
                          size: 18, color: ArdentColors.fg2),
                      const SizedBox(width: 8),
                      Text('Seen by ${m.viewCount ?? rows.length}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : rows.isEmpty
                          ? ListView(
                              controller: controller,
                              children: const [
                                SizedBox(height: 40),
                                Center(
                                  child: Text('No views yet.',
                                      style:
                                          TextStyle(color: ArdentColors.fg3)),
                                ),
                              ],
                            )
                          : ListView.builder(
                              controller: controller,
                              itemCount: rows.length,
                              itemBuilder: (context, i) {
                                final row = asMap(rows[i]);
                                final p = personFromJson(
                                    row['user'] ?? row['viewer'] ?? row);
                                final reaction = '${row['reaction'] ??
                                    row['emoji'] ?? ''}';
                                return ListTile(
                                  leading: DsAvatar(
                                      initials: p.initials,
                                      color: p.color,
                                      size: 40),
                                  title: Text(p.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle:
                                      p.role.isNotEmpty ? Text(p.role) : null,
                                  trailing: reaction.isEmpty
                                      ? null
                                      : Text(reaction,
                                          style: const TextStyle(fontSize: 20)),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Viewer footer (someone else's story): quick reactions.
  // -------------------------------------------------------------------------

  Widget _reactionRow() {
    final mine = _currentMedia?.myReaction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mine != null && mine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text('You reacted $mine',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final emoji in _quickReactions) _reactionChoice(emoji),
          ],
        ),
      ],
    );
  }

  Widget _reactionChoice(String emoji) {
    final active = _currentMedia?.myReaction == emoji;
    return GestureDetector(
      onTap: () => _sendReaction(emoji),
      child: AnimatedScale(
        scale: active ? 1.25 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: active
              ? BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                )
              : null,
          child: Text(emoji, style: const TextStyle(fontSize: 30)),
        ),
      ),
    );
  }

  void _sendReaction(String emoji) {
    final m = _currentMedia;
    if (m == null || story.id.isEmpty || m.id.isEmpty) return;
    final previous = m.myReaction;
    // Toggle locally: same emoji clears it.
    setState(() => m.myReaction = previous == emoji ? null : emoji);
    Api.instance.stories.reactToMedia(story.id, m.id, emoji).catchError((_) {
      if (mounted) setState(() => m.myReaction = previous);
      return <String, dynamic>{};
    });
  }

  String _currentCaption() {
    if (_media.isEmpty) return story.caption;
    final c = _media[_index].caption;
    return (c == null || c.isEmpty) ? story.caption : c;
  }

  Widget _page(MediaItem m) {
    if (m.isVideo) {
      // No video player dependency yet — show a poster with a play affordance.
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64),
      );
    }
    return Center(
      child: Image.network(
        m.url,
        fit: BoxFit.contain,
        width: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        },
        errorBuilder: (context, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
        ),
      ),
    );
  }

  Widget _captionOnly(String caption) {
    return Container(
      color: ArdentColors.navy900,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Text(
        caption.isEmpty ? 'No content' : caption,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.4),
      ),
    );
  }
}
