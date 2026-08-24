import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'user_profile_screen.dart';

/// Cross-entity search — backed by `GET /search?q=` (people, posts, listings).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';
  String _committed = '';
  final List<String> _recent = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _run(String term) {
    final t = term.trim();
    setState(() {
      _ctrl.text = t;
      _query = t;
      _committed = t;
      if (t.isNotEmpty && !_recent.contains(t)) _recent.insert(0, t);
    });
  }

  Future<({List<Person> people, List<Listing> listings})> _search() async {
    final data = await Api.instance.search.query(_committed);
    final people = asList(data['people'] ?? data['users']).map(personFromJson).toList();
    final listings = asList(data['listings']).map(listingFromJson).toList();
    return (people: people, listings: listings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: _run,
          decoration: InputDecoration(
            hintText: 'Search Ardent Community',
            isDense: true,
            filled: true,
            fillColor: ArdentColors.bgSubtle,
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: ArdentColors.fg3),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() {
                      _ctrl.clear();
                      _query = '';
                      _committed = '';
                    }),
                  ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ArdentRadii.pill),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ArdentRadii.pill),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      body: _committed.trim().isEmpty ? _recentList() : _results(),
    );
  }

  Widget _recentList() {
    final text = Theme.of(context).textTheme;
    if (_recent.isEmpty) {
      return Center(
        child: Text('Search people, posts, and listings',
            style: text.bodyLarge?.copyWith(color: ArdentColors.fg3)),
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Expanded(child: Overline('Recent')),
              GestureDetector(
                onTap: () => setState(_recent.clear),
                child: const Text('Clear all',
                    style: TextStyle(
                        color: ArdentColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ],
          ),
        ),
        for (final term in _recent)
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: ArdentColors.bgSubtle,
              child: Icon(Icons.history_rounded, color: ArdentColors.fg2),
            ),
            title: Text(term, style: text.bodyLarge?.copyWith(color: ArdentColors.fg1)),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: ArdentColors.fg3),
              onPressed: () => setState(() => _recent.remove(term)),
            ),
            onTap: () => _run(term),
          ),
      ],
    );
  }

  Widget _results() {
    final text = Theme.of(context).textTheme;
    return FutureBuilder<({List<Person> people, List<Listing> listings})>(
      key: ValueKey(_committed),
      future: _search(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text("Couldn't search right now. Try again.",
                  textAlign: TextAlign.center, style: text.bodyLarge),
            ),
          );
        }
        final people = snapshot.data!.people;
        final listings = snapshot.data!.listings;
        if (people.isEmpty && listings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No results for "$_committed"',
                  textAlign: TextAlign.center, style: text.bodyLarge),
            ),
          );
        }
        return ListView(
          children: [
            if (people.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Overline('People'),
              ),
              for (final p in people)
                ListTile(
                  leading: DsAvatar(initials: p.initials, color: p.color, size: 42),
                  title: Text(p.name, style: text.titleMedium?.copyWith(fontSize: 15)),
                  subtitle: Text(p.role),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => UserProfileScreen(person: p)),
                  ),
                ),
            ],
            if (listings.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Overline('Marketplace'),
              ),
              for (final l in listings)
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: l.color,
                      borderRadius: BorderRadius.circular(ArdentRadii.sm),
                    ),
                    child: const Icon(Icons.image_outlined, color: Colors.white54),
                  ),
                  title: Text(l.title, style: text.titleMedium?.copyWith(fontSize: 15)),
                  subtitle: Text('${l.price} · ${l.seller}'),
                ),
            ],
          ],
        );
      },
    );
  }
}
