import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// Create a group — form backed by `POST /groups` (requires
/// `module:groups.view`). The creator is auto-added as the first admin. Returns
/// `true` on success so the caller can refresh.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _submitting = false;

  /// Optional group photo, chosen from the gallery.
  Uint8List? _photoBytes;
  String _photoName = '';

  /// Optional accent colour, sent as a hex string. `null` = let the server use
  /// its default.
  int _colorIndex = 0;

  static const _colors = <({String hex, Color color})>[
    (hex: '#1D4456', color: ArdentColors.navy700),
    (hex: '#2C5A6E', color: ArdentColors.navy600),
    (hex: '#43798F', color: ArdentColors.navy500),
    (hex: '#C6324C', color: ArdentColors.crimson500),
    (hex: '#8E2237', color: ArdentColors.crimson700),
    (hex: '#E90408', color: ArdentColors.accent),
  ];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoName = picked.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not pick photo')));
    }
  }

  static String _ext(String name, {required String fallback}) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return fallback;
    return name.substring(i + 1).toLowerCase();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await Api.instance.groups.create(
        fields: {
          'name': _name.text.trim(),
          if (_description.text.trim().isNotEmpty)
            'description': _description.text.trim(),
          'color': _colors[_colorIndex].hex,
        },
        photo: _photoBytes == null
            ? null
            : (
                bytes: _photoBytes!,
                filename: _photoName.isEmpty ? 'group.jpg' : _photoName,
                contentType: 'image/${_ext(_photoName, fallback: 'jpeg')}',
              ),
      );
      navigator.pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('Group created')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(
          content: Text(e.isForbidden
              ? "You don't have permission to create groups."
              : e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create group'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(ArdentSpacing.s4),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: _colors[_colorIndex].color,
                            borderRadius: BorderRadius.circular(ArdentRadii.lg),
                          ),
                          child: _photoBytes != null
                              ? Image.memory(_photoBytes!,
                                  fit: BoxFit.cover,
                                  width: 88,
                                  height: 88)
                              : const Icon(Icons.groups_rounded,
                                  color: Colors.white, size: 40),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: ArdentColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: ArdentColors.bgSurface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ArdentSpacing.s2),
                    Text(_photoBytes == null ? 'Add photo' : 'Change photo',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ArdentColors.accent)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ArdentSpacing.s5),
            _label('Group name'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Design Community'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'A name is required' : null,
            ),
            const SizedBox(height: ArdentSpacing.s4),
            _label('Description'),
            TextFormField(
              controller: _description,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What is this group about?'),
            ),
            const SizedBox(height: ArdentSpacing.s4),
            _label('Colour'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < _colors.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _colorIndex = i),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _colors[i].color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorIndex == i ? ArdentColors.fg1 : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ArdentSpacing.s6),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Create group'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Overline(text),
      );
}
