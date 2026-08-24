import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Facebook-style search — a full-screen field with recent searches below,
/// filtering people and groups as you type.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  // A little seeded history so the empty state looks alive.
  final List<String> _recent = ['Sportsfest 2026', 'Priya Nandakumar', 'Design Community'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
      body: _query.trim().isEmpty ? _recentList() : _results(),
    );
  }

  Widget _recentList() {
    final text = Theme.of(context).textTheme;
    if (_recent.isEmpty) {
      return Center(
        child: Text('No recent searches', style: text.bodyLarge),
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
            onTap: () => setState(() {
              _ctrl.text = term;
              _query = term;
            }),
          ),
      ],
    );
  }

  Widget _results() {
    final text = Theme.of(context).textTheme;
    final q = _query.toLowerCase();
    final people = Seed.people.where((p) => p.name.toLowerCase().contains(q)).toList();
    final groups = Seed.groups.where((g) => g.name.toLowerCase().contains(q)).toList();

    if (people.isEmpty && groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No results for "$_query"',
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
              onTap: () => _pick(p.name),
            ),
        ],
        if (groups.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Overline('Groups'),
          ),
          for (final g in groups)
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: g.color,
                  borderRadius: BorderRadius.circular(ArdentRadii.sm),
                ),
              ),
              title: Text(g.name, style: text.titleMedium?.copyWith(fontSize: 15)),
              subtitle: Text('${g.members} members'),
              onTap: () => _pick(g.name),
            ),
        ],
      ],
    );
  }

  void _pick(String term) {
    if (!_recent.contains(term)) {
      setState(() => _recent.insert(0, term));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening "$term"')),
    );
  }
}
