import 'dart:typed_data';

import '../api_client.dart';

/// Posts / Feed. See docs §Posts / Feed. Reads are optional-auth (personalised
/// when a token is sent); creating a post requires `module:feed.post`.
class PostsService {
  PostsService(this._api);
  final ApiClient _api;

  /// `GET /posts?type=&limit=&offset=&before=` — feed, pinned first then newest.
  /// `limit` ≤ 100 (default 20). [before] is an ISO `createdAt` cursor (from the
  /// oldest unpinned post already held) for scrolling further back — an
  /// alternative to [offset].
  Future<List<dynamic>> feed(
      {String? type, int? limit, int? offset, String? before}) async {
    final data = await _api.get('/posts', query: {
      'type': type,
      'limit': limit,
      'offset': offset,
      'before': before,
    });
    return data is List ? data : const [];
  }

  /// `GET /posts/:id` — one post with its full comment list attached.
  Future<Map<String, dynamic>> get(String id) async =>
      Map<String, dynamic>.from(await _api.get('/posts/$id') as Map);

  /// `GET /posts/:id/comments` — comments for a post (public).
  Future<List<dynamic>> comments(String id) async {
    final data = await _api.get('/posts/$id/comments');
    return data is List ? data : const [];
  }

  /// `POST /posts` — create a post (`module:feed.post`). Returns 201.
  ///
  /// [fields] carries the JSON payload (`type`, `text`, `title`, `note`,
  /// `signoff`, `lines`, `details`, `pinned`, `kudosTo`, `groupId`,
  /// `pollOptions`, `pollMultiple`, `sharedPostId`, `mentions`, …).
  ///
  /// Attachments use the `postUpload` preset: [media] carries up to 10 images
  /// (`media[]`) and [files] up to 10 documents (`files[]`). The singular
  /// [photo]/[file] params remain for older callers; a post never mixes the two
  /// shapes. When any attachment is present the request is sent as multipart
  /// (array/object fields become JSON strings).
  Future<Map<String, dynamic>> create({
    required Map<String, dynamic> fields,
    List<({Uint8List bytes, String filename, String? contentType})> media =
        const [],
    List<({Uint8List bytes, String filename, String? contentType})> files =
        const [],
    ({Uint8List bytes, String filename, String? contentType})? photo,
    ({Uint8List bytes, String filename, String? contentType})? file,
  }) async {
    final uploads = <UploadFile>[
      for (final m in media)
        UploadFile(
            field: 'media',
            filename: m.filename,
            bytes: m.bytes,
            contentType: m.contentType),
      for (final f in files)
        UploadFile(
            field: 'files',
            filename: f.filename,
            bytes: f.bytes,
            contentType: f.contentType),
      if (photo != null)
        UploadFile(
            field: 'photo',
            filename: photo.filename,
            bytes: photo.bytes,
            contentType: photo.contentType),
      if (file != null)
        UploadFile(
            field: 'file',
            filename: file.filename,
            bytes: file.bytes,
            contentType: file.contentType),
    ];
    if (uploads.isEmpty) {
      final data = await _api.post('/posts', body: fields);
      return Map<String, dynamic>.from(data as Map);
    }
    final data =
        await _api.multipart('POST', '/posts', fields: fields, files: uploads);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `PATCH /posts/:id` — edit (owner or `admin.users`).
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> fields) async =>
      Map<String, dynamic>.from(await _api.patch('/posts/$id', body: fields) as Map);

  /// `DELETE /posts/:id` — delete (owner or `admin.users`).
  Future<void> delete(String id) => _api.delete('/posts/$id');

