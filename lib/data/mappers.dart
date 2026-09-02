import 'package:flutter/material.dart';

import '../api/services/media_service.dart';
import '../theme/ardent_colors.dart';
import 'seed.dart';

/// Maps backend JSON (see `docs/API_DOCUMENTATION.md`) onto the app's existing
/// UI model classes (`Person`, `Post`, `EventItem`, …).
///
/// The backend response bodies aren't fully specified in the docs, so every
/// parser here is **defensive**: it tries several common field names and
/// degrades to sensible defaults instead of throwing. When you confirm the real
/// field names against a running backend, tighten the `_pick([...])` lists.

// ---------------------------------------------------------------------------
// Primitive helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<dynamic> asList(dynamic v) => v is List ? v : const [];

/// First non-null value among [keys] in [json].
dynamic _pick(Map json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v != null) return v;
  }
  return null;
}

String _str(dynamic v, [String fallback = '']) => v == null ? fallback : '$v';

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is List) return v.length;
  return int.tryParse('$v') ?? fallback;
}

bool _bool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return fallback;
}

// ---------------------------------------------------------------------------
// Avatar identity
// ---------------------------------------------------------------------------

const _avatarPalette = <Color>[
  ArdentColors.navy700,
  ArdentColors.navy500,
  ArdentColors.crimson500,
  ArdentColors.navy800,
  ArdentColors.navy600,
  ArdentColors.crimson700,
  ArdentColors.accent,
];

/// Deterministic brand colour for a user/entity, so the same person always gets
/// the same avatar colour even when the server sends none.
Color avatarColorFor(String seed) {
  if (seed.isEmpty) return ArdentColors.navy700;
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _avatarPalette[hash % _avatarPalette.length];
}

/// Parses `#rrggbb` / `#aarrggbb` / `rgb(...)` / a CSS var (falls back to null).
Color? parseColor(dynamic value) {
  if (value == null) return null;
  final s = '$value'.trim();
  if (s.startsWith('#')) {
    var hex = s.substring(1);
    if (hex.length == 6) hex = 'ff$hex';
    final v = int.tryParse(hex, radix: 16);
    if (v != null) return Color(v);
  }
  return null; // `var(--navy-700)` etc. — let the caller derive a colour.
}

/// Up-to-two-letter initials from a display name.
String initialsFrom(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final p = parts.first;
    return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse('$v')?.toLocal();
}

/// Philippine Standard Time is a fixed UTC+8 (no DST). The backend stores UTC
/// and the web renders in Manila time, so we display in Manila on every device —
/// otherwise an emulator/phone set to another zone shows the wrong wall-clock.
const Duration kManilaOffset = Duration(hours: 8);

/// True when [s] already carries a timezone (`Z`, or a `+HH:MM` / `-HHMM`
/// offset), so [DateTime.tryParse] interpreted it correctly.
bool _hasTimezone(String s) {
  final t = s.contains('T') ? s.substring(s.indexOf('T') + 1) : s;
  if (t.endsWith('Z') || t.endsWith('z')) return true;
  return RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(t);
}

/// Parses a backend timestamp as a true UTC instant. A string without any
/// timezone marker is assumed to be UTC (the backend's convention), rather than
/// the device's local zone as [DateTime.tryParse] would default to.
DateTime? _parseUtc(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toUtc();
  final s = '$v'.trim();
  if (s.isEmpty) return null;
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  if (parsed.isUtc || _hasTimezone(s)) return parsed.toUtc();
  // Naive timestamp → re-tag its wall-clock fields as UTC.
  return DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour,
      parsed.minute, parsed.second, parsed.millisecond, parsed.microsecond);
}

/// A backend timestamp as Asia/Manila wall-clock time. Read its `.hour`/`.day`/…
/// fields for display; its absolute instant is intentionally shifted, so don't
/// compare it against a raw `DateTime.now()` — use [manilaNow] instead.
DateTime? parseManilaTime(dynamic v) => _parseUtc(v)?.add(kManilaOffset);

