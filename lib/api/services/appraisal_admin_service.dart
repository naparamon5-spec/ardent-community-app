import '../api_client.dart';

/// Appraisal Admin (HR/admin side). See docs §Appraisal Admin. All routes
/// require `module:appraisal.manage`. Covers rating scales, templates/versions,
/// the competency library, cycles, and per-appraisal HR actions.
class AppraisalAdminService {
  AppraisalAdminService(this._api);
  final ApiClient _api;

  // ---- Rating scales --------------------------------------------------------

  /// `GET /appraisal-admin/scales` — list rating scales + options.
  Future<List<dynamic>> scales() async {
    final data = await _api.get('/appraisal-admin/scales');
    return data is List ? data : const [];
  }

  /// `POST /appraisal-admin/scales` — create a scale.
  Future<Map<String, dynamic>> createScale(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await _api.post('/appraisal-admin/scales', body: body) as Map);

  /// `PUT /appraisal-admin/scales/:id` — update a scale (options replaced
  /// wholesale when sent).
  Future<Map<String, dynamic>> updateScale(
          String id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await _api.put('/appraisal-admin/scales/$id', body: body) as Map);

  // ---- Templates & versions -------------------------------------------------

  /// `GET /appraisal-admin/templates` — templates with their versions.
  Future<List<dynamic>> templates() async {
    final data = await _api.get('/appraisal-admin/templates');
    return data is List ? data : const [];
  }

