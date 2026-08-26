import 'package:flutter/material.dart';

import '../api/session.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'edit_profile_screen.dart';

/// Settings — mirrors the web `ProfileSettingsModal.vue`, as a full page with
/// grouped rows and toggles.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifs = true;
  bool _emailNotifs = false;
  bool _mentions = true;
  bool _compactFeed = false;

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(ArdentSpacing.s4),
        children: [
          _section('Account'),
          _tile(Icons.person_outline_rounded, 'Edit profile',
              subtitle: 'Name, role, photo, and bio', onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          }),
          _tile(Icons.lock_outline_rounded, 'Password & security',
              onTap: () => _toast('Security settings (demo)')),
          _tile(Icons.verified_user_outlined, 'Privacy',
              onTap: () => _toast('Privacy settings (demo)')),
          const SizedBox(height: ArdentSpacing.s5),
          _section('Notifications'),
          _switchTile(Icons.notifications_active_outlined, 'Push notifications',
              _pushNotifs, (v) => setState(() => _pushNotifs = v)),
          _switchTile(Icons.mail_outline_rounded, 'Email notifications',
              _emailNotifs, (v) => setState(() => _emailNotifs = v)),
          _switchTile(Icons.alternate_email_rounded, 'Mentions & replies',
              _mentions, (v) => setState(() => _mentions = v)),
          const SizedBox(height: ArdentSpacing.s5),
          _section('Appearance'),
          _switchTile(Icons.view_agenda_outlined, 'Compact feed',
              _compactFeed, (v) => setState(() => _compactFeed = v)),
          _tile(Icons.dark_mode_outlined, 'Theme', subtitle: 'Light',
              onTap: () => _toast('Dark mode coming soon')),
          const SizedBox(height: ArdentSpacing.s5),
          _section('Support'),
          _tile(Icons.help_outline_rounded, 'Help center',
              onTap: () => _toast('Help center (demo)')),
          _tile(Icons.info_outline_rounded, 'About Ardent',
              subtitle: 'Version 1.0.0', onTap: () => _toast('Ardent v1.0.0')),
          const SizedBox(height: ArdentSpacing.s6),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(),
            style: OutlinedButton.styleFrom(
              foregroundColor: ArdentColors.accent,
              side: const BorderSide(color: ArdentColors.red200),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log out'),
          ),
          const SizedBox(height: ArdentSpacing.s6),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can always log back in with your Ardent account.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      await AppSession.instance.signOut();
      // The AuthGate listens to the auth store and swaps in the login screen;
      // pop settings so we don't leave it stacked over the gate.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: ArdentSpacing.s2, left: 4),
        child: Overline(title),
      );

  Widget _tile(IconData icon, String title, {String? subtitle, VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: ArdentColors.fg2),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded, color: ArdentColors.fg3),
        onTap: onTap,
      ),
    );
  }

  Widget _switchTile(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Icon(icon, color: ArdentColors.fg2),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        activeThumbColor: ArdentColors.accent,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
