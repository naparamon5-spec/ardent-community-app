import 'package:flutter/material.dart';

import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'admin_users_screen.dart';
import 'appraisal_admin_screen.dart';
import 'appraisals_screen.dart';
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
    return ListView(
      padding: const EdgeInsets.all(ArdentSpacing.s4),
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SearchScreen())),
          child: AbsorbPointer(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search people or posts…',
                prefixIcon: const Icon(Icons.search_rounded, color: ArdentColors.fg3),
              ),
            ),
          ),
        ),
        const SizedBox(height: ArdentSpacing.s5),

        const _SectionLabel('Discover'),
        _MenuTile(Icons.people_alt_rounded, 'People', ArdentColors.navy600,
            onTap: () => _openScaffold(context, 'People', const PeopleScreen())),
        _MenuTile(Icons.groups_rounded, 'Groups', ArdentColors.crimson500,
            onTap: () => _push(context, const GroupsScreen())),
        _MenuTile(Icons.event_rounded, 'Events', ArdentColors.accent,
            onTap: () => _push(context, const EventsScreen())),
        _MenuTile(Icons.storefront_rounded, 'Mall of Ardent', const Color(0xFFC77700),
            onTap: () => _push(context, const MarketplaceScreen())),
        _MenuTile(Icons.bookmark_rounded, 'Saved', ArdentColors.navy500,
            onTap: () => _push(context, const SavedScreen())),

        const SizedBox(height: ArdentSpacing.s4),
        const _SectionLabel('Appraisals'),
        _MenuTile(Icons.workspace_premium_rounded, 'My appraisals', ArdentColors.navy700,
            onTap: () => _push(context, const AppraisalsScreen())),
        _MenuTile(Icons.tune_rounded, 'Manage', ArdentColors.navy600,
            onTap: () => _push(context, const AppraisalAdminScreen())),

        const SizedBox(height: ArdentSpacing.s4),
        const _SectionLabel('Bookings'),
        _MenuTile(Icons.directions_car_rounded, 'Vans & rooms', ArdentColors.navy600,
            onTap: () => _push(context, const BookingsScreen())),

        const SizedBox(height: ArdentSpacing.s4),
        const _SectionLabel('Ethics'),
        _MenuTile(Icons.shield_rounded, 'Reports', ArdentColors.crimson500,
            onTap: () => _push(context, const EthicsScreen())),
        _MenuTile(Icons.gavel_rounded, 'Review', ArdentColors.navy700,
            onTap: () => _push(context, const EthicsAdminScreen())),

        const SizedBox(height: ArdentSpacing.s4),
        const _SectionLabel('System settings'),
        _MenuTile(Icons.manage_accounts_rounded, 'Manage users', ArdentColors.navy700,
            onTap: () => _push(context, const AdminUsersScreen())),
        _MenuTile(Icons.category_rounded, 'Marketplace categories', const Color(0xFFC77700),
            onTap: () => _push(context, const CategoriesAdminScreen())),
        _MenuTile(Icons.receipt_long_rounded, 'System log', ArdentColors.navy500,
            onTap: () => _soon(context, 'System log')),
        const SizedBox(height: ArdentSpacing.s6),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s2, left: 2),
      child: Overline(text),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile(this.icon, this.label, this.color, {this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ArdentSpacing.s2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ArdentRadii.md),
        child: SurfaceCard(
          padding: const EdgeInsets.symmetric(
              horizontal: ArdentSpacing.s3, vertical: ArdentSpacing.s3),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ArdentRadii.sm),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: ArdentSpacing.s3),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: ArdentColors.fg1)),
              ),
              const Icon(Icons.chevron_right_rounded, color: ArdentColors.fg3),
            ],
          ),
        ),
      ),
    );
  }
}
