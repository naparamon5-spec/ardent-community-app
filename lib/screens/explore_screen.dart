import 'package:flutter/material.dart';

import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'admin_users_screen.dart';
import 'appraisal_admin_screen.dart';
import 'appraisals_screen.dart';
import 'booking_admin_screen.dart';
import 'bookings_screen.dart';
import 'categories_admin_screen.dart';
import 'ethics_admin_screen.dart';
import 'ethics_screen.dart';
import 'events_screen.dart';
import 'groups_screen.dart';
import 'marketplace_screen.dart';
import 'people_screen.dart';
import 'saved_screen.dart';
import 'search_screen.dart';

/// Explore — the app's full menu, mirroring the web sidebar. Every module the
/// backend exposes is reachable from here.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key, this.onOpenTab});

  final void Function(int index)? onOpenTab;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _openScaffold(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: body),
    ));
  }

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label is coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final discover = <_Feature>[
      _Feature(Icons.people_alt_rounded, 'People', ArdentColors.navy600,
          () => _openScaffold(context, 'People', const PeopleScreen())),
      _Feature(Icons.groups_rounded, 'Groups', ArdentColors.crimson500,
          () => _push(context, const GroupsScreen())),
      _Feature(Icons.event_rounded, 'Events', ArdentColors.accent,
          () => _push(context, const EventsScreen())),
      _Feature(Icons.storefront_rounded, 'Mall of Ardent',
          const Color(0xFFC77700), () => _push(context, const MarketplaceScreen())),
      _Feature(Icons.bookmark_rounded, 'Saved', ArdentColors.navy500,
          () => _push(context, const SavedScreen())),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Hero(
          onSearch: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SearchScreen())),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(ArdentSpacing.s4, ArdentSpacing.s4,
              ArdentSpacing.s4, ArdentSpacing.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('Discover'),
              const SizedBox(height: ArdentSpacing.s3),
              _FeatureGrid(features: discover),

              const SizedBox(height: ArdentSpacing.s6),
              const _SectionLabel('Workspace'),
              const SizedBox(height: ArdentSpacing.s3),
              _MenuGroup(
                Icons.workspace_premium_rounded,
                'Appraisals',
                'Your reviews and rater tasks',
                ArdentColors.navy700,
                children: [
                  _SubTile(Icons.assignment_ind_rounded, 'My appraisals',
                      onTap: () => _push(context, const AppraisalsScreen())),
                  _SubTile(Icons.tune_rounded, 'Manage',
                      onTap: () => _push(context, const AppraisalAdminScreen())),
                ],
              ),
              _MenuGroup(
                Icons.directions_car_rounded,
                'Bookings',
                'Vans, rooms and the schedule',
                ArdentColors.navy600,
                children: [
                  _SubTile(Icons.event_seat_rounded, 'Vans & rooms',
                      onTap: () => _push(context, const BookingsScreen())),
                  _SubTile(Icons.tune_rounded, 'Manage',
                      onTap: () => _push(context, const BookingAdminScreen())),
                ],
              ),
              _MenuGroup(
                Icons.shield_rounded,
                'Ethics',
                'Raise or review a concern',
                ArdentColors.crimson500,
                children: [
                  _SubTile(Icons.flag_rounded, 'Reports',
                      onTap: () => _push(context, const EthicsScreen())),
                  _SubTile(Icons.gavel_rounded, 'Review',
                      onTap: () => _push(context, const EthicsAdminScreen())),
                ],
              ),

              const SizedBox(height: ArdentSpacing.s6),
              const _SectionLabel('System settings'),
              const SizedBox(height: ArdentSpacing.s3),
              _MenuGroup(
                Icons.settings_rounded,
                'Administration',
                'People, categories and logs',
                ArdentColors.navy500,
                children: [
                  _SubTile(Icons.manage_accounts_rounded, 'Manage users',
                      onTap: () => _push(context, const AdminUsersScreen())),
                  _SubTile(Icons.category_rounded, 'Marketplace categories',
                      onTap: () => _push(context, const CategoriesAdminScreen())),
                  _SubTile(Icons.receipt_long_rounded, 'System log',
                      onTap: () => _soon(context, 'System log')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Branded gradient header with the app name and an inline search entry.
class _Hero extends StatelessWidget {
  const _Hero({required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(ArdentSpacing.s4, topPad + ArdentSpacing.s5,
          ArdentSpacing.s4, ArdentSpacing.s5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ArdentColors.navy800, ArdentColors.navy600],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(ArdentRadii.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ArdentColors.accent,
                  borderRadius: BorderRadius.circular(ArdentRadii.md),
                ),
                child: const Icon(Icons.explore_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: ArdentSpacing.s3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Everything Ardent',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  const Text('Jump into any part of the workspace',
                      style: TextStyle(color: ArdentColors.fgOnDark2, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: ArdentSpacing.s4),
          GestureDetector(
            onTap: onSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ArdentSpacing.s3, vertical: ArdentSpacing.s3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ArdentRadii.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: ArdentColors.fg3, size: 20),
                  SizedBox(width: ArdentSpacing.s2),
                  Text('Search people or posts…',
                      style: TextStyle(color: ArdentColors.fg3, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A responsive grid of colorful feature cards.
class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.features});
  final List<_Feature> features;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = ArdentSpacing.s3;
        final cols = constraints.maxWidth > 520 ? 3 : 2;
        final width = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final f in features)
              SizedBox(width: width, child: _FeatureCard(f)),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard(this.feature);
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: feature.onTap,
      borderRadius: BorderRadius.circular(ArdentRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(ArdentSpacing.s3),
        decoration: BoxDecoration(
          color: ArdentColors.bgSurface,
          borderRadius: BorderRadius.circular(ArdentRadii.lg),
          border: Border.all(color: ArdentColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    feature.color.withValues(alpha: 0.18),
                    feature.color.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(ArdentRadii.md),
              ),
              child: Icon(feature.icon, color: feature.color, size: 24),
            ),
            const SizedBox(height: ArdentSpacing.s3),
            Text(feature.label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: ArdentColors.fg1)),
          ],
        ),
      ),
    );
  }
}

class _Feature {
  const _Feature(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Overline(text),
    );
  }
}

