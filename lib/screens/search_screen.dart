import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import '../widgets/post_card.dart';
import 'events_screen.dart';
import 'group_chat_screen.dart';
import 'listing_detail_screen.dart';
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
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// Live search as the user types (debounced so we don't hit the API on every
  /// keystroke).
  void _onChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    final t = v.trim();
    if (t.isEmpty) {
      setState(() => _committed = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _committed = t);
    });
  }

  void _run(String term) {
    _debounce?.cancel();
    final t = term.trim();
    setState(() {
      _ctrl.text = t;
      _query = t;
      _committed = t;
      if (t.isNotEmpty && !_recent.contains(t)) _recent.insert(0, t);
    });
  }

  Future<_Results> _search() async {
    final q = _committed.trim();
    final lower = q.toLowerCase();
    final res = await Future.wait([
      Api.instance.search.query(q),
      Api.instance.events.list().catchError((_) => <dynamic>[]),
      Api.instance.groups.list().catchError((_) => <dynamic>[]),
    ]);
    final data = asMap(res[0]);
    final people =
        asList(data['people'] ?? data['users']).map(personFromJson).toList();
    final posts = asList(data['posts']).map(postFromJson).toList();
    final listings = asList(data['listings']).map(listingFromJson).toList();

    bool has(String s) => s.toLowerCase().contains(lower);
    final events = (res[1] as List)
        .map(eventFromJson)
        .where((e) => has('${e.title} ${e.location} ${e.desc}'))
        .toList();
    final groups = (res[2] as List)
        .map(groupFromJson)
        .where((g) => !g.isDirect && has('${g.name} ${g.desc}'))
        .toList();
    return _Results(
        people: people,
        posts: posts,
        events: events,
        groups: groups,
        listings: listings);
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
          onChanged: _onChanged,
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
        child: Text('Search people, posts, events, groups, and listings',
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
    return FutureBuilder<_Results>(
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
        final r = snapshot.data!;
        if (r.isEmpty) {
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
            if (r.people.isNotEmpty) ...[
              _section('People', r.people.length),
              for (final p in r.people) _personTile(p, text),
            ],
            if (r.posts.isNotEmpty) ...[
              _section('Posts', r.posts.length),
              for (final p in r.posts) _postTile(p, text),
            ],
            if (r.events.isNotEmpty) ...[
              _section('Events', r.events.length),
              for (final e in r.events) _eventTile(e, text),
            ],
            if (r.groups.isNotEmpty) ...[
              _section('Groups', r.groups.length),
              for (final g in r.groups) _groupTile(g, text),
            ],
            if (r.listings.isNotEmpty) ...[
              _section('Marketplace', r.listings.length),
              for (final l in r.listings) _listingTile(l, text),
            ],
            const SizedBox(height: ArdentSpacing.s6),
          ],
        );
      },
    );
  }

  Widget _section(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Overline(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: ArdentColors.bgSubtle,
              borderRadius: BorderRadius.circular(ArdentRadii.pill),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ArdentColors.fg2)),
          ),
        ],
      ),
    );
  }

  Widget _personTile(Person p, TextTheme text) {
    return ListTile(
      leading: DsAvatar(initials: p.initials, color: p.color, size: 42),
      title: Text(p.name, style: text.titleMedium?.copyWith(fontSize: 15)),
      subtitle: Text(p.role),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserProfileScreen(person: p)),
      ),
    );
  }

  Widget _postTile(Post post, TextTheme text) {
    final snippet = post.title.isNotEmpty ? post.title : post.text;
    return ListTile(
      leading: DsAvatar(
          initials: post.author.initials, color: post.author.color, size: 42),
      title: Text(post.author.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(fontSize: 15)),
      subtitle: Text(snippet,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(color: ArdentColors.fg3)),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Post')),
            body: ListView(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              children: [PostCard(post: post)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _eventTile(EventItem e, TextTheme text) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: ArdentColors.accentSoft,
          borderRadius: BorderRadius.circular(ArdentRadii.sm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(e.mon.toUpperCase(),
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: ArdentColors.accent)),
            Text(e.day,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ArdentColors.accent)),
          ],
        ),
      ),
      title: Text(e.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(fontSize: 15)),
      subtitle: Text(
          [e.time, if (e.location.isNotEmpty) e.location].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EventsScreen()),
      ),
    );
  }

  Widget _groupTile(Group g, TextTheme text) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: g.color,
          borderRadius: BorderRadius.circular(ArdentRadii.md),
        ),
        child: const Icon(Icons.groups_rounded, color: Colors.white),
      ),
      title: Text(g.name, style: text.titleMedium?.copyWith(fontSize: 15)),
      subtitle: Text('${g.members} members',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupChatScreen(group: g)),
      ),
    );
  }

  Widget _listingTile(Listing l, TextTheme text) {
    return ListTile(
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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: l)),
      ),
    );
  }
}

/// Grouped, cross-entity search results.
class _Results {
  const _Results({
    required this.people,
    required this.posts,
    required this.events,
    required this.groups,
    required this.listings,
  });
  final List<Person> people;
  final List<Post> posts;
  final List<EventItem> events;
  final List<Group> groups;
  final List<Listing> listings;

  bool get isEmpty =>
      people.isEmpty &&
      posts.isEmpty &&
      events.isEmpty &&
      groups.isEmpty &&
      listings.isEmpty;
}
