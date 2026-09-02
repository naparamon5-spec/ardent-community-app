import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';
import 'group_chat_screen.dart';

/// Chats — direct-message threads, group threads, and a people/groups directory
/// to start new conversations (`GET /groups/direct`, `GET /groups`,
/// `GET /users`; `POST /groups/direct` to open a DM).
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsData {
  const _ChatsData(this.dms, this.groups, this.people);
  final List<Group> dms;
  final List<Group> groups;
  final List<Person> people;
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  int _tab = 0; // 0 = People, 1 = Groups

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<_ChatsData> _load() async {
    final results = await Future.wait([
      Api.instance.groups.directThreads().catchError((_) => <dynamic>[]),
      Api.instance.groups.list().catchError((_) => <dynamic>[]),
      Api.instance.users.list().catchError((_) => <dynamic>[]),
    ]);
    final dms = results[0].map(groupFromJson).toList();
    final groups =
        results[1].map(groupFromJson).where((g) => !g.isDirect).toList();
    final meId = AppSession.instance.me.id;
    final people = results[2]
        .map(personFromJson)
        .where((p) => p.id.isNotEmpty && p.id != meId)
        .toList();
    return _ChatsData(dms, groups, people);
  }

  bool _matches(String s) =>
      _search.isEmpty || s.toLowerCase().contains(_search.toLowerCase());

  Future<void> _openPerson(Person p) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final raw = await Api.instance.groups.openDirect(p.id);
      final g = groupFromJson(raw);
      final thread = Group(
        id: g.id,
        name: p.name,
        color: p.color,
        desc: '',
        isDirect: true,
        joined: true,
        members: 2,
        online: p.online,
        lastActive: p.lastActive,
      );
      navigator.push(
        MaterialPageRoute(builder: (_) => GroupChatScreen(group: thread)),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openThread(Group g) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupChatScreen(group: g)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(
              ArdentSpacing.s4, ArdentSpacing.s3, ArdentSpacing.s4, ArdentSpacing.s3),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search chats',
              filled: true,
              fillColor: ArdentColors.bgSubtle,
              prefixIcon: const Icon(Icons.search_rounded, color: ArdentColors.fg3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ArdentRadii.pill),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ArdentRadii.pill),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ArdentRadii.pill),
                borderSide: const BorderSide(color: ArdentColors.accent),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
        // People / Groups segmented control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: ArdentColors.bgSubtle,
              borderRadius: BorderRadius.circular(ArdentRadii.pill),
            ),
            child: Row(
              children: [
                _segment('People', Icons.person_outline_rounded, 0),
                _segment('Groups', Icons.groups_rounded, 1),
              ],
            ),
          ),
        ),
        const SizedBox(height: ArdentSpacing.s2),
        Expanded(
          child: AsyncView<_ChatsData>(
            loader: _load,
            builder: (context, data, reload) => RefreshIndicator(
              onRefresh: reload,
              child: _tab == 0 ? _peopleView(data) : _groupsView(data),
            ),
          ),
        ),
      ],
    );
  }

  Widget _segment(String label, IconData icon, int value) {
    final active = _tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? ArdentColors.bgSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(ArdentRadii.pill),
            boxShadow: active
                ? const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 1))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17, color: active ? ArdentColors.accent : ArdentColors.fg2),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: active ? ArdentColors.accent : ArdentColors.fg2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _peopleView(_ChatsData data) {
    final dms = data.dms.where((g) => _matches(g.name)).toList();
    final people = data.people.where((p) => _matches(p.name)).toList();
    final online = people.where((p) => p.online).length;
    return ListView(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s10),
      children: [
        if (dms.isNotEmpty) ...[
          _sectionLabel('Conversations', dms.length),
          for (final g in dms) _dmTile(g),
        ],
        _sectionLabel('People', people.length,
            trailing: online > 0 ? '$online online' : null),
        if (people.isEmpty)
          _emptyLine('No people found.')
        else
          for (final p in people) _personTile(p),
      ],
    );
  }

  Widget _groupsView(_ChatsData data) {
    final joined = data.groups.where((g) => g.joined && _matches(g.name)).toList();
    final other = data.groups.where((g) => !g.joined && _matches(g.name)).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s10),
      children: [
        if (joined.isNotEmpty) ...[
          _sectionLabel('Conversations', joined.length),
          for (final g in joined) _groupTile(g),
        ],
        if (other.isNotEmpty) ...[
          _sectionLabel('Discover groups', other.length),
          for (final g in other) _groupTile(g),
        ],
        if (joined.isEmpty && other.isEmpty) _emptyLine('No groups found.'),
      ],
    );
  }

  Widget _sectionLabel(String text, int count, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ArdentSpacing.s4, ArdentSpacing.s4, ArdentSpacing.s4, ArdentSpacing.s1),
      child: Row(
        children: [
          Overline(text),
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
          const Spacer(),
          if (trailing != null)
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: Color(0xFF2FAE5C), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(trailing,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ArdentColors.fg3)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _emptyLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ArdentSpacing.s4, vertical: ArdentSpacing.s4),
      child: Center(
        child: Text(text, style: const TextStyle(color: ArdentColors.fg3)),
      ),
    );
  }

  /// Shared row shell: press ripple, avatar, title/subtitle, trailing widget.
  Widget _row({
    required Widget avatar,
    required String title,
    required Widget subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ArdentSpacing.s4, vertical: 8),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: ArdentSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  subtitle,
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: ArdentSpacing.s2),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _subtitle(String text, {Color color = ArdentColors.fg3}) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 13),
      );

  Widget _dmTile(Group g) {
    return _row(
      avatar: DsAvatar(initials: initialsFrom(g.name), color: g.color, size: 48, imageUrl: g.photoUrl),
      title: g.name,
      subtitle: Row(
        children: [
          const Icon(Icons.check_rounded, size: 13, color: ArdentColors.fg3),
          const SizedBox(width: 3),
          Flexible(child: _subtitle('Direct message')),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: ArdentColors.fg3),
      onTap: () => _openThread(g),
    );
  }

  Widget _groupTile(Group g) {
    return _row(
      avatar: _groupAvatar(g),
      title: g.name,
      subtitle: _subtitle('${g.members} member${g.members == 1 ? '' : 's'}'),
      trailing: g.joined
          ? const Icon(Icons.chevron_right_rounded, color: ArdentColors.fg3)
          : _actionButton(Icons.chat_bubble_outline_rounded, () => _openThread(g)),
      onTap: () => _openThread(g),
    );
  }

  /// A group's 48px avatar — its uploaded photo when set, else the gradient
  /// group-icon fallback (also used if the photo fails to load).
  Widget _groupAvatar(Group g) {
    final fallback = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [g.color, Color.lerp(g.color, Colors.black, 0.28)!],
        ),
        borderRadius: BorderRadius.circular(ArdentRadii.md),
      ),
      child: const Icon(Icons.groups_rounded, color: Colors.white),
    );
    if (g.photoUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      child: Image.network(
        g.photoUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  Widget _personTile(Person p) {
    return _row(
      avatar: DsAvatar(
          initials: p.initials, color: p.color, size: 48, online: p.online, imageUrl: p.avatarUrl),
      title: p.name,
      subtitle: _subtitle(
        p.online ? 'Active now' : p.lastActive,
        color: p.online ? const Color(0xFF2FAE5C) : ArdentColors.fg3,
      ),
      trailing: _actionButton(
          Icons.chat_bubble_outline_rounded, () => _openPerson(p)),
      onTap: () => _openPerson(p),
    );
  }

  /// Circular soft-accent action button used on directory rows.
  Widget _actionButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: ArdentColors.accentSoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18, color: ArdentColors.accent),
        ),
      ),
    );
  }
}
