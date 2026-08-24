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
              const SizedBox(height: ArdentSpacing.s2),
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
      height: 92,
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

  Widget _addStory() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StoryComposerScreen()),
      ),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: ArdentColors.accentSoft,
                shape: BoxShape.circle,
                border: Border.all(color: ArdentColors.accent, width: 1.5),
              ),
              child: const Icon(Icons.add_rounded, color: ArdentColors.accent),
            ),
            const SizedBox(height: 6),
            Text('Add', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _story(Story s) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StoryViewerScreen(story: s)),
      ),
      child: SizedBox(
      width: 76,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ArdentColors.brandCoral, ArdentColors.accent, ArdentColors.red800],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: DsAvatar(initials: s.initials, color: s.color, size: 56),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.name.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
                child: _ComposerAction(Icons.bar_chart_rounded, 'Poll', ArdentColors.navy600,
                    onTap: () => _openComposer(kind: PostKind.poll)),
              ),
              Expanded(
                child: _ComposerAction(Icons.emoji_events_rounded, 'Kudos',
                    const Color(0xFFC77700),
                    onTap: () => _openComposer(kind: PostKind.kudos)),
              ),
              Expanded(
                child: _ComposerAction(Icons.campaign_rounded, 'Announce', ArdentColors.accent,
                    onTap: () => _openComposer(kind: PostKind.announcement)),
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
