import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import '../widgets/post_card.dart';

/// Another member's profile / timeline — Facebook-style: cover, identity,
/// action buttons, an Intro/About card, and their posts.
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key, required this.person});

  final Person person;

  /// A few sample posts authored by this person for their timeline.
  List<Post> _timeline() {
    return [
      Post(
        id: '${person.id}-p1',
        author: person,
        time: '3h ago',
        kind: PostKind.text,
        text: 'Grateful to be part of such an amazing team at Ardent. '
            'Big things coming this quarter! 🚀',
        likeCount: 42,
        shareCount: 3,
        comments: [
          Comment(author: Seed.people.first, text: 'Well said! 🙌', likes: 3),
        ],
      ),
      Post(
        id: '${person.id}-p2',
        author: person,
        time: 'Yesterday',
        kind: PostKind.photo,
        text: 'Throwback to last year\'s team offsite. Who\'s ready for the next one?',
        likeCount: 88,
        shareCount: 6,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      // Cover bleeds up behind a transparent app bar; the avatar overlaps it
      // via a non-clipping Stack (the sliver version clipped the avatar's top).
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
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
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
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text('Message'),
                      ),
                    ),
                    const SizedBox(width: ArdentSpacing.s3),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                        label: const Text('Follow'),
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
                      _line(Icons.place_outlined, 'Pasig City, Philippines', text),
                      _line(Icons.mail_outline_rounded,
                          '${person.name.split(' ').first.toLowerCase()}@ardentnetworks.com.ph',
                          text),
                      _line(Icons.cake_outlined, 'Joined 2024', text),
                    ],
                  ),
                ),
                const SizedBox(height: ArdentSpacing.s5),
                Overline('Posts'),
                const SizedBox(height: ArdentSpacing.s3),
              ],
            ),
          ),
          for (final post in _timeline()) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
              child: PostCard(post: post),
            ),
            const SizedBox(height: ArdentSpacing.s3),
          ],
          const SizedBox(height: ArdentSpacing.s6),
        ],
      ),
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
