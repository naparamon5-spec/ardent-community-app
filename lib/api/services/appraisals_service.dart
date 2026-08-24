import 'dart:typed_data';

import '../api_client.dart';

/// Appraisals (employee/rater side). See docs §Appraisals. All routes require
/// `module:appraisal.view`; per-appraisal visibility is gated record-by-record.
/// Evidence is private — streamed via [attachment], never a public URL.
class AppraisalsService {
  AppraisalsService(this._api);
  final ApiClient _api;

  /// `GET /appraisals/mine` — own appraisals + appraisals where the caller is a
  /// rater. Final score shown only on the caller's own card, once released.
  Future<Map<String, dynamic>> mine() async =>
      Map<String, dynamic>.from(await _api.get('/appraisals/mine') as Map);

  /// `GET /appraisals/:id` — one appraisal, shaped for the viewer.
  Future<Map<String, dynamic>> get(String id) async =>
      Map<String, dynamic>.from(await _api.get('/appraisals/$id') as Map);

  /// `GET /appraisals/:id/form` — the template form + the viewer's saved answers.
  Future<Map<String, dynamic>> form(String id) async =>
      Map<String, dynamic>.from(await _api.get('/appraisals/$id/form') as Map);

  /// `PATCH /appraisals/:id/responses` — autosave answers (bulk upsert). Only
  /// items belonging to this form and this rater's `role` are accepted; the
  /// first save flips status to `in_progress`.
  Future<Map<String, dynamic>> saveResponses(
    String id, {
    required String role,
    required List<Map<String, dynamic>> responses,
  }) async {
    final data = await _api.patch('/appraisals/$id/responses',
        body: {'role': role, 'responses': responses});
    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /appraisals/:id/submit` — submit/lock this rater's responses.
  Future<Map<String, dynamic>> submit(
    String id, {
    required String role,
    String? overallComment,
  }) async {
    final data = await _api.post('/appraisals/$id/submit', body: {
      'role': role,
      'overallComment': ?overallComment,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /appraisals/:id/result` — the final score/result (403 until released).
  Future<Map<String, dynamic>> result(String id) async =>
      Map<String, dynamic>.from(await _api.get('/appraisals/$id/result') as Map);

  /// `POST /appraisals/:id/acknowledge` — acknowledge a released result.
  Future<void> acknowledge(String id, {String? comment}) => _api.post(
      '/appraisals/$id/acknowledge',
      body: {'comment': ?comment});

  /// `GET /appraisals/:id/attachments` — list evidence attachments.
  Future<List<dynamic>> attachments(String id) async {
    final data = await _api.get('/appraisals/$id/attachments');
    return data is List ? data : const [];
  }

  /// `POST /appraisals/:id/attachments` — attach supporting evidence
  /// (`appraisalUpload`). Only an active rater on this appraisal, or
  /// `appraisal.manage`, may attach.
  Future<Map<String, dynamic>> uploadAttachment(
    String id, {
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final data = await _api.multipart(
      'POST',
      '/appraisals/$id/attachments',
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

  /// `GET /appraisals/:id/attachments/:attachmentId` — stream one evidence file
  /// (authenticated; never a public URL).
  Future<({Uint8List bytes, String? contentType})> attachment(
          String id, String attachmentId) =>
      _api.getBytes('/appraisals/$id/attachments/$attachmentId');
}