/// "Now" as Asia/Manila wall-clock, to pair with [parseManilaTime] for
/// same-day / relative comparisons.
DateTime manilaNow() => DateTime.now().toUtc().add(kManilaOffset);

/// Compact presence age used for "last active" labels — mirrors the web store's
/// formatter exactly: `Just now`, `5m`, `3h`, `2d`, `4w`, then a locale date.
/// Returns `''` when the timestamp is missing or unparseable.
String _presenceAge(dynamic iso) {
  final dt = _parseDate(iso);
  if (dt == null) return '';
  var secs = DateTime.now().difference(dt).inSeconds;
  if (secs < 0) secs = 0;
  if (secs < 45) return 'Just now';
  final mins = secs ~/ 60;
  if (mins < 60) return '${mins}m';
  final hours = mins ~/ 60;
  if (hours < 24) return '${hours}h';
  final days = hours ~/ 24;
  if (days < 7) return '${days}d';
  final weeks = days ~/ 7;
  if (weeks < 5) return '${weeks}w';
  return '${dt.month}/${dt.day}/${dt.year}';
}

/// Web-identical presence label: `Active now` when [online], otherwise
/// `Active <age> ago` from [lastActiveAt] (e.g. `Active 3h ago`), falling back
/// to `Offline` when there's no known last-active time.
String presenceLabel(bool online, dynamic lastActiveAt) {
  if (online) return 'Active now';
  final age = _presenceAge(lastActiveAt);
  return age.isEmpty ? 'Offline' : 'Active $age ago';
}

/// A short relative label like `2h ago`, `Yesterday`, `Mar 3`.
String relativeTime(dynamic iso) {
  final dt = _parseDate(iso);
  if (dt == null) return _str(iso);
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${_months[dt.month - 1]} ${dt.day}';
}

/// A plain `YYYY-MM-DD` label (used for appraisal cycle periods).
String relativeDateOnly(dynamic iso) {
  final dt = _parseDate(iso);
  if (dt == null) return '';
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '${dt.year}-$m-$d';
}

/// A calendar label like `Mar 2024` (used for hire/join dates).
String relativeDate(dynamic iso) {
  final dt = _parseDate(iso);
  if (dt == null) return _str(iso);
  return '${_months[dt.month - 1]} ${dt.year}';
}

String _clock(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
}

// ---------------------------------------------------------------------------
// People
// ---------------------------------------------------------------------------

Person personFromJson(dynamic value) {
  final json = asMap(value);
  final id = _str(_pick(json, ['id', 'slug', '_id', 'userId']));
  var name = _str(_pick(json, ['name', 'fullName', 'displayName']));
  if (name.isEmpty) {
    final first = _str(_pick(json, ['firstName', 'first']));
    final last = _str(_pick(json, ['lastName', 'last']));
    name = '$first $last'.trim();
  }
  if (name.isEmpty) name = 'Unknown';
  final initials = _str(_pick(json, ['initials'])).isNotEmpty
      ? _str(_pick(json, ['initials']))
      : initialsFrom(name);
  final online = _bool(_pick(json, ['online', 'isOnline']));
  final avatar = _mediaItem(_pick(json,
      ['avatarUrl', 'avatar', 'photoUrl', 'photo', 'image', 'imageUrl', 'picture', 'pictureUrl', 'profilePhoto', 'profilePhotoUrl']));
  final cover = _mediaItem(_pick(json,
      ['coverUrl', 'cover', 'coverPhoto', 'coverPhotoUrl', 'banner', 'bannerUrl']));
  return Person(
    id: id,
    name: name,
    initials: initials,
    role: _str(_pick(json, ['role', 'title', 'jobTitle', 'department']), 'Community Member'),
    color: parseColor(_pick(json, ['color', 'avatarColor'])) ??
        avatarColorFor(id.isNotEmpty ? id : name),
    online: online,
    lastActive: presenceLabel(
        online, _pick(json, ['lastActiveAt', 'lastActive', 'lastSeen'])),
    email: _str(_pick(json, ['email', 'workEmail'])),
    department: _str(_pick(json, ['department', 'dept'])),
    location: _str(_pick(json, ['location'])),
    bio: _str(_pick(json, ['bio', 'about'])),
    avatarUrl: avatar?.url ?? '',
    coverUrl: cover?.url ?? '',
  );
}

