import 'dart:typed_data';

import '../api_client.dart';
import '../api_exception.dart';

/// Stories (My-Day). See docs §Stories. Reads optional-auth; posting requires
/// `module:stories.post`. Media uses the `storyUpload` preset (1–10 image/video
/// files).
class StoriesService {
  StoriesService(this._api);
  final ApiClient _api;

  /// `GET /stories?limit=` — recent stories, newest first (default 7, ≤ 30).
  Future<List<dynamic>> list({int? limit}) async {
    final data = await _api.get('/stories', query: {'limit': limit});
    return data is List ? data : const [];
  }

  /// `POST /stories` — create a story. [media] required (1–10). Optional
  /// `caption`; `newMediaCaptions` (JSON array parallel to media) via [fields].
  Future<Map<String, dynamic>> create({
    required List<UploadFile> media,
    Map<String, dynamic> fields = const {},
  }) async {
    final data =
        await _api.multipart('POST', '/stories', fields: fields, files: media);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `PATCH /stories/:id` — edit (owner or `admin.users`). Add [media]; remove
  /// via `removeMediaIds`; caption edits via `mediaCaptions`/`newMediaCaptions`
  /// in [fields]. Must retain ≥1 media item after edit.
  Future<Map<String, dynamic>> update(
    String id, {
    List<UploadFile> media = const [],
    Map<String, dynamic> fields = const {},
  }) async {
    final data = await _api.multipart('PATCH', '/stories/$id',
        fields: fields, files: media);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /stories/:id` — delete a story and all its media (owner or
  /// `admin.users`).
  Future<void> delete(String id) => _api.delete('/stories/$id');

  /// `POST /stories/:id/media/:mediaId/view` — record that the caller saw this
  /// item. Idempotent; a no-op on your own story. Best-effort.
  Future<void> recordMediaView(String storyId, String mediaId) async {
    if (mediaId.isEmpty) return;
    try {
      await _api.post('/stories/$storyId/media/$mediaId/view');
    } on ApiException {
      // Ignore — viewing shouldn't surface an error to the user.
    }
  }

  /// `GET /stories/:id/media/:mediaId/viewers` — who watched this item and what
  /// they reacted with. **Author-only** (403 otherwise). Returns the raw list.
  Future<List<dynamic>> mediaViewers(String storyId, String mediaId) async {
    final data = await _api.get('/stories/$storyId/media/$mediaId/viewers');
    if (data is List) return data;
    if (data is Map) {
      final list = data['viewers'] ?? data['views'] ?? data['users'];
      return list is List ? list : const [];
    }
    return const [];
  }

  /// `POST /stories/:id/media/:mediaId/react` — set/toggle your reaction to one
  /// item (`emoji` ∈ 👍 ❤️ 😆 😮 😢 🙏); sending the same emoji clears it.
  Future<Map<String, dynamic>> reactToMedia(
          String storyId, String mediaId, String emoji) async =>
      Map<String, dynamic>.from(await _api.post(
          '/stories/$storyId/media/$mediaId/react',
          body: {'emoji': emoji}) as Map);
}

/// Convenience builder for a story media file.
UploadFile storyMedia({
  required Uint8List bytes,
  required String filename,
  String? contentType,
}) =>
    UploadFile(
        field: 'media',
        filename: filename,
        bytes: bytes,
        contentType: contentType);
