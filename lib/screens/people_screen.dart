import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import 'user_profile_screen.dart';

/// People directory — backed by `GET /users` (with server-side `?search=`).
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Person>> _load() async {
    final raw = await Api.instance.users.list(search: _search.isEmpty ? null : _search);
    return raw.map(personFromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              ArdentSpacing.s4, ArdentSpacing.s4, ArdentSpacing.s4, ArdentSpacing.s2),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => setState(() => _search = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search people…',
              prefixIcon: const Icon(Icons.search_rounded, color: ArdentColors.fg3),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _search = '';
                      }),
                    ),
            ),
          ),
        ),
        Expanded(
          child: AsyncView<List<Person>>(
            // Re-run the loader when the search term changes.
            key: ValueKey(_search),
            loader: _load,
            builder: (context, people, reload) {
              if (people.isEmpty) {
                return const EmptyState(
                    message: 'No people found.', icon: Icons.people_outline_rounded);
              }
              return RefreshIndicator(
                onRefresh: reload,
                child: ListView.separated(
                  padding: const EdgeInsets.all(ArdentSpacing.s4),
                  itemCount: people.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: ArdentSpacing.s3),
                  itemBuilder: (context, i) {
                    if (i == 0) return Overline('${people.length} people');
                    final p = people[i - 1];
                    return _personCard(context, p, text);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _personCard(BuildContext context, Person p, TextTheme text) {
    return SurfaceCard(
      child: Row(
        children: [
          DsAvatar(initials: p.initials, color: p.color, size: 46, online: p.online),
          const SizedBox(width: ArdentSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: text.titleMedium?.copyWith(fontSize: 15)),
                Text(p.role, style: text.bodyMedium),
                Text(
                  p.lastActive,
                  style: text.bodySmall?.copyWith(
                      color: p.online ? const Color(0xFF2FAE5C) : ArdentColors.fg3),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => UserProfileScreen(person: p)),
            ),
            icon: const Icon(Icons.person_outline_rounded, size: 16),
            label: const Text('View'),
          ),
        ],
      ),
    );
  }
}
