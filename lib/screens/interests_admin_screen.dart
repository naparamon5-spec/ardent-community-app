import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../theme/ardent_colors.dart';
import '../utils/paged.dart';
import '../widgets/async_view.dart';
import '../widgets/ds.dart';

/// Profile-tag admin — manage the shared **Interests** pool that people pick
/// from on their profiles. Rename, hide/show, and delete tags; the list is
/// searchable and server-paginated (`GET /interests/admin/all`).
/// Requires `module:admin.users`.
///
/// The pool is a single shared catalog — a tag has no `kind` (the
/// interest/hobby/like distinction lives per-user on `user.interests[]`). Tags
/// are created implicitly when someone types a new one on their profile, so
/// there is no "add" action here.
class InterestsAdminScreen extends StatefulWidget {
  const InterestsAdminScreen({super.key});

  @override
  State<InterestsAdminScreen> createState() => _InterestsAdminScreenState();
}

class _InterestsAdminScreenState extends State<InterestsAdminScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<dynamic> _items = [];
  String _query = '';
  int _page = 0; // last page loaded (0 = nothing yet)
  int _pageCount = 1;
  bool _loading = false;
  bool _initialised = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 240 &&
          !_loading &&
          _page < _pageCount) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _items.clear();
    _page = 0;
    _pageCount = 1;
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      final Paged result = await Api.instance.interests.adminAll(
        q: _query.isEmpty ? null : _query,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _pageCount = result.pageCount;
        _initialised = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _initialised = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    final next = value.trim();
    if (next == _query) return;
    _query = next;
    _refresh();
  }

  Future<String?> _promptName(String title, {String initial = ''}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: initial);
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Interest name'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                child: const Text('Save')),
          ],
        );
      },
    );
  }

  Future<void> _rename(String id, String current) async {
    final name = await _promptName('Rename interest', initial: current);
    if (name == null || name.isEmpty || name == current || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await Api.instance.interests.update(id, name: name);
      if (res['merged'] == true || res['moved'] == true) {
        messenger.showSnackBar(SnackBar(
            content: Text('"$current" merged into existing "$name".')));
      }
      await _refresh();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _setActive(String id, bool active) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.interests.update(id, isActive: active);
      await _refresh();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete interest?'),
        content: Text('"$name" will be removed from every profile that had it.'),
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
      await Api.instance.interests.delete(id);
      await _refresh();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile interests')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(ArdentSpacing.s4, ArdentSpacing.s3,
                ArdentSpacing.s4, ArdentSpacing.s2),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search interests',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      ),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _buildBody(text)),
        ],
      ),
    );
  }

  Widget _buildBody(TextTheme text) {
    if (!_initialised) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState(
        message: _error is ApiException
            ? (_error as ApiException).message
            : 'Could not load interests.',
        icon: Icons.error_outline_rounded,
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        message: _query.isEmpty
            ? 'No interests yet. They appear here once people add them on their profiles.'
            : 'No interests match "$_query".',
        icon: Icons.local_offer_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(
            ArdentSpacing.s4, ArdentSpacing.s1, ArdentSpacing.s4, 96),
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: ArdentSpacing.s2),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            if (_page < _pageCount) {
              return const Padding(
                padding: EdgeInsets.all(ArdentSpacing.s4),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return const SizedBox.shrink();
          }
          final t = asMap(_items[i]);
          final id = '${t['id'] ?? t['_id'] ?? ''}';
          final name = '${t['name'] ?? ''}';
          final active = t['isActive'] != false;
          final count = t['usageCount'] ?? t['count'] ?? t['userCount'];
          final n = count is num
              ? count.toInt()
              : int.tryParse('${count ?? ''}') ?? 0;
          return SurfaceCard(
            child: Row(
              children: [
                const Icon(Icons.local_offer_outlined,
                    color: ArdentColors.navy600, size: 20),
                const SizedBox(width: ArdentSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: text.titleMedium?.copyWith(fontSize: 15)),
                      Text('$n ${n == 1 ? 'person' : 'people'}',
                          style: text.bodySmall),
                    ],
                  ),
                ),
                if (!active)
                  const DsChip(
                      label: 'Hidden',
                      fg: ArdentColors.fg2,
                      bg: ArdentColors.bgSubtle),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: ArdentColors.navy600),
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        _rename(id, name);
                      case 'toggle':
                        _setActive(id, !active);
                      case 'delete':
                        _delete(id, name);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Rename'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(active
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        title: Text(active ? 'Hide' : 'Show'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded,
                            color: ArdentColors.accent),
                        title: Text('Delete',
                            style: TextStyle(color: ArdentColors.accent)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
