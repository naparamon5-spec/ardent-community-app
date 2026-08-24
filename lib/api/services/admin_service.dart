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
}
