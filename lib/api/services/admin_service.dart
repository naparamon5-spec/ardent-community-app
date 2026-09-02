import '../api_client.dart';

/// Admin — user/module management. See docs §Admin. All routes require
/// `module:admin.users`.
class AdminService {
  AdminService(this._api);
  final ApiClient _api;

  /// `GET /admin/modules` — module registry + access roles + role defaults.
  Future<Map<String, dynamic>> modules() async =>
      Map<String, dynamic>.from(await _api.get('/admin/modules') as Map);

  /// `GET /admin/email-status` — `{ configured, reachable, message }` (never
  /// throws).
  Future<Map<String, dynamic>> emailStatus() async =>
      Map<String, dynamic>.from(await _api.get('/admin/email-status') as Map);

  /// `GET /admin/users?search=` — list/search users (admin view; includes
  /// email, employeeId, supervisor).
  Future<List<dynamic>> users({String? search}) async {
    final data = await _api.get('/admin/users', query: {'search': search});
    return data is List ? data : const [];
  }

  /// `POST /admin/users` — create a user and email an invite link. `name` +
  /// `email` (unique) required. The account can't log in until the invitee sets
  /// a password via the emailed link.
  Future<Map<String, dynamic>> createUser(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _api.post('/admin/users', body: body) as Map);

  /// `PATCH /admin/users/:id` — update a user's access/role/status. `modules`
  /// is an array of valid keys or `null` (reset to role defaults). Can't
  /// deactivate your own account or change your own `accessRole` away from
  /// `admin`.
  Future<Map<String, dynamic>> updateUser(
          String id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await _api.patch('/admin/users/$id', body: body) as Map);

  /// `POST /admin/users/:id/resend-invite` — re-send the invite/reset email
  /// (refused if the account is deactivated).
  Future<void> resendInvite(String id) =>
      _api.post('/admin/users/$id/resend-invite');

  // ---- System log (audit & errors) ------------------------------------------

  /// `GET /admin/audit` — administrative-action audit events, newest first.
  /// Optional filters `action`, `actorId`, `entityId`; `limit` default 100
  /// (max 300).
  Future<List<dynamic>> audit({
    String? action,
    String? actorId,
    String? entityId,
    int? limit,
  }) async {
    final data = await _api.get('/admin/audit', query: {
      'action': action,
      'actorId': actorId,
      'entityId': entityId,
      'limit': limit,
    });
    return data is List ? data : const [];
  }

  /// `GET /admin/errors` — server-error events (deduplicated by fingerprint)
  /// plus a `summary`. Returns the raw payload (`{ errors, summary }`).
  /// `includeResolved` default false; optional `source`; `limit` default 100
  /// (max 300).
  Future<Map<String, dynamic>> errors({
    bool? includeResolved,
    String? source,
    int? limit,
  }) async =>
      Map<String, dynamic>.from(await _api.get('/admin/errors', query: {
        'includeResolved': includeResolved,
        'source': source,
        'limit': limit,
      }) as Map);

  /// `POST /admin/errors/:id/resolve` — mark an error as handled.
  Future<void> resolveError(String id) =>
      _api.post('/admin/errors/$id/resolve');

  // ---- Background jobs ------------------------------------------------------

  /// `GET /admin/jobs` — status of every registered background job. Returns
  /// `{ jobs: [{name, enabled, everyMs, lastRunAt, lastStatus, ...}] }`.
  Future<Map<String, dynamic>> jobs() async =>
      Map<String, dynamic>.from(await _api.get('/admin/jobs') as Map);

  /// `POST /admin/jobs/:name/run` — run one job immediately, ignoring its
  /// schedule (404 for an unknown job). Returns the refreshed job-status list.
  Future<Map<String, dynamic>> runJob(String name) async =>
      Map<String, dynamic>.from(await _api.post('/admin/jobs/$name/run') as Map);
}
