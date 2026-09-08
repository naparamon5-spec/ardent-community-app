import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/async_view.dart';
import '../widgets/post_card.dart';

/// A single post with its comment thread, shown full-screen. Reached two ways:
///
/// * from a post-related notification — pass [postId] and it loads the post via
///   `GET /posts/:id`.
/// * by tapping a post in a feed — pass the already-loaded [post] object so its
///   local state (likes, comments, saved) carries straight over with no reload.
class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, this.postId, this.post})
      : assert(postId != null || post != null,
            'PostDetailScreen needs either a postId or a post');

  final String? postId;
  final Post? post;

  Future<Post> _load() async {
    final data = await Api.instance.posts.get(postId!);
    return postFromJson(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: post != null
          ? ListView(
              padding: const EdgeInsets.all(ArdentSpacing.s4),
              children: [PostCard(post: post!, detail: true)],
            )
          : AsyncView<Post>(
              loader: _load,
              builder: (context, loaded, reload) => RefreshIndicator(
                onRefresh: reload,
                child: ListView(
                  padding: const EdgeInsets.all(ArdentSpacing.s4),
                  children: [PostCard(post: loaded, detail: true)],
                ),
              ),
            ),
    );
  }
}
