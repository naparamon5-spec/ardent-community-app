import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'group_chat_screen.dart';

/// Listing detail — photo, price, description, seller, and Inquire / Save / Like
/// actions (`/listings/:id/save`, `/listings/:id/like`). Inquire opens a DM with
/// the seller (`POST /groups/direct`).
class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listing});
  final Listing listing;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late final Listing l = widget.listing;
  bool _inquiring = false;

  Future<void> _toggleSave() async {
    setState(() => l.saved = !l.saved);
    final saved = l.saved;
    final f = saved
        ? Api.instance.listings.save(l.id)
        : Api.instance.listings.unsave(l.id);
    f.catchError((_) {
      if (mounted) setState(() => l.saved = !saved);
    });
  }

  Future<void> _toggleLike() async {
    setState(() {
      l.liked = !l.liked;
      l.likeCount += l.liked ? 1 : -1;
    });
    final liked = l.liked;
    final f = liked
        ? Api.instance.listings.like(l.id)
        : Api.instance.listings.unlike(l.id);
    f.catchError((_) {
      if (mounted) {
        setState(() {
          l.liked = !liked;
          l.likeCount += l.liked ? 1 : -1;
        });
      }
    });
  }

  Future<void> _inquire() async {
    if (l.sellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller is unavailable to message')),
      );
      return;
    }
    setState(() => _inquiring = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final thread = await Api.instance.groups.openDirect(l.sellerId);
      final group = groupFromJson(thread);
      if (!mounted) return;
      navigator.push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _inquiring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        children: [
          _photo(),
          Padding(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l.price,
                      style: text.headlineMedium?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: l.free ? ArdentColors.statusResolved : ArdentColors.accent,
                      ),
                    ),
                    if (l.sold) ...[
                      const SizedBox(width: 10),
                      const DsChip(
                          label: 'Sold',
                          fg: ArdentColors.fg2,
                          bg: ArdentColors.bgSubtle),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${l.category}${l.posted.isNotEmpty ? ' · Posted ${l.posted}' : ''}',
                  style: text.bodySmall,
                ),
                if (l.description.isNotEmpty) ...[
                  const SizedBox(height: ArdentSpacing.s4),
                  Text(l.description,
                      style: text.bodyLarge?.copyWith(color: ArdentColors.fg2, height: 1.5)),
                ],
                const SizedBox(height: ArdentSpacing.s4),
                const Divider(height: 1),
                const SizedBox(height: ArdentSpacing.s4),
                Row(
                  children: [
                    DsAvatar(
                        initials: initialsFrom(l.seller),
                        color: l.color,
                        size: 40,
                        imageUrl: l.sellerAvatarUrl),
                    const SizedBox(width: ArdentSpacing.s3),
                    Expanded(
                      child: Text(l.seller,
                          style: text.titleMedium?.copyWith(fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: ArdentSpacing.s5),
                _actions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photo() {
    if (l.coverUrl.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(l.coverUrl, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _photoPlaceholder()),
      );
    }
    return _photoPlaceholder();
  }

  Widget _photoPlaceholder() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        color: ArdentColors.navy900,
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, color: Colors.white38, size: 22),
              SizedBox(width: 8),
              Text('No photos', style: TextStyle(color: Colors.white38, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _inquiring ? null : _inquire,
            icon: _inquiring
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Inquire',
                maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        const SizedBox(width: ArdentSpacing.s2),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleSave,
            icon: Icon(l.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: 18, color: l.saved ? ArdentColors.accent : ArdentColors.fg2),
            label: const Text('Save',
                maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              foregroundColor: ArdentColors.fg1,
              side: const BorderSide(color: ArdentColors.borderStrong),
              minimumSize: const Size.fromHeight(46),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        const SizedBox(width: ArdentSpacing.s2),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleLike,
            icon: Icon(l.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18, color: l.liked ? ArdentColors.accent : ArdentColors.fg2),
            label: Text('${l.likeCount}',
                maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              foregroundColor: ArdentColors.fg1,
              side: const BorderSide(color: ArdentColors.borderStrong),
              minimumSize: const Size.fromHeight(46),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }
}