  /// `POST /appraisal-admin/templates` — create a template + first draft (v1).
  Future<Map<String, dynamic>> createTemplate({
    required String name,
    String? description,
  }) async {
    final data = await _api.post('/appraisal-admin/templates', body: {
      'name': name,
      'description': ?description,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /appraisal-admin/versions/:versionId` — one version (sections/items/
  /// bands).
  Future<Map<String, dynamic>> version(String versionId) async =>
      Map<String, dynamic>.from(
          await _api.get('/appraisal-admin/versions/$versionId') as Map);

  /// `POST /appraisal-admin/versions/:versionId/structure/preview` — dry-run
  /// impact report (no writes).
  Future<Map<String, dynamic>> previewStructure(
          String versionId, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _api.post(
          '/appraisal-admin/versions/$versionId/structure/preview',
          body: body) as Map);

  /// `PUT /appraisal-admin/versions/:versionId/structure` — bulk-save the
  /// section/item tree. A breaking edit to a published version with real answers
  /// is refused (400) unless `force: true`.
  Future<Map<String, dynamic>> saveStructure(
          String versionId, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _api.put(
          '/appraisal-admin/versions/$versionId/structure',
          body: body) as Map);

  /// `GET /appraisal-admin/versions/:versionId/validate` — `{ ready, errors }`.
  Future<Map<String, dynamic>> validateVersion(String versionId) async =>
      Map<String, dynamic>.from(
          await _api.get('/appraisal-admin/versions/$versionId/validate') as Map);

  /// `POST /appraisal-admin/versions/:versionId/publish` — publish a version.
  Future<Map<String, dynamic>> publishVersion(String versionId) async =>
      Map<String, dynamic>.from(
          await _api.post('/appraisal-admin/versions/$versionId/publish') as Map);

  /// `POST /appraisal-admin/versions/:versionId/clone` — clone into a new draft.
  Future<Map<String, dynamic>> cloneVersion(String versionId) async =>
      Map<String, dynamic>.from(
          await _api.post('/appraisal-admin/versions/$versionId/clone') as Map);

  /// `GET /appraisal-admin/versions/:versionId/changes` — change-log (last 200).
  Future<List<dynamic>> versionChanges(String versionId) async {
    final data = await _api.get('/appraisal-admin/versions/$versionId/changes');
    return data is List ? data : const [];
  }

  // ---- Competency library ---------------------------------------------------

  /// `GET /appraisal-admin/item-library` — active library items.
  Future<List<dynamic>> itemLibrary() async {
    final data = await _api.get('/appraisal-admin/item-library');
    return data is List ? data : const [];
  }

  /// `POST /appraisal-admin/item-library` — upsert a reusable library item.
  /// `code` + `label` required.
  Future<Map<String, dynamic>> upsertLibraryItem(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await _api.post('/appraisal-admin/item-library', body: body) as Map);

  // ---- Cycles ---------------------------------------------------------------

  /// `GET /appraisal-admin/cycles` — list cycles.
  Future<List<dynamic>> cycles() async {
    final data = await _api.get('/appraisal-admin/cycles');
    return data is List ? data : const [];
  }

  /// `POST /appraisal-admin/cycles` — create a cycle. `name` + `versionId`
  /// (published) required.
  Future<Map<String, dynamic>> createCycle(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await _api.post('/appraisal-admin/cycles', body: body) as Map);

  /// `PUT /appraisal-admin/cycles/:id` — update a cycle.
  Future<Map<String, dynamic>> updateCycle(
          String id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await _api.put('/appraisal-admin/cycles/$id', body: body) as Map);

  /// `POST /appraisal-admin/cycles/:id/activate` — advance status.
  Future<void> activateCycle(String id) =>
      _api.post('/appraisal-admin/cycles/$id/activate');

  /// `POST /appraisal-admin/cycles/:id/lock` — advance status.
  Future<void> lockCycle(String id) =>
      _api.post('/appraisal-admin/cycles/$id/lock');

  /// `POST /appraisal-admin/cycles/:id/close` — advance status.
  Future<void> closeCycle(String id) =>
      _api.post('/appraisal-admin/cycles/$id/close');

  /// `POST /appraisal-admin/cycles/:id/generate` — generate appraisal records.
  /// With no `userIds`, generates for every active employee.
  Future<Map<String, dynamic>> generateCycle(
    String id, {
    List<String>? userIds,
    List<String>? departments,
    String? versionId,
  }) async {
    final data = await _api.post('/appraisal-admin/cycles/$id/generate', body: {
      'userIds': ?userIds,
      'departments': ?departments,
      'versionId': ?versionId,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /appraisal-admin/cycles/:id/release` — release results (optional
  /// `appraisalIds` subset).
  Future<Map<String, dynamic>> releaseCycle(
    String id, {
    List<String>? appraisalIds,
  }) async {
    final data = await _api.post('/appraisal-admin/cycles/$id/release', body: {
      'appraisalIds': ?appraisalIds,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /appraisal-admin/cycles/:id/progress` — completion dashboard.
  Future<Map<String, dynamic>> cycleProgress(String id) async =>
      Map<String, dynamic>.from(
          await _api.get('/appraisal-admin/cycles/$id/progress') as Map);

  /// `GET /appraisal-admin/cycles/:id/eligible` — active employees not yet in
  /// this cycle.
  Future<List<dynamic>> cycleEligible(String id) async {
    final data = await _api.get('/appraisal-admin/cycles/$id/eligible');
    return data is List ? data : const [];
  }

  // ---- Per-appraisal HR actions ---------------------------------------------

  /// `POST /appraisal-admin/appraisals/:id/assign-hr-rater`.
  Future<Map<String, dynamic>> assignHrRater(String id, String userId) async =>
      Map<String, dynamic>.from(await _api.post(
          '/appraisal-admin/appraisals/$id/assign-hr-rater',
          body: {'userId': userId}) as Map);

  /// `POST /appraisal-admin/appraisals/:id/override` — override a final score.
  Future<Map<String, dynamic>> overrideScore(
    String id, {
    required num finalScore,
    required String reason,
  }) async {
    final data = await _api.post('/appraisal-admin/appraisals/$id/override',
        body: {'finalScore': finalScore, 'reason': reason});
    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /appraisal-admin/appraisals/:id/override` — clear an override.
  Future<void> clearOverride(String id) =>
      _api.delete('/appraisal-admin/appraisals/$id/override');

  /// `POST /appraisal-admin/appraisals/:id/reopen` — reopen a submitted rater's
  /// section. `role` must be a valid rater role.
  Future<void> reopenSection(String id, {required String role, required String reason}) =>
      _api.post('/appraisal-admin/appraisals/$id/reopen',
          body: {'role': role, 'reason': reason});

  /// `POST /appraisal-admin/appraisals/:id/recalculate` — force-recompute.
  Future<Map<String, dynamic>> recalculate(String id) async =>
      Map<String, dynamic>.from(await _api
          .post('/appraisal-admin/appraisals/$id/recalculate') as Map);

  /// `GET /appraisal-admin/appraisals/:id/events` — audit history (last 200).
  Future<List<dynamic>> appraisalEvents(String id) async {
    final data = await _api.get('/appraisal-admin/appraisals/$id/events');
    return data is List ? data : const [];
  }

  /// `POST /appraisal-admin/appraisals/:id/version/preview` — dry-run: effect of
  /// moving this employee to another form version (no writes).
  Future<Map<String, dynamic>> previewVersionMove(
    String id, {
    required String versionId,
    String? onConflict,
  }) async {
    final data =
        await _api.post('/appraisal-admin/appraisals/$id/version/preview', body: {
      'versionId': versionId,
      'onConflict': ?onConflict,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /appraisal-admin/appraisals/:id/version` — move one employee's
  /// appraisal onto a different form version.
  Future<Map<String, dynamic>> moveVersion(
    String id, {
    required String versionId,
    String? onConflict,
    String? reason,
  }) async {
    final data = await _api.post('/appraisal-admin/appraisals/$id/version', body: {
      'versionId': versionId,
      'onConflict': ?onConflict,
      'reason': ?reason,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /appraisal-admin/appraisals/:id` — remove one appraisal from its
  /// cycle. Refused if already `released`/`acknowledged`.
  Future<void> deleteAppraisal(String id, {String? reason}) => _api.delete(
      '/appraisal-admin/appraisals/$id',
      body: {'reason': ?reason});
}
