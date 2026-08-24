import '../api_client.dart';
import '../api_config.dart';
import '../auth_store.dart';

/// SSO — enterprise single sign-on via Authentik (OIDC + PKCE). Optional;
/// password login always works independently. See docs §SSO.
class SsoService {
  SsoService(this._api, {AuthStore? authStore})
      : _auth = authStore ?? AuthStore.instance;

  final ApiClient _api;
  final AuthStore _auth;

  /// `GET /auth/sso/status` — `{ enabled, reason, issuer, redirectUri }`. Lets
  /// the UI show/hide the SSO button.
  Future<Map<String, dynamic>> status() async =>
      Map<String, dynamic>.from(await _api.get('/auth/sso/status') as Map);

  /// The URL to open in a browser/WebView to begin the SSO flow. Navigation
  /// only — this is not an XHR endpoint (it 302-redirects to Authentik). On
  /// success the browser is redirected to
  /// `{FRONTEND_APP_URL}/sso/callback?accessToken=<token>`.
  String get loginUrl => '${ApiConfig.baseUrl}/auth/sso/login';

  /// Completes SSO on the app side: store the `accessToken` captured from the
  /// callback redirect's query string.
  Future<void> completeWithAccessToken(String accessToken) =>
      _auth.setToken(accessToken);
}
