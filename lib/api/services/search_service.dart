import '../api_client.dart';

/// Search — cross-entity search across people, posts, and listings.
/// See docs §Search. Optional-auth (results carry per-viewer flags when a token
/// is sent). An empty `q` returns empty result sets rather than erroring.
class SearchService {
  SearchService(this._api);
  final ApiClient _api;

  /// `GET /search?q=`.
  Future<Map<String, dynamic>> query(String q) async =>
      Map<String, dynamic>.from(await _api.get('/search', query: {'q': q}) as Map);
}
