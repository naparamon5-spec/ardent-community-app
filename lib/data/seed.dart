import 'package:flutter/material.dart';

import '../theme/ardent_colors.dart';

/// UI model classes shared across screens. These are populated at runtime from
/// the backend API via `lib/data/mappers.dart` (JSON → these types); the app no
/// longer ships mock content. Reaction definitions below are static UI config.

class Person {
  const Person({
    required this.id,
    required this.name,
    required this.initials,
    required this.role,
    required this.color,
    this.online = false,
    this.lastActive = 'Active recently',
  });

  final String id;
  final String name;
  final String initials;
  final String role;
  final Color color;
  final bool online;
  final String lastActive;
}

class Reaction {
  const Reaction(this.key, this.label, this.icon, this.color);
  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

/// Post kinds mirror the web PostCard branches.
enum PostKind { text, announcement, kudos, poll, photo }

/// A single piece of attached media (image, video, or document) on a post or
/// story. [url] is already absolute (resolved against the API origin).
class MediaItem {
  const MediaItem({
    required this.url,
    required this.type,
    this.caption,
    this.fileName,
  });

  final String url;

  /// `image`, `video`, or `file`.
  final String type;
  final String? caption;
  final String? fileName;

  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
  bool get isFile => type == 'file';
}

class PollOption {
  PollOption(this.label, this.votes, {this.id = ''});
  final String id;
  final String label;
  int votes;
}

class Comment {
  Comment({
    this.id = '',
    required this.author,
    required this.text,
    this.likes = 0,
    List<Comment>? replies,
  }) : replies = replies ?? [];

  final String id;
  final Person author;
  final String text;
  int likes;

  /// Threaded replies to this comment.
  final List<Comment> replies;

  /// Whether the current user has liked this comment.
  bool liked = false;
}

class Post {
  Post({
    required this.id,
    required this.author,
    required this.time,
    required this.kind,
    this.text = '',
    this.title = '',
    this.details = const [],
    this.note = '',
    this.signoff = '',
    this.kudosTo = '',
    this.pollOptions = const [],
    this.pinned = false,
    List<Comment>? comments,
    this.likeCount = 0,
    this.shareCount = 0,
    this.media = const [],
  }) : comments = comments ?? [];

  final String id;
  final Person author;
  final String time;
  final PostKind kind;
  final String text;
  final String title;
  final List<MapEntry<String, String>> details;
  final String note;
  final String signoff;
  final String kudosTo;
  final List<PollOption> pollOptions;
  final bool pinned;
  final List<Comment> comments;
  int likeCount;
  int shareCount;

  /// Attached images / videos / documents.
  final List<MediaItem> media;

  bool liked = false;
  bool saved = false;
}

class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.date,
    required this.day,
    required this.mon,
    required this.time,
    required this.location,
    required this.desc,
    required this.attendees,
    this.interested = 0,
    this.featured = false,
  });

  final String id;
  final String title;
  final String date;
  final String day;
  final String mon;
  final String time;
  final String location;
  final String desc;
  final int attendees;
  final int interested;
  final bool featured;
}

class Group {
  const Group({
    this.id = '',
    required this.name,
    required this.members,
    required this.color,
    required this.desc,
    this.isDirect = false,
  });
  final String id;
  final String name;
  final int members;
  final Color color;
  final String desc;

  /// True for a 1:1 direct-message thread rather than a named group.
  final bool isDirect;
}

class Listing {
  const Listing({
    this.id = '',
    required this.title,
    required this.price,
    required this.category,
    required this.seller,
    required this.color,
    this.free = false,
  });
  final String id;
  final String title;
  final String price;
  final String category;
  final String seller;
  final Color color;
  final bool free;
}

class Story {
  const Story(
    this.name,
    this.initials,
    this.color, {
    this.id = '',
    this.media = const [],
    this.caption = '',
  });
  final String id;
  final String name;
  final String initials;
  final Color color;

  /// The story's media items (images/videos), shown in the viewer.
  final List<MediaItem> media;

  /// Story-level caption (some backends put the caption on the story itself).
  final String caption;
}

// ---- Reactions (web REACTIONS) ----
const reactions = <Reaction>[
  Reaction('like', 'Like', Icons.thumb_up_alt_rounded, ArdentColors.accent),
  Reaction('celebrate', 'Celebrate', Icons.celebration_rounded, Color(0xFFC77700)),
  Reaction('support', 'Support', Icons.favorite_rounded, ArdentColors.crimson500),
  Reaction('insightful', 'Insightful', Icons.lightbulb_rounded, ArdentColors.navy600),
];
