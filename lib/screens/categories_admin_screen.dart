import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

/// Marketplace categories admin — list/create/delete (`/categories`).
/// Requires `module:admin.users`.
class CategoriesAdminScreen extends StatefulWidget {
  const CategoriesAdminScreen({super.key});

  @override
  State<CategoriesAdminScreen> createState() => _CategoriesAdminScreenState();
}

class _CategoriesAdminScreenState extends State<CategoriesAdminScreen> {
  int _reloadTick = 0;

  Future<List<dynamic>> _load() => Api.instance.categories.list(all: true);

  Future<void> _add() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('New category'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Category name'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                child: const Text('Create')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.categories.create(name);
      if (!mounted) return;
      setState(() => _reloadTick++);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('"$name" will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: ArdentColors.accent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.categories.delete(id);
      if (!mounted) return;
      setState(() => _reloadTick++);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: AsyncView<List<dynamic>>(
        key: ValueKey(_reloadTick),
        loader: _load,
        builder: (context, items, reload) {
          if (items.isEmpty) {
            return const EmptyState(
                message: 'No categories yet.', icon: Icons.category_outlined);
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: ArdentSpacing.s2),
              itemBuilder: (context, i) {
                final c = asMap(items[i]);
                final id = '${c['id'] ?? c['_id'] ?? ''}';
                final name = '${c['name'] ?? ''}';
                final active = c['isActive'] != false;
                return SurfaceCard(
                  child: Row(
                    children: [
                      const Icon(Icons.sell_outlined, color: ArdentColors.navy600, size: 20),
                      const SizedBox(width: ArdentSpacing.s3),
                      Expanded(
                        child: Text(name, style: text.titleMedium?.copyWith(fontSize: 15)),
                      ),
                      if (!active)
                        const DsChip(
                            label: 'Inactive',
                            fg: ArdentColors.fg2,
                            bg: ArdentColors.bgSubtle),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: ArdentColors.accent),
                        onPressed: () => _delete(id, name),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
