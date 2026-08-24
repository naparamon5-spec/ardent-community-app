import 'package:flutter/material.dart';

import '../api/api.dart';
import '../api/session.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Edit profile — a form backed by `PATCH /users/me`.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController(text: AppSession.instance.me.name);
  final _role = TextEditingController(text: AppSession.instance.me.role);
  final _location = TextEditingController();
  final _bio = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _location.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final updated = await Api.instance.users.updateMe({
        'name': _name.text.trim(),
        'role': _role.text.trim(),
        if (_location.text.trim().isNotEmpty) 'location': _location.text.trim(),
        if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
      });
      // Reflect the change in the session so the profile/composer update.
      AppSession.instance.setFromJson(updated);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = AppSession.instance.me;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ArdentSpacing.s4),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                DsAvatar(initials: me.initials, color: me.color, size: 96),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Material(
                    color: ArdentColors.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Change photo (demo)')),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ArdentSpacing.s6),
          _field('Full name', _name),
          _field('Role / title', _role),
          _field('Location', _location),
          _field('Bio', _bio, maxLines: 4),
          const SizedBox(height: ArdentSpacing.s5),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {int maxLines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Overline(label),
          ),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboard,
          ),
        ],
      ),
    );
  }
}
