import 'dart:typed_data';

import '../api_client.dart';

/// Ethics (reporter side). See docs §Ethics. All routes require
/// `module:ethics.report`; per-case access is enforced record-by-record.
/// Evidence is private — never a public URL — and streamed via [attachment].
class EthicsService {
  EthicsService(this._api);
  final ApiClient _api;

  /// `GET /ethics/categories` — complaint categories.
  Future<List<dynamic>> categories() async {
    final data = await _api.get('/ethics/categories');
    return data is List ? data : const [];
  }

  /// `GET /ethics/mine` — the caller's own filed complaints.
  Future<List<dynamic>> mine() async {
    final data = await _api.get('/ethics/mine');
    return data is List ? data : const [];
  }

  /// `POST /ethics/complaints` — file a new complaint. `title` + `description`
  /// required. Optional `isAnonymous`, `subjectUserId` (not self),
  /// `subjectFreeText`, `category` (default `other`), `incidentDate`,
  /// `location`.
  Future<Map<String, dynamic>> fileComplaint(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await _api.post('/ethics/complaints', body: body) as Map);

  /// `GET /ethics/complaints/:id` — view one case, shaped for the viewer.
  Future<Map<String, dynamic>> complaint(String id) async =>
      Map<String, dynamic>.from(await _api.get('/ethics/complaints/$id') as Map);

  /// `POST /ethics/complaints/:id/messages` — post a message on the thread.
  Future<Map<String, dynamic>> postMessage(String id, String body) async =>
      Map<String, dynamic>.from(await _api
          .post('/ethics/complaints/$id/messages', body: {'body': body}) as Map);

  /// `POST /ethics/complaints/:id/withdraw` — withdraw the complaint.
  Future<void> withdraw(String id, {String? reason}) => _api.post(
      '/ethics/complaints/$id/withdraw',
      body: {'reason': ?reason});

  /// `POST /ethics/complaints/:id/read` — mark the case thread read.
  Future<void> markRead(String id) => _api.post('/ethics/complaints/$id/read');

  /// `GET /ethics/complaints/:id/attachments` — list evidence attachments.
  Future<List<dynamic>> attachments(String id) async {
    final data = await _api.get('/ethics/complaints/$id/attachments');
    return data is List ? data : const [];
  }

  /// `POST /ethics/complaints/:id/attachments` — upload evidence
  /// (`ethicsUpload`). Optional `fileName` rename override.
  Future<Map<String, dynamic>> uploadAttachment(
    String id, {
    required Uint8List bytes,
    required String filename,
    String? fileName,
    String? contentType,
  }) async {
    final data = await _api.multipart(
      'POST',
      '/ethics/complaints/$id/attachments',
      fields: {'fileName': ?fileName},
      files: [
        UploadFile(
            field: 'file',
            filename: filename,
            bytes: bytes,
            contentType: contentType),
      ],
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /ethics/complaints/:id/attachments/:attachmentId` — stream one
  /// evidence file (authenticated; never a public URL). Returns raw bytes +
  /// content type.
  Future<({Uint8List bytes, String? contentType})> attachment(
          String id, String attachmentId) =>
      _api.getBytes('/ethics/complaints/$id/attachments/$attachmentId');
}
