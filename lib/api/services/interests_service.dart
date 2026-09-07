import '../api_client.dart';
import '../../utils/paged.dart';

/// Interests — the shared interest / hobby / like tag pool shown on profiles and
/// the people directory. See docs §Interests (and §Users / People for a user's
/// own selected tags).
///
/// The pool is a single shared catalog: a tag has no `kind` of its own —
/// `{ id, name, slug, isActive, usageCount }`. The `kind` (interest / hobby /
/// like) is a *per-user* attribute of `user.interests[]`, set via
/// `PUT /users/me/interests` (see [UsersService.setInterests]). Anyone may
/// browse/search the pool; reshaping it (rename / hide / delete) needs
/// `module:admin.users`. Tags are *created implicitly* when a user types a new
/// one on their profile — there is no create endpoint here.
class InterestsService {
  InterestsService(this._api);
  final ApiClient _api;

  /// `GET /interests?q=&limit=` — type-ahead search for the profile picker.
  /// Active tags only, commonest first (matches name and slug). Each row is
  /// `{ id, name, slug, isActive, usageCount }`.
  Future<List<dynamic>> search({String? q, int limit = 12}) async {
    final data = await _api.get('/interests', query: {
      'q': ?q,
      'limit': limit,
    });
    return data is List ? data : const [];
  }

  /// `GET /interests/:slug/people` — colleagues who listed this tag (the payoff
  /// for tapping a chip on a profile). Returns a `user[]`.
  Future<List<dynamic>> people(String slug) async {
    final data = await _api.get('/interests/$slug/people');
    return data is List ? data : const [];
  }

  /// `GET /interests/admin/all?q=&page=&limit=` — one paginated page of the
  /// whole pool (active + inactive), each with a `usageCount`. Requires
  /// `module:admin.users`. Returns the shared pagination envelope.
  Future<Paged> adminAll({String? q, int page = 1, int? limit}) async {
    final data = await _api.get('/interests/admin/all', query: {
      'q': ?q,
      'page': page,
      'limit': ?limit,
    });
    return Paged.fromJson(data as Map);
  }

  /// `PATCH /interests/:id` — deactivate/reactivate (`isActive`) **or** rename
  /// (`name`). Renaming to a name that already exists on another tag *merges*
  /// into it (everyone who had the old tag now has the existing one); the
  /// response then carries `merged`/`moved`. 400 on an unusable new name.
  /// Requires `module:admin.users`.
  Future<Map<String, dynamic>> update(
    String id, {
    String? name,
    bool? isActive,
  }) async {
    final data = await _api.patch('/interests/$id', body: {
      'name': ?name,
      'isActive': ?isActive,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /interests/:id` — remove a tag entirely; cascades, stripping it
  /// from every profile that had it. Requires `module:admin.users`.
  Future<void> delete(String id) => _api.delete('/interests/$id');
}
