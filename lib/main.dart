import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'api/api.dart';
import 'api/session.dart';
import 'screens/chats_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'theme/ardent_colors.dart';
import 'theme/ardent_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load API_BASE_URL (and any other config) from the bundled .env. Optional —
  // a missing file just falls back to the default/localhost base URL.
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('[Config] .env loaded (API_BASE_URL='
        '${dotenv.maybeGet('API_BASE_URL') ?? '<not set>'})');
  } catch (e) {
    // No .env bundled; ApiConfig falls back to its default.
    debugPrint('[Config] .env NOT loaded ($e) — using default base URL');
  }
  debugPrint('[Config] Resolved API base URL = ${ApiConfig.baseUrl}');
  // Restore any saved JWT so authenticated API calls (Api.instance.*) work from
  // launch. The backend client lives under lib/api/ — see lib/api/api.dart.
  await AuthStore.instance.load();
  runApp(const ArdentCommunityApp());
}

class ArdentCommunityApp extends StatelessWidget {
  const ArdentCommunityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ardent Community',
      debugShowCheckedModeBanner: false,
      theme: ArdentTheme.light(),
      // Clamp the OS text-scale so an aggressive accessibility font size can't
      // break layouts on any device, while still honouring smaller/larger
      // preferences within a safe range.
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.2,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}

/// Chooses between the login screen and the main app based on whether a valid
/// session is held. Rebuilds whenever the auth token changes (sign-in / -out).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    AuthStore.instance.addListener(_onAuthChanged);
    _ensureProfileLoaded();
  }

  @override
  void dispose() {
    AuthStore.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
    _ensureProfileLoaded();
  }

  /// When a token is present but the profile hasn't loaded yet (e.g. session
  /// restored at launch), fetch `/auth/me`. A failure (invalid/expired token)
  /// clears the token via ApiClient's 401 handler, dropping us to login.
  Future<void> _ensureProfileLoaded() async {
    if (AuthStore.instance.isAuthenticated && !AppSession.instance.isReady) {
      try {
        await AppSession.instance.loadMe();
        Api.instance.realtime.connect();
      } catch (_) {
        // Handled by the 401 flow / surfaced on next interaction.
      }
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthStore.instance.isAuthenticated) {
      return const LoginScreen();
    }
    // Authenticated but still fetching the profile at cold start.
    if (!AppSession.instance.isReady) {
      return const Scaffold(
        backgroundColor: ArdentColors.bgSurface,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AnimatedBuilder(
      animation: AppSession.instance,
      builder: (_, _) => const AppShell(),
    );
  }
}

/// One tab in the bottom navigation.
class _Tab {
  const _Tab(this.title, this.icon, this.activeIcon, this.builder);
  final String title;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder builder;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final List<_Tab> _tabs = [
    _Tab('Home', Icons.home_outlined, Icons.home_rounded, (_) => const HomeScreen()),
    _Tab('Explore', Icons.explore_outlined, Icons.explore_rounded,
        (_) => ExploreScreen(onOpenTab: _goTab)),
    _Tab('Chats', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded,
        (_) => const ChatsScreen()),
    _Tab('Profile', Icons.person_outline_rounded, Icons.person_rounded,
        (_) => const ProfileScreen()),
  ];

  void _goTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_index];
    return Scaffold(
      // NestedScrollView + a floating/snapping SliverAppBar gives the
      // Facebook behaviour: the bar slides away when scrolling down and comes
      // straight back on the first scroll up.
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            forceElevated: innerBoxIsScrolled,
            backgroundColor: ArdentColors.bgSurface,
            surfaceTintColor: Colors.transparent,
            title: _index == 0 ? _brandTitle() : Text(tab.title),
            actions: [
              if (_index == 0)
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  color: ArdentColors.fg2,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                color: ArdentColors.fg2,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ],
        // Key the body per-tab so switching tabs resets the scroll position
        // instead of carrying one tab's offset into another.
        body: KeyedSubtree(key: ValueKey(_index), child: tab.builder(context)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _goTab,
        items: [
          for (final t in _tabs)
            BottomNavigationBarItem(
              icon: Icon(t.icon),
              activeIcon: Icon(t.activeIcon),
              label: t.title,
            ),
        ],
      ),
    );
  }

  Widget _brandTitle() {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.3, -0.4),
              radius: 1.0,
              colors: [ArdentColors.brandCoral, ArdentColors.brandRed, ArdentColors.red800],
              stops: [0.0, 0.48, 1.0],
            ),
          ),
        ),
        const SizedBox(width: ArdentSpacing.s2),
        const Flexible(
          child: Text(
            'Ardent Community',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
