import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';

/// "Sell something" — create a marketplace listing (`POST /listings`, requires
/// `module:marketplace.sell`). Returns `true` on success so the caller refreshes.
class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _price = TextEditingController(text: '0');
  final _description = TextEditingController();
  String? _category;
  late Future<List<String>> _categories;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _categories = _loadCategories();
  }

  Future<List<String>> _loadCategories() async {
    try {
      final raw = await Api.instance.categories.list();
      final names = raw
          .map((c) => asMap(c)['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (names.isNotEmpty && _category == null) _category = names.first;
      return names;
    } on ApiException {
      return const [];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
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
      await Api.instance.listings.create(fields: {
        'title': _title.text.trim(),
        'price': int.tryParse(_price.text.trim()) ?? 0,
        if (_category != null) 'category': _category,
        if (_description.text.trim().isNotEmpty) 'description': _description.text.trim(),
      });
      navigator.pop(true);
      messenger.showSnackBar(const SnackBar(content: Text('Listing posted')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(
          content: Text(e.isForbidden
              ? "You don't have permission to sell here."
              : e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell something'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(ArdentSpacing.s4),
          children: [
            _label('Photos & videos'),
            _photoPlaceholder(),
            const SizedBox(height: ArdentSpacing.s4),
            _label('Title'),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What are you selling?'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'A title is required' : null,
            ),
            const SizedBox(height: ArdentSpacing.s4),
            _label('Price (₱, enter 0 for free)'),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '0'),
            ),
            const SizedBox(height: ArdentSpacing.s4),
            _label('Category'),
            FutureBuilder<List<String>>(
              future: _categories,
              builder: (context, snapshot) {
                final cats = snapshot.data ?? const <String>[];
                return DropdownButtonFormField<String>(
                  initialValue: _category,
                  items: [
                    for (final c in cats) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                  decoration: const InputDecoration(),
                  hint: const Text('Select a category'),
                );
              },
            ),
            const SizedBox(height: ArdentSpacing.s4),
            _label('Description'),
            TextFormField(
              controller: _description,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Condition, pickup details…'),
            ),
            const SizedBox(height: ArdentSpacing.s6),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Post listing'),
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

  Widget _photoPlaceholder() {
    // Image upload needs an image picker (not wired yet); this mirrors the web
    // "Add" tile so the layout matches.
    return DottedTile(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo upload is coming soon')),
      ),
    );
  }
}

/// Dashed "Add" tile, matching the web's Photos & videos placeholder.
class DottedTile extends StatelessWidget {
  const DottedTile({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.md),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: ArdentColors.bgSubtle,
          borderRadius: BorderRadius.circular(ArdentRadii.md),
          border: Border.all(color: ArdentColors.borderStrong, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: ArdentColors.fg2, size: 26),
            SizedBox(height: 4),
            Text('Add', style: TextStyle(color: ArdentColors.fg3, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
