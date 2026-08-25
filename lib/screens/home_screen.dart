import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import '../widgets/post_card.dart';
import 'create_post_sheet.dart';
import 'story_composer_screen.dart';
import 'story_viewer_screen.dart';

/// Home feed — backed by `GET /posts` (feed) and `GET /stories`, with the
/// composer posting to `POST /posts`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Post> _posts = [];
  List<Story> _stories = [];

  /// Keys of stories the user has already opened this session — their ring is
  /// drawn gray (viewed) instead of the coloured gradient, but stays in the row.
  final Set<String> _viewedStories = {};

  String _storyKey(Story s) =>
      s.id.isNotEmpty ? s.id : '${s.name}|${s.initials}';

  void _toast(String message, {IconData icon = Icons.check_circle_rounded}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  Future<void> _loadFeed() async {
    final results = await Future.wait([
      Api.instance.posts.feed(limit: 30),
      Api.instance.stories.list().catchError((_) => <dynamic>[]),
    ]);
    _posts = (results[0]).map(postFromJson).toList();
    _stories = (results[1]).map(storyFromJson).toList();
  }

  /// Opens the composer, sends the draft to the backend, and prepends the
  /// created post to the feed.
  Future<void> _openComposer({PostKind kind = PostKind.text}) async {
    final draft = await showCreatePostSheet(context, initialKind: kind);
    if (!mounted || draft == null) return;
    try {
      final created = await Api.instance.posts.create(fields: draft);
      if (!mounted) return;
      setState(() => _posts.insert(0, postFromJson(created)));
      _toast('Your post is now live in the feed');
    } on ApiException catch (e) {
      if (!mounted) return;
      final message = e.isForbidden
          ? "You don't have permission to post to the feed."
          : e.message;
      _toast(message, icon: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AsyncView<void>(
      loader: _loadFeed,
      builder: (context, _, reload) {
        final pinned = _posts.where((p) => p.pinned).cast<Post?>().firstWhere(
              (p) => true,
              orElse: () => null,
            );
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            children: [
              if (pinned != null) ...[
                _pinnedBanner(text, pinned),
                const SizedBox(height: ArdentSpacing.s4),
              ],
              _storiesRow(),
              const SizedBox(height: ArdentSpacing.s3),
              _composer(text),
              const SizedBox(height: ArdentSpacing.s4),
              if (_posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: ArdentSpacing.s8),
                  child: EmptyState(
                      message: 'No posts yet. Be the first to share something.',
                      icon: Icons.dynamic_feed_rounded),
                )
              else
                for (final p in _posts) ...[
                  PostCard(post: p),
                  const SizedBox(height: ArdentSpacing.s4),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _pinnedBanner(TextTheme text, Post pinned) {
    final label = pinned.title.isNotEmpty ? pinned.title : pinned.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ArdentColors.red50,
        border: Border.all(color: ArdentColors.red100),
        borderRadius: BorderRadius.circular(ArdentRadii.md),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: ArdentColors.accent, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: ArdentSpacing.s3),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: text.bodyMedium?.copyWith(color: ArdentColors.navy900, height: 1.4),
                children: [
                  const TextSpan(
                      text: 'Pinned announcement: ',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: label),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storiesRow() {
    return SizedBox(
      height: 160,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _addStory(),
          const SizedBox(width: 10),
          for (final s in _stories) ...[
            _story(s),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  static const double _storyW = 104;
  static const double _storyH = 160;

  Widget _addStory() {
    final me = AppSession.instance.me;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StoryComposerScreen()),
      ),
      child: Container(
        width: _storyW,
        height: _storyH,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ArdentRadii.lg),
          border: Border.all(color: ArdentColors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                // Top: the profile initial as the card background.
                Expanded(
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          me.color,
                          Color.lerp(me.color, Colors.black, 0.30)!,
                        ],
                      ),
                    ),
                    child: Text(
                      me.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 34,
                      ),
                    ),
                  ),
                ),
                // Bottom: white strip with the label.
                Container(
                  height: 46,
                  width: double.infinity,
                  color: ArdentColors.bgSurface,
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 6),
                  child: const Text('Add update',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: ArdentColors.fg1)),
                ),
              ],
            ),
            // + badge straddling the boundary.
            Positioned(
              bottom: 34,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ArdentColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _story(Story s) {
    final viewed = _viewedStories.contains(_storyKey(s));
    final cover = s.media
        .cast<MediaItem?>()
        .firstWhere((m) => m != null && m.isImage, orElse: () => null);
    return GestureDetector(
      onTap: () async {
        final start = _stories.indexOf(s);
        final seen = await Navigator.of(context).push<Set<String>>(
          MaterialPageRoute(
            builder: (_) => StoryViewerScreen(
              stories: _stories,
              initialIndex: start < 0 ? 0 : start,
            ),
          ),
        );
        if (!mounted) return;
        setState(() {
          _viewedStories.add(_storyKey(s));
          if (seen != null) _viewedStories.addAll(seen);
        });
      },
      child: Container(
        width: _storyW,
        height: _storyH,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ArdentRadii.lg),
          border: Border.all(color: ArdentColors.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover: story image if present, otherwise a branded gradient.
            if (cover != null)
              Image.network(cover.url, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _gradientCover(s))
            else
              _gradientCover(s),
            // Bottom scrim for legible name.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                ),
              ),
            ),
            // Avatar ring — gray once viewed, coloured otherwise.
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: viewed ? ArdentColors.gray400 : ArdentColors.accent,
                ),
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: DsAvatar(initials: s.initials, color: s.color, size: 30),
                ),
              ),
            ),
            // Name.
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                s.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientCover(Story s) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [s.color, Color.lerp(s.color, Colors.black, 0.35)!],
        ),
      ),
    );
  }

  Widget _composer(TextTheme text) {
    final me = AppSession.instance.me;
    return SurfaceCard(
      child: Column(
        children: [
          Row(
            children: [
              DsAvatar(initials: me.initials, color: me.color, size: 40),
              const SizedBox(width: ArdentSpacing.s3),
              Expanded(
                child: InkWell(
                  onTap: () => _openComposer(),
                  borderRadius: BorderRadius.circular(ArdentRadii.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: ArdentColors.bgSubtle,
                      borderRadius: BorderRadius.circular(ArdentRadii.pill),
                    ),
                    child: Text(
                      "Share something…",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(color: ArdentColors.fg3),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: ArdentSpacing.s5),
          Row(
            children: [
              Expanded(
                child: _ComposerAction(Icons.photo_library_rounded, 'Photo',
                    const Color(0xFF2FAE5C),
                    onTap: () => _openComposer(kind: PostKind.photo)),
              ),
              Expanded(
                child: _ComposerAction(Icons.attach_file_rounded, 'File',
                    ArdentColors.navy600,
                    onTap: () => _openComposer(kind: PostKind.file)),
              ),
              Expanded(
                child: _ComposerAction(Icons.bar_chart_rounded, 'Poll',
                    ArdentColors.navy500,
                    onTap: () => _openComposer(kind: PostKind.poll)),
              ),
              Expanded(
                child: _ComposerAction(Icons.emoji_events_rounded, 'Kudos',
                    const Color(0xFFC77700),
                    onTap: () => _openComposer(kind: PostKind.kudos)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction(this.icon, this.label, this.color, {this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: ArdentColors.fg2, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