  /// `POST /posts/:id/comments` — add a comment/reply.
  Future<Map<String, dynamic>> addComment(
    String id, {
    required String text,
    String? parentId,
    List<String>? mentions,
  }) async {
    final data = await _api.post('/posts/$id/comments', body: {
      'text': text,
      'parentId': ?parentId,
      'mentions': ?mentions,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `PATCH /posts/:id/comments/:commentId` — edit your own comment (author
  /// only, 403 otherwise). Stamps `editedAt`; only newly-added mentions notify.
  Future<Map<String, dynamic>> editComment(
    String id,
    String commentId, {
    required String text,
    List<String>? mentions,
  }) async {
    final data = await _api.patch('/posts/$id/comments/$commentId', body: {
      'text': text,
      'mentions': ?mentions,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /posts/:id/comments/:commentId` — delete a comment (author, the
  /// post's owner, or `admin.users`). Returns
  /// `{ outcome: 'tombstoned' | 'removed', commentId, post }`.
  Future<Map<String, dynamic>> deleteComment(String id, String commentId) async =>
      Map<String, dynamic>.from(
          await _api.delete('/posts/$id/comments/$commentId') as Map);

  /// `PUT /posts/:id/comments/:commentId/reaction` — set/replace your reaction
  /// to a comment. [type] ∈ `like | celebrate | support | insightful`.
  Future<Map<String, dynamic>> setCommentReaction(
    String id,
    String commentId,
    String type,
  ) async =>
      Map<String, dynamic>.from(await _api.put(
          '/posts/$id/comments/$commentId/reaction',
          body: {'type': type}) as Map);

  /// `DELETE /posts/:id/comments/:commentId/reaction` — remove your reaction to
  /// a comment.
  Future<void> removeCommentReaction(String id, String commentId) =>
      _api.delete('/posts/$id/comments/$commentId/reaction');

  /// `GET /posts/:id/comments/:commentId/reactions` — who reacted to a comment
  /// (`{ commentId, total, people: [{...author, reaction}] }`).
  Future<Map<String, dynamic>> commentReactions(String id, String commentId) async =>
      Map<String, dynamic>.from(
          await _api.get('/posts/$id/comments/$commentId/reactions') as Map);

  /// `PUT /posts/:id/reaction` — set/replace your reaction.
  /// [type] ∈ `like | celebrate | support | insightful`.
  Future<Map<String, dynamic>> setReaction(String id, String type) async =>
      Map<String, dynamic>.from(
          await _api.put('/posts/$id/reaction', body: {'type': type}) as Map);

  /// `DELETE /posts/:id/reaction` — remove your reaction.
  Future<void> removeReaction(String id) => _api.delete('/posts/$id/reaction');

  /// `GET /posts/:id/reactions` — who reacted to the post, grouped and flat
  /// (`{ total, byType: {...}, people: [{...author, reaction}] }`).
  Future<Map<String, dynamic>> reactions(String id) async =>
      Map<String, dynamic>.from(await _api.get('/posts/$id/reactions') as Map);

  /// `GET /posts/:id/sharers` — who shared the post
  /// (`{ total, unattributed, people: [{...author, sharedAt}] }`).
  Future<Map<String, dynamic>> sharers(String id) async =>
      Map<String, dynamic>.from(await _api.get('/posts/$id/sharers') as Map);

  /// `PUT /posts/:id/save` — save the post.
  Future<void> save(String id) => _api.put('/posts/$id/save');

  /// `DELETE /posts/:id/save` — unsave.
  Future<void> unsave(String id) => _api.delete('/posts/$id/save');

  /// `POST /posts/:id/share` — share (creates a `share`-type record).
  Future<Map<String, dynamic>> share(String id) async =>
      Map<String, dynamic>.from(await _api.post('/posts/$id/share') as Map);

  /// `GET /posts/:id/poll/voters` — `{ [optionId]: [author, ...] }`.
  Future<Map<String, dynamic>> pollVoters(String id) async =>
      Map<String, dynamic>.from(await _api.get('/posts/$id/poll/voters') as Map);

  /// `POST /posts/:id/vote` — vote for [optionId] (adds a choice if the poll is
  /// multiple-choice).
  Future<Map<String, dynamic>> vote(String id, String optionId) async =>
      Map<String, dynamic>.from(
          await _api.post('/posts/$id/vote', body: {'optionId': optionId}) as Map);

  /// `DELETE /posts/:id/vote` — withdraw your vote(s).
  Future<void> removeVote(String id) => _api.delete('/posts/$id/vote');
}