/// Expandable menu group — a header tile that reveals its sub-items on tap
/// (collapsed by default), mirroring the collapsible groups in the web sidebar.
class _MenuGroup extends StatefulWidget {
  const _MenuGroup(this.icon, this.label, this.subtitle, this.color,
      {required this.children});
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final List<_SubTile> children;

  @override
  State<_MenuGroup> createState() => _MenuGroupState();
}

class _MenuGroupState extends State<_MenuGroup> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: ArdentColors.bgSurface,
          borderRadius: BorderRadius.circular(ArdentRadii.lg),
          border: Border.all(
              color: _open ? widget.color.withValues(alpha: 0.5) : ArdentColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.all(ArdentSpacing.s3),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.color.withValues(alpha: 0.18),
                            widget.color.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(ArdentRadii.md),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 22),
                    ),
                    const SizedBox(width: ArdentSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: ArdentColors.fg1)),
                          const SizedBox(height: 2),
                          Text(widget.subtitle,
                              style: const TextStyle(
                                  fontSize: 12, color: ArdentColors.fg3)),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: _open ? widget.color : ArdentColors.fg3),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Column(
                children: [
                  const Divider(height: 1, color: ArdentColors.border),
                  for (final child in widget.children) child,
                ],
              ),
              crossFadeState:
                  _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single row inside an expanded [_MenuGroup].
class _SubTile extends StatelessWidget {
  const _SubTile(this.icon, this.label, {required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ArdentSpacing.s3, vertical: ArdentSpacing.s3),
        child: Row(
          children: [
            const SizedBox(width: ArdentSpacing.s1),
            Icon(icon, size: 20, color: ArdentColors.fg2),
            const SizedBox(width: ArdentSpacing.s3),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: ArdentColors.fg2)),
            ),
            const Icon(Icons.chevron_right_rounded, color: ArdentColors.fg3),
          ],
        ),
      ),
    );
  }
}
