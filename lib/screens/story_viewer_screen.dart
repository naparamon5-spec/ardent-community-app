import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Full-screen story viewer — pages through a story's media (images/videos) with
/// the author header and caption overlaid. Tap the right/left edge to advance or
/// go back; tap the ✕ (or swipe past the end) to close.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({super.key, required this.story});

  final Story story;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  final _controller = PageController();
  int _index = 0;

  List<MediaItem> get _media => widget.story.media;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _media.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_index > 0) {
      _controller.previousPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
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
                    onPageChanged: (i) => setState(() => _index = i),
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
          // Progress segments.
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
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Caption overlay.
          if (_currentCaption().isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Text(_currentCaption(),
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.35)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _currentCaption() {
    if (_media.isEmpty) return widget.story.caption;
    final c = _media[_index].caption;
    return (c == null || c.isEmpty) ? widget.story.caption : c;
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
