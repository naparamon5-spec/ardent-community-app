import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../theme/ardent_colors.dart';

/// Runs an async [loader] and renders loading / error / data states, with a
/// [reload] callback passed to the builder for pull-to-refresh and retry.
///
/// Keeps the API-backed screens free of repetitive `FutureBuilder` boilerplate.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.loader, required this.builder});

  final Future<T> Function() loader;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload)
      builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  Future<void> _reload() async {
    final next = widget.loader();
    // Block body: an arrow body would *return* the Future, which setState rejects.
    setState(() {
      _future = next;
    });
    // Await completion so the RefreshIndicator spinner clears; the FutureBuilder
    // renders any error itself, so swallow it here rather than rethrowing.
    try {
      await next;
    } catch (_) {
      // Surfaced by the FutureBuilder error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error!, onRetry: _reload);
        }
        return widget.builder(context, snapshot.data as T, _reload);
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  String get _message {
    final e = error;
    if (e is ApiException) {
      if (e.isUnauthorized) return 'Your session has expired. Please sign in again.';
      if (e.isForbidden) return "You don't have access to this.";
      return e.message;
    }
    return "Couldn't load this. Check your connection and try again.";
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ArdentSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: ArdentColors.fg3),
            const SizedBox(height: ArdentSpacing.s3),
            Text(_message,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: ArdentColors.fg2)),
            const SizedBox(height: ArdentSpacing.s4),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple centered empty-state message for lists with no items.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_rounded});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ArdentSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: ArdentColors.fg3),
            const SizedBox(height: ArdentSpacing.s3),
            Text(message,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: ArdentColors.fg3)),
          ],
        ),
      ),
    );
  }
}
