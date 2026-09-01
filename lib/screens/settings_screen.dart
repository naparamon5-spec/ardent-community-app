import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../theme/ardent_colors.dart';

/// Settings — mirrors the web `ProfileSettingsModal.vue`: grouped Account,
/// Privacy, Notifications, and Danger Zone rows. Privacy and notification
/// toggles are read from `GET /auth/me` and persisted to `PATCH /users/me`, so
/// the screen reflects (and writes) the signed-in user's real settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  String? _error;

  // Real settings, loaded from the server.
  bool _isPrivate = false;
  bool _showEmail = true;
  bool _emailNotifs = true;
  bool _notifyComments = true;
  bool _notifyKudos = true;
  String? _passwordChanged; // e.g. "March 2023", when the server provides it.

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Api.instance.auth.me();
      final user = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : data;
      if (!mounted) return;
      setState(() {
        _isPrivate = _boolOf(user, ['isPrivate', 'is_private'], false);
        _showEmail = _boolOf(user, ['showEmail', 'show_email'], true);
        _emailNotifs = _boolOf(user, ['emailNotifs', 'email_notifs'], true);
        _notifyComments =
            _boolOf(user, ['notifyComments', 'notify_comments'], true);
        _notifyKudos = _boolOf(user, ['notifyKudos', 'notify_kudos'], true);
        _passwordChanged = _monthYearOf(user['passwordChangedAt'] ??
            user['password_changed_at'] ??
            user['passwordUpdatedAt']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Couldn\'t load your settings.';
        _loading = false;
      });
    }
  }

  bool _boolOf(Map<String, dynamic> m, List<String> keys, bool fallback) {
    for (final k in keys) {
      final v = m[k];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v == 'true' || v == '1';
    }
    return fallback;
  }

  String? _monthYearOf(dynamic raw) {
    if (raw == null) return null;
    final d = DateTime.tryParse('$raw');
    if (d == null) return null;
    return '${_months[d.month - 1]} ${d.year}';
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  /// Optimistically flips a toggle, then persists just that field. Reverts and
  /// warns if the server rejects it.
  Future<void> _save(String field, bool value, void Function(bool) apply) async {
    setState(() => apply(value));
    try {
      await Api.instance.users.updateMe({field: value});
    } catch (_) {
      if (!mounted) return;
      setState(() => apply(!value));
      _toast('Couldn\'t save that change. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : ListView(
                  padding: const EdgeInsets.all(ArdentSpacing.s4),
                  children: [
                    _section('Account'),
                    _actionRow(
                      title: 'Password',
                      description: _passwordChanged != null
                          ? 'Last changed $_passwordChanged.'
                          : 'Change your account password.',
                      button: 'Change password',
                      onPressed: _changePassword,
                    ),
                    _actionRow(
                      title: 'Sessions',
                      description: 'Sign out everywhere except this device.',
                      button: 'Log out all',
                      onPressed: _confirmLogout,
                    ),
                    _divider(),
                    _section('Privacy'),
                    _toggleRow(
                      title: 'Private account',
                      description: 'Hide your posts and activity from anyone but you.',
                      value: _isPrivate,
                      onChanged: (v) =>
                          _save('isPrivate', v, (x) => _isPrivate = x),
                    ),
                    _toggleRow(
                      title: 'Show email on profile',
                      description: 'Let coworkers see your email under About.',
                      value: _showEmail,
                      onChanged: (v) =>
                          _save('showEmail', v, (x) => _showEmail = x),
                    ),
                    _divider(),
                    _section('Notifications'),
                    _toggleRow(
                      title: 'Email notifications',
                      description:
                          "Get an email summary of anything you haven't read after a couple of hours.",
                      value: _emailNotifs,
                      onChanged: (v) =>
                          _save('emailNotifs', v, (x) => _emailNotifs = x),
                    ),
                    _toggleRow(
                      title: 'Comments',
                      description: 'Notify me when someone comments on my posts.',
                      value: _notifyComments,
                      onChanged: (v) => _save(
                          'notifyComments', v, (x) => _notifyComments = x),
                    ),
                    _toggleRow(
                      title: 'Kudos',
                      description: 'Notify me when a coworker gives me kudos.',
                      value: _notifyKudos,
                      onChanged: (v) =>
                          _save('notifyKudos', v, (x) => _notifyKudos = x),
                    ),
                    _divider(),
                    _section('Danger zone', danger: true),
                    _actionRow(
                      title: 'Deactivate account',
                      description: 'Hide your profile and posts from Ardent.',
                      button: 'Deactivate',
                      danger: true,
                      onPressed: _confirmDeactivate,
                    ),
                    const SizedBox(height: ArdentSpacing.s6),
                  ],
                ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(ArdentSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: ArdentColors.fg3, size: 40),
              const SizedBox(height: ArdentSpacing.s3),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ArdentColors.fg2)),
              const SizedBox(height: ArdentSpacing.s4),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );

  // ---- Password change ------------------------------------------------------

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var busy = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Change password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Current password'),
                ),
                TextFormField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'At least 6 characters'
                      : null,
                ),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm new password'),
                  validator: (v) =>
                      v != newCtrl.text ? 'Passwords don\'t match' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setLocal(() => busy = true);
                      try {
                        await Api.instance.auth.changePassword(
                          currentPassword: currentCtrl.text.isEmpty
                              ? null
                              : currentCtrl.text,
                          newPassword: newCtrl.text,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop(true);
                      } catch (_) {
                        setLocal(() => busy = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Couldn\'t change password. Check your current one.')),
                          );
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    if (ok == true && mounted) _toast('Password changed.');
  }

  // ---- Sessions / logout ----------------------------------------------------

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'You can always log back in with your Ardent account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
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
      // AuthGate swaps in the login screen; pop settings so it isn't stacked.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // ---- Danger zone ----------------------------------------------------------

  Future<void> _confirmDeactivate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate account?'),
        content: const Text(
            'Your profile and posts will be hidden from Ardent. Contact your '
            'Ardent admin if you want to reactivate later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ArdentColors.accent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    // There is no self-service deactivation endpoint; it's an admin action.
    _toast('Account deactivation is handled by your Ardent admin.');
  }

  // ---- Row builders ---------------------------------------------------------

  Widget _section(String title, {bool danger = false}) => Padding(
        padding: const EdgeInsets.only(
            top: ArdentSpacing.s2, bottom: ArdentSpacing.s3),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: danger ? ArdentColors.accent : ArdentColors.fg3,
          ),
        ),
      );

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: ArdentSpacing.s2),
        child: Divider(height: 1, color: ArdentColors.border),
      );

  Widget _toggleRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ArdentSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: ArdentColors.accent,
          ),
          const SizedBox(width: ArdentSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: ArdentColors.fg1)),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                        color: ArdentColors.fg3, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required String title,
    required String description,
    required String button,
    required VoidCallback onPressed,
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ArdentSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: ArdentColors.fg1)),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                        color: ArdentColors.fg3, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: ArdentSpacing.s3),
          danger
              ? TextButton(
                  onPressed: onPressed,
                  style: TextButton.styleFrom(
                      foregroundColor: ArdentColors.accent),
                  child: Text(button,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                )
              : OutlinedButton(
                  onPressed: onPressed,
                  child: Text(button),
                ),
        ],
      ),
    );
  }
}
