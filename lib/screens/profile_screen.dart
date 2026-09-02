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
  int _activityFilter = 0; // 0 All, 1 Posts, 2 Comments, 3 Groups, 4 Events
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
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
      api.groups
          .list()
          .then((r) => r.map(groupFromJson).where((g) => g.joined && !g.isDirect).length)
          .catchError((_) => 0),
    ]);
    return _ProfileData(
      posts: results[0] as List<Post>,
      certificates: results[1] as List<Map<String, dynamic>>,
      hr: results[2] as Map<String, dynamic>,
      groupCount: results[3] as int,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next.catchError((_) => _ProfileData(
        posts: const [], certificates: const [], hr: const {}, groupCount: 0));
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
          stat('${data?.certificates.length ?? '—'}', 'Certificates'),
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
        return _activities(data.posts);
      case _Tab.certificates:
        return _certificates(data.certificates);
      case _Tab.about:
        return _about(data.hr);
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

  Widget _activities(List<Post> posts) {
    const filters = ['All', 'Posts', 'Comments', 'Groups', 'Events'];
    // Only Posts activity is available from the API today; the other categories
    // show an empty state (parity with the web placeholder).
    final showPosts = _activityFilter == 0 || _activityFilter == 1;
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
        if (showPosts && posts.isNotEmpty)
          _postsList(posts)
        else
          _empty('Nothing in this category yet.'),
      ],
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
    if (certs.isEmpty) return _empty('No certificates yet.');
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
      child: SurfaceCard(
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
                        if ((certs[i]['issuer'] ?? certs[i]['issuedOn']) != null)
                          Text(
                            certs[i]['issuer']?.toString() ??
                                relativeDate(certs[i]['issuedOn']),
                            style: text.bodySmall,
                          ),
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

  // ---- About ----------------------------------------------------------------

  Widget _about(Map<String, dynamic> hr) {
    final me = AppSession.instance.me;
    final text = Theme.of(context).textTheme;
    final employeeId = hr['employeeId']?.toString();
    final dateHired = hr['dateHired']?.toString();
    final rows = <Widget>[];
    void line(IconData icon, String label) => rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 17, color: ArdentColors.fg3),
              const SizedBox(width: ArdentSpacing.s3),
              Expanded(child: Text(label, style: text.bodyLarge)),
            ],
          ),
        ));

    if (me.bio.isNotEmpty) line(Icons.info_outline_rounded, me.bio);
    if (me.email.isNotEmpty) line(Icons.mail_outline_rounded, me.email);
    if (me.department.isNotEmpty) line(Icons.apartment_rounded, me.department);
    if (me.location.isNotEmpty) line(Icons.place_outlined, me.location);
    if (employeeId != null && employeeId.isNotEmpty) {
      line(Icons.badge_outlined, 'Employee ID: $employeeId');
    }
    if (dateHired != null && dateHired.isNotEmpty) {
      line(Icons.cake_outlined, 'Joined ${relativeDate(dateHired)}');
    }
    line(hr['linked'] == true ? Icons.link_rounded : Icons.link_off_rounded,
        hr['linked'] == true ? 'Linked to HR system' : 'Not linked to HR system');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
      child: SurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
      ),
    );
  }
}

class _ProfileData {
  _ProfileData({
    required this.posts,
    required this.certificates,
    required this.hr,
    required this.groupCount,
  });
  final List<Post> posts;
  final List<Map<String, dynamic>> certificates;
  final Map<String, dynamic> hr;
  final int groupCount;
}
