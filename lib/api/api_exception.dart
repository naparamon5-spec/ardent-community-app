/// Thrown for any non-2xx response from the backend, carrying the parsed
/// `error` envelope described in `API_DOCUMENTATION.md`:
///
/// ```json
/// { "success": false, "error": { "message": "...", "details": {...} } }
/// ```
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.details,
    this.stack,
  });

  /// HTTP status code (0 for transport/decoding failures with no response).
  final int statusCode;

  /// Human-readable message extracted from `error.message`, or a fallback.
  final String message;

  /// Optional `error.details` map (present on some validation errors).
  final Map<String, dynamic>? details;

  /// Server stack trace — only sent by the backend in development on 5xx.
  final String? stack;

  /// Missing, invalid, or expired token.
  bool get isUnauthorized => statusCode == 401;

  /// Authenticated but not permitted (missing module, not the owner, recused).
  bool get isForbidden => statusCode == 403;

  /// Resource not found.
  bool get isNotFound => statusCode == 404;

  /// Conflict — e.g. duplicate email / unique-constraint violation.
  bool get isConflict => statusCode == 409;

  /// Bad request — missing/invalid fields.
  bool get isBadRequest => statusCode == 400;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
