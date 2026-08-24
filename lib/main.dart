import 'package:flutter/material.dart';

import 'screens/chats_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'theme/ardent_colors.dart';
import 'theme/ardent_theme.dart';

void main() {
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
      home: const AppShell(),
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
