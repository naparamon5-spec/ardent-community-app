import '../api_client.dart';
import '../auth_store.dart';

/// Auth — password login/registration, password management, and the
/// single-use reset/invite token flow. See docs §Auth.
///
/// On successful login/register/reset the returned `token` is stored in
/// [AuthStore] automatically so subsequent calls are authenticated.
class AuthService {
  AuthService(this._api, {AuthStore? authStore})
      : _auth = authStore ?? AuthStore.instance;

  final ApiClient _api;
  final AuthStore _auth;

  /// `POST /auth/login` — `{ email, password }` → `{ token, user }`.
  /// 401 on bad credentials, 403 if the account is deactivated.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post('/auth/login',
        body: {'email': email, 'password': password});
    return _storeToken(data);
  }

  /// `POST /auth/register` — self-registration (password ≥ 6 chars).
  /// Returns `{ token, user }` (201). 409 if the email already exists.
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? role,
    String? department,
  }) async {
    final data = await _api.post('/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      'role': ?role,
      'department': ?department,
    });
    return _storeToken(data);
  }

  /// `GET /auth/me` — the current user's profile. Requires auth.
  Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from(await _api.get('/auth/me') as Map);

  /// `POST /auth/change-password` — change own password (newPassword ≥ 6).
  /// Emails a "password changed" notice.
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) =>
      _api.post('/auth/change-password', body: {
        'currentPassword': ?currentPassword,
        'newPassword': newPassword,
      });

  /// `POST /auth/forgot-password` — always responds identically regardless of
  /// whether the account exists (anti-enumeration); emails a reset link if it
  /// does and is active.
  Future<void> forgotPassword(String email) =>
      _api.post('/auth/forgot-password', body: {'email': email});

  /// `GET /auth/reset-token?token=` — validate a reset/invite token before
  /// showing the reset form. Returns `{ valid, reason? }` or, when valid,
  /// `{ valid: true, purpose, name, email }`.
  Future<Map<String, dynamic>> validateResetToken(String token) async =>
      Map<String, dynamic>.from(
          await _api.get('/auth/reset-token', query: {'token': token}) as Map);

  /// `POST /auth/reset-password` — consume a single-use reset/invite token,
  /// set the new password (≥ 8 chars), and sign in. Returns `{ token, user }`.
  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String password,
  }) async {
    final data = await _api
        .post('/auth/reset-password', body: {'token': token, 'password': password});
    return _storeToken(data);
  }

  /// Clears the local token. (There is no server logout endpoint; the JWT is
  /// stateless and simply discarded.)
  Future<void> logout() => _auth.clear();

  Future<Map<String, dynamic>> _storeToken(dynamic data) async {
    final map = Map<String, dynamic>.from(data as Map);
    final token = map['token'];
    if (token is String && token.isNotEmpty) {
      await _auth.setToken(token);
    }
    return map;
  }
}
