import 'dart:typed_data';

import '../api_client.dart';

/// Marketplace (Listings). See docs §Marketplace. Reads are optional-auth;
/// creating requires `module:marketplace.sell`. Media uses the `listingUpload`
/// preset (up to 10 image/video files).
class ListingsService {
  ListingsService(this._api);
  final ApiClient _api;

  /// `GET /listings?category=&search=` — browse listings.
  Future<List<dynamic>> list({String? category, String? search}) async {
    final data = await _api
        .get('/listings', query: {'category': category, 'search': search});
    return data is List ? data : const [];
  }

  /// `GET /listings/:id` — one listing.
  Future<Map<String, dynamic>> get(String id) async =>
      Map<String, dynamic>.from(await _api.get('/listings/$id') as Map);

  /// `POST /listings` — create a listing (201). `title` required; price via
  /// `price` (whole units) or `priceCents`. [media] up to 10 image/video files.
  Future<Map<String, dynamic>> create({
    required Map<String, dynamic> fields,
    List<UploadFile> media = const [],
  }) async {
    final data = await _api.multipart('POST', '/listings',
        fields: fields, files: media);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `PATCH /listings/:id` — edit (owner only). Add [media]; remove existing via
  /// `removeMediaIds` in [fields].
  Future<Map<String, dynamic>> update(
    String id, {
    Map<String, dynamic> fields = const {},
    List<UploadFile> media = const [],
  }) async {
    final data = await _api.multipart('PATCH', '/listings/$id',
        fields: fields, files: media);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /listings/:id` — delete (owner only); cleans up stored media.
  Future<void> delete(String id) => _api.delete('/listings/$id');

  /// `PATCH /listings/:id/sold` — mark sold/unsold (owner only; defaults true).
  Future<Map<String, dynamic>> setSold(String id, {bool sold = true}) async =>
      Map<String, dynamic>.from(
          await _api.patch('/listings/$id/sold', body: {'sold': sold}) as Map);

  /// `PUT /listings/:id/like` — like.
  Future<void> like(String id) => _api.put('/listings/$id/like');

  /// `DELETE /listings/:id/like` — unlike.
  Future<void> unlike(String id) => _api.delete('/listings/$id/like');

  /// `PUT /listings/:id/save` — save.
  Future<void> save(String id) => _api.put('/listings/$id/save');

  /// `DELETE /listings/:id/save` — unsave.
  Future<void> unsave(String id) => _api.delete('/listings/$id/save');
}

/// Convenience builder for a listing media file.
UploadFile listingMedia({
  required Uint8List bytes,
  required String filename,
  String? contentType,
}) =>
    UploadFile(
        field: 'media',
        filename: filename,
        bytes: bytes,
        contentType: contentType);
