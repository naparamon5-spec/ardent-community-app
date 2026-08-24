import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Static configuration for the backend API.
///
/// The base URL points at the Ardent Community backend documented in
/// `API_DOCUMENTATION.md`. All service calls are made relative to
/// [ApiConfig.baseUrl] (which always includes the `/api` prefix — it is appended
/// automatically if your configured value omits it).
///
/// ## Where the value comes from (first match wins)
/// 1. A `--dart-define=API_BASE_URL=...` build flag, if provided.
/// 2. `API_BASE_URL` in the project's `.env` file (loaded at startup).
/// 3. The `http://localhost:4000/api` fallback.
///
/// ## Choosing a base URL on a device
/// `localhost` only resolves to the machine running the app, so it will not
/// reach a backend on your dev machine from a phone or (Android) emulator:
///
/// * Android emulator  → `http://10.0.2.2:4000`
/// * iOS simulator     → `http://localhost:4000`
/// * Physical device   → `http://<your-computer-LAN-ip>:4000`
/// * Production        → `https://community-api.ardentnetworks.com.ph`
class ApiConfig {
  ApiConfig._();

  /// Root of the REST API, including the `/api` segment. No trailing slash.
  static String get baseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    final raw = fromDefine.isNotEmpty
        ? fromDefine
        : (_fromEnvFile() ?? 'http://localhost:4000/api');
    return _normalize(raw);
  }

  /// Reads `API_BASE_URL` from the loaded `.env`, tolerating the file being
  /// absent or not yet loaded.
  static String? _fromEnvFile() {
    try {
      if (!dotenv.isInitialized) return null;
      final v = dotenv.maybeGet('API_BASE_URL');
      return (v == null || v.trim().isEmpty) ? null : v.trim();
    } catch (_) {
      return null;
    }
  }

  /// Strips a trailing slash and appends `/api` when the value is a bare origin
  /// (e.g. `https://community-api.ardentnetworks.com.ph` → `.../api`), so the
  /// route paths below resolve correctly either way.
  static String _normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    final uri = Uri.tryParse(u);
    if (uri != null && (uri.path.isEmpty)) u = '$u/api';
    return u;
  }

  /// Origin (scheme + host + port) the REST API lives under, derived from
  /// [baseUrl] by stripping the trailing `/api`. Used for the Socket.IO
  /// connection and for absolutising any server-relative media URLs.
  static String get origin {
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  /// Default request timeout. The backend streams some media/AI responses, so
  /// callers that expect long responses can pass their own timeout.
  static const Duration timeout = Duration(seconds: 30);
}