// ---------------------------------------------------------------------------
// Media
// ---------------------------------------------------------------------------

const _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'];
const _videoExts = ['.mp4', '.webm', '.mov', '.ogg', '.m4v', '.avi'];

String _mediaType(String url, dynamic explicit) {
  final t = '$explicit'.toLowerCase();
  if (t.contains('image')) return 'image';
  if (t.contains('video')) return 'video';
  if (t.isNotEmpty && (t.contains('file') || t.contains('doc') || t.contains('pdf'))) {
    return 'file';
  }
  final lower = url.toLowerCase();
  if (_imageExts.any(lower.contains)) return 'image';
  if (_videoExts.any(lower.contains)) return 'video';
  return 'file';
}

/// Builds a [MediaItem] from a media object or a bare URL string.
MediaItem? _mediaItem(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    if (value.isEmpty) return null;
    return MediaItem(url: MediaService.resolve(value), type: _mediaType(value, null));
  }
  final m = asMap(value);
  final rawUrl = _str(_pick(m, ['url', 'src', 'path', 'href', 'link', 'downloadUrl', 'fileUrl']));
  if (rawUrl.isEmpty) return null;
  final type = _mediaType(rawUrl,
      _pick(m, ['type', 'mimeType', 'mime', 'contentType', 'fileType', 'kind', 'format']));
  final name = _str(_pick(m, ['fileName', 'filename', 'name', 'originalName']));
  final vc = _pick(m, ['viewCount', 'views', 'seenCount']);
  final reaction = _pick(m, ['myReaction', 'reaction']);
  return MediaItem(
    id: _str(_pick(m, ['id', '_id', 'mediaId'])),
    url: MediaService.resolve(rawUrl),
    type: type,
    caption: _str(_pick(m, ['caption', 'text'])).isEmpty
        ? null
        : _str(_pick(m, ['caption', 'text'])),
    fileName: name.isEmpty ? null : name,
    viewCount: vc == null ? null : _int(vc),
    myReaction: (reaction == null || '$reaction'.isEmpty) ? null : '$reaction',
  );
}

