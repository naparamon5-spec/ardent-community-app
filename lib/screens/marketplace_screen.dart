import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

/// Mall of Ardent — backed by `GET /categories` and `GET /listings`
/// (category filtered server-side).
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _category = 'All';
  late Future<List<String>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
  }

  Future<List<String>> _loadCategories() async {
    try {
      final raw = await Api.instance.categories.list();
      final names = raw
          .map((c) => asMap(c)['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      return ['All', ...names];
    } on ApiException {
      return const ['All'];
    }
  }

  Future<List<Listing>> _loadListings() async {
    final raw = await Api.instance.listings
        .list(category: _category == 'All' ? null : _category);
    return raw.map(listingFromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 52,
          child: FutureBuilder<List<String>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              final categories = snapshot.data ?? const ['All'];
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: ArdentSpacing.s4, vertical: 8),
                children: [
                  for (final c in categories) ...[
                    _categoryChip(c),
                    const SizedBox(width: 8),
                  ],
                ],
              );
            },
          ),
        ),
        Expanded(
          child: AsyncView<List<Listing>>(
            key: ValueKey(_category),
            loader: _loadListings,
            builder: (context, listings, reload) {
              if (listings.isEmpty) {
                return const EmptyState(
                    message: 'No listings here yet.',
                    icon: Icons.storefront_outlined);
              }
              return RefreshIndicator(
                onRefresh: reload,
                child: GridView.count(
                  padding: const EdgeInsets.all(ArdentSpacing.s4),
                  crossAxisCount: 2,
                  crossAxisSpacing: ArdentSpacing.s3,
                  mainAxisSpacing: ArdentSpacing.s3,
                  childAspectRatio: 0.72,
                  children: [for (final l in listings) _listingCard(l)],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _listingCard(Listing l) {
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [l.color, l.color.withValues(alpha: 0.65)],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(ArdentRadii.md)),
              ),
              child: const Center(
                child: Icon(Icons.image_outlined, color: Colors.white54, size: 34),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ArdentSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600, color: ArdentColors.fg1)),
                const SizedBox(height: 4),
                Text(
                  l.price,
                  style: text.titleMedium?.copyWith(
                    color: l.free ? ArdentColors.statusResolved : ArdentColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(l.seller, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String c) {
    final active = c == _category;
    return GestureDetector(
      onTap: () => setState(() => _category = c),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? ArdentColors.accent : ArdentColors.bgSubtle,
          borderRadius: BorderRadius.circular(ArdentRadii.pill),
          border: Border.all(color: active ? ArdentColors.accent : ArdentColors.border),
        ),
        child: Text(
          c,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : ArdentColors.fg2,
          ),
        ),
      ),
    );
  }
}
