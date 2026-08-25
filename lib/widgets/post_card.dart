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

  /// Tapping the Like button toggles a plain 👍 (or clears the current one).
  void _toggleLike() => _react(post.myReaction == null ? 'like' : null);

  /// Applies [type] (or clears the reaction when [type] is null / re-selected),
  /// updates the local counts optimistically, and persists to the backend.
  void _react(String? type) {
    final me = AppSession.instance.me;
    final prev = post.myReaction;
    if (prev == type) type = null; // re-selecting the same reaction removes it

    setState(() {
      if (prev != null) {
        final n = (post.reactionCounts[prev] ?? 1) - 1;
        if (n <= 0) {
          post.reactionCounts.remove(prev);
        } else {
          post.reactionCounts[prev] = n;
        }
        post.reactors.removeWhere((r) => r.person.id == me.id && r.type == prev);
        if (post.likeCount > 0) post.likeCount--;
      }
      post.myReaction = type;
      if (type != null) {
        post.reactionCounts[type] = (post.reactionCounts[type] ?? 0) + 1;
        post.reactors.insert(0, PostReactor(me, type));
        post.likeCount++;
      }
      post.liked = type != null;
    });

    final applied = type;
    final Future<void> future = applied == null
        ? Api.instance.posts.removeReaction(post.id)
        : Api.instance.posts.setReaction(post.id, applied);
    future.catchError((_) {
      // On failure, revert to the previous reaction.
      if (mounted) setState(() => _revertReaction(prev, applied, me));
    });
  }

  void _revertReaction(String? prev, String? applied, Person me) {
    if (applied != null) {
      final n = (post.reactionCounts[applied] ?? 1) - 1;
      if (n <= 0) {
        post.reactionCounts.remove(applied);
      } else {
        post.reactionCounts[applied] = n;
      }
      post.reactors.removeWhere((r) => r.person.id == me.id && r.type == applied);
      if (post.likeCount > 0) post.likeCount--;
    }
    post.myReaction = prev;
    if (prev != null) {
      post.reactionCounts[prev] = (post.reactionCounts[prev] ?? 0) + 1;
      post.reactors.insert(0, PostReactor(me, prev));
      post.likeCount++;
    }
    post.liked = prev != null;
  }

  /// Opens the floating reaction picker anchored above [anchorKey].
  void _showReactionPicker(GlobalKey anchorKey) {
    final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final screenW = overlay.size.width;

    late OverlayEntry entry;
    void close() => entry.remove();
    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Tap-outside barrier.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
            ),
          ),
          Positioned(
            left: 12,
            right: screenW - topLeft.dx - 240 < 12 ? 12 : null,
            top: topLeft.dy - 52,
            child: Material(
              color: Colors.transparent,
              child: _ReactionBar(
                selected: post.myReaction,
                onPick: (key) {
                  close();
                  _react(key);
                },
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(entry);
  }

  /// Single-select vote: moves the caller's vote to [idx] (no-op if already
  /// there). Optimistic, with rollback on failure.
  void _vote(int idx) {
    final option = post.pollOptions[idx];
    if (option.voted) return; // already the current choice
    final previous = post.pollOptions.indexWhere((o) => o.voted);
    setState(() {
      if (previous >= 0) {
        post.pollOptions[previous].voted = false;
        if (post.pollOptions[previous].votes > 0) post.pollOptions[previous].votes--;
      }
      option.voted = true;
      option.votes++;
    });
    if (option.id.isEmpty) return; // No server id available; local-only.
    Api.instance.posts.vote(post.id, option.id).catchError((_) {
      if (mounted) {
        setState(() {
          option.voted = false;
          if (option.votes > 0) option.votes--;
          if (previous >= 0) {
            post.pollOptions[previous].voted = true;
            post.pollOptions[previous].votes++;
          }
        });
      }
      return <String, dynamic>{};
    });
  }

  /// Withdraws the caller's vote entirely.
  void _removeVote() {
    final idx = post.pollOptions.indexWhere((o) => o.voted);
    if (idx < 0) return;
    final option = post.pollOptions[idx];
    setState(() {
      option.voted = false;
      if (option.votes > 0) option.votes--;
    });
    Api.instance.posts.removeVote(post.id).catchError((_) {
      if (mounted) {
        setState(() {
          option.voted = true;
          option.votes++;
        });
      }
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
          _attachments(),
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
      case PostKind.photo:
        label = 'Photo';
        icon = Icons.image_rounded;
        fg = ArdentColors.navy600;
        bg = ArdentColors.statusOpenBg;
      case PostKind.file:
        label = 'File';
        icon = Icons.insert_drive_file_rounded;
        fg = ArdentColors.navy600;
        bg = ArdentColors.statusOpenBg;
      case PostKind.text:
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
      case PostKind.file:
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
    final hasVoted = post.pollOptions.any((o) => o.voted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(post.text,
            style: text.titleMedium?.copyWith(
                color: ArdentColors.fg1, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: ArdentSpacing.s1),
        Text('Select one · you can change or remove your vote anytime',
            style: text.bodySmall),
        const SizedBox(height: ArdentSpacing.s3),
        for (var i = 0; i < post.pollOptions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _pollOption(post.pollOptions[i], total, () => _vote(i)),
          ),
        Row(
          children: [
            Text('$total vote${total == 1 ? '' : 's'}', style: text.bodySmall),
            if (hasVoted) ...[
              const SizedBox(width: ArdentSpacing.s3),
              InkWell(
                onTap: _removeVote,
                borderRadius: BorderRadius.circular(ArdentRadii.sm),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text('Remove my vote',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: ArdentColors.accent)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _pollOption(PollOption opt, int total, VoidCallback onTap) {
    final pct = total == 0 ? 0.0 : opt.votes / total;
    final selected = opt.voted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      child: Stack(
        children: [
          // Percentage fill.
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct == 0 ? 0.001 : pct,
              child: Container(
                decoration: BoxDecoration(
                  color: ArdentColors.accentSoft,
                  borderRadius: BorderRadius.circular(ArdentRadii.md),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? ArdentColors.accent : ArdentColors.border,
                width: selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(ArdentRadii.md),
            ),
            child: Row(
              children: [
                // Radio / selected check.
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? ArdentColors.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? ArdentColors.accent : ArdentColors.borderStrong,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(opt.label,
                      style: TextStyle(
                          fontSize: 14,
                          color: ArdentColors.fg1,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                ),
                Text('${opt.votes}',
                    style: const TextStyle(fontSize: 12.5, color: ArdentColors.fg3)),
                if (total > 0) ...[
                  const SizedBox(width: 10),
                  Text('${(pct * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: ArdentColors.fg1)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Decides what attachment UI (if any) to show under the post body:
  /// real media when present, otherwise a placeholder that mirrors the web feed
  /// for `photo`/`file` posts that carry no downloadable URL.
  Widget _attachments() {
    if (post.media.isNotEmpty) {
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
    if (post.kind == PostKind.photo) {
      return Padding(
        padding: const EdgeInsets.only(top: ArdentSpacing.s3),
        child: _photoPlaceholder(),
      );
    }
    if (post.kind == PostKind.file || post.fileName.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: ArdentSpacing.s3),
        child: _fileCard(
          post.fileName.isNotEmpty ? post.fileName : 'Attachment',
          post.fileSize,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _photoPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ArdentRadii.sm),
      child: Container(
        height: 220,
        color: ArdentColors.bgSubtle,
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, color: ArdentColors.fg3, size: 22),
              SizedBox(width: 8),
              Text('Photo', style: TextStyle(color: ArdentColors.fg3, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileCard(String name, String size) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: ArdentColors.bgSubtle,
        borderRadius: BorderRadius.circular(ArdentRadii.sm),
        border: Border.all(color: ArdentColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded, color: ArdentColors.fg2, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, color: ArdentColors.fg1),
            ),
          ),
          if (size.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(size, style: const TextStyle(color: ArdentColors.fg3, fontSize: 12)),
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
          _likeButton(),
          const SizedBox(width: 4),
          _iconAction(
            Icons.mode_comment_outlined,
            count: post.comments.length,
            onTap: () => setState(() => _commentsOpen = !_commentsOpen),
          ),
          const SizedBox(width: 4),
          _iconAction(
            Icons.share_outlined,
            count: post.shareCount,
            onTap: _openShareSheet,
          ),
          const Spacer(),
          _iconAction(
            post.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: post.saved ? ArdentColors.accent : ArdentColors.fg2,
            onTap: _toggleSave,
          ),
        ],
      ),
    );
  }

  /// A compact icon-only action (Facebook-style), with an optional count.
  Widget _iconAction(IconData icon,
      {int count = 0,
      Color color = ArdentColors.fg2,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text('$count',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
            ],
          ],
        ),
      ),
    );
  }

  final GlobalKey _likeKey = GlobalKey();

  /// The Like action: tap toggles 👍, long-press (or hold) opens the reaction
  /// picker. Shows the user's own reaction as a coloured icon plus the total
  /// count (tap the count to see who reacted).
  Widget _likeButton() {
    final mine = post.myReaction;
    final visual = mine == null ? null : reactionVisual(mine);
    final color = visual?.color ?? ArdentColors.fg2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: _likeKey,
          borderRadius: BorderRadius.circular(ArdentRadii.sm),
          onTap: _toggleLike,
          onLongPress: () => _showReactionPicker(_likeKey),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Icon(
              visual?.icon ?? Icons.thumb_up_alt_outlined,
              size: 20,
              color: color,
            ),
          ),
        ),
        if (post.likeCount > 0)
          InkWell(
            borderRadius: BorderRadius.circular(ArdentRadii.sm),
            onTap: _openWhoReacted,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text('${post.likeCount}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
          ),
      ],
    );
  }

  /// A small coloured circle carrying a reaction icon (used on reactor
  /// avatars in the "who reacted" sheet).
  Widget _reactionBadge(String key, {double size = 18}) {
    final v = reactionVisual(key);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: v.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(v.icon, size: size * 0.55, color: Colors.white),
    );
  }

  /// Bottom sheet listing everyone who reacted, filterable by reaction type —
  /// like tapping the reaction count on a Facebook post.
  void _openWhoReacted() {
    final counts = post.reactionCounts;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ArdentColors.bgSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ArdentRadii.xl)),
      ),
      builder: (ctx) {
        final tabs = <String>['all', ...counts.keys];
        return DefaultTabController(
          length: tabs.length,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, controller) => Column(
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
                TabBar(
                  isScrollable: true,
                  labelColor: ArdentColors.accent,
                  unselectedLabelColor: ArdentColors.fg2,
                  indicatorColor: ArdentColors.accent,
                  tabs: [
                    Tab(text: 'All ${post.likeCount}'),
                    for (final k in counts.keys)
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(reactionVisual(k).icon,
                                size: 16, color: reactionVisual(k).color),
                            const SizedBox(width: 4),
                            Text('${counts[k]}'),
                          ],
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _reactorList(controller, null),
                      for (final k in counts.keys) _reactorList(controller, k),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _reactorList(ScrollController controller, String? type) {
    final people = type == null
        ? post.reactors
        : post.reactors.where((r) => r.type == type).toList();
    if (people.isEmpty) {
      return ListView(
        controller: controller,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Text(
              type == null
                  ? '${post.likeCount} ${post.likeCount == 1 ? 'reaction' : 'reactions'}'
                  : 'No detail available',
              style: const TextStyle(color: ArdentColors.fg3),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: controller,
      itemCount: people.length,
      itemBuilder: (context, i) {
        final r = people[i];
        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              DsAvatar(initials: r.person.initials, color: r.person.color, size: 40),
              Positioned(
                right: -2,
                bottom: -2,
                child: _reactionBadge(r.type, size: 18),
              ),
            ],
          ),
          title: Text(r.person.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: r.person.role.isNotEmpty ? Text(r.person.role) : null,
        );
      },
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

/// Icon + colour for a reaction key, shared by the picker, the summary cluster,
/// and the "who reacted" sheet.
({IconData icon, Color color}) reactionVisual(String key) {
  switch (key) {
    case 'celebrate':
      return (icon: Icons.waving_hand_rounded, color: const Color(0xFFE6A000));
    case 'support':
      return (icon: Icons.favorite_rounded, color: ArdentColors.crimson500);
    case 'insightful':
      return (icon: Icons.lightbulb_rounded, color: ArdentColors.navy600);
    case 'like':
    default:
      return (icon: Icons.thumb_up_alt_rounded, color: ArdentColors.accent);
  }
}

/// The floating reaction picker — a rounded bar of the four reactions that pops
/// up above the Like button (Facebook-style long-press menu).
class _ReactionBar extends StatelessWidget {
  const _ReactionBar({required this.selected, required this.onPick});

  final String? selected;
  final void Function(String key) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: ArdentColors.bgSurface,
        borderRadius: BorderRadius.circular(ArdentRadii.pill),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in reactions)
            _ReactionButton(
              visual: reactionVisual(r.key),
              label: r.label,
              active: selected == r.key,
              onTap: () => onPick(r.key),
            ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  const _ReactionButton(
      {required this.visual,
      required this.label,
      required this.active,
      required this.onTap});
  final ({IconData icon, Color color}) visual;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Tooltip(
        message: widget.label,
        child: AnimatedScale(
          scale: _hover ? 1.2 : (widget.active ? 1.1 : 1.0),
          duration: const Duration(milliseconds: 120),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: widget.active
                  ? const BoxDecoration(
                      color: ArdentColors.accentSoft, shape: BoxShape.circle)
                  : null,
              child: Icon(widget.visual.icon, size: 26, color: widget.visual.color),
            ),
          ),
        ),
      ),
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
