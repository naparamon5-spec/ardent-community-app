# Ardent Community API client

A typed Dart client for the Ardent Community backend, generated to match
[`docs/API_DOCUMENTATION.md`](../../docs/API_DOCUMENTATION.md). Every documented
endpoint (all 22 sections + realtime) has a callable method.

## Quick start

```dart
import 'package:ardent_community/api/api.dart';

// In main(), before runApp():
WidgetsFlutterBinding.ensureInitialized();
await AuthStore.instance.load();          // restore a saved session

// Anywhere:
final api = Api.instance;

// Sign in — the JWT is stored automatically for later calls.
final res = await api.auth.login(email: email, password: password);

// Optional-auth reads work signed-out and are personalised when signed in.
final feed = await api.posts.feed(limit: 20);

// Uploads take bytes (nothing touches local disk, same as the backend).
await api.users.uploadAvatar(bytes: pngBytes, filename: 'me.png');
```

## Configuration

Base URL comes from `ApiConfig.baseUrl` (default `http://localhost:4000/api`).
Override per run without editing source:

```
flutter run --dart-define=API_BASE_URL=https://staging.example.com/api
```

On a device `localhost` won't reach your dev machine — use `10.0.2.2` (Android
emulator) or your LAN IP (physical device). See `api_config.dart`.

## Shape of things

- **Envelope** — the server wraps everything in `{ success, data }` /
  `{ success, error }`. The client unwraps it: service methods return the bare
  `data` payload (`Map`/`List`), and any failure throws `ApiException` (with
  `statusCode`, `message`, optional `details`).
- **Auth** — `AuthStore` (a `ChangeNotifier`) holds the JWT and persists it via
  `shared_preferences`. `ApiClient` attaches `Authorization: Bearer <token>`
  automatically and clears the token on a `401`.
- **Facade** — `Api.instance` exposes one service per doc section:
  `auth`, `sso`, `users`, `posts`, `listings`, `events`, `stories`, `groups`,
  `categories`, `celebrations`, `notifications`, `search`, `bookings`,
  `bookingAdmin`, `ethics`, `ethicsAdmin`, `appraisals`, `appraisalAdmin`,
  `ashtrid`, `admin`, `health`, plus `realtime` (Socket.IO).
- **Media** — `MediaService.resolve(url)` absolutises the server-relative media
  URLs the API returns. Private evidence (ethics/appraisal) is **not** a public
  URL; fetch it via the service's `attachment(...)` byte stream instead.
- **Realtime** — `api.realtime.connect()` after sign-in; subscribe with
  `onPresence(...)` or `on('presence:update', ...)`. `disconnect()` on sign-out.

## Files

| File | Purpose |
| --- | --- |
| `api.dart` | Barrel export + `Api` facade |
| `api_config.dart` | Base URL / origin / timeout |
| `api_client.dart` | HTTP verbs, multipart, envelope unwrap, auth header |
| `api_exception.dart` | Error type |
| `auth_store.dart` | JWT storage |
| `services/*.dart` | One file per documentation section |

## App wiring

The app is now live against this client — there is no mock data left:

- **Auth** — `LoginScreen` + `AuthGate` (in `main.dart`) gate the app on a real
  session; the JWT is stored via `AuthStore` (secure storage) and the profile
  in `AppSession`. Sign-out is in Settings.
- **Screens** read from the API through `lib/data/mappers.dart` (JSON → the
  `Person`/`Post`/… UI models): Home feed + composer, Stories composer (captures
  the preview to a PNG and uploads it), People, Events (+RSVP), Marketplace
  (+categories), Groups (+join), Chats (DMs/groups + live messages),
  Notifications, Search, Profile (+HR + certificates), Edit profile, and member
  profiles. Post like/save/comment/vote/share hit the API optimistically.
- **Loading/error/empty** states use `lib/widgets/async_view.dart`.

### Response-shape caveat
The backend's exact JSON field names aren't in the docs, so the parsers in
`mappers.dart` are defensive (they try several common keys). Verify them against
a running backend and tighten the `_pick([...])` lists where needed.

### Config reminder
Set the backend URL for your target — e.g. Android emulator:
`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api`. Cleartext
HTTP is enabled for dev on Android/iOS; move to `https://` for production.
