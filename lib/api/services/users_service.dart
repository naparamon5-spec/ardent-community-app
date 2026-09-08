import 'dart:typed_data';

import '../api_client.dart';

/// Users / People — directory, public profiles, own-profile editing, avatar/
/// cover uploads, HR-linked details, and profile certificates.
/// See docs §Users / People. `:id` accepts a user's slug or UUID.
class UsersService {
  UsersService(this._api);
  final ApiClient _api;

  /// `GET /users?search=&interest=` — directory listing (matches
  /// name/role/department). Pass [interest] (a tag's *slug*) to narrow the
  /// directory to people who listed that tag — an unknown slug yields `[]`, not
  /// everyone. Each user includes their `interests[]`. Optional auth
  /// (personalises viewer flags when a token is sent).
  Future<List<dynamic>> list({String? search, String? interest}) async {
    final data = await _api.get('/users', query: {
      'search': search,
      'interest': interest,
    });
    return data is List ? data : const [];
  }

  /// `GET /users/:id` — one user's public profile.
  Future<Map<String, dynamic>> get(String id) async =>
      Map<String, dynamic>.from(await _api.get('/users/$id') as Map);

  /// `GET /users/:id/posts` — posts authored by that user.
  Future<List<dynamic>> posts(String id) async {
    final data = await _api.get('/users/$id/posts');
    return data is List ? data : const [];
  }

  /// `GET /users/:id/certificates` — that user's profile certificates.
  Future<List<dynamic>> certificatesOf(String id) async {
    final data = await _api.get('/users/$id/certificates');
    return data is List ? data : const [];
  }

  /// `PATCH /users/me` — update own profile/privacy fields. Pass any subset of
  /// the documented keys (name, role, department, bio, phone, location,
  /// manager, color, initials, avatarPosition, coverPosition, isPrivate,
  /// showEmail, emailNotifs, pushNotifs, notifyComments, notifyKudos).
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> fields) async =>
      Map<String, dynamic>.from(await _api.patch('/users/me', body: fields) as Map);

  /// `PUT /users/me/interests` — replace the current user's whole interest /
  /// hobby / like list wholesale. [interests] is the full list, each entry
  /// `{ name, kind? }` where `kind` is `interest` (default) | `hobby` | `like`.
  /// Unusable entries (blank, an emoji alone) are silently dropped; a list over
  /// 30 tags is rejected (400). Returns the saved list `[{id, name, slug, kind}]`.
  Future<List<dynamic>> setInterests(List<Map<String, dynamic>> interests) async {
    final data = await _api.put('/users/me/interests', body: {'interests': interests});
    return data is List ? data : const [];
  }

  /// `GET /users/me/interests/counts` — `{ [slug]: count }`: how many *other*
  /// colleagues share each of your own tags (the "· 4" hint on your profile).
  Future<Map<String, dynamic>> myInterestCounts() async =>
      Map<String, dynamic>.from(await _api.get('/users/me/interests/counts') as Map);

  /// `GET /users/me/hr` — own HR-linked details
  /// (`{ employeeId, dateHired, birthMonth, birthDay, linked }`). Never a birth
  /// year; degrades to nulls if the HR system is unreachable.
  Future<Map<String, dynamic>> myHr() async =>
      Map<String, dynamic>.from(await _api.get('/users/me/hr') as Map);

  /// `POST /users/me/avatar` — upload/replace avatar (image; deletes the old).
  Future<Map<String, dynamic>> uploadAvatar({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final data = await _api.multipart('POST', '/users/me/avatar', files: [
      UploadFile(
          field: 'avatar',
          filename: filename,
          bytes: bytes,
          contentType: contentType),
    ]);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `POST /users/me/cover` — upload/replace cover photo (image).
  Future<Map<String, dynamic>> uploadCover({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) async {
    final data = await _api.multipart('POST', '/users/me/cover', files: [
      UploadFile(
          field: 'cover',
          filename: filename,
          bytes: bytes,
          contentType: contentType),
    ]);
    return Map<String, dynamic>.from(data as Map);
  }

  /// `GET /users/me/certificates` — list own certificates.
  Future<List<dynamic>> myCertificates() async {
    final data = await _api.get('/users/me/certificates');
    return data is List ? data : const [];
  }

  /// `POST /users/me/certificates` — add a certificate (image/PDF file + a
  /// required `title`, optional `issuer`/`issuedOn`). Returns 201.
  Future<Map<String, dynamic>> addCertificate({
    required Uint8List bytes,
    required String filename,
    required String title,
    String? issuer,
    String? issuedOn,
    String? contentType,
  }) async {
    final data = await _api.multipart(
      'POST',
      '/users/me/certificates',
      fields: {
        'title': title,
        'issuer': ?issuer,
        'issuedOn': ?issuedOn,
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

  /// `PATCH /users/me/certificates/:certificateId` — update own certificate.
  Future<Map<String, dynamic>> updateCertificate(
    String certificateId, {
    String? title,
    String? issuer,
    String? issuedOn,
  }) async {
    final data = await _api.patch('/users/me/certificates/$certificateId', body: {
      'title': ?title,
      'issuer': ?issuer,
      'issuedOn': ?issuedOn,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// `DELETE /users/me/certificates/:certificateId` — delete own certificate.
  Future<void> deleteCertificate(String certificateId) =>
      _api.delete('/users/me/certificates/$certificateId');

  /// `POST /users/fcm-token` — register/upsert this device's FCM push token.
  /// Multi-device: many tokens may map to one user. Payload matches the shared
  /// backend contract (see docs/FCM_PUSH_NOTIFICATIONS.md). Bearer auth is
  /// attached automatically by [ApiClient].
  Future<void> registerFcmToken(Map<String, dynamic> payload) =>
      _api.post('/users/fcm-token', body: payload);

  /// `DELETE /users/fcm-token` — remove only this device's token (on logout).
  /// Same body as register; the backend deletes the row matching
  /// `employee_id` AND `fcm_token`.
  Future<void> removeFcmToken(Map<String, dynamic> payload) =>
      _api.delete('/users/fcm-token', body: payload);
}
