import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import 'ds.dart';

/// Feed post card — a faithful port of the web `feed/PostCard.vue`, covering
/// the announcement, kudos, poll, and text variants, plus the like / comment /
/// share / save action bar and an inline comment thread.
class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post});

  final Post post;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _commentsOpen = false;
  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();

  /// When set, the bottom composer is replying to this comment (Facebook-style
  /// "Replying to …" banner) instead of posting a new top-level comment.
  Comment? _replyTarget;

  Post get post => widget.post;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      post.liked = !post.liked;
      post.likeCount += post.liked ? 1 : -1;
    });
    // Fire-and-forget; roll back on failure.
    final liked = post.liked;
    final future = liked
        ? Api.instance.posts.setReaction(post.id, 'like')
        : Api.instance.posts.removeReaction(post.id);
    future.catchError((_) {
      if (!mounted) return;
      setState(() {
        post.liked = !liked;
        post.likeCount += post.liked ? 1 : -1;
      });
    });
  }

  void _vote(int idx) {
    final option = post.pollOptions[idx];
    setState(() => option.votes++);
    if (option.id.isEmpty) return; // No server id available; local-only.
    Api.instance.posts.vote(post.id, option.id).catchError((_) {
      if (mounted) setState(() => option.votes--);
      return <String, dynamic>{};
    });
  }

  /// Tapping "Reply" on a comment aims the bottom composer at it and focuses
  /// the field so the keyboard opens right away.
  void _startReply(Comment target) {
    setState(() => _replyTarget = target);
    _commentFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyTarget = null);
  }

  void _submitComment() {
    final t = _commentCtrl.text.trim();
    if (t.isEmpty) return;
    final target = _replyTarget;
    final comment = Comment(author: AppSession.instance.me, text: t);
    setState(() {
      if (target != null) {
        target.replies.add(comment);
      } else {
        post.comments.add(comment);
      }
      _commentCtrl.clear();
      _replyTarget = null;
    });
    _toast(target != null ? 'Reply posted' : 'Comment posted');
    // Persist to the backend; on failure, remove the optimistic bubble.
    Api.instance.posts
        .addComment(post.id,
            text: t, parentId: target?.id.isNotEmpty == true ? target!.id : null)
        .catchError((_) {
      if (!mounted) return <String, dynamic>{};
      setState(() {
        (target?.replies ?? post.comments).remove(comment);
      });
      _toast('Comment failed to send', icon: Icons.error_outline_rounded);
      return <String, dynamic>{};
    });
  }

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

  void _toggleSave() {
    setState(() => post.saved = !post.saved);
    _toast(post.saved ? 'Saved to your bookmarks' : 'Removed from saved',
        icon: post.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded);
    final saved = post.saved;
    final future =
        saved ? Api.instance.posts.save(post.id) : Api.instance.posts.unsave(post.id);
    future.catchError((_) {
      if (!mounted) return;
      setState(() => post.saved = !saved);
    });
  }

  /// Share flow — a Facebook-style sheet that slides up from the bottom with
  /// share destinations. "Share to your feed" bumps the count and confirms.
  Future<void> _openShareSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ArdentColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ArdentRadii.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ArdentColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text('Share',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            // Mini preview of the post being shared.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  DsAvatar(initials: post.author.initials, color: post.author.color, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.author.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(post.time,
                            style: const TextStyle(color: ArdentColors.fg3, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            _shareItem(ctx, Icons.dynamic_feed_rounded, 'Share to your feed',
                'Post now to Community', 'feed'),
            _shareItem(ctx, Icons.send_rounded, 'Send in a message',
                'Share privately in Chats', 'message'),
            _shareItem(ctx, Icons.group_rounded, 'Share to a group',
                'Post in one of your groups', 'group'),
            _shareItem(ctx, Icons.link_rounded, 'Copy link',
                'Copy a link to this post', 'copy'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'feed':
        setState(() => post.shareCount++);
        _toast('Post shared to your feed');
        Api.instance.posts.share(post.id).catchError((_) {
          if (mounted) setState(() => post.shareCount--);
          return <String, dynamic>{};
        });
      case 'message':
        _toast('Opening a message…', icon: Icons.send_rounded);
      case 'group':
        setState(() => post.shareCount++);
        _toast('Shared to your group', icon: Icons.group_rounded);
      case 'copy':
        _toast('Link copied to clipboard', icon: Icons.link_rounded);
    }
  }

  Widget _shareItem(
      BuildContext ctx, IconData icon, String title, String subtitle, String value) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: ArdentColors.bgSubtle,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: ArdentColors.fg1, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle),
      onTap: () => Navigator.of(ctx).pop(value),
    );
  }

  /// The overflow (3-dot) menu — a bottom sheet of post actions.
  void _openPostMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetItem(ctx, Icons.edit_outlined, 'Edit post', () => _toast('Edit post (demo)')),
            _sheetItem(ctx, Icons.link_rounded, 'Copy link',
                () => _toast('Link copied to clipboard')),
            _sheetItem(
                ctx,
                post.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                post.saved ? 'Remove from saved' : 'Save post',
                _toggleSave),
            _sheetItem(ctx, Icons.notifications_off_outlined, 'Mute notifications',
                () => _toast('Notifications muted for this post', icon: Icons.notifications_off_rounded)),
            _sheetItem(ctx, Icons.flag_outlined, 'Report post',
                () => _toast('Post reported to admins', icon: Icons.flag_rounded),
                danger: true),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem(BuildContext ctx, IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? ArdentColors.accent : ArdentColors.fg1;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.of(ctx).pop();
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      padding: const EdgeInsets.all(ArdentSpacing.s4 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(text),
          const SizedBox(height: ArdentSpacing.s3),
          _typeBadge(),
          _body(text),
          if (post.media.isNotEmpty) _mediaSection(),
          const SizedBox(height: ArdentSpacing.s3),
          _actionBar(),
          if (_commentsOpen) _commentThread(text),
        ],
      ),
    );
  }

  Widget _header(TextTheme text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsAvatar(initials: post.author.initials, color: post.author.color, size: 42),
        const SizedBox(width: ArdentSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.author.name, style: text.titleMedium?.copyWith(fontSize: 14)),
              Text(post.author.role, style: text.bodySmall),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(post.time, style: text.bodySmall),
                  const SizedBox(width: 5),
                  const Icon(Icons.public, size: 12, color: ArdentColors.fg3),
                ],
              ),
            ],
          ),
        ),
        if (post.pinned)
          const DsChip(label: 'Pinned', fg: ArdentColors.statusUrgent, bg: ArdentColors.statusUrgentBg),
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded, color: ArdentColors.fg3),
          onPressed: _openPostMenu,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _typeBadge() {
    late final String label;
    late final IconData icon;
    late final Color fg;
    late final Color bg;
    switch (post.kind) {
      case PostKind.announcement:
        label = 'Announcement';
        icon = Icons.campaign_rounded;
        fg = ArdentColors.accent;
        bg = ArdentColors.accentSoft;
      case PostKind.kudos:
        label = 'Kudos';
        icon = Icons.emoji_events_rounded;
        fg = const Color(0xFFC77700);
        bg = ArdentColors.statusPendingBg;
      case PostKind.poll:
        label = 'Poll';
        icon = Icons.bar_chart_rounded;
        fg = ArdentColors.navy600;
        bg = ArdentColors.statusOpenBg;
      case PostKind.text:
      case PostKind.photo:
        return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s2),
      child: DsChip(label: label, fg: fg, bg: bg, icon: icon),
    );
  }

  Widget _body(TextTheme text) {
    switch (post.kind) {
      case PostKind.announcement:
        return _announcement(text);
      case PostKind.kudos:
        return _kudos(text);
      case PostKind.poll:
        return _poll(text);
      case PostKind.text:
      case PostKind.photo:
        return Text(post.text, style: text.bodyLarge);
    }
  }

  Widget _announcement(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(post.title, style: text.titleLarge),
        const SizedBox(height: ArdentSpacing.s2),
        Text(post.text, style: text.bodyLarge),
        if (post.details.isNotEmpty) ...[
          const SizedBox(height: ArdentSpacing.s3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ArdentColors.bgSubtle,
              borderRadius: BorderRadius.circular(ArdentRadii.sm),
            ),
            child: Column(
              children: [
                for (final d in post.details)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text('${d.key}:',
                              style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700, color: ArdentColors.fg1)),
                        ),
                        Expanded(child: Text(d.value, style: text.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (post.note.isNotEmpty) ...[
          const SizedBox(height: ArdentSpacing.s3),
          Text(post.note, style: text.bodyMedium),
        ],
        if (post.signoff.isNotEmpty) ...[
          const SizedBox(height: ArdentSpacing.s2),
          Text(post.signoff,
              style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600, color: ArdentColors.fg1)),
        ],
      ],
    );
  }

  Widget _kudos(TextTheme text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ArdentColors.red50, Colors.white],
        ),
        border: Border.all(color: ArdentColors.red100),
        borderRadius: BorderRadius.circular(ArdentRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kudos to ${post.kudosTo}',
              style: text.titleMedium?.copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          Text(post.text, style: text.bodyLarge),
        ],
      ),
    );
  }

  Widget _poll(TextTheme text) {
    final total = post.pollOptions.fold<int>(0, (s, o) => s + o.votes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(post.text,
            style: text.bodyLarge?.copyWith(
                color: ArdentColors.fg1, fontWeight: FontWeight.w600)),
        const SizedBox(height: ArdentSpacing.s1),
        Text('Tap an option to vote · you can change your vote anytime',
            style: text.bodySmall),
        const SizedBox(height: ArdentSpacing.s2),
        for (var i = 0; i < post.pollOptions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _pollOption(post.pollOptions[i], total, () => _vote(i)),
          ),
        Text('$total vote${total == 1 ? '' : 's'}', style: text.bodySmall),
      ],
    );
  }

  Widget _pollOption(PollOption opt, int total, VoidCallback onTap) {
    final pct = total == 0 ? 0.0 : opt.votes / total;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.sm),
      child: Stack(
        children: [
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct == 0 ? 0.001 : pct,
              child: Container(
                decoration: BoxDecoration(
                  color: ArdentColors.accentSoft,
                  borderRadius: BorderRadius.circular(ArdentRadii.sm),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: ArdentColors.borderStrong),
              borderRadius: BorderRadius.circular(ArdentRadii.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(opt.label,
                      style: const TextStyle(fontSize: 13, color: ArdentColors.fg1)),
                ),
                Text('${opt.votes}',
                    style: const TextStyle(fontSize: 12, color: ArdentColors.fg3)),
                if (total > 0) ...[
                  const SizedBox(width: 8),
                  Text('${(pct * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: ArdentColors.fg1)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renders attached images inline, videos as a poster tile, and documents as
  /// a file card.
  Widget _mediaSection() {
    return Padding(
      padding: const EdgeInsets.only(top: ArdentSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < post.media.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _mediaTile(post.media[i]),
          ],
        ],
      ),
    );
  }

  Widget _mediaTile(MediaItem m) {
    if (m.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(ArdentRadii.sm),
        child: Image.network(
          m.url,
          fit: BoxFit.fitWidth,
          width: double.infinity,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 200,
              color: ArdentColors.bgSubtle,
              child: const Center(
                child: SizedBox(
                    width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          },
          errorBuilder: (context, _, _) => _brokenMedia('Image unavailable'),
        ),
      );
    }
    if (m.isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(ArdentRadii.sm),
        child: Container(
          height: 200,
          color: ArdentColors.navy900,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 52),
              if (m.caption != null && m.caption!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(m.caption!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
      );
    }
    // File / document.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: ArdentColors.bgSubtle,
        borderRadius: BorderRadius.circular(ArdentRadii.sm),
        border: Border.all(color: ArdentColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded, color: ArdentColors.accent, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              m.fileName ?? m.url.split('/').last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: ArdentColors.fg1),
            ),
          ),
          const Icon(Icons.download_rounded, color: ArdentColors.fg3, size: 20),
        ],
      ),
    );
  }

  Widget _brokenMedia(String label) {
    return Container(
      height: 160,
      color: ArdentColors.bgSubtle,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined, color: ArdentColors.fg3, size: 32),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: ArdentColors.fg3, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: ArdentColors.border),
          bottom: BorderSide(color: ArdentColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              post.liked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
              'Like · ${post.likeCount}',
              color: post.liked ? ArdentColors.accent : ArdentColors.fg2,
              onTap: _toggleLike,
            ),
          ),
          Expanded(
            child: _actionButton(
              Icons.mode_comment_outlined,
              'Comment · ${post.comments.length}',
              onTap: () => setState(() => _commentsOpen = !_commentsOpen),
            ),
          ),
          Expanded(
            child: _actionButton(
              Icons.share_outlined,
              'Share · ${post.shareCount}',
              onTap: _openShareSheet,
            ),
          ),
          _actionButton(
            post.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            '',
            color: post.saved ? ArdentColors.accent : ArdentColors.fg2,
            onTap: _toggleSave,
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label,
      {Color color = ArdentColors.fg2, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(ArdentRadii.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _commentThread(TextTheme text) {
    return Padding(
      padding: const EdgeInsets.only(top: ArdentSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in post.comments) ...[
            _CommentTile(comment: c, onReply: _startReply),
            // Inline reply composer, tucked directly under the comment being
            // replied to (indented to the reply level, like Facebook).
            if (_replyTarget == c)
              Padding(
                padding: const EdgeInsets.only(left: 36, bottom: 10),
                child: _composerRow(replying: true),
              ),
          ],
          // Main composer for new top-level comments — hidden while replying so
          // the shared controller is only ever attached to one field.
          if (_replyTarget == null) _composerRow(replying: false),
        ],
      ),
    );
  }

  /// The comment/reply input row. When [replying], it stacks a "Replying to …"
  /// banner (with a cancel ✕) above the field.
  Widget _composerRow({required bool replying}) {
    final field = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DsAvatar(
            initials: AppSession.instance.me.initials,
            color: AppSession.instance.me.color,
            size: replying ? 26 : 30),
        const SizedBox(width: 8),
        // Facebook-style rounded pill holding the field and inline actions.
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: ArdentColors.bgSubtle,
              borderRadius: BorderRadius.circular(ArdentRadii.pill),
            ),
            padding: const EdgeInsets.only(left: 16, right: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    focusNode: _commentFocus,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                    decoration: InputDecoration(
                      hintText: replying ? 'Write a reply…' : 'Write a comment…',
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                // Send appears once there's text; otherwise show subtle
                // emoji / camera affordances like Facebook.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _commentCtrl,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    if (!hasText) {
                      return const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_emotions_outlined,
                                size: 20, color: ArdentColors.fg3),
                            SizedBox(width: 10),
                            Icon(Icons.photo_camera_outlined,
                                size: 20, color: ArdentColors.fg3),
                          ],
                        ),
                      );
                    }
                    return IconButton(
                      onPressed: _submitComment,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.send_rounded, size: 20),
                      color: ArdentColors.accent,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (!replying) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ArdentColors.bgSubtle,
            borderRadius: BorderRadius.circular(ArdentRadii.sm),
          ),
          child: Row(
            children: [
              const Icon(Icons.reply_rounded, size: 14, color: ArdentColors.fg3),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Replying to ${_replyTarget!.author.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: ArdentColors.fg2),
                ),
              ),
              GestureDetector(
                onTap: _cancelReply,
                child: const Icon(Icons.close_rounded, size: 16, color: ArdentColors.fg3),
              ),
            ],
          ),
        ),
        field,
      ],
    );
  }
}

