import 'dart:typed_data';

import '../api_client.dart';

/// Ashtrid (AI Assistant). See docs §Ashtrid. All routes require auth;
/// system-query routes also require `module:ashtrid.use`; the employee picker
/// requires `module:admin.users`. Access is always scoped server-side.
class AshtridService {
  AshtridService(this._api);
  final ApiClient _api;

  /// `GET /ashtrid/systems` — connected/planned systems + the default key.
  Future<Map<String, dynamic>> systems() async =>
      Map<String, dynamic>.from(await _api.get('/ashtrid/systems') as Map);

  /// `POST /ashtrid/ask` — ask a natural-language question, routed to the chosen
  /// system's adapter (defaults to the configured default system).
  Future<Map<String, dynamic>> ask({
    required String question,
    String? system,
  }) async {
    final data = await _api.post('/ashtrid/ask', body: {
      'question': question,
      'system': ?system,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /ashtrid/documents/:documentId/files?system=` — files attached to a
  /// document, scoped to the caller's access.
  Future<List<dynamic>> documentFiles(String documentId, {String? system}) async {
    final data = await _api
        .get('/ashtrid/documents/$documentId/files', query: {'system': system});
    return data is List ? data : const [];
  }

  /// `GET /ashtrid/document/:fileId?system=` — stream a specific file inline.
  Future<({Uint8List bytes, String? contentType})> document(
    String fileId, {
    String? system,
  }) =>
      _api.getBytes('/ashtrid/document/$fileId', query: {'system': system});

  /// `GET /ashtrid/employees?q=` — search the e-Forward/HR employee directory
  /// (admin-only; up to 50 rows).
  Future<List<dynamic>> employees({String? q}) async {
    final data = await _api.get('/ashtrid/employees', query: {'q': q});
    return data is List ? data : const [];
  }
}
