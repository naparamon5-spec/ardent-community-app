import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Edit profile — a form mirroring the web profile edit flow.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController(text: Seed.currentUser.name);
  final _role = TextEditingController(text: Seed.currentUser.role);
  final _email = TextEditingController(text: 'ramon.napa@ardentnetworks.com.ph');
  final _location = TextEditingController(text: 'Pasig City, Philippines');
  final _bio = TextEditingController(
      text: 'Community member at Ardent Networks. Coffee, code, and House spirit. 🔴');

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _email.dispose();
    _location.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _save() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Seed.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
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
          _field('Email', _email, keyboard: TextInputType.emailAddress),
          _field('Location', _location),
          _field('Bio', _bio, maxLines: 4),
          const SizedBox(height: ArdentSpacing.s5),
          ElevatedButton(
            onPressed: _save,
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
