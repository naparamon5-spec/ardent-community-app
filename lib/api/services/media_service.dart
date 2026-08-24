import '../api_config.dart';

/// Media — public file streaming. See docs §Media.
///
/// All media URLs the API returns already point back at the API
/// (`/api/media/<folder>/<key>`), never at the storage backend. This helper
/// only resolves such URLs to absolute ones for use in `Image.network` etc.
///
/// Note: appraisal/ethics evidence is NOT served here — it is streamed only via
/// its own authenticated `.../attachments/:id` route (see EthicsService /
/// AppraisalsService), because it must never be a public URL.
class MediaService {
  MediaService._();

  /// Absolutises a media URL the API returned.
  ///
  /// * Already absolute (`http(s)://…`)  → returned unchanged.
  /// * Server-relative (`/api/media/…` or `/media/…`) → prefixed with the API
  ///   origin.
  static String resolve(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final path = url.startsWith('/') ? url : '/$url';
    return '${ApiConfig.origin}$path';
  }

  /// Builds a public media URL from a `folder` + object `key`.
  static String url(String folder, String key) =>
      '${ApiConfig.baseUrl}/media/$folder/$key';
}
