import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import 'api_config.dart';
import 'api_exception.dart';
import 'auth_store.dart';

/// A single field + file pair for a `multipart/form-data` upload.
///
/// Supply the bytes directly ([bytes]) — the app reads uploads in-memory the
/// same way the backend does (Multer → MinIO), so no local file path is needed.
class UploadFile {
  UploadFile({
    required this.field,
    required this.filename,
    required this.bytes,
    this.contentType,
  });

  /// Form field name, per the docs (e.g. `avatar`, `cover`, `photo`, `file`,
  /// `media`, `cover`).
  final String field;

  /// File name reported to the server (used for extension/type sniffing).
  final String filename;

  /// Raw file contents.
  final Uint8List bytes;

  /// Optional explicit MIME type (e.g. `image/png`). Inferred by the server if
  /// omitted.
  final String? contentType;
}

/// Low-level HTTP wrapper around the Ardent Community backend.
///
/// Responsibilities:
/// * prefixes every path with [ApiConfig.baseUrl];
/// * attaches `Authorization: Bearer <token>` when a token is held;
/// * unwraps the `{ success, data }` / `{ success, error }` envelope so callers
///   receive the bare `data` payload;
/// * turns any non-2xx (or a `success: false`) response into an [ApiException].
///
/// One shared instance is exposed as [ApiClient.instance]; the typed service
/// classes in `services/` are thin wrappers over it.
class ApiClient {
  ApiClient({http.Client? httpClient, AuthStore? authStore})
      : _http = httpClient ?? http.Client(),
        _auth = authStore ?? AuthStore.instance;

  static final ApiClient instance = ApiClient();

  final http.Client _http;
  final AuthStore _auth;

  /// Invoked whenever the server rejects a request with 401. The default clears
  /// the stored token so the app can route back to the login screen.
  Future<void> Function()? onUnauthorized = () => AuthStore.instance.clear();

  // ---- JSON verbs -----------------------------------------------------------

  /// `GET {path}` with optional [query]. Returns the unwrapped `data`.
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _sendJson('GET', path, query: query);

  /// `POST {path}` with a JSON [body].
  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _sendJson('POST', path, body: body, query: query);

  /// `PATCH {path}` with a JSON [body].
  Future<dynamic> patch(String path, {Object? body, Map<String, dynamic>? query}) =>
      _sendJson('PATCH', path, body: body, query: query);

  /// `PUT {path}` with an optional JSON [body].
  Future<dynamic> put(String path, {Object? body, Map<String, dynamic>? query}) =>
      _sendJson('PUT', path, body: body, query: query);

  /// `DELETE {path}` with an optional JSON [body].
  Future<dynamic> delete(String path, {Object? body, Map<String, dynamic>? query}) =>
      _sendJson('DELETE', path, body: body, query: query);

  // ---- Multipart ------------------------------------------------------------

