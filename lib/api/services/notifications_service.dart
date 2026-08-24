import '../api_client.dart';

/// Notifications — always scoped to the caller. See docs §Notifications.
/// All routes require auth.
class NotificationsService {
  NotificationsService(this._api);
  final ApiClient _api;

  /// `GET /notifications?limit=&before=` — list + current unread count.
  /// Default limit 20; `before` is a cursor.
  Future<Map<String, dynamic>> list({int? limit, String? before}) async =>
      Map<String, dynamic>.from(await _api
          .get('/notifications', query: {'limit': limit, 'before': before}) as Map);

  /// `GET /notifications/unread-count` — unread count only.
  Future<dynamic> unreadCount() => _api.get('/notifications/unread-count');

  /// `POST /notifications/:id/read` — mark one read (404 if not found).
  Future<void> markRead(String id) => _api.post('/notifications/$id/read');

  /// `POST /notifications/read-all` — mark all read.
  Future<void> markAllRead() => _api.post('/notifications/read-all');
}
