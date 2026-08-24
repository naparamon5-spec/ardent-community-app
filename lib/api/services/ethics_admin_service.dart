import 'dart:typed_data';

import '../api_client.dart';

/// Ethics Admin (HR/reviewer side). See docs §Ethics Admin. All routes require
/// `module:ethics.manage`. A reviewer who is the subject of, or filed, a case is
/// recused per record — a recused case returns 404 (indistinguishable from not
/// existing).
class EthicsAdminService {
  EthicsAdminService(this._api);
  final ApiClient _api;

  /// `GET /ethics-admin/cases?status=&category=&assignee=`.
  Future<List<dynamic>> cases({
    String? status,
    String? category,
    String? assignee,
  }) async {
    final data = await _api.get('/ethics-admin/cases', query: {
      'status': status,
      'category': category,
      'assignee': assignee,
    });
    return data is List ? data : const [];
  }

  /// `GET /ethics-admin/stats` — case counts/stats for this reviewer.
  Future<dynamic> stats() => _api.get('/ethics-admin/stats');

  /// `GET /ethics-admin/cases/:id` — view one case (recusal → 404).
  Future<Map<String, dynamic>> get(String id) async =>
      Map<String, dynamic>.from(await _api.get('/ethics-admin/cases/$id') as Map);

  /// `GET /ethics-admin/cases/:id/events` — full audit-event history.
  Future<List<dynamic>> events(String id) async {
    final data = await _api.get('/ethics-admin/cases/$id/events');
    return data is List ? data : const [];
  }

  /// `GET /ethics-admin/cases/:id/reviewers` — who this case can be assigned to.
  Future<List<dynamic>> reviewers(String id) async {
    final data = await _api.get('/ethics-admin/cases/$id/reviewers');
    return data is List ? data : const [];
  }

  /// `POST /ethics-admin/cases/:id/acknowledge`.
  Future<void> acknowledge(String id) =>
      _api.post('/ethics-admin/cases/$id/acknowledge');

  /// `POST /ethics-admin/cases/:id/start-investigation`.
  Future<void> startInvestigation(String id) =>
      _api.post('/ethics-admin/cases/$id/start-investigation');

  /// `POST /ethics-admin/cases/:id/request-info` — request more info from the
  /// reporter (posts a message on the thread).
  Future<void> requestInfo(String id, String body) =>
      _api.post('/ethics-admin/cases/$id/request-info', body: {'body': body});

  /// `POST /ethics-admin/cases/:id/resume` — resume after an info request.
  Future<void> resume(String id) => _api.post('/ethics-admin/cases/$id/resume');

  /// `POST /ethics-admin/cases/:id/resolve` — resolve the case. `outcome` must
  /// be a valid enum; optional `note`.
  Future<void> resolve(String id, {required String outcome, String? note}) =>
      _api.post('/ethics-admin/cases/$id/resolve',
          body: {'outcome': outcome, 'note': ?note});

  /// `POST /ethics-admin/cases/:id/dismiss` — dismiss the case.
  Future<void> dismiss(String id, {String? note}) => _api.post(
      '/ethics-admin/cases/$id/dismiss',
      body: {'note': ?note});

  /// `POST /ethics-admin/cases/:id/reopen` — reopen a closed case.
  Future<void> reopen(String id) => _api.post('/ethics-admin/cases/$id/reopen');

  /// `POST /ethics-admin/cases/:id/assign` — reassign the case.
  Future<void> assign(String id, String assigneeId) => _api
      .post('/ethics-admin/cases/$id/assign', body: {'assigneeId': assigneeId});

  /// `POST /ethics-admin/cases/:id/messages` — post a message/internal note.
  /// `isInternal: true` notes are HR-only (reporter never notified).
  Future<Map<String, dynamic>> postMessage(
    String id, {
    required String body,
    bool? isInternal,
  }) async {
    final data = await _api.post('/ethics-admin/cases/$id/messages', body: {
      'body': body,
      'isInternal': ?isInternal,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /ethics-admin/cases/:id/read` — mark thread read for this reviewer.
  Future<void> markRead(String id) => _api.post('/ethics-admin/cases/$id/read');

  /// `GET /ethics-admin/cases/:id/attachments` — list evidence attachments.
  Future<List<dynamic>> attachments(String id) async {
    final data = await _api.get('/ethics-admin/cases/$id/attachments');
    return data is List ? data : const [];
  }

  /// `POST /ethics-admin/cases/:id/attachments` — upload HR-side evidence
  /// (`ethicsUpload`). Optional `fileName`, `isInternal` (`"true"`).
  Future<Map<String, dynamic>> uploadAttachment(
    String id, {
    required Uint8List bytes,
    required String filename,
    String? fileName,
    bool? isInternal,
    String? contentType,
  }) async {
    final data = await _api.multipart(
      'POST',
      '/ethics-admin/cases/$id/attachments',
      fields: {
        'fileName': ?fileName,
        if (isInternal != null) 'isInternal': isInternal ? 'true' : 'false',
      },
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

  /// `GET /ethics-admin/cases/:id/attachments/:attachmentId` — stream one
  /// evidence file (authenticated; never a public URL).
  Future<({Uint8List bytes, String? contentType})> attachment(
          String id, String attachmentId) =>
      _api.getBytes('/ethics-admin/cases/$id/attachments/$attachmentId');
}
