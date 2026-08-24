import 'package:flutter/material.dart';

import '../theme/ardent_colors.dart';

/// Saved — placeholder. Items are saved per-post/per-listing via their own
/// endpoints, but the backend does not expose an aggregate "list my saved"
/// route yet, so there is nothing to fetch here.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ArdentSpacing.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bookmark_border_rounded,
                  size: 44, color: ArdentColors.fg3),
              const SizedBox(height: ArdentSpacing.s3),
              Text('Saved items', style: text.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Save posts and listings with the bookmark icon. A combined saved '
                'list will appear here once the backend exposes it.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: ArdentColors.fg3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
