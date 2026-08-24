import '../api_client.dart';

/// Bookings — van/meeting-room self-service. See docs §Bookings.
/// All routes require `module:bookings.view`; writes also need
/// `module:bookings.book`.
class BookingsService {
  BookingsService(this._api);
  final ApiClient _api;

  /// `GET /bookings/meta` — resource type labels/icons + `maxDurationDays`.
  Future<Map<String, dynamic>> meta() async =>
      Map<String, dynamic>.from(await _api.get('/bookings/meta') as Map);

  /// `GET /bookings/resources?type=` — active bookable resources
  /// (`type` = `van` | `room`).
  Future<List<dynamic>> resources({String? type}) async {
    final data = await _api.get('/bookings/resources', query: {'type': type});
    return data is List ? data : const [];
  }

  /// `GET /bookings/availability?type=&from=&to=` — resources + bookings
  /// touching the window (`from`/`to` ISO, required). 400 if `to <= from`.
  Future<Map<String, dynamic>> availability({
    String? type,
    required String from,
    required String to,
  }) async =>
      Map<String, dynamic>.from(await _api.get('/bookings/availability',
          query: {'type': type, 'from': from, 'to': to}) as Map);

  /// `GET /bookings/mine?scope=` — the caller's own bookings
  /// (`upcoming` | `past` | `all`, default `upcoming`).
  Future<List<dynamic>> mine({String scope = 'upcoming'}) async {
    final data = await _api.get('/bookings/mine', query: {'scope': scope});
    return data is List ? data : const [];
  }

  /// `POST /bookings` — create a booking. Required: `resourceId`, `purpose`,
  /// `startsAt`, `endsAt` (≤30-day window, not in the past unless caller has
  /// `bookings.manage`). Optional `occupants`, `notes`, and van-only
  /// `destination`, `pickupPoint`, `driverName`, `driverUserId`.
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _api.post('/bookings', body: body) as Map);

  /// `GET /bookings/:id` — one booking (booker, occupant, or manager).
  Future<Map<String, dynamic>> get(String id) async =>
      Map<String, dynamic>.from(await _api.get('/bookings/$id') as Map);

  /// `PATCH /bookings/:id` — update/move a booking (owner or manager).
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _api.patch('/bookings/$id', body: body) as Map);

  /// `POST /bookings/:id/cancel` — cancel a booking (owner or manager).
  Future<Map<String, dynamic>> cancel(String id, {String? reason}) async =>
      Map<String, dynamic>.from(await _api.post('/bookings/$id/cancel',
          body: {'reason': ?reason}) as Map);
}
