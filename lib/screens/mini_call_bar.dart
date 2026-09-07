import 'package:flutter/material.dart';

import '../calls/call_controller.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// A small floating, draggable call bar shown while the call UI is minimized
/// (see [CallController.minimize]). Tapping it restores the full-screen call;
/// it also carries quick mute and hang-up buttons. Rendered in the root
/// [Overlay] so it floats above whatever screen the user navigates to.
class MiniCallBar extends StatefulWidget {
  const MiniCallBar({super.key});

  @override
  State<MiniCallBar> createState() => _MiniCallBarState();
}

class _MiniCallBarState extends State<MiniCallBar> {
  static const double _w = 232;
  static const double _h = 66;

  Offset _pos = Offset.zero;
  bool _placed = false;

  @override
  Widget build(BuildContext context) {
    final c = CallController.instance;
    final media = MediaQuery.of(context);
    if (!_placed) {
      // Start pinned top-right, below the status bar.
      _pos = Offset(media.size.width - _w - 12, media.padding.top + 8);
      _placed = true;
    }
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        if (!c.isBusy || !c.minimized) return const SizedBox.shrink();
        return Positioned(
          left: _pos.dx,
          top: _pos.dy,
          child: GestureDetector(
            onTap: c.maximize,
            onPanUpdate: (d) {
              setState(() {
                final nx = (_pos.dx + d.delta.dx)
                    .clamp(8.0, media.size.width - _w - 8);
                final ny = (_pos.dy + d.delta.dy)
                    .clamp(media.padding.top + 4, media.size.height - _h - 8);
                _pos = Offset(nx, ny);
              });
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: _w,
                height: _h,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: ArdentColors.navy900,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 12,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    DsAvatar(
                      initials: c.peerInitials,
                      color: c.peerColor,
                      size: 40,
                      imageUrl: c.peerAvatarUrl,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.peerName.isEmpty ? 'On a call' : c.peerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                          Text(
                            c.connectingMedia
                                ? 'Connecting…'
                                : (c.screenShareEnabled
                                    ? 'Sharing screen'
                                    : 'Tap to return'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0x99FFFFFF), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    _miniBtn(
                      icon: c.micEnabled
                          ? Icons.mic_rounded
                          : Icons.mic_off_rounded,
                      bg: c.micEnabled ? Colors.white24 : Colors.white,
                      fg: c.micEnabled ? Colors.white : ArdentColors.navy900,
                      onTap: c.toggleMic,
                    ),
                    const SizedBox(width: 6),
                    _miniBtn(
                      icon: Icons.call_end_rounded,
                      bg: ArdentColors.crimson500,
                      fg: Colors.white,
                      onTap: c.hangUp,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniBtn({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: fg),
        ),
      ),
    );
  }
}
