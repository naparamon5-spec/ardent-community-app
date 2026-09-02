import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/post_card.dart';

/// A group's own post feed — backed by `GET /groups/:id/posts` (separate from
/// the group chat). Read-only here; posting to a group lives on the web.
class GroupPostsScreen extends StatelessWidget {
  const GroupPostsScreen({super.key, required this.group});
  final Group group;

  Future<List<Post>> _load() async {
    final raw = await Api.instance.groups.posts(group.id, limit: 50);
    return raw.map(postFromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${group.name} · Posts')),
      body: AsyncView<List<Post>>(
        loader: _load,
        builder: (context, posts, reload) {
          if (posts.isEmpty) {
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                      message: 'No posts in this group yet.',
                      icon: Icons.dynamic_feed_rounded),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: ArdentSpacing.s4),
              itemBuilder: (context, i) => PostCard(post: posts[i]),
            ),
          );
        },
      ),
    );
  }
}
