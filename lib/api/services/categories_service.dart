import '../api_client.dart';

/// Categories — marketplace category management. See docs §Categories.
/// Reads optional-auth; writes require `module:admin.users`.
class CategoriesService {
  CategoriesService(this._api);
  final ApiClient _api;

  /// `GET /categories?all=1` — active categories by default; `all: true`
  /// includes inactive (only honoured for `admin.users` holders).
  Future<List<dynamic>> list({bool all = false}) async {
    final data = await _api.get('/categories', query: {if (all) 'all': 1});
    return data is List ? data : const [];
  }

  /// `POST /categories` — create a category (`module:admin.users`; rejects a
  /// duplicate name).
  Future<Map<String, dynamic>> create(String name) async =>
      Map<String, dynamic>.from(
          await _api.post('/categories', body: {'name': name}) as Map);

  /// `PATCH /categories/:id` — update name/active/position (`module:admin.users`).
  Future<Map<String, dynamic>> update(
    String id, {
    String? name,
    bool? isActive,
    int? position,
  }) async {
    final data = await _api.patch('/categories/$id', body: {
      'name': ?name,
      'isActive': ?isActive,
      'position': ?position,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /categories/:id` — delete a category (`module:admin.users`).
  Future<void> delete(String id) => _api.delete('/categories/$id');
}
