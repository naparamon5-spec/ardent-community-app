import 'package:flutter/material.dart';

import '../api/api.dart';
import '../data/mappers.dart';
import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import '../widgets/post_card.dart';

/// Another member's profile / timeline — identity, an Intro card, and their
/// posts loaded from `GET /users/:id/posts`.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.person});

  final Person person;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<List<Post>> _posts;

  Person get person => widget.person;

  @override
  void initState() {
    super.initState();
    _posts = Api.instance.users
        .posts(person.id)
        .then((r) => r.map(postFromJson).toList())
        .catchError((_) => <Post>[]);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 150,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ArdentColors.navy700, ArdentColors.navy900],
                  ),
                ),
              ),
              Positioned(
                left: ArdentSpacing.s4,
                bottom: -40,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration:
                      const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: DsAvatar(
                      initials: person.initials,
                      color: person.color,
                      size: 84,
                      online: person.online),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name, style: text.headlineMedium?.copyWith(fontSize: 22)),
                Text(person.role, style: text.bodyLarge),
                Text(person.online ? 'Active now' : person.lastActive,
                    style: text.bodySmall?.copyWith(
                        color: person.online ? const Color(0xFF2FAE5C) : ArdentColors.fg3)),
                const SizedBox(height: ArdentSpacing.s4),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _messageSoon(context),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text('Message'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ArdentSpacing.s5),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Intro', style: text.titleLarge?.copyWith(fontSize: 16)),
                      const SizedBox(height: ArdentSpacing.s3),
                      _line(Icons.work_outline_rounded,
                          '${person.role} at Ardent Networks', text),
                    ],
                  ),
                ),
                const SizedBox(height: ArdentSpacing.s5),
                Overline('Posts'),
                const SizedBox(height: ArdentSpacing.s3),
              ],
            ),
          ),
          FutureBuilder<List<Post>>(
            future: _posts,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(ArdentSpacing.s6),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final posts = snapshot.data ?? const <Post>[];
              if (posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(ArdentSpacing.s6),
                  child: Center(
                    child: Text('No posts yet.',
                        style: text.bodyLarge?.copyWith(color: ArdentColors.fg3)),
                  ),
                );
              }
              return Column(
                children: [
                  for (final post in posts) ...[
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
                      child: PostCard(post: post),
                    ),
                    const SizedBox(height: ArdentSpacing.s3),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: ArdentSpacing.s6),
        ],
      ),
    );
  }

  void _messageSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Open Chats to message this person')),
    );
  }

  Widget _line(IconData icon, String label, TextTheme text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: ArdentColors.fg3),
          const SizedBox(width: ArdentSpacing.s3),
          Expanded(child: Text(label, style: text.bodyLarge)),
        ],
      ),
    );
  }
}
