import 'package:flutter/material.dart';

import '../data/seed.dart';
import '../theme/ardent_colors.dart';
import '../widgets/ds.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

/// Profile — port of `pages/profile.vue`: cover, identity, stats, about, and
/// a certificates/activity section.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final me = Seed.currentUser;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Cover + avatar
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 132,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ArdentColors.navy800, ArdentColors.navy900],
                ),
              ),
            ),
            Positioned(
              left: ArdentSpacing.s4,
              bottom: -36,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: DsAvatar(initials: me.initials, color: me.color, size: 84),
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ArdentSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(me.name, style: text.headlineMedium?.copyWith(fontSize: 22)),
              Text(me.role, style: text.bodyLarge),
              const SizedBox(height: ArdentSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit profile'),
                    ),
                  ),
                  const SizedBox(width: ArdentSpacing.s3),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    child: const Icon(Icons.settings_outlined, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: ArdentSpacing.s5),
              SurfaceCard(
                child: Row(
                  children: [
                    _stat('128', 'Posts', text),
                    _divider(),
                    _stat('342', 'Kudos', text),
                    _divider(),
                    _stat('5', 'Groups', text),
                  ],
                ),
              ),
              const SizedBox(height: ArdentSpacing.s5),
              const Overline('About'),
              const SizedBox(height: ArdentSpacing.s2),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _aboutLine(Icons.mail_outline_rounded,
                        'ramon.napa@ardentnetworks.com.ph', text),
                    _aboutLine(Icons.business_outlined, 'Ardent Networks Inc.', text),
                    _aboutLine(Icons.place_outlined, 'Pasig City, Philippines', text),
                    _aboutLine(Icons.cake_outlined, 'Joined March 2024', text),
                  ],
                ),
              ),
              const SizedBox(height: ArdentSpacing.s5),
              const Overline('Certificates'),
              const SizedBox(height: ArdentSpacing.s2),
              SurfaceCard(
                child: Column(
                  children: [
                    _certificate('Employee of the Quarter', 'Q1 2026', text),
                    const Divider(height: ArdentSpacing.s5),
                    _certificate('5 Years of Service', '2024', text),
                  ],
                ),
              ),
              const SizedBox(height: ArdentSpacing.s6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label, TextTheme text) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: text.headlineMedium?.copyWith(fontSize: 22)),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 34, color: ArdentColors.border);

  Widget _aboutLine(IconData icon, String label, TextTheme text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: ArdentColors.fg3),
          const SizedBox(width: ArdentSpacing.s3),
          Expanded(child: Text(label, style: text.bodyLarge)),
        ],
      ),
    );
  }

  Widget _certificate(String title, String year, TextTheme text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ArdentColors.statusPendingBg,
            borderRadius: BorderRadius.circular(ArdentRadii.sm),
          ),
          child: const Icon(Icons.workspace_premium_rounded,
              color: Color(0xFFC77700), size: 22),
        ),
        const SizedBox(width: ArdentSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium?.copyWith(fontSize: 14)),
              Text(year, style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
