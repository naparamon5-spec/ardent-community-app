import '../api_client.dart';

/// Celebrations — this month's birthdays/work anniversaries (Asia/Manila) for
/// linked, active accounts. See docs §Celebrations. Requires auth. Degrades to
/// an empty list with a `warnings` message if HR is unreachable (never a 500);
/// never returns a birth year.
class CelebrationsService {
  CelebrationsService(this._api);
  final ApiClient _api;

  /// `GET /celebrations`.
  Future<dynamic> list() => _api.get('/celebrations');
}
