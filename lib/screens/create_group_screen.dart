import 'package:flutter/material.dart';

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

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await Api.instance.groups.create(fields: {
        'name': _name.text.trim(),
        if (_description.text.trim().isNotEmpty) 'description': _description.text.trim(),
        'color': _colors[_colorIndex].hex,
      });
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
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _colors[_colorIndex].color,
                  borderRadius: BorderRadius.circular(ArdentRadii.lg),
                ),
                child: const Icon(Icons.groups_rounded, color: Colors.white, size: 34),
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
