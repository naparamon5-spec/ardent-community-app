import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
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

  /// Whether the bottom nav is shown — hidden while scrolling content down,
  /// revealed again on the first scroll up (Facebook behaviour).
  bool _navVisible = true;

  void _goTab(int i) => setState(() {
        _index = i;
        _navVisible = true; // always reveal when switching tabs
      });

  bool _onScroll(UserScrollNotification n) {
    // Hide-on-scroll only applies on Home; other tabs always keep the bar.
    if (_index != 0) return false;
    // Ignore horizontal scrolls (e.g. the stories row).
    if (n.metrics.axis != Axis.vertical) return false;
    switch (n.direction) {
      case ScrollDirection.reverse: // dragging content up → hide
        if (_navVisible) setState(() => _navVisible = false);
      case ScrollDirection.forward: // dragging content down → show
        if (!_navVisible) setState(() => _navVisible = true);
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_index];
    return Scaffold(
      // NestedScrollView + a floating/snapping SliverAppBar gives the
      // Facebook behaviour: the bar slides away when scrolling down and comes
      // straight back on the first scroll up.
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: NestedScrollView(
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
      ),
      // The bar only ever hides on Home; every other tab always shows it.
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: (_index != 0 || _navVisible)
            ? _ArdentBottomNav(
                tabs: _tabs,
                index: _index,
                onTap: _goTab,
              )
            : const SizedBox(width: double.infinity),
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

/// Custom bottom navigation — a clean white bar with an animated pill highlight
/// behind the active tab, using the Ardent red accent.
class _ArdentBottomNav extends StatelessWidget {
  const _ArdentBottomNav(
      {required this.tabs, required this.index, required this.onTap});

  final List<_Tab> tabs;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ArdentColors.bgSurface,
        border: Border(top: BorderSide(color: ArdentColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: ArdentSpacing.s3, vertical: ArdentSpacing.s2),
          child: Row(
            children: [
              for (int i = 0; i < tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    tab: tabs[i],
                    active: i == index,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.tab, required this.active, required this.onTap});

  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? ArdentColors.accent : ArdentColors.fg3;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              decoration: BoxDecoration(
                color: active ? ArdentColors.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(ArdentRadii.pill),
              ),
              child: Icon(active ? tab.activeIcon : tab.icon,
                  size: 24, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              tab.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
