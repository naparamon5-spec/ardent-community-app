import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/post_card.dart';

/// A single post with its comments — reached by tapping a post-related
/// notification (comment, reply, reaction, mention, kudos). Loads the post by
/// id via `GET /posts/:id` so callers only need the id.
class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  Future<Post> _load() async {
    final data = await Api.instance.posts.get(postId);
    return postFromJson(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: AsyncView<Post>(
        loader: _load,
        builder: (context, post, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(ArdentSpacing.s4),
            children: [PostCard(post: post)],
          ),
        ),
      ),
    );
  }
}
