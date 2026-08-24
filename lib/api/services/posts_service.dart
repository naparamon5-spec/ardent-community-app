import 'dart:typed_data';

import '../api_client.dart';

/// Posts / Feed. See docs §Posts / Feed. Reads are optional-auth (personalised
/// when a token is sent); creating a post requires `module:feed.post`.
class PostsService {
  PostsService(this._api);
  final ApiClient _api;

  /// `GET /posts?type=&limit=&offset=` — feed, pinned first then newest.
  /// `limit` ≤ 100 (default 20).
  Future<List<dynamic>> feed({String? type, int? limit, int? offset}) async {
    final data = await _api
        .get('/posts', query: {'type': type, 'limit': limit, 'offset': offset});
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
  /// `signoff`, `lines`, `details`, `pinned`, `kudosTo`, `pollOptions`,
  /// `pollMultiple`, `sharedPostId`, `mentions`, …). Optional [photo]/[file]
  /// attachments use the `postUpload` preset. When attachments are present the
  /// request is sent as multipart (array/object fields become JSON strings).
  Future<Map<String, dynamic>> create({
    required Map<String, dynamic> fields,
    ({Uint8List bytes, String filename, String? contentType})? photo,
    ({Uint8List bytes, String filename, String? contentType})? file,
  }) async {
    if (photo == null && file == null) {
      final data = await _api.post('/posts', body: fields);
      return Map<String, dynamic>.from(data as Map);
    }
    final files = <UploadFile>[
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
    final data =
        await _api.multipart('POST', '/posts', fields: fields, files: files);
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

  /// `PUT /posts/:id/reaction` — set/replace your reaction.
  /// [type] ∈ `like | celebrate | support | insightful`.
  Future<Map<String, dynamic>> setReaction(String id, String type) async =>
      Map<String, dynamic>.from(
          await _api.put('/posts/$id/reaction', body: {'type': type}) as Map);

  /// `DELETE /posts/:id/reaction` — remove your reaction.
  Future<void> removeReaction(String id) => _api.delete('/posts/$id/reaction');

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
