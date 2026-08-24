import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import 'create_listing_screen.dart';
import 'listing_detail_screen.dart';

/// Mall of Ardent — backed by `GET /categories` and `GET /listings`, with a
/// "Sell something" flow (`POST /listings`), a Show-sold filter, and a listing
/// detail page.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _category = 'All';
  bool _showSold = false;
  int _reloadTick = 0;
  String _search = '';
  final _searchCtrl = TextEditingController();
  late Future<List<String>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    final raw = await Api.instance.listings.list(
      category: _category == 'All' ? null : _category,
      search: _search.isEmpty ? null : _search,
    );
    final all = raw.map(listingFromJson).toList();
    return _showSold ? all : all.where((l) => !l.sold).toList();
  }

  Future<void> _openSell() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (created == true && mounted) setState(() => _reloadTick++);
  }

  Future<void> _openDetail(Listing l) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: l)),
    );
    if (mounted) setState(() => _reloadTick++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mall of Ardent')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSell,
        icon: const Icon(Icons.sell_rounded),
        label: const Text('Sell'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ArdentSpacing.s4, ArdentSpacing.s3, ArdentSpacing.s4, ArdentSpacing.s2),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() {
                _search = v.trim();
                _reloadTick++;
              }),
              decoration: InputDecoration(
                hintText: 'Search the marketplace…',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, color: ArdentColors.fg3),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _search = '';
                          _reloadTick++;
                        }),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: FutureBuilder<List<String>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                final categories = snapshot.data ?? const ['All'];
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ArdentSpacing.s4, ArdentSpacing.s2, ArdentSpacing.s2, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Buy, sell, and give away with coworkers.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ArdentColors.fg3, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                const Text('Show sold',
                    style: TextStyle(
                        color: ArdentColors.fg2,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Switch(
                  value: _showSold,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeThumbColor: ArdentColors.accent,
                  onChanged: (v) => setState(() {
                    _showSold = v;
                    _reloadTick++;
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<Listing>>(
              key: ValueKey('$_category-$_showSold-$_reloadTick'),
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
                    padding: const EdgeInsets.fromLTRB(ArdentSpacing.s4,
                        ArdentSpacing.s3, ArdentSpacing.s4, ArdentSpacing.s12),
                    crossAxisCount: 2,
                    crossAxisSpacing: ArdentSpacing.s3,
                    mainAxisSpacing: ArdentSpacing.s3,
                    childAspectRatio: 0.68,
                    children: [for (final l in listings) _listingCard(l)],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _listingCard(Listing l) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _openDetail(l),
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(ArdentRadii.md)),
                    child: l.coverUrl.isNotEmpty
                        ? Image.network(l.coverUrl, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _imagePlaceholder(l))
                        : _imagePlaceholder(l),
                  ),
                  if (l.sold)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(ArdentRadii.pill),
                        ),
                        child: const Text('SOLD',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(ArdentSpacing.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.price,
                    style: text.titleMedium?.copyWith(
                      color: l.free ? ArdentColors.statusResolved : ArdentColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(l.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600, color: ArdentColors.fg1)),
                  const SizedBox(height: 2),
                  Text('${l.category} · ${l.seller}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder(Listing l) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [l.color, l.color.withValues(alpha: 0.65)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white54, size: 30),
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
