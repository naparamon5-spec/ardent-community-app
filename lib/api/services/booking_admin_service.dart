import 'dart:typed_data';

import '../api_client.dart';

/// Booking Admin — fleet/room management. See docs §Booking Admin.
/// All routes require `module:bookings.manage`.
class BookingAdminService {
  BookingAdminService(this._api);
  final ApiClient _api;

  /// `GET /booking-admin/resources?type=` — all resources, including inactive.
  Future<List<dynamic>> resources({String? type}) async {
    final data =
        await _api.get('/booking-admin/resources', query: {'type': type});
    return data is List ? data : const [];
  }

  /// `POST /booking-admin/resources` — create a bookable resource. `name`
  /// required; `type` = `van` | `room` (default `van`). Optional `photo` image.
  Future<Map<String, dynamic>> createResource({
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
    final data = await _api.multipart('POST', '/booking-admin/resources',
        fields: fields, files: files);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `PATCH /booking-admin/resources/:id` — update a resource (same fields as
  /// create + `isActive`). Replacing `photo` deletes the old file.
  Future<Map<String, dynamic>> updateResource(
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
    final data = await _api.multipart('PATCH', '/booking-admin/resources/$id',
        fields: fields, files: files);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /booking-admin/resources/:id/impact` — preview how many/which future
  /// bookings a deactivation would affect.
  Future<Map<String, dynamic>> resourceImpact(String id) async =>
      Map<String, dynamic>.from(
          await _api.get('/booking-admin/resources/$id/impact') as Map);

  /// `POST /booking-admin/resources/:id/deactivate` — take out of service
  /// (existing bookings kept; occupants notified).
  Future<void> deactivateResource(String id) =>
      _api.post('/booking-admin/resources/$id/deactivate');

  /// `DELETE /booking-admin/resources/:id` — permanently delete (409 if it has
  /// booking history — deactivate instead).
  Future<void> deleteResource(String id) =>
      _api.delete('/booking-admin/resources/$id');

  /// `GET /booking-admin/bookings` — full booking log with filters
  /// (`type`, `resourceId`, `status`, `from`, `to`).
  Future<List<dynamic>> bookings({
    String? type,
    String? resourceId,
    String? status,
    String? from,
    String? to,
  }) async {
    final data = await _api.get('/booking-admin/bookings', query: {
      'type': type,
      'resourceId': resourceId,
      'status': status,
      'from': from,
      'to': to,
    });
    return data is List ? data : const [];
  }

  /// `GET /booking-admin/stats` — utilization (count + hours) per resource,
  /// last 30 days.
  Future<dynamic> stats() => _api.get('/booking-admin/stats');

  /// `POST /booking-admin/bookings/:id/cancel` — admin-cancel any booking.
  Future<Map<String, dynamic>> cancelBooking(String id, {String? reason}) async =>
      Map<String, dynamic>.from(await _api.post(
          '/booking-admin/bookings/$id/cancel',
          body: {'reason': ?reason}) as Map);
}
