import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

/// Profile — the signed-in user (`AppSession`) plus live HR details
/// (`GET /users/me/hr`) and certificates (`GET /users/me/certificates`).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProfileData> _load() async {
    final api = Api.instance;
    final me = AppSession.instance.me;
    final results = await Future.wait([
      api.users.myHr().catchError((_) => <String, dynamic>{}),
      api.users.myCertificates().catchError((_) => <dynamic>[]),
      api.users.posts(me.id).then((p) => p.length).catchError((_) => 0),
    ]);
    return _ProfileData(
      hr: results[0] as Map<String, dynamic>,
      certificates: (results[1] as List).map(asMap).toList(),
      postCount: results[2] as int,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
              const SizedBox(height: 44),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.name, style: text.headlineMedium?.copyWith(fontSize: 22)),
                    Text(me.role, style: text.bodyLarge),
                    const SizedBox(height: ArdentSpacing.s4),
                    _actions(context),
                    const SizedBox(height: ArdentSpacing.s5),
                    SurfaceCard(
                      child: Row(
                        children: [
                          _stat('${data?.postCount ?? '—'}', 'Posts', text),
                          _divider(),
                          _stat('${data?.certificates.length ?? '—'}', 'Certificates', text),
                          _divider(),
                          _stat(me.online ? 'Online' : 'Offline', 'Status', text),
                        ],
                      ),
                    ),
                    const SizedBox(height: ArdentSpacing.s5),
                    const Overline('About'),
                    const SizedBox(height: ArdentSpacing.s2),
                    _about(data, text),
                    const SizedBox(height: ArdentSpacing.s5),
                    const Overline('Certificates'),
                    const SizedBox(height: ArdentSpacing.s2),
                    _certificates(data, text),
                    const SizedBox(height: ArdentSpacing.s6),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _coverAndAvatar(Person me) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 132,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ArdentColors.navy800, ArdentColors.navy900],
            ),
          ),
        ),
        Positioned(
          left: ArdentSpacing.s4,
          bottom: -36,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: DsAvatar(initials: me.initials, color: me.color, size: 84),
          ),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
              if (mounted) _refresh();
            },
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Edit profile'),
          ),
        ),
        const SizedBox(width: ArdentSpacing.s3),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          child: const Icon(Icons.settings_outlined, size: 18),
        ),
      ],
    );
  }

  Widget _about(_ProfileData? data, TextTheme text) {
    final hr = data?.hr ?? const {};
    final employeeId = hr['employeeId']?.toString();
    final dateHired = hr['dateHired']?.toString();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aboutLine(Icons.badge_outlined,
              employeeId != null && employeeId.isNotEmpty
                  ? 'Employee ID: $employeeId'
                  : 'Ardent Networks Inc.',
              text),
          if (dateHired != null && dateHired.isNotEmpty)
            _aboutLine(Icons.cake_outlined, 'Joined ${relativeDate(dateHired)}', text),
          _aboutLine(
              hr['linked'] == true ? Icons.link_rounded : Icons.link_off_rounded,
              hr['linked'] == true ? 'Linked to HR system' : 'Not linked to HR system',
              text),
        ],
      ),
    );
  }

  Widget _certificates(_ProfileData? data, TextTheme text) {
    final certs = data?.certificates ?? const [];
    if (data != null && certs.isEmpty) {
      return SurfaceCard(
        child: Text('No certificates yet.',
            style: text.bodyMedium?.copyWith(color: ArdentColors.fg3)),
      );
    }
    if (data == null) {
      return const SurfaceCard(
        child: Center(child: Padding(
          padding: EdgeInsets.all(8),
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        )),
      );
    }
    return SurfaceCard(
      child: Column(
        children: [
          for (var i = 0; i < certs.length; i++) ...[
            if (i > 0) const Divider(height: ArdentSpacing.s5),
            _certificate(
              asMap(certs[i])['title']?.toString() ?? 'Certificate',
              asMap(certs[i])['issuer']?.toString() ??
                  asMap(certs[i])['issuedOn']?.toString() ??
                  '',
              text,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String label, TextTheme text) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: text.titleLarge?.copyWith(fontSize: 18)),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 34, color: ArdentColors.border);

  Widget _aboutLine(IconData icon, String label, TextTheme text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: ArdentColors.fg3),
          const SizedBox(width: ArdentSpacing.s3),
          Expanded(child: Text(label, style: text.bodyLarge)),
        ],
      ),
    );
  }

  Widget _certificate(String title, String subtitle, TextTheme text) {
    return Row(
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
              Text(title, style: text.titleMedium?.copyWith(fontSize: 14)),
              if (subtitle.isNotEmpty) Text(subtitle, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileData {
  _ProfileData({required this.hr, required this.certificates, required this.postCount});
  final Map<String, dynamic> hr;
  final List<Map<String, dynamic>> certificates;
  final int postCount;
}
