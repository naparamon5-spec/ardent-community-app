/// Ardent Community backend API — single entry point.
///
/// Import this one file to reach the whole client:
///
/// ```dart
/// import 'package:ardent_community/api/api.dart';
///
/// await AuthStore.instance.load();          // restore a saved session
/// final api = Api.instance;
/// final result = await api.auth.login(email: e, password: p);
/// final feed   = await api.posts.feed(limit: 20);
/// ```
///
/// Every service maps 1:1 to a section of `API_DOCUMENTATION.md`. Services return
/// the already-unwrapped `data` payload (plain `Map`/`List`); failures throw
/// [ApiException]. See individual service classes for per-endpoint docs.
library;

import 'api_client.dart';
import 'services/admin_service.dart';
import 'services/appraisal_admin_service.dart';
import 'services/appraisals_service.dart';
import 'services/ashtrid_service.dart';
import 'services/booking_admin_service.dart';
import 'services/bookings_service.dart';
import 'services/calls_service.dart';
import 'services/categories_service.dart';
import 'services/celebrations_service.dart';
import 'services/ethics_admin_service.dart';
import 'services/ethics_service.dart';
import 'services/events_service.dart';
import 'services/groups_service.dart';
import 'services/health_service.dart';
import 'services/listings_service.dart';
import 'services/notifications_service.dart';
import 'services/posts_service.dart';
import 'services/realtime_service.dart';
import 'services/search_service.dart';
import 'services/sso_service.dart';
import 'services/stories_service.dart';
import 'services/users_service.dart';
import 'services/auth_service.dart';

export 'api_client.dart' show ApiClient, UploadFile;
export 'api_config.dart';
export 'api_exception.dart';
export 'auth_store.dart';
export 'services/admin_service.dart';
export 'services/appraisal_admin_service.dart';
export 'services/appraisals_service.dart';
export 'services/ashtrid_service.dart';
export 'services/auth_service.dart';
export 'services/booking_admin_service.dart';
export 'services/bookings_service.dart';
export 'services/calls_service.dart';
export 'services/categories_service.dart';
export 'services/celebrations_service.dart';
export 'services/ethics_admin_service.dart';
export 'services/ethics_service.dart';
export 'services/events_service.dart';
export 'services/groups_service.dart';
export 'services/health_service.dart';
export 'services/listings_service.dart';
export 'services/media_service.dart';
export 'services/notifications_service.dart';
export 'services/posts_service.dart';
export 'services/realtime_service.dart';
export 'services/search_service.dart';
export 'services/sso_service.dart';
export 'services/stories_service.dart';
export 'services/users_service.dart';

/// Facade that lazily exposes every backend service over one [ApiClient].
///
/// Use [Api.instance] for the app-wide singleton, or construct your own with a
/// custom client (handy in tests).
class Api {
  Api({ApiClient? client}) : _client = client ?? ApiClient.instance;

  static final Api instance = Api();

  final ApiClient _client;

  /// The underlying HTTP client (for advanced/one-off calls).
  ApiClient get client => _client;

  late final HealthService health = HealthService(_client);
  late final AuthService auth = AuthService(_client);
  late final SsoService sso = SsoService(_client);
  late final UsersService users = UsersService(_client);
  late final PostsService posts = PostsService(_client);
  late final ListingsService listings = ListingsService(_client);
  late final EventsService events = EventsService(_client);
  late final StoriesService stories = StoriesService(_client);
  late final GroupsService groups = GroupsService(_client);
  late final CategoriesService categories = CategoriesService(_client);
  late final CelebrationsService celebrations = CelebrationsService(_client);
  late final NotificationsService notifications = NotificationsService(_client);
  late final SearchService search = SearchService(_client);
  late final BookingsService bookings = BookingsService(_client);
  late final BookingAdminService bookingAdmin = BookingAdminService(_client);
  late final CallsService calls = CallsService(_client);
  late final EthicsService ethics = EthicsService(_client);
  late final EthicsAdminService ethicsAdmin = EthicsAdminService(_client);
  late final AppraisalsService appraisals = AppraisalsService(_client);
  late final AppraisalAdminService appraisalAdmin = AppraisalAdminService(_client);
  late final AshtridService ashtrid = AshtridService(_client);
  late final AdminService admin = AdminService(_client);

  /// Real-time presence + group chat over Socket.IO. Call `connect()` after
  /// sign-in and `disconnect()` on sign-out.
  late final RealtimeService realtime = RealtimeService();
}
