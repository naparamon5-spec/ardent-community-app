import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api.dart';
import '../theme/ardent_colors.dart';

/// Story composer — mirrors the web "Add to My Day" modal: pick up to 10 photos
/// or videos, give each an optional description, add an overall caption, and
/// share to your story (`POST /stories`, which requires ≥1 media file).
class StoryComposerScreen extends StatefulWidget {
  const StoryComposerScreen({super.key});

  @override
  State<StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _PickedMedia {
  _PickedMedia(this.bytes, this.name, this.isVideo);
  final Uint8List bytes;
  final String name;
  final bool isVideo;
  final TextEditingController caption = TextEditingController();
}

class _StoryComposerScreenState extends State<StoryComposerScreen> {
  static const int _maxItems = 10;

  final _caption = TextEditingController();
  final _picker = ImagePicker();
  final List<_PickedMedia> _media = [];
  bool _sharing = false;

  @override
  void dispose() {
    _caption.dispose();
    for (final m in _media) {
      m.caption.dispose();
    }
    super.dispose();
  }

  Future<void> _addMedia() async {
    if (_media.length >= _maxItems) return;
    final remaining = _maxItems - _media.length;
    try {
      final picked = await _picker.pickMultipleMedia(imageQuality: 90);
      if (picked.isEmpty) return;
      final take = picked.take(remaining);
      for (final x in take) {
        final bytes = await x.readAsBytes();
        final isVideo = _looksLikeVideo(x.name, x.mimeType);
        if (mounted) {
          setState(() => _media.add(_PickedMedia(bytes, x.name, isVideo)));
        }
      }
      if (picked.length > remaining && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can add up to 10 items.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't open your gallery.")));
      }
    }
  }

  static bool _looksLikeVideo(String name, String? mime) {
    if (mime != null && mime.startsWith('video/')) return true;
    final n = name.toLowerCase();
    return n.endsWith('.mp4') ||
        n.endsWith('.mov') ||
        n.endsWith('.webm') ||
        n.endsWith('.ogg');
  }

  String _contentType(_PickedMedia m) {
    final n = m.name.toLowerCase();
    if (m.isVideo) {
      if (n.endsWith('.mov')) return 'video/quicktime';
      if (n.endsWith('.webm')) return 'video/webm';
      if (n.endsWith('.ogg')) return 'video/ogg';
      return 'video/mp4';
    }
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _share() async {
    if (_sharing || _media.isEmpty) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final files = [
        for (final m in _media)
          storyMedia(
            bytes: m.bytes,
            filename: m.name.isEmpty ? 'story' : m.name,
            contentType: _contentType(m),
          ),
      ];
      // Per-item descriptions, parallel to the media order.
      final captions = [for (final m in _media) m.caption.text.trim()];
      await Api.instance.stories.create(
        media: files,
        fields: {
          if (_caption.text.trim().isNotEmpty) 'caption': _caption.text.trim(),
          if (captions.any((c) => c.isNotEmpty))
            'newMediaCaptions': _jsonArray(captions),
        },
      );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Your story was shared')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sharing = false);
      messenger.showSnackBar(SnackBar(
          content: Text(e.isForbidden ? "You can't post stories." : e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sharing = false);
      messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't share your story. Try again.")));
    }
  }

  /// Minimal JSON string array (the API accepts a JSON string for captions).
  static String _jsonArray(List<String> values) {
    final escaped = values.map((v) =>
        '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"');
    return '[${escaped.join(',')}]';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: ArdentColors.bgApp,
      appBar: AppBar(
        title: const Text('Add to My Day'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(ArdentSpacing.s4),
                children: [
                  _addTile(),
                  const SizedBox(height: ArdentSpacing.s2),
                  Text(
                    'Photos and videos — up to 10. Add a description to each if '
                    'you like.',
                    style: text.bodyMedium?.copyWith(color: ArdentColors.fg3),
                  ),
                  if (_media.isNotEmpty) ...[
                    const SizedBox(height: ArdentSpacing.s4),
                    for (var i = 0; i < _media.length; i++) _mediaRow(i),
                  ],
                  const SizedBox(height: ArdentSpacing.s5),
                  const Text('Overall caption (optional)',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: ArdentColors.fg1)),
                  const SizedBox(height: ArdentSpacing.s2),
                  TextField(
                    controller: _caption,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        hintText: 'Say something about your day…'),
                  ),
                ],
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              decoration: const BoxDecoration(
                color: ArdentColors.bgSurface,
                border: Border(top: BorderSide(color: ArdentColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _sharing ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: ArdentColors.accent),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: ArdentSpacing.s2),
                  FilledButton(
                    onPressed: (_media.isEmpty || _sharing) ? null : _share,
                    child: _sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Share'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The dashed "Add photo or video" button.
  Widget _addTile() {
    final full = _media.length >= _maxItems;
    return InkWell(
      onTap: full ? null : _addMedia,
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      child: DottedBorder(
        color: ArdentColors.borderStrong,
        radius: ArdentRadii.md,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded,
                  color: full ? ArdentColors.fg3 : ArdentColors.fg1),
              const SizedBox(width: 8),
              Text(
                full ? 'Maximum of 10 reached' : 'Add photo or video',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: full ? ArdentColors.fg3 : ArdentColors.fg1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One picked media item: thumbnail, per-item description, and a remove ✕.
  Widget _mediaRow(int i) {
    final m = _media[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ArdentRadii.sm),
            child: SizedBox(
              width: 60,
              height: 60,
              child: m.isVideo
                  ? Container(
                      color: ArdentColors.navy900,
                      child: const Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 26),
                    )
                  : Image.memory(m.bytes, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: ArdentSpacing.s3),
          Expanded(
            child: TextField(
              controller: m.caption,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Description (optional)',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: ArdentColors.fg3),
            onPressed: () => setState(() {
              _media.removeAt(i).caption.dispose();
            }),
          ),
        ],
      ),
    );
  }
}

/// A lightweight dashed-border box (avoids an extra package dependency).
class DottedBorder extends StatelessWidget {
  const DottedBorder(
      {super.key, required this.child, required this.color, this.radius = 10});
  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, d + dash),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color || old.radius != radius;
}
