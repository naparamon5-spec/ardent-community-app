import 'dart:typed_data';

import '../api_client.dart';

/// Events. See docs §Events. Reads optional-auth (viewer RSVP attached);
/// creating requires `module:events.create`. `cover` uses `imageUpload`.
class EventsService {
  EventsService(this._api);
  final ApiClient _api;

  /// `GET /events` — list all events.
  Future<List<dynamic>> list() async {
    final data = await _api.get('/events');
    return data is List ? data : const [];
  }

  /// `GET /events/:id` — one event (404 if not found).
  Future<Map<String, dynamic>> get(String id) async =>
      Map<String, dynamic>.from(await _api.get('/events/$id') as Map);

  /// `POST /events` — create an event. `title` and a start date
  /// (`startsAt`/`startAt`/`date`) required. `featured` is forced false unless
  /// caller has `admin.users`. Optional `cover` image.
  Future<Map<String, dynamic>> create({
    required Map<String, dynamic> fields,
    ({Uint8List bytes, String filename, String? contentType})? cover,
  }) async {
    final files = cover == null
        ? const <UploadFile>[]
        : [
            UploadFile(
                field: 'cover',
                filename: cover.filename,
                bytes: cover.bytes,
                contentType: cover.contentType)
          ];
    final data =
        await _api.multipart('POST', '/events', fields: fields, files: files);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `PATCH /events/:id` — update (creator or `admin.users`).
  Future<Map<String, dynamic>> update(
    String id, {
    Map<String, dynamic> fields = const {},
    ({Uint8List bytes, String filename, String? contentType})? cover,
  }) async {
    final files = cover == null
        ? const <UploadFile>[]
        : [
            UploadFile(
                field: 'cover',
                filename: cover.filename,
                bytes: cover.bytes,
                contentType: cover.contentType)
          ];
    final data = await _api.multipart('PATCH', '/events/$id',
        fields: fields, files: files);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /events/:id` — delete (creator or `admin.users`).
  Future<void> delete(String id) => _api.delete('/events/$id');

  /// `GET /events/:id/attendees` — "going" and "interested" users.
  Future<Map<String, dynamic>> attendees(String id) async =>
      Map<String, dynamic>.from(await _api.get('/events/$id/attendees') as Map);

  /// `PUT /events/:id/rsvp` — set/replace RSVP (`going` | `interested`,
  /// defaults `going`).
  Future<Map<String, dynamic>> rsvp(String id, {String status = 'going'}) async =>
      Map<String, dynamic>.from(
          await _api.put('/events/$id/rsvp', body: {'status': status}) as Map);

  /// `DELETE /events/:id/rsvp` — clear your RSVP.
  Future<void> clearRsvp(String id) => _api.delete('/events/$id/rsvp');
}
