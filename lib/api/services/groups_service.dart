import 'dart:typed_data';

import '../api_client.dart';

/// Groups & direct messages, including group chat. See docs §Groups.
/// Every route requires `module:groups.view`. The chat REST routes here share
/// the same JWT as the Socket.IO connection (see [RealtimeService]).
class GroupsService {
  GroupsService(this._api);
  final ApiClient _api;

  /// `GET /groups` — groups visible to the viewer.
  Future<List<dynamic>> list() async {
    final data = await _api.get('/groups');
    return data is List ? data : const [];
  }

  /// `GET /groups/direct` — the caller's direct-message threads.
  Future<List<dynamic>> directThreads() async {
    final data = await _api.get('/groups/direct');
    return data is List ? data : const [];
  }

  /// `POST /groups/direct` — open or find an existing 1:1 DM thread.
  Future<Map<String, dynamic>> openDirect(String userId) async =>
      Map<String, dynamic>.from(
          await _api.post('/groups/direct', body: {'userId': userId}) as Map);

  /// `GET /groups/:id` — one group/thread (404 if not found).
  Future<Map<String, dynamic>> get(String id) async =>
      Map<String, dynamic>.from(await _api.get('/groups/$id') as Map);

  /// `POST /groups` — create a group (creator becomes first admin). `name`
  /// required; optional `description`, `color`, `adminIds`, `photo`.
  Future<Map<String, dynamic>> create({
    required Map<String, dynamic> fields,
    ({Uint8List bytes, String filename, String? contentType})? photo,
  }) async {
    final files = photo == null
        ? const <UploadFile>[]
        : [
            UploadFile(
                field: 'photo',
                filename: photo.filename,
                bytes: photo.bytes,
                contentType: photo.contentType)
          ];
    final data =
        await _api.multipart('POST', '/groups', fields: fields, files: files);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `PATCH /groups/:id` — rename/re-describe/re-photo (group-admin or
  /// site-admin; not on direct threads).
  Future<Map<String, dynamic>> update(
    String id, {
    Map<String, dynamic> fields = const {},
    ({Uint8List bytes, String filename, String? contentType})? photo,
  }) async {
    final files = photo == null
        ? const <UploadFile>[]
        : [
            UploadFile(
                field: 'photo',
                filename: photo.filename,
                bytes: photo.bytes,
                contentType: photo.contentType)
          ];
    final data = await _api.multipart('PATCH', '/groups/$id',
        fields: fields, files: files);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /groups/:id` — delete a group (group-admin or site-admin).
  Future<void> delete(String id) => _api.delete('/groups/$id');

  /// `PUT /groups/:id/join` — request to join a closed group.
  Future<Map<String, dynamic>> join(String id) async =>
      Map<String, dynamic>.from(await _api.put('/groups/$id/join') as Map);

  /// `DELETE /groups/:id/join` — leave a group.
  Future<void> leave(String id) => _api.delete('/groups/$id/join');

  /// `DELETE /groups/:id/request` — cancel a pending join request.
  Future<void> cancelJoinRequest(String id) => _api.delete('/groups/$id/request');

  /// `GET /groups/:id/members` — list members (active membership or site admin).
  Future<List<dynamic>> members(String id) async {
    final data = await _api.get('/groups/$id/members');
    return data is List ? data : const [];
  }

  /// `POST /groups/:id/members` — admin adds a member directly.
  Future<Map<String, dynamic>> addMember(
    String id, {
    required String userId,
    bool? isGroupAdmin,
  }) async {
    final data = await _api.post('/groups/$id/members', body: {
      'userId': userId,
      'isGroupAdmin': ?isGroupAdmin,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `PATCH /groups/:id/members/:userId` — promote/demote a member.
  Future<Map<String, dynamic>> setMemberAdmin(
    String id,
    String userId, {
    required bool isGroupAdmin,
  }) async =>
      Map<String, dynamic>.from(await _api.patch('/groups/$id/members/$userId',
          body: {'isGroupAdmin': isGroupAdmin}) as Map);

  /// `DELETE /groups/:id/members/:userId` — remove a member.
  Future<void> removeMember(String id, String userId) =>
      _api.delete('/groups/$id/members/$userId');

  /// `GET /groups/:id/requests` — pending join requests (group/site admin).
  Future<List<dynamic>> requests(String id) async {
    final data = await _api.get('/groups/$id/requests');
    return data is List ? data : const [];
  }

  /// `POST /groups/:id/requests/:userId/approve` — approve a join request.
  Future<void> approveRequest(String id, String userId) =>
      _api.post('/groups/$id/requests/$userId/approve');

  /// `POST /groups/:id/requests/:userId/reject` — reject a join request.
  Future<void> rejectRequest(String id, String userId) =>
      _api.post('/groups/$id/requests/$userId/reject');

  /// `GET /groups/:id/blocked` — list blocked users (group/site admin).
  Future<List<dynamic>> blocked(String id) async {
    final data = await _api.get('/groups/$id/blocked');
    return data is List ? data : const [];
  }

  /// `POST /groups/:id/members/:userId/block` — block a member.
  Future<void> blockMember(String id, String userId) =>
      _api.post('/groups/$id/members/$userId/block');

  /// `DELETE /groups/:id/blocked/:userId` — unblock a user.
  Future<void> unblock(String id, String userId) =>
      _api.delete('/groups/$id/blocked/$userId');

  /// `GET /groups/:id/shared` — files/media/links shared in chat, with counts.
  Future<Map<String, dynamic>> shared(String id) async =>
      Map<String, dynamic>.from(await _api.get('/groups/$id/shared') as Map);

  /// `GET /groups/:id/messages?limit=&before=` — chat history (active
  /// membership). `before` is a cursor.
  Future<List<dynamic>> messages(String id, {int? limit, String? before}) async {
    final data = await _api
        .get('/groups/$id/messages', query: {'limit': limit, 'before': before});
    return data is List ? data : const [];
  }

  /// `POST /groups/:id/messages` — send a chat message (broadcast over
  /// websocket). `text` required unless an attachment is present. Optional
  /// single `file` attachment (`chatUpload`), `mentions`, `replyToId`.
  Future<Map<String, dynamic>> sendMessage(
    String id, {
    String? text,
    List<String>? mentions,
    String? replyToId,
    ({Uint8List bytes, String filename, String? contentType})? file,
  }) async {
    final fields = <String, dynamic>{
      'text': ?text,
      'mentions': ?mentions,
      'replyToId': ?replyToId,
    };
    final files = file == null
        ? const <UploadFile>[]
        : [
            UploadFile(
                field: 'file',
                filename: file.filename,
                bytes: file.bytes,
                contentType: file.contentType)
          ];
    final data = await _api.multipart('POST', '/groups/$id/messages',
        fields: fields, files: files);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /groups/:id/messages/:messageId` — soft-delete a message.
  Future<void> deleteMessage(String id, String messageId) =>
      _api.delete('/groups/$id/messages/$messageId');

  /// `POST /groups/:id/messages/:messageId/react` — toggle an emoji reaction
  /// (≤8 chars; broadcast over websocket).
  Future<Map<String, dynamic>> reactToMessage(
    String id,
    String messageId,
    String emoji,
  ) async =>
      Map<String, dynamic>.from(await _api.post(
          '/groups/$id/messages/$messageId/react',
          body: {'emoji': emoji}) as Map);
}