/// Collects media from the many shapes a post/story might use: a `media`/
/// `attachments`/`photos` array, or single `photo`/`image`/`file` fields.
List<MediaItem> mediaFromJson(Map json) {
  final out = <MediaItem>[];
  for (final key in ['media', 'attachments', 'photos', 'images', 'files']) {
    for (final e in asList(json[key])) {
      final item = _mediaItem(e);
      if (item != null) out.add(item);
    }
  }
  for (final key in [
    'photo', 'photoUrl', 'image', 'imageUrl', 'file', 'fileUrl', 'attachment'
  ]) {
    if (json[key] != null) {
      final item = _mediaItem(json[key]);
      if (item != null) out.add(item);
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Posts
// ---------------------------------------------------------------------------

PostKind _postKind(dynamic type) {
  switch ('$type') {
    case 'announcement':
      return PostKind.announcement;
    case 'kudos':
      return PostKind.kudos;
    case 'poll':
      return PostKind.poll;
    case 'photo':
      return PostKind.photo;
    case 'file':
      return PostKind.file;
    default:
      return PostKind.text;
  }
}

/// Formats a file size that may arrive as a byte count or an already-formatted
/// string (e.g. `1.2 MB`).
String _fileSizeLabel(dynamic v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  var size = _int(v).toDouble();
  if (size <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var u = 0;
  while (size >= 1024 && u < units.length - 1) {
    size /= 1024;
    u++;
  }
  final rounded = (u == 0) ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
  return '$rounded ${units[u]}';
}

List<MapEntry<String, String>> _details(dynamic value) {
  if (value is Map) {
    return value.entries.map((e) => MapEntry('${e.key}', '${e.value}')).toList();
  }
  if (value is List) {
    return value.map((e) {
      final m = asMap(e);
      final k = _str(_pick(m, ['key', 'label', 'name']));
      final v = _str(_pick(m, ['value', 'text']));
      return MapEntry(k, v);
    }).where((e) => e.key.isNotEmpty || e.value.isNotEmpty).toList();
  }
  return const [];
}

PollOption _pollOption(dynamic value) {
  final m = asMap(value);
  return PollOption(
    _str(_pick(m, ['label', 'text', 'option'])),
    _int(_pick(m, ['votes', 'voteCount', 'count'])),
    id: _str(_pick(m, ['id', '_id', 'optionId'])),
    voted: _bool(_pick(m, ['votedByMe', 'myVote', 'selected', 'isVoted'])),
  );
}

Comment commentFromJson(dynamic value) {
  final json = asMap(value);
  final comment = Comment(
    id: _str(_pick(json, ['id', '_id'])),
    author: personFromJson(_pick(json, ['author', 'user', 'createdBy'])),
    text: _str(_pick(json, ['text', 'body', 'content'])),
    likes: _int(_pick(json, ['likeCount', 'likes', 'reactionCount'])),
    replies: asList(_pick(json, ['replies', 'children'])).map(commentFromJson).toList(),
  );
  comment.liked = _bool(_pick(json, ['likedByMe', 'liked']));
  return comment;
}

String _kudosTo(dynamic value) {
  if (value is Map) return _str(_pick(value, ['name', 'fullName', 'displayName']));
  return _str(value);
}

Post postFromJson(dynamic value) {
  final json = asMap(value);
  final media = mediaFromJson(json);
  // File metadata for `file` posts: prefer explicit fields, else a file media item.
  final fileItem = media.where((m) => m.isFile).cast<MediaItem?>().firstWhere(
        (m) => true,
        orElse: () => null,
      );
  final fileName = _str(_pick(json, ['fileName', 'filename', 'attachmentName']),
      fileItem?.fileName ?? '');
  final fileSize = _fileSizeLabel(_pick(json, ['fileSize', 'size', 'bytes']));
  final post = Post(
    id: _str(_pick(json, ['id', '_id', 'slug'])),
    author: personFromJson(_pick(json, ['author', 'user', 'createdBy', 'postedBy'])),
    time: relativeTime(_pick(json, ['createdAt', 'created_at', 'time', 'date'])),
    kind: _postKind(_pick(json, ['type', 'kind'])),
    text: _str(_pick(json, ['text', 'body', 'content', 'caption'])),
    title: _str(_pick(json, ['title', 'headline'])),
    details: _details(_pick(json, ['details', 'meta'])),
    note: _str(_pick(json, ['note'])),
    signoff: _str(_pick(json, ['signoff', 'signOff'])),
    kudosTo: _kudosTo(_pick(json, ['kudosTo', 'kudosRecipient'])),
    pollOptions: asList(_pick(json, ['pollOptions', 'options'])).map(_pollOption).toList(),
    pinned: _bool(_pick(json, ['pinned', 'isPinned'])),
    comments: asList(_pick(json, ['comments'])).map(commentFromJson).toList(),
    likeCount: _int(_pick(json, ['likeCount', 'likes', 'reactionCount', 'reactionsCount'])),
    shareCount: _int(_pick(json, ['shareCount', 'shares'])),
    media: media,
    fileName: fileName,
    fileSize: fileSize,
  );
  // Poll-level "my vote" — mark the matching option when the backend reports a
  // voted option id rather than a per-option flag.
  final myVoteId = _str(_pick(json, ['votedOptionId', 'myVoteOptionId', 'myVote']));
  if (myVoteId.isNotEmpty) {
    for (final o in post.pollOptions) {
      if (o.id == myVoteId) o.voted = true;
    }
  }
  // My own reaction (a type key like `like`/`support`), if any.
  final myReactionRaw = _pick(json, ['myReaction', 'reaction', 'userReaction']);
  post.myReaction = myReactionRaw is Map
      ? (_str(_pick(myReactionRaw, ['type', 'key'])).isEmpty
          ? null
          : _str(_pick(myReactionRaw, ['type', 'key'])))
      : (myReactionRaw == null || '$myReactionRaw'.isEmpty ? null : '$myReactionRaw');
  post.liked = post.myReaction != null ||
      _bool(_pick(json, ['likedByMe', 'liked']));
  if (post.liked && post.myReaction == null) post.myReaction = 'like';

  // Per-type counts, from a breakdown map when the backend provides one.
  final counts = <String, int>{};
  final breakdown = _pick(json, ['reactionCounts', 'reactionBreakdown', 'reactionsByType']);
  if (breakdown is Map) {
    breakdown.forEach((k, v) => counts['$k'] = _int(v));
  }

  // Reactor list: who reacted with what.
  final reactors = <PostReactor>[];
  final rawReactors = _pick(json, ['reactors', 'reactions', 'reactionList']);
  if (rawReactors is List) {
    for (final r in rawReactors) {
      final rm = asMap(r);
      final person = personFromJson(_pick(rm, ['user', 'person', 'author']) ?? rm);
      final type = _str(_pick(rm, ['type', 'reaction', 'key']), 'like');
      reactors.add(PostReactor(person, type));
      if (breakdown is! Map) counts[type] = (counts[type] ?? 0) + 1;
    }
  }
  post.reactionCounts = counts;
  post.reactors = reactors;
  post.saved = _bool(_pick(json, ['savedByMe', 'saved']));
  return post;
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

EventItem eventFromJson(dynamic value) {
  final json = asMap(value);
  final start = _parseDate(_pick(json, ['startsAt', 'startAt', 'date', 'start']));
  final end = _parseDate(_pick(json, ['endsAt', 'endAt', 'end']));
  final dateStr = start == null
      ? _str(_pick(json, ['dateLabel']))
      : '${_weekdays[start.weekday - 1]}, ${_months[start.month - 1]} ${start.day}, ${start.year}';
  final timeStr = start == null
      ? ''
      : end == null
          ? _clock(start)
          : '${_clock(start)} – ${_clock(end)}';
  final going = _pick(json, ['attendees', 'goingCount', 'going']);
  return EventItem(
    id: _str(_pick(json, ['id', '_id'])),
    title: _str(_pick(json, ['title', 'name'])),
    date: dateStr,
    day: start == null ? '--' : start.day.toString().padLeft(2, '0'),
    mon: start == null ? '' : _months[start.month - 1].toUpperCase(),
    time: timeStr,
    location: _str(_pick(json, ['location', 'venue'])),
    desc: _str(_pick(json, ['description', 'desc'])),
    attendees: _int(going),
    interested: _int(_pick(json, ['interested', 'interestedCount'])),
    featured: _bool(_pick(json, ['featured', 'isFeatured'])),
    myRsvp: _rsvpStatus(_pick(json, ['myRsvp', 'rsvp', 'viewerRsvp', 'myStatus'])),
    startAt: start,
    endAt: end,
    creatorId: _entityId(_pick(json,
        ['creatorId', 'createdById', 'organizerId', 'ownerId', 'userId']) ??
        _pick(json, ['createdBy', 'organizer', 'owner', 'author', 'creator', 'user'])),
    canManage: _bool(_pick(json, ['canManage', 'canEdit', 'isOwner', 'mine'])),
    coverUrl: _coverUrl(json),
  );
}

String _coverUrl(Map json) {
  final direct = _mediaItem(_pick(json, ['coverUrl', 'cover', 'image', 'imageUrl', 'banner']));
  if (direct != null && direct.isImage) return direct.url;
  final img = mediaFromJson(json).where((m) => m.isImage).cast<MediaItem?>().firstWhere(
        (_) => true,
        orElse: () => null,
      );
  return img?.url ?? '';
}

/// Extracts an id from either a bare id value or an embedded user/entity object.
String _entityId(dynamic v) {
  if (v == null) return '';
  if (v is Map) return _str(_pick(v, ['id', '_id', 'slug']));
  return _str(v);
}

String _rsvpStatus(dynamic v) {
  final s = '${v is Map ? _pick(v, ['status']) : v}'.toLowerCase();
  if (s == 'going' || s == 'interested') return s;
  return '';
}

// ---------------------------------------------------------------------------
// Listings
// ---------------------------------------------------------------------------

String _priceLabel(Map json, {required bool free}) {
  if (free) return 'Free';
  final cents = _pick(json, ['priceCents']);
  if (cents != null) return '₱${(_int(cents) / 100).toStringAsFixed(0)}';
  final price = _pick(json, ['price']);
  if (price != null) return '₱${_int(price)}';
  return '—';
}

Listing listingFromJson(dynamic value) {
  final json = asMap(value);
  final id = _str(_pick(json, ['id', '_id']));
  final free = _bool(_pick(json, ['free', 'isFree'])) ||
      (_pick(json, ['priceCents']) != null && _int(_pick(json, ['priceCents'])) == 0);
  final category = _pick(json, ['category']);
  final seller = personFromJson(_pick(json, ['seller', 'owner', 'user', 'author']));
  final images = mediaFromJson(json).where((m) => m.isImage);
  return Listing(
    id: id,
    title: _str(_pick(json, ['title', 'name'])),
    price: _priceLabel(json, free: free),
    category: category is Map ? _str(_pick(category, ['name'])) : _str(category, 'Other'),
    seller: seller.name,
    sellerId: seller.id,
    sellerAvatarUrl: seller.avatarUrl,
    color: avatarColorFor(seller.id.isNotEmpty ? seller.id : id),
    free: free,
    description: _str(_pick(json, ['description', 'desc'])),
    likeCount: _int(_pick(json, ['likeCount', 'likes', 'likesCount'])),
    sold: _bool(_pick(json, ['sold', 'isSold'])),
    posted: relativeTime(_pick(json, ['createdAt', 'created_at', 'postedAt'])),
    coverUrl: images.isEmpty ? '' : images.first.url,
  )
    ..liked = _bool(_pick(json, ['likedByMe', 'liked']))
    ..saved = _bool(_pick(json, ['savedByMe', 'saved']));
}

// ---------------------------------------------------------------------------
// Stories
// ---------------------------------------------------------------------------

Story storyFromJson(dynamic value) {
  final json = asMap(value);
  final author = personFromJson(_pick(json, ['author', 'user', 'createdBy']));
  return Story(
    author.name,
    author.initials,
    author.color,
    id: _str(_pick(json, ['id', '_id'])),
    authorId: author.id,
    media: mediaFromJson(json),
    caption: _str(_pick(json, ['caption', 'text'])),
    isMine: _bool(_pick(json, ['isMine', 'mine'])),
    avatarUrl: author.avatarUrl,
  );
}

// ---------------------------------------------------------------------------
// Groups
// ---------------------------------------------------------------------------

Group groupFromJson(dynamic value) {
  final json = asMap(value);
  final id = _str(_pick(json, ['id', '_id']));
  final isDirect = _bool(_pick(json, ['isDirect', 'direct'])) ||
      '${_pick(json, ['type'])}' == 'direct';
  final status = '${_pick(json, ['membershipStatus', 'status', 'myStatus'])}'.toLowerCase();
  final joined = _bool(_pick(json, ['joined', 'isMember', 'member'])) ||
      status == 'member' ||
      status == 'active';
  final pending = _bool(_pick(json, ['pending', 'requested'])) ||
      status == 'pending' ||
      status == 'requested';

  // Direct threads carry the counterpart in `other` — its name/color identify
  // the thread and its presence drives the "Active now / Active 3h ago" label.
  final other = isDirect ? _pick(json, ['other', 'peer', 'user']) : null;
  final otherPerson = other == null ? null : personFromJson(other);

  final name = otherPerson?.name ??
      _str(_pick(json, ['name', 'title']), isDirect ? 'Direct message' : 'Group');
  final color = otherPerson?.color ??
      parseColor(_pick(json, ['color'])) ??
      avatarColorFor(id);

  // A group's own cover/avatar photo; direct threads use the counterpart avatar.
  final photoItem = _mediaItem(_pick(json,
      ['photo', 'photoUrl', 'image', 'imageUrl', 'avatar', 'avatarUrl', 'cover', 'coverUrl', 'banner']));
  final photoUrl = otherPerson != null
      ? otherPerson.avatarUrl
      : (photoItem != null && photoItem.url.isNotEmpty ? photoItem.url : '');

  return Group(
    id: id,
    name: name,
    members: _int(_pick(json, ['memberCount', 'membersCount', 'members'])),
    color: color,
    desc: _str(_pick(json, ['description', 'desc'])),
    isDirect: isDirect,
    joined: joined,
    pending: pending,
    online: otherPerson?.online ?? false,
    lastActive: otherPerson?.lastActive ?? '',
    photoUrl: photoUrl,
  );
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

/// A single notification row, parsed for the notifications screen.
class NotificationItem {
  NotificationItem({
    required this.id,
    required this.actor,
    required this.action,
    required this.time,
    required this.unread,
    required this.icon,
    required this.color,
  });

  final String id;
  final Person actor;
  final String action;
  final String time;
  final bool unread;
  final IconData icon;
  final Color color;
}

({IconData icon, Color color}) _notificationStyle(String type) {
  switch (type) {
    case 'reaction':
    case 'like':
      return (icon: Icons.thumb_up_alt_rounded, color: ArdentColors.accent);
    case 'kudos':
      return (icon: Icons.emoji_events_rounded, color: const Color(0xFFC77700));
    case 'comment':
    case 'reply':
      return (icon: Icons.mode_comment_rounded, color: ArdentColors.navy600);
    case 'mention':
      return (icon: Icons.alternate_email_rounded, color: ArdentColors.crimson500);
    case 'follow':
      return (icon: Icons.person_add_alt_1_rounded, color: ArdentColors.navy500);
    case 'event':
    case 'rsvp':
      return (icon: Icons.event_rounded, color: ArdentColors.accent);
    default:
      return (icon: Icons.notifications_rounded, color: ArdentColors.navy600);
  }
}

NotificationItem notificationFromJson(dynamic value) {
  final json = asMap(value);
  final style = _notificationStyle(_str(_pick(json, ['type', 'kind'])));
  final read = _pick(json, ['read', 'isRead']) != null
      ? _bool(_pick(json, ['read', 'isRead']))
      : !_bool(_pick(json, ['unread']), true);
  return NotificationItem(
    id: _str(_pick(json, ['id', '_id'])),
    actor: personFromJson(_pick(json, ['actor', 'fromUser', 'sender', 'user'])),
    action: _str(_pick(json, ['message', 'text', 'action', 'body']), 'sent you a notification'),
    time: relativeTime(_pick(json, ['createdAt', 'time'])),
    unread: !read,
    icon: style.icon,
    color: style.color,
  );
}
