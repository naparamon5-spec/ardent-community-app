import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Story composer — mirrors the web `StoryComposerModal.vue`: pick a background,
/// type a caption, and share to your story. A full-screen preview so the look
/// can be reviewed.
class StoryComposerScreen extends StatefulWidget {
  const StoryComposerScreen({super.key});

  @override
  State<StoryComposerScreen> createState() => _StoryComposerScreenState();
}

class _StoryComposerScreenState extends State<StoryComposerScreen> {
  final _caption = TextEditingController();
  final _previewKey = GlobalKey();
  int _bg = 0;
  bool _sharing = false;

  static const _backgrounds = <List<Color>>[
    [ArdentColors.brandCoral, ArdentColors.accent, ArdentColors.red800],
    [ArdentColors.navy700, ArdentColors.navy900],
    [ArdentColors.crimson500, Color(0xFF8E2237)],
    [Color(0xFF2C5A6E), Color(0xFF0B1E27)],
    [Color(0xFFC77700), Color(0xFF7A0203)],
  ];

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  /// Rasterises the gradient+caption preview to a PNG and posts it as story
  /// media (`POST /stories`, which requires at least one media file).
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final boundary = _previewKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      await Api.instance.stories.create(
        media: [storyMedia(bytes: bytes, filename: 'story.png', contentType: 'image/png')],
        fields: {if (_caption.text.trim().isNotEmpty) 'caption': _caption.text.trim()},
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

  @override
  Widget build(BuildContext context) {
    final me = AppSession.instance.me;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Add to story', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Live preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              child: RepaintBoundary(
                key: _previewKey,
                child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _backgrounds[_bg],
                  ),
                  borderRadius: BorderRadius.circular(ArdentRadii.xl),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: DsAvatar(initials: me.initials, color: me.color, size: 34),
                          ),
                          const SizedBox(width: 8),
                          Text(me.name,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _caption.text.isEmpty ? 'Your story text…' : _caption.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _caption.text.isEmpty
                                ? Colors.white54
                                : Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
          // Background swatches
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
              itemCount: _backgrounds.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => setState(() => _bg = i),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _backgrounds[i]),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _bg == i ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Caption + share
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ArdentSpacing.s4, ArdentSpacing.s3, ArdentSpacing.s4, ArdentSpacing.s4),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caption,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Write something…',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ArdentRadii.md),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(ArdentRadii.md),
                          borderSide: const BorderSide(color: Colors.white38),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: ArdentSpacing.s3),
                  ElevatedButton.icon(
                    onPressed: _sharing ? null : _share,
                    icon: _sharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Share'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