/// A single comment with working Like and Reply, plus its nested replies.
/// Tapping Reply calls [onReply]; the post's shared bottom composer handles the
/// actual input (Facebook-style "Replying to …"). [isReply] renders the
/// smaller, indented variant with a connector line.
class _CommentTile extends StatefulWidget {
  const _CommentTile({
    required this.comment,
    required this.onReply,
    this.isReply = false,
  });

  final Comment comment;
  final void Function(Comment target) onReply;
  final bool isReply;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  Comment get c => widget.comment;

  void _toggleLike() {
    setState(() {
      c.liked = !c.liked;
      c.likes += c.liked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = widget.isReply ? 24.0 : 28.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsAvatar(initials: c.author.initials, color: c.author.color, size: avatarSize),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chat-style bubble.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ArdentColors.bgSubtle,
                    borderRadius: BorderRadius.circular(ArdentRadii.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.author.name,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ArdentColors.fg1)),
                      const SizedBox(height: 2),
                      Text(c.text,
                          style: const TextStyle(fontSize: 13, color: ArdentColors.fg2)),
                    ],
                  ),
                ),
                // Like · Reply · count
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Row(
                    children: [
                      _link(
                        c.liked ? 'Liked' : 'Like',
                        onTap: _toggleLike,
                        color: c.liked ? ArdentColors.accent : ArdentColors.fg2,
                      ),
                      _dot(),
                      _link('Reply', onTap: () => widget.onReply(c)),
                      if (c.likes > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: ArdentColors.accent, shape: BoxShape.circle),
                          child: const Icon(Icons.thumb_up_alt_rounded,
                              size: 8, color: Colors.white),
                        ),
                        const SizedBox(width: 3),
                        Text('${c.likes}',
                            style: const TextStyle(fontSize: 11, color: ArdentColors.fg3)),
                      ],
                    ],
                  ),
                ),
                // Nested replies — replying to a reply threads under the same
                // parent comment.
                for (final r in c.replies)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _CommentTile(
                      comment: r,
                      isReply: true,
                      onReply: (_) => widget.onReply(c),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _link(String label, {required VoidCallback onTap, Color color = ArdentColors.fg2}) {
    return InkWell(
      onTap: onTap,
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('·', style: TextStyle(color: ArdentColors.fg3, fontWeight: FontWeight.w700)),
      );
}
