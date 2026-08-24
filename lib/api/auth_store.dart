import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the current JWT for the session and persists it **securely** across
/// launches.
///
/// The token is a credential, so it is kept in OS-backed secure storage
/// (iOS Keychain / Android Keystore via EncryptedSharedPreferences) rather than
/// plaintext `SharedPreferences`. It is minted by `/auth/login`,
/// `/auth/register`, `/auth/reset-password` or the SSO callback
/// (`?accessToken=`). It carries only the user id + slug; the server re-reads the
/// account on every request, so a deactivated account's token stops working
/// immediately (surfaced to us as a 401).
///
/// A single shared instance ([AuthStore.instance]) is used by [ApiClient]. It is
/// a [ChangeNotifier] so widgets can rebuild when the user signs in or out.
class AuthStore extends ChangeNotifier {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const String _tokenKey = 'ardent.auth.token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String? _token;

  /// The current bearer token, or `null` when signed out.
  String? get token => _token;

  /// Whether a token is currently held (does not prove it is still valid).
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  bool _loaded = false;

  /// Whether [load] has completed at least once.
  bool get isLoaded => _loaded;

  /// Reads any persisted token into memory. Call once during app startup
  /// (idempotent). Safe to await before deciding which screen to show.
  Future<void> load() async {
    if (_loaded) return;
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {
      // Keystore/Keychain read can fail (e.g. after a device restore); treat as
      // signed-out rather than crashing at launch.
      _token = null;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Persists [token] and notifies listeners. Pass the value returned in the
  /// login/register/reset `data.token` field.
  ///
  /// The in-memory token is set first, so a persistence failure (e.g. the
  /// secure-storage plugin not being registered before a full rebuild) does not
  /// block a successful sign-in — the session still works for this run.
  Future<void> setToken(String token) async {
    _token = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (e) {
      debugPrint('[AuthStore] secure-storage write failed; token kept in memory '
          'only (persist will work after a full rebuild): $e');
    }
    notifyListeners();
  }

  /// Clears the token (sign-out) and notifies listeners.
  Future<void> clear() async {
    _token = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (e) {
      debugPrint('[AuthStore] secure-storage delete failed: $e');
    }
    notifyListeners();
  }
}
