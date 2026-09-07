import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import '../widgets/post_card.dart';
import 'settings_screen.dart';

/// Profile — the signed-in user with web-parity tabs: Posts, Activities,
/// Certificates, and About. Data is live: own posts (`GET /users/:id/posts`),
/// certificates (`GET /users/me/certificates`), HR details (`GET /users/me/hr`),
/// and joined groups (`GET /groups`).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _Tab { posts, activities, certificates, about }

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileData> _future;
  _Tab _tab = _Tab.posts;
  int _activityFilter = 0; // 0 All, 1 Posts, 2 Groups, 3 Events
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;

  // ---- Add-certificate form state ----
  bool _addingCert = false;
  bool _savingCert = false;
  final _certTitle = TextEditingController();
  final _certIssuer = TextEditingController();
  String? _certFileName;
  Uint8List? _certBytes;
  DateTime? _certIssuedOn;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _certTitle.dispose();
    _certIssuer.dispose();
    super.dispose();
  }

  Future<_ProfileData> _load() async {
    final api = Api.instance;
    final me = AppSession.instance.me;
    final results = await Future.wait([
      api.users.posts(me.id).then((r) => r.map(postFromJson).toList()).catchError(
          (_) => <Post>[]),
      api.users.myCertificates().then((r) => r.map(asMap).toList()).catchError(
          (_) => <Map<String, dynamic>>[]),
      api.users.myHr().catchError((_) => <String, dynamic>{}),
      // Joined groups (not direct threads) — powers both the stat count and the
      // Groups activity filter.
      api.groups
          .list()
          .then((r) =>
              r.map(groupFromJson).where((g) => g.joined && !g.isDirect).toList())
          .catchError((_) => <Group>[]),
      // Full profile JSON — carries fields the lightweight `me` Person omits
      // (phone, manager, interests, hobbies, likes) so About mirrors the web.
      api.users.get(me.id).catchError((_) => <String, dynamic>{}),
      // Events the user RSVP'd to — powers the Events activity filter.
      api.events
          .list()
          .then((r) =>
              r.map(eventFromJson).where((e) => e.myRsvp.isNotEmpty).toList())
          .catchError((_) => <EventItem>[]),
    ]);
    return _ProfileData(
      posts: results[0] as List<Post>,
      certificates: results[1] as List<Map<String, dynamic>>,
      hr: results[2] as Map<String, dynamic>,
      groups: results[3] as List<Group>,
      profile: results[4] as Map<String, dynamic>,
      events: results[5] as List<EventItem>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next.catchError((_) => _ProfileData(
        posts: const [],
        certificates: const [],
        hr: const {},
        groups: const [],
        profile: const {},
        events: const []));
  }

  @override
  Widget build(BuildContext context) {
    final me = AppSession.instance.me;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _coverAndAvatar(me),
              const SizedBox(height: ArdentSpacing.s3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
                    Text(me.role.isEmpty ? 'Community Member' : me.role,
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: ArdentSpacing.s4),
                    _actions(context),
                    const SizedBox(height: ArdentSpacing.s5),
                    _statsRow(data),
                    const SizedBox(height: ArdentSpacing.s5),
                    _tabBar(),
                    const SizedBox(height: ArdentSpacing.s4),
                  ],
                ),
              ),
              _tabContent(data),
              const SizedBox(height: ArdentSpacing.s8),
            ],
          );
        },
      ),
    );
  }

  // ---- Header ---------------------------------------------------------------

  Widget _coverGradient() => Container(
        height: 132,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ArdentColors.navy800, ArdentColors.navy900],
          ),
        ),
      );

  Widget _coverAndAvatar(Person me) {
    // A single fixed-height box holds everything as direct children so every
    // control stays inside the Stack's bounds and remains tappable (Positioned
    // children painted outside a Stack don't receive taps, even with Clip.none).
    const coverH = 132.0;
    const avatarBox = 92.0; // 84 avatar + 4 white ring on each side
    const avatarLeft = ArdentSpacing.s4;
    const avatarTop = 90.0; // overhangs the cover
    const headerH = avatarTop + avatarBox + 6; // 188
    return SizedBox(
      height: headerH,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cover photo / gradient.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: coverH,
            child: me.coverUrl.isEmpty
                ? _coverGradient()
                : Image.network(
                    me.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _coverGradient(),
                  ),
          ),
          if (_uploadingCover)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: coverH,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0x55000000)),
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  ),
                ),
              ),
            ),
          // ⋯ menu for the cover photo (top-right).
          Positioned(
            top: ArdentSpacing.s3,
            right: ArdentSpacing.s3,
            child: _dotButton(onTap: _uploadingCover ? null : _coverMenu),
          ),
          // Avatar (overhangs the cover but stays within this box).
          Positioned(
            left: avatarLeft,
            top: avatarTop,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration:
                  const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: DsAvatar(
                  initials: me.initials,
                  color: me.color,
                  size: 84,
                  imageUrl: me.avatarUrl),
            ),
          ),
          if (_uploadingAvatar)
            const Positioned(
              left: avatarLeft + 4,
              top: avatarTop + 4,
              width: 84,
              height: 84,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Color(0x66000000), shape: BoxShape.circle),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  ),
                ),
              ),
            ),
          // ⋯ menu badge for the profile picture (bottom-right of the avatar).
          Positioned(
            left: avatarLeft + avatarBox - 26,
            top: avatarTop + avatarBox - 26,
            child: _dotButton(
                onTap: _uploadingAvatar ? null : _avatarMenu, size: 30),
          ),
        ],
      ),
    );
  }

  /// A round white ⋯ button used to open a photo menu.
  Widget _dotButton({required VoidCallback? onTap, double size = 34}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1.5,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.more_horiz_rounded,
              size: size * 0.55, color: ArdentColors.fg2),
        ),
      ),
    );
  }

  void _coverMenu() {
    _photoSheet(
      title: 'Cover photo',
      actionLabel: AppSession.instance.me.coverUrl.isEmpty
          ? 'Upload cover photo'
          : 'Change cover photo',
      icon: Icons.image_outlined,
      onPick: _changeCover,
    );
  }

  void _avatarMenu() {
    _photoSheet(
      title: 'Profile picture',
      actionLabel: AppSession.instance.me.avatarUrl.isEmpty
          ? 'Upload profile picture'
          : 'Change profile picture',
      icon: Icons.person_outline_rounded,
      onPick: _changeAvatar,
    );
  }

  /// Bottom-sheet menu opened by a ⋯ button, offering the photo action.
  void _photoSheet({
    required String title,
    required String actionLabel,
    required IconData icon,
    required Future<void> Function() onPick,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  ArdentSpacing.s5, 0, ArdentSpacing.s5, ArdentSpacing.s2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title,
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            ListTile(
              leading: Icon(icon, color: ArdentColors.accent),
              title: Text(actionLabel),
              onTap: () {
                Navigator.of(ctx).pop();
                onPick();
              },
            ),
            const SizedBox(height: ArdentSpacing.s2),
          ],
        ),
      ),
    );
  }

  Future<void> _changeAvatar() async {
    await _pickAndUpload(
      isCover: false,
      onUploading: (v) => setState(() => _uploadingAvatar = v),
    );
  }

  Future<void> _changeCover() async {
    await _pickAndUpload(
      isCover: true,
      onUploading: (v) => setState(() => _uploadingCover = v),
    );
  }

  /// Picks an image and uploads it as the avatar or cover, then refreshes the
  /// session so it shows immediately on mobile (and the web — same account).
  Future<void> _pickAndUpload({
    required bool isCover,
    required void Function(bool) onUploading,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (picked == null) return;
      onUploading(true);
      final bytes = await picked.readAsBytes();
      final name = picked.name.isEmpty
          ? (isCover ? 'cover.jpg' : 'avatar.jpg')
          : picked.name;
      final contentType = 'image/${_ext(name, fallback: 'jpeg')}';
      if (isCover) {
        await Api.instance.users
            .uploadCover(bytes: bytes, filename: name, contentType: contentType);
      } else {
        await Api.instance.users
            .uploadAvatar(bytes: bytes, filename: name, contentType: contentType);
      }
      await AppSession.instance.loadMe();
      if (!mounted) return;
      onUploading(false);
      messenger.showSnackBar(SnackBar(
          content: Text(isCover ? 'Cover photo updated' : 'Profile picture updated')));
    } on ApiException catch (e) {
      if (!mounted) return;
      onUploading(false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      onUploading(false);
      messenger.showSnackBar(const SnackBar(content: Text('Could not update photo')));
    }
  }

  static String _ext(String name, {required String fallback}) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return fallback;
    return name.substring(i + 1).toLowerCase();
  }

  Widget _actions(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
        icon: const Icon(Icons.settings_outlined, size: 18),
        label: const Text('Profile settings'),
      ),
    );
  }

  Widget _statsRow(_ProfileData? data) {
    final text = Theme.of(context).textTheme;
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, style: text.titleLarge?.copyWith(fontSize: 20)),
              Text(label, style: text.bodySmall),
            ],
          ),
        );
    Widget divider() => Container(width: 1, height: 34, color: ArdentColors.border);
    return SurfaceCard(
      child: Row(
        children: [
          stat('${data?.posts.length ?? '—'}', 'Posts'),
          divider(),
          stat('${data?.groupCount ?? '—'}', 'Groups'),
          divider(),
          stat('${data?.kudosReceived ?? '—'}', 'Kudos received'),
        ],
      ),
    );
  }

  // ---- Tabs -----------------------------------------------------------------

  Widget _tabBar() {
    const labels = {
      _Tab.posts: 'Posts',
      _Tab.activities: 'Activities',
      _Tab.certificates: 'Certificates',
      _Tab.about: 'About',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in labels.entries) ...[
            _tabChip(entry.value, _tab == entry.key, () => setState(() => _tab = entry.key)),
            const SizedBox(width: ArdentSpacing.s2),
          ],
        ],
      ),
    );
  }

  Widget _tabChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: active ? ArdentColors.accent : ArdentColors.bgSubtle,
          borderRadius: BorderRadius.circular(ArdentRadii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: active ? Colors.white : ArdentColors.fg2,
          ),
        ),
      ),
    );
  }

  Widget _tabContent(_ProfileData? data) {
    if (data == null) {
      return const Padding(
        padding: EdgeInsets.all(ArdentSpacing.s8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    switch (_tab) {
      case _Tab.posts:
        return _postsList(data.posts);
      case _Tab.activities:
        return _activities(data);
      case _Tab.certificates:
        return _certificates(data.certificates);
      case _Tab.about:
        return _about(data);
    }
  }

  Widget _empty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
      child: Text(message,
          style: TextStyle(color: ArdentColors.fg3, fontSize: 14)),
    );
  }

  // ---- Posts ----------------------------------------------------------------

  Widget _postsList(List<Post> posts) {
    if (posts.isEmpty) return _empty('Nothing in this category yet.');
    return Column(
      children: [
        for (final p in posts) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
            child: PostCard(post: p),
          ),
          const SizedBox(height: ArdentSpacing.s3),
        ],
      ],
    );
  }

  // ---- Activities -----------------------------------------------------------

  Widget _activities(_ProfileData data) {
    const filters = ['All', 'Posts', 'Groups', 'Events'];
    final all = _activityFilter == 0;
    final content = <Widget>[];

    if ((all || _activityFilter == 1) && data.posts.isNotEmpty) {
      content.add(_postsList(data.posts));
    }
    if ((all || _activityFilter == 2) && data.groups.isNotEmpty) {
      content.add(_groupsList(data.groups));
    }
    if ((all || _activityFilter == 3) && data.events.isNotEmpty) {
      content.add(_eventsList(data.events));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < filters.length; i++) ...[
                  _activityChip(filters[i], i),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: ArdentSpacing.s4),
        if (content.isEmpty)
          _empty('Nothing in this category yet.')
        else
          for (final w in content) ...[
            w,
            const SizedBox(height: ArdentSpacing.s3),
          ],
      ],
    );
  }

  /// Joined-groups list for the Groups activity filter.
  Widget _groupsList(List<Group> groups) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
      child: SurfaceCard(
        child: Column(
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const Divider(height: ArdentSpacing.s5),
              Row(
                children: [
                  DsAvatar(
                    initials: initialsFrom(groups[i].name),
                    color: groups[i].color,
                    imageUrl: groups[i].photoUrl,
                    size: 40,
                  ),
                  const SizedBox(width: ArdentSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(groups[i].name,
                            style: text.titleMedium?.copyWith(fontSize: 14)),
                        Text('${groups[i].members} members', style: text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// RSVP'd-events list for the Events activity filter.
  Widget _eventsList(List<EventItem> events) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
      child: SurfaceCard(
        child: Column(
          children: [
            for (var i = 0; i < events.length; i++) ...[
              if (i > 0) const Divider(height: ArdentSpacing.s5),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ArdentColors.bgSubtle,
                      borderRadius: BorderRadius.circular(ArdentRadii.sm),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(events[i].mon.toUpperCase(),
                            style: text.labelSmall
                                ?.copyWith(color: ArdentColors.accent, height: 1)),
                        Text(events[i].day,
                            style: text.titleMedium
                                ?.copyWith(fontSize: 15, height: 1.1)),
                      ],
                    ),
                  ),
                  const SizedBox(width: ArdentSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(events[i].title,
                            style: text.titleMedium?.copyWith(fontSize: 14)),
                        Text(
                          [
                            events[i].time,
                            if (events[i].location.isNotEmpty) events[i].location,
                          ].join(' · '),
                          style: text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  DsChip(
                    label: events[i].myRsvp == 'going' ? 'Going' : 'Interested',
                    fg: ArdentColors.accent,
                    bg: ArdentColors.bgSubtle,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _activityChip(String label, int index) {
    final active = _activityFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _activityFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? ArdentColors.accent : ArdentColors.bgSurface,
          borderRadius: BorderRadius.circular(ArdentRadii.pill),
          border: Border.all(color: active ? ArdentColors.accent : ArdentColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: active ? Colors.white : ArdentColors.fg2)),
      ),
    );
  }

  // ---- Certificates ---------------------------------------------------------

  Widget _certificates(List<Map<String, dynamic>> certs) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + add toggle (web: "CERTIFICATES — Images and PDFs, up to
          // 10 MB each." with an Add certificate action).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Overline('Certificates'),
                    const SizedBox(height: 2),
                    Text('Images and PDFs, up to 10 MB each.',
                        style: text.bodySmall),
                  ],
                ),
              ),
              if (!_addingCert)
                FilledButton.icon(
                  onPressed: () => setState(() => _addingCert = true),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add certificate'),
                ),
            ],
          ),
          const SizedBox(height: ArdentSpacing.s3),
          if (_addingCert) ...[
            _certForm(),
            const SizedBox(height: ArdentSpacing.s4),
          ],
          if (certs.isEmpty)
            _empty('No certificates yet.')
          else
            SurfaceCard(
              child: Column(
                children: [
                  for (var i = 0; i < certs.length; i++) ...[
                    if (i > 0) const Divider(height: ArdentSpacing.s5),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: ArdentColors.statusPendingBg,
                            borderRadius: BorderRadius.circular(ArdentRadii.sm),
                          ),
                          child: const Icon(Icons.workspace_premium_rounded,
                              color: Color(0xFFC77700), size: 22),
                        ),
                        const SizedBox(width: ArdentSpacing.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(certs[i]['title']?.toString() ?? 'Certificate',
                                  style: text.titleMedium?.copyWith(fontSize: 14)),
                              if (_certSubtitle(certs[i]).isNotEmpty)
                                Text(_certSubtitle(certs[i]), style: text.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _deleteCertificate(certs[i]),
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          color: ArdentColors.fg3,
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Issuer and/or issued date line under a certificate title.
  String _certSubtitle(Map<String, dynamic> cert) {
    final issuer = cert['issuer']?.toString().trim() ?? '';
    final issued = cert['issuedOn'];
    final date = issued == null ? '' : relativeDate(issued);
    return [issuer, date].where((s) => s.isNotEmpty).join(' · ');
  }

  /// The inline "Add certificate" form (web parity: file, title, issuer, date).
  Widget _certForm() {
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _savingCert ? null : _pickCertFile,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('Choose file'),
              ),
              const SizedBox(width: ArdentSpacing.s3),
              Expanded(
                child: Text(
                  _certFileName ?? 'No file chosen — image or PDF',
                  style: text.bodySmall?.copyWith(
                      color: _certFileName == null
                          ? ArdentColors.fg3
                          : ArdentColors.fg2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: ArdentSpacing.s3),
          Text('Title', style: text.labelMedium),
          const SizedBox(height: 4),
          TextField(
            controller: _certTitle,
            decoration: const InputDecoration(
                hintText: 'e.g. AWS Certified Solutions Architect'),
          ),
          const SizedBox(height: ArdentSpacing.s3),
          Text('Issued by', style: text.labelMedium),
          const SizedBox(height: 4),
          TextField(
            controller: _certIssuer,
            decoration: const InputDecoration(hintText: 'e.g. Amazon Web Services'),
          ),
          const SizedBox(height: ArdentSpacing.s3),
          Text('Issue date', style: text.labelMedium),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _savingCert ? null : _pickCertDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(
              _certIssuedOn == null
                  ? 'mm/dd/yyyy'
                  : relativeDateOnly(_certIssuedOn!.toIso8601String()),
            ),
          ),
          const SizedBox(height: ArdentSpacing.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _savingCert ? null : _cancelCertForm,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: ArdentSpacing.s2),
              FilledButton(
                onPressed: _savingCert ? null : _submitCertificate,
                child: _savingCert
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Add certificate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCertFile() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'pdf',
        ],
      );
      final file = res?.files.singleOrNull;
      if (file == null || file.bytes == null) return;
      const maxBytes = 10 * 1024 * 1024;
      if (file.bytes!.lengthInBytes > maxBytes) {
        messenger.showSnackBar(
            const SnackBar(content: Text('File must be 10 MB or smaller')));
        return;
      }
      setState(() {
        _certBytes = file.bytes;
        _certFileName = file.name;
      });
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not pick file')));
    }
  }

  Future<void> _pickCertDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _certIssuedOn ?? now,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _certIssuedOn = picked);
  }

  void _cancelCertForm() {
    setState(() {
      _addingCert = false;
      _certBytes = null;
      _certFileName = null;
      _certIssuedOn = null;
      _certTitle.clear();
      _certIssuer.clear();
    });
  }

  Future<void> _submitCertificate() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = _certTitle.text.trim();
    if (_certBytes == null || _certFileName == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Choose an image or PDF first')));
      return;
    }
    if (title.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Title is required')));
      return;
    }
    setState(() => _savingCert = true);
    try {
      final issuer = _certIssuer.text.trim();
      await Api.instance.users.addCertificate(
        bytes: _certBytes!,
        filename: _certFileName!,
        title: title,
        issuer: issuer.isEmpty ? null : issuer,
        issuedOn: _certIssuedOn == null
            ? null
            : relativeDateOnly(_certIssuedOn!.toIso8601String()),
        contentType: _certContentType(_certFileName!),
      );
      if (!mounted) return;
      _cancelCertForm();
      setState(() => _savingCert = false);
      messenger.showSnackBar(
          const SnackBar(content: Text('Certificate added')));
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _savingCert = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingCert = false);
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not add certificate')));
    }
  }

  Future<void> _deleteCertificate(Map<String, dynamic> cert) async {
    final id = (cert['id'] ?? cert['certificateId'])?.toString();
    if (id == null || id.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete certificate?'),
        content: Text(
            'Remove “${cert['title'] ?? 'this certificate'}” from your profile?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Api.instance.users.deleteCertificate(id);
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Certificate removed')));
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not delete certificate')));
    }
  }

  static String _certContentType(String name) {
    final ext = _ext(name, fallback: '');
    if (ext == 'pdf') return 'application/pdf';
    if (ext.isEmpty) return 'application/octet-stream';
    return 'image/${ext == 'jpg' ? 'jpeg' : ext}';
  }

  // ---- About ----------------------------------------------------------------

  Widget _about(_ProfileData data) {
    final hr = data.hr;
    final profile = data.profile;
    final me = AppSession.instance.me;

    final employeeId = hr['employeeId']?.toString();
    final dateHired = hr['dateHired']?.toString();
    final phone = _profileString(profile, ['phone', 'phoneNumber', 'mobile']);
    final manager = _managerName(profile);
    final birthday = _birthdayLabel(hr);

    // Labelled info rows — mirrors the web About form's field list.
    final rows = <Widget>[
      if (me.department.isNotEmpty)
        _infoRow(Icons.apartment_rounded, 'Department', me.department),
      if (manager.isNotEmpty) _infoRow(Icons.person_outline_rounded, 'Manager', manager),
      if (me.location.isNotEmpty)
        _infoRow(Icons.place_outlined, 'Location', me.location),
      if (me.email.isNotEmpty) _infoRow(Icons.mail_outline_rounded, 'Email', me.email),
      if (employeeId != null && employeeId.isNotEmpty)
        _infoRow(Icons.badge_outlined, 'Employee ID', employeeId),
      if (phone.isNotEmpty) _infoRow(Icons.phone_outlined, 'Phone', phone),
      if (dateHired != null && dateHired.isNotEmpty)
        _infoRow(Icons.event_outlined, 'Joined', relativeDate(dateHired)),
      if (birthday.isNotEmpty) _infoRow(Icons.cake_outlined, 'Birthday', birthday),
    ];

    final interests = _profileList(profile, ['interests']);
    final hobbies = _profileList(profile, ['hobbies']);
    final likes = _profileList(profile, ['likes', 'favorites']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Overline('About'),
                const SizedBox(height: ArdentSpacing.s2),
                Text(
                  me.bio.isNotEmpty ? me.bio : 'No bio yet.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: me.bio.isNotEmpty ? null : ArdentColors.fg3,
                      ),
                ),
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: ArdentSpacing.s3),
                  const Divider(height: 1, color: ArdentColors.border),
                  const SizedBox(height: ArdentSpacing.s2),
                  ...rows,
                ],
              ],
            ),
          ),
          const SizedBox(height: ArdentSpacing.s4),
          _tagSection(Icons.lightbulb_outline_rounded, 'Interests', interests),
          const SizedBox(height: ArdentSpacing.s4),
          _tagSection(Icons.emoji_events_outlined, 'Hobbies', hobbies),
          const SizedBox(height: ArdentSpacing.s4),
          _tagSection(Icons.favorite_outline_rounded, 'Likes', likes),
        ],
      ),
    );
  }

  /// One labelled About row: icon + muted label + value.
  Widget _infoRow(IconData icon, String label, String value) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: ArdentColors.fg3),
          const SizedBox(width: ArdentSpacing.s3),
          SizedBox(
            width: 96,
            child: Text(label,
                style: text.bodyMedium?.copyWith(color: ArdentColors.fg3)),
          ),
          const SizedBox(width: ArdentSpacing.s2),
          Expanded(
            child: Text(value,
                style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// An Interests / Hobbies / Likes card with pill tags (or an empty note).
  Widget _tagSection(IconData icon, String title, List<String> tags) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: ArdentColors.fg3),
              const SizedBox(width: ArdentSpacing.s2),
              Overline(title),
            ],
          ),
          const SizedBox(height: ArdentSpacing.s3),
          if (tags.isEmpty)
            Text('None yet.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: ArdentColors.fg3))
          else
            Wrap(
              spacing: ArdentSpacing.s2,
              runSpacing: ArdentSpacing.s2,
              children: [
                for (final t in tags)
                  DsChip(
                    label: t,
                    fg: ArdentColors.fg2,
                    bg: ArdentColors.bgSubtle,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // ---- About field helpers --------------------------------------------------

  /// First non-empty string among [keys] in the raw profile map.
  String _profileString(Map<String, dynamic> profile, List<String> keys) {
    for (final k in keys) {
      final v = profile[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  /// Manager can arrive as a plain string or a nested `{ name }` object.
  String _managerName(Map<String, dynamic> profile) {
    final v = profile['manager'] ?? profile['reportsTo'];
    if (v is Map) {
      return (v['name'] ?? v['fullName'] ?? '').toString().trim();
    }
    return v?.toString().trim() ?? '';
  }

  /// A list of tag strings from the profile map, tolerating list-of-strings or
  /// list-of-`{name}` shapes; other/missing values yield an empty list.
  List<String> _profileList(Map<String, dynamic> profile, List<String> keys) {
    for (final k in keys) {
      final v = profile[k];
      if (v is List) {
        return v
            .map((e) => e is Map ? (e['name'] ?? e['label'] ?? '').toString() : e.toString())
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  /// Birthday as `Month D` (no year) from HR `birthMonth`/`birthDay`.
  String _birthdayLabel(Map<String, dynamic> hr) {
    final month = int.tryParse(hr['birthMonth']?.toString() ?? '');
    final day = int.tryParse(hr['birthDay']?.toString() ?? '');
    if (month == null || day == null || month < 1 || month > 12) return '';
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${names[month - 1]} $day';
  }
}

class _ProfileData {
  _ProfileData({
    required this.posts,
    required this.certificates,
    required this.hr,
    required this.groups,
    required this.profile,
    required this.events,
  });
  final List<Post> posts;
  final List<Map<String, dynamic>> certificates;
  final Map<String, dynamic> hr;

  /// Groups the user has joined (excludes direct threads).
  final List<Group> groups;

  /// Events the user has RSVP'd to (going or interested).
  final List<EventItem> events;

  /// Raw `GET /users/:id` JSON — source for phone/manager/interests/hobbies/
  /// likes that the lightweight [Person] model does not carry.
  final Map<String, dynamic> profile;

  int get groupCount => groups.length;

  /// Kudos received, read from the profile JSON (web parity stat).
  int get kudosReceived {
    for (final k in ['kudosReceived', 'kudosCount', 'kudos', 'kudosGiven']) {
      final v = profile[k];
      final n = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
      if (n != null) return n;
    }
    return 0;
  }
}