  /// Sends a `multipart/form-data` request (uploads).
  ///
  /// [fields] are string form values; non-string values are JSON-encoded, which
  /// matches the backend's habit of accepting array/object fields as JSON
  /// strings when sent via multipart (e.g. `mentions`, `removeMediaIds`).
  /// [files] may repeat the same [UploadFile.field] (e.g. `media` up to 10).
  Future<dynamic> multipart(
    String method,
    String path, {
    Map<String, dynamic>? fields,
    List<UploadFile> files = const [],
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path, query);
    final request = http.MultipartRequest(method, uri);
    request.headers.addAll(_headers(json: false));

    fields?.forEach((key, value) {
      if (value == null) return;
      request.fields[key] = value is String ? value : jsonEncode(value);
    });

    for (final f in files) {
      request.files.add(http.MultipartFile.fromBytes(
        f.field,
        f.bytes,
        filename: f.filename,
        contentType:
            f.contentType == null ? null : MediaType.parse(f.contentType!),
      ));
    }

    _log('→ $method $uri (multipart, ${files.length} file(s))');
    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(ApiConfig.timeout);
      response = await http.Response.fromStream(streamed);
    } catch (e, st) {
      throw _transportError(method, uri, e, st);
    }
    _log('← ${response.statusCode} $method $uri');
    return _handle(response);
  }

  // ---- Raw binary (authenticated downloads) ---------------------------------

  /// Fetches raw bytes for an authenticated stream route (e.g. ethics /
  /// appraisal evidence at `.../attachments/:id`, which is never a public URL).
  ///
  /// Returns the body bytes together with the `Content-Type` header so callers
  /// can render or save the file. Throws [ApiException] on a non-2xx status.
  Future<({Uint8List bytes, String? contentType})> getBytes(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path, query);
    final http.Response response;
    try {
      response =
          await _http.get(uri, headers: _headers(json: false)).timeout(ApiConfig.timeout);
    } catch (e, st) {
      throw _transportError('GET', uri, e, st);
    }
    if (response.statusCode == 401) await onUnauthorized?.call();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFromResponse(response);
    }
    return (
      bytes: response.bodyBytes,
      contentType: response.headers['content-type'],
    );
  }

  // ---- Internals ------------------------------------------------------------

  Future<dynamic> _sendJson(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(path, query);
    _log('→ $method $uri');
    final request = http.Request(method, uri);
    request.headers.addAll(_headers(json: true));
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(ApiConfig.timeout);
      response = await http.Response.fromStream(streamed);
    } catch (e, st) {
      throw _transportError(method, uri, e, st);
    }
    _log('← ${response.statusCode} $method $uri');
    return _handle(response);
  }

  /// Wraps a transport-layer failure (no HTTP response: DNS, TLS, timeout,
  /// refused connection, CORS on web) in an [ApiException] with `statusCode: 0`,
  /// and logs the full detail to the console for diagnosis.
  ApiException _transportError(String method, Uri uri, Object e, StackTrace st) {
    final detail = e is TimeoutException
        ? 'request timed out after ${ApiConfig.timeout.inSeconds}s'
        : e.toString();
    debugPrint('[ApiClient] ✗ TRANSPORT ERROR on $method $uri');
    debugPrint('[ApiClient]   → $detail');
    debugPrint('[ApiClient]   → Check: is API_BASE_URL correct and reachable '
        'from this device? (resolved base = ${ApiConfig.baseUrl})');
    if (kDebugMode) debugPrintStack(stackTrace: st, maxFrames: 6);
    return ApiException(statusCode: 0, message: 'Network error: $detail');
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[ApiClient] $message');
  }

  Uri _uri(String path, Map<String, dynamic>? query) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('${ApiConfig.baseUrl}$normalized');
    if (query == null || query.isEmpty) return base;
    // Drop null values; stringify everything else (query params are strings).
    final params = <String, String>{};
    query.forEach((k, v) {
      if (v != null) params[k] = '$v';
    });
    return base.replace(queryParameters: {...base.queryParameters, ...params});
  }

  Map<String, String> _headers({required bool json}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) headers['Content-Type'] = 'application/json';
    final token = _auth.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> _handle(http.Response response) async {
    if (response.statusCode == 401) await onUnauthorized?.call();

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        // Non-JSON body (unexpected). Fall through to raw handling below.
      }
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok) {
      if (decoded is Map && decoded['success'] == false) {
        throw _errorFromEnvelope(response.statusCode, decoded);
      }
      // Envelope: return the `data` payload; tolerate a bare body too.
      if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
      return decoded;
    }

    if (decoded is Map) throw _errorFromEnvelope(response.statusCode, decoded);
    throw _errorFromResponse(response);
  }

  ApiException _errorFromEnvelope(int status, Map decoded) {
    final error = decoded['error'];
    if (error is Map) {
      return ApiException(
        statusCode: status,
        message: (error['message'] ?? 'Request failed').toString(),
        details: error['details'] is Map
            ? Map<String, dynamic>.from(error['details'] as Map)
            : null,
        stack: error['stack']?.toString(),
      );
    }
    return ApiException(
      statusCode: status,
      message: (decoded['message'] ?? 'Request failed').toString(),
    );
  }

  ApiException _errorFromResponse(http.Response response) => ApiException(
        statusCode: response.statusCode,
        message: response.reasonPhrase?.isNotEmpty == true
            ? response.reasonPhrase!
            : 'HTTP ${response.statusCode}',
      );

  /// Releases the underlying HTTP client. Rarely needed (the shared instance
  /// lives for the app's lifetime).
  void close() => _http.close();
}
