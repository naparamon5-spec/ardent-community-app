import 'package:flutter/material.dart';

import '../api/api.dart';
import '../calls/call_controller.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

/// Call history — a faithful port of the web **Calls** page. Lists the 1:1 and
/// group voice/video calls the user took part in (`GET /calls`), newest first,
/// showing direction, time, talk time, and the answered/missed/declined
/// outcome, with a one-tap call-back on direct rows.
class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  final ScrollController _scroll = ScrollController();
  final List<CallRecord> _calls = [];
  static const int _pageSize = 30;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _loadInitial() async {
    final raw = await Api.instance.calls.history(limit: _pageSize);
    final parsed = raw.map(callFromJson).toList();
    _calls
      ..clear()
      ..addAll(parsed);
    _hasMore = parsed.length >= _pageSize;
    _loadingMore = false;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _calls.isEmpty) return;
    setState(() => _loadingMore = true);
    // The API pages back with a `before` = ISO startedAt cursor.
    final cursor = _calls.last.startedAt?.toUtc().toIso8601String();
    try {
      final raw =
          await Api.instance.calls.history(limit: _pageSize, before: cursor);
      final parsed = raw.map(callFromJson).toList();
      final seen = _calls.map((c) => c.id).toSet();
      final fresh =
          parsed.where((c) => c.id.isEmpty || !seen.contains(c.id)).toList();
      if (!mounted) return;
      setState(() {
        _calls.addAll(fresh);
        _hasMore = parsed.length >= _pageSize && fresh.isNotEmpty;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Calls the other party back (direct calls only). Group call-backs need the
  /// live group, which the history row doesn't carry.
  void _callBack(CallRecord c) {
    if (c.isGroup || c.peer.id.isEmpty) return;
    CallController.instance.startDirect(c.peer, video: c.video);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Calls')),
      body: AsyncView<void>(
        loader: _loadInitial,
        builder: (context, _, reload) {
          if (_calls.isEmpty) {
            return const EmptyState(
              message: 'No calls yet. Start a voice or video call from a chat.',
              icon: Icons.call_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: ArdentSpacing.s8),
              itemCount: _calls.length + 2, // header + footer
              separatorBuilder: (_, i) => i == 0
                  ? const SizedBox.shrink()
                  : const Divider(
                      height: 1, indent: 72, color: ArdentColors.border),
              itemBuilder: (context, i) {
                if (i == 0) return _header(text);
                if (i == _calls.length + 1) return _footer();
                return _callTile(_calls[i - 1], text);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _header(TextTheme text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ArdentSpacing.s4, ArdentSpacing.s3, ArdentSpacing.s4, ArdentSpacing.s2),
      child: Text(
        'Your voice calls. Only who and when is kept — conversations are never recorded.',
        style: text.bodySmall?.copyWith(color: ArdentColors.fg3),
      ),
    );
  }

  Widget _footer() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: ArdentSpacing.s3),
        child: Center(
          child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      );
    }
    return const SizedBox(height: ArdentSpacing.s4);
  }

  Widget _callTile(CallRecord c, TextTheme text) {
    return InkWell(
      onTap: c.isGroup ? null : () => _callBack(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ArdentSpacing.s4, vertical: 10),
        child: Row(
          children: [
            _avatar(c),
            const SizedBox(width: ArdentSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(c.video ? Icons.videocam_rounded : _dirIcon(c),
                          size: 15, color: _dirColor(c)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                        color: c.isMissed ? ArdentColors.accent : ArdentColors.fg3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ArdentSpacing.s2),
            _statusChip(c),
            if (!c.isGroup && c.peer.id.isNotEmpty) ...[
              const SizedBox(width: 6),
              _callButton(c),
            ],
          ],
        ),
      ),
    );
  }

  Widget _avatar(CallRecord c) {
    if (c.isGroup) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.peer.color, Color.lerp(c.peer.color, Colors.black, 0.28)!],
          ),
          borderRadius: BorderRadius.circular(ArdentRadii.md),
        ),
        child: const Icon(Icons.groups_rounded, color: Colors.white),
      );
    }
    return DsAvatar(
        initials: c.peer.initials,
        color: c.peer.color,
        size: 48,
        imageUrl: c.peer.avatarUrl);
  }

  /// The direction glyph — a missed call always shows the missed variant.
  IconData _dirIcon(CallRecord c) {
    if (c.isMissed) {
      return c.isIncoming ? Icons.call_missed_rounded : Icons.call_missed_outgoing_rounded;
    }
    return c.isIncoming ? Icons.call_received_rounded : Icons.call_made_rounded;
  }

  Color _dirColor(CallRecord c) {
    if (c.isMissed) return ArdentColors.accent; // red — needs attention
    if (c.isIncoming) return const Color(0xFF2FAE5C); // green — received
    return ArdentColors.navy600; // outgoing
  }

  String _subtitle(CallRecord c) {
    final parts = <String>[];
    if (c.isGroup) {
      parts.add('Group call');
      if (c.participantsJoined > 0) parts.add('${c.participantsJoined} joined');
    } else {
      parts.add(c.isIncoming ? 'Incoming' : 'Outgoing');
    }
    if (c.timeLabel.isNotEmpty) parts.add(c.timeLabel);
    if (c.isAnswered && c.durationSeconds > 0) {
      parts.add(_duration(c.durationSeconds));
    }
    return parts.join(' · ');
  }

  String _duration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _statusChip(CallRecord c) {
    late final String label;
    late final Color color;
    if (c.isMissed) {
      label = 'MISSED';
      color = ArdentColors.accent;
    } else if (c.isDeclined) {
      label = 'DECLINED';
      color = ArdentColors.fg3;
    } else {
      label = 'ANSWERED';
      color = const Color(0xFF2FAE5C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ArdentRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: color)),
        ],
      ),
    );
  }

  Widget _callButton(CallRecord c) {
    return Material(
      color: ArdentColors.accentSoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _callBack(c),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.call_rounded, size: 18, color: ArdentColors.accent),
        ),
      ),
    );
  }
}
