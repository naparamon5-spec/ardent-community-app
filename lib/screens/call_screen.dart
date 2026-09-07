import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../calls/call_controller.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Full-screen call UI, driven entirely by [CallController]. Shows the incoming
/// (accept/decline), outgoing (calling…/cancel), and active states — the last
/// rendering live LiveKit video/audio with mic, camera, speaker and hang-up
/// controls, for both 1:1 and group calls.
class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CallController.instance;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        c.phase == CallPhase.incoming ? c.decline() : c.hangUp();
      },
      child: Scaffold(
        backgroundColor: ArdentColors.navy900,
        body: AnimatedBuilder(
          animation: c,
          builder: (context, _) => SafeArea(
            child: c.phase == CallPhase.active
                ? _activeView(c)
                : _ringingView(c),
          ),
        ),
      ),
    );
  }

  // ---- Incoming / outgoing ---------------------------------------------------

  Widget _ringingView(CallController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        children: [
          const Spacer(),
          DsAvatar(
            initials: c.peerInitials,
            color: c.peerColor,
            size: 116,
            imageUrl: c.peerAvatarUrl,
          ),
          const SizedBox(height: 24),
          Text(
            c.peerName.isEmpty ? 'Call' : c.peerName,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitle(c),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 15),
          ),
          const Spacer(),
          _ringingControls(c),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _subtitle(CallController c) {
    if (c.statusMessage != null) return c.statusMessage!;
    switch (c.phase) {
      case CallPhase.incoming:
        return c.kind == 'group'
            ? 'Incoming group call${c.groupName.isNotEmpty ? ' · ${c.groupName}' : ''}'
            : 'Incoming call…';
      case CallPhase.outgoing:
        return 'Calling…';
      case CallPhase.ended:
        return 'Call ended';
      default:
        return '';
    }
  }

  Widget _ringingControls(CallController c) {
    if (c.phase == CallPhase.incoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundButton(
              icon: Icons.call_end_rounded,
              color: ArdentColors.crimson500,
              label: 'Decline',
              onTap: c.decline),
          _RoundButton(
              icon: Icons.call_rounded,
              color: const Color(0xFF2FAE5C),
              label: 'Accept',
              onTap: c.accept),
        ],
      );
    }
    return Center(
      child: _RoundButton(
          icon: Icons.call_end_rounded,
          color: ArdentColors.crimson500,
          label: 'Cancel',
          onTap: c.hangUp),
    );
  }

  // ---- Active (in call) ------------------------------------------------------

  Widget _activeView(CallController c) {
    final remotes = c.remoteParticipants;
    return Stack(
      children: [
        // Remote video / avatars fill the screen.
        Positioned.fill(child: _remoteStage(c, remotes)),

        // Local camera preview, picture-in-picture.
        if (c.cameraEnabled && c.localParticipant != null)
          Positioned(
            right: 16,
            top: 16,
            width: 108,
            height: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _ParticipantTile(
                  participant: c.localParticipant!,
                  label: 'You',
                  mirror: true),
            ),
          ),

        // Connecting / error banner.
        if (c.connectingMedia || c.mediaError != null)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  c.mediaError ?? 'Connecting…',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),

        // Controls.
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: _activeControls(c),
        ),
      ],
    );
  }

  Widget _remoteStage(CallController c, List<RemoteParticipant> remotes) {
    if (remotes.isEmpty) {
      // No one else in the room yet — show the peer/group avatar.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsAvatar(
                initials: c.peerInitials,
                color: c.peerColor,
                size: 116,
                imageUrl: c.peerAvatarUrl),
            const SizedBox(height: 20),
            Text(c.peerName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Waiting for others to join…',
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 14)),
          ],
        ),
      );
    }
    if (remotes.length == 1) {
      return _ParticipantTile(participant: remotes.first, label: remotes.first.name);
    }
    // Group call → grid.
    final cross = remotes.length <= 4 ? 2 : 3;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: GridView.count(
        crossAxisCount: cross,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: [
          for (final p in remotes)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _ParticipantTile(participant: p, label: p.name),
            ),
        ],
      ),
    );
  }

  Widget _activeControls(CallController c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(
          icon: c.micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
          color: c.micEnabled ? Colors.white24 : Colors.white,
          iconColor: c.micEnabled ? Colors.white : ArdentColors.navy900,
          label: c.micEnabled ? 'Mute' : 'Unmute',
          onTap: c.toggleMic,
        ),
        const SizedBox(width: 14),
        _RoundButton(
          icon: c.cameraEnabled
              ? Icons.videocam_rounded
              : Icons.videocam_off_rounded,
          color: c.cameraEnabled ? Colors.white : Colors.white24,
          iconColor: c.cameraEnabled ? ArdentColors.navy900 : Colors.white,
          label: 'Video',
          onTap: c.toggleCamera,
        ),
        const SizedBox(width: 14),
        _RoundButton(
          icon: c.speakerOn
              ? Icons.volume_up_rounded
              : Icons.hearing_rounded,
          color: c.speakerOn ? Colors.white : Colors.white24,
          iconColor: c.speakerOn ? ArdentColors.navy900 : Colors.white,
          label: 'Speaker',
          onTap: c.toggleSpeaker,
        ),
        const SizedBox(width: 14),
        _RoundButton(
          icon: Icons.call_end_rounded,
          color: ArdentColors.crimson500,
          label: 'End',
          onTap: c.hangUp,
        ),
      ],
    );
  }
}

/// One participant's live video, or their initials avatar when they have no
/// (unmuted, subscribed) camera track.
class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    this.label = '',
    this.mirror = false,
  });

  final Participant participant;
  final String label;
  final bool mirror;

  VideoTrack? get _videoTrack {
    for (final pub in participant.videoTrackPublications) {
      final track = pub.track;
      if (track is VideoTrack && !pub.muted) return track;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final track = _videoTrack;
    return Container(
      color: ArdentColors.navy800,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (track != null)
            VideoTrackRenderer(
              track,
              mirrorMode:
                  mirror ? VideoViewMirrorMode.mirror : VideoViewMirrorMode.off,
            )
          else
            Center(
              child: DsAvatar(
                initials: _initials(participant),
                color: ArdentColors.navy700,
                size: 88,
              ),
            ),
          if (label.isNotEmpty)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  String _initials(Participant p) {
    final name = p.name.isNotEmpty ? p.name : p.identity;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(icon, color: iconColor, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
