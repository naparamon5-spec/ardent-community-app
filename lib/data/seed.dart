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
    this.email = '',
    this.department = '',
    this.location = '',
    this.bio = '',
  });

  final String id;
  final String name;
  final String initials;
  final String role;
  final Color color;
  final bool online;
  final String lastActive;
  final String email;
  final String department;
  final String location;
  final String bio;
}

class Reaction {
  const Reaction(this.key, this.label, this.icon, this.color);
  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

/// Post kinds mirror the web PostCard branches.
enum PostKind { text, announcement, kudos, poll, photo, file }

/// A single piece of attached media (image, video, or document) on a post or
/// story. [url] is already absolute (resolved against the API origin).
class MediaItem {
  MediaItem({
    required this.url,
    required this.type,
    this.caption,
    this.fileName,
    this.id = '',
    this.viewCount,
    this.myReaction,
  });

  /// Media item id — needed for the story view/react/viewers endpoints.
  final String id;
  final String url;

  /// `image`, `video`, or `file`.
  final String type;
  final String? caption;
  final String? fileName;

  /// Story media only: how many people saw this item (author-only; null
  /// otherwise). Mutable so an optimistic self-view can bump it.
  int? viewCount;

  /// Story media only: the emoji the current viewer reacted with, if any.
  String? myReaction;

  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
  bool get isFile => type == 'file';
}

class PollOption {
  PollOption(this.label, this.votes, {this.id = '', this.voted = false});
  final String id;
  final String label;
  int votes;

  /// Whether the current user's vote is on this option (single-select polls).
  bool voted;
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
    this.fileName = '',
    this.fileSize = '',
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

  /// Document metadata for `file` posts (shown even when no downloadable URL is
  /// present, mirroring the web feed).
  final String fileName;
  final String fileSize;

  bool liked = false;
  bool saved = false;

  /// The current user's reaction key (`like`, `celebrate`, `support`,
  /// `insightful`), or `null` if they haven't reacted.
  String? myReaction;

  /// Count of each reaction type left on the post, keyed by reaction key.
  Map<String, int> reactionCounts = {};

  /// Who reacted and with what — powers the "see who reacted" sheet.
  List<PostReactor> reactors = [];
}

/// One person's reaction on a post (name + which reaction they left).
class PostReactor {
  const PostReactor(this.person, this.type);
  final Person person;
  final String type;
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
    this.myRsvp = '',
    this.startAt,
    this.endAt,
    this.creatorId = '',
    this.canManage = false,
    this.coverUrl = '',
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

  /// The viewer's RSVP: `going`, `interested`, or `` (none).
  final String myRsvp;

  /// Raw start/end for editing (the display strings above are derived).
  final DateTime? startAt;
  final DateTime? endAt;

  /// Creator id and whether the server says the viewer may edit/delete.
  final String creatorId;
  final bool canManage;

  /// Optional cover image URL (absolute).
  final String coverUrl;
}

class Group {
  const Group({
    this.id = '',
    required this.name,
    required this.members,
    required this.color,
    required this.desc,
    this.isDirect = false,
    this.joined = false,
    this.pending = false,
  });
  final String id;
  final String name;
  final int members;
  final Color color;
  final String desc;

  /// True for a 1:1 direct-message thread rather than a named group.
  final bool isDirect;

  /// Whether the current user is an active member.
  final bool joined;

  /// Whether the current user has a pending join request.
  final bool pending;
}

class Listing {
  Listing({
    this.id = '',
    required this.title,
    required this.price,
    required this.category,
    required this.seller,
    required this.color,
    this.free = false,
    this.description = '',
    this.sellerId = '',
    this.likeCount = 0,
    this.sold = false,
    this.posted = '',
    this.coverUrl = '',
    this.liked = false,
    this.saved = false,
  });
  final String id;
  final String title;
  final String price;
  final String category;
  final String seller;
  final Color color;
  final bool free;
  final String description;
  final String sellerId;
  int likeCount;
  final bool sold;
  final String posted;
  final String coverUrl;
  bool liked;
  bool saved;
}

class Story {
  const Story(
    this.name,
    this.initials,
    this.color, {
    this.id = '',
    this.authorId = '',
    this.media = const [],
    this.caption = '',
    this.isMine = false,
  });
  final String id;

  /// The story author's user id — used to tell "my story" from someone else's.
  final String authorId;
  final String name;
  final String initials;
  final Color color;

  /// The story's media items (images/videos), shown in the viewer.
  final List<MediaItem> media;

  /// Story-level caption (some backends put the caption on the story itself).
  final String caption;

  /// Whether the signed-in viewer is the author (server-provided). When true,
  /// each media[].viewCount is populated and the viewers endpoint is usable.
  final bool isMine;
}

// ---- Reactions (web REACTIONS) ----
const reactions = <Reaction>[
  Reaction('like', 'Like', Icons.thumb_up_alt_rounded, ArdentColors.accent),
  Reaction('celebrate', 'Celebrate', Icons.celebration_rounded, Color(0xFFC77700)),
  Reaction('support', 'Support', Icons.favorite_rounded, ArdentColors.crimson500),
  Reaction('insightful', 'Insightful', Icons.lightbulb_rounded, ArdentColors.navy600),
];
