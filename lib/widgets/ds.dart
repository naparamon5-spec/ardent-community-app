import 'package:flutter/material.dart';

import '../theme/ardent_colors.dart';

/// Small shared building blocks mirroring the web `ds/*` components
/// (DsAvatar, DsChip) and the `.ds-overline` type helper.

class DsAvatar extends StatelessWidget {
  const DsAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 40,
    this.online,
    this.imageUrl,
  });

  final String initials;
  final Color color;
  final double size;

  /// When non-null, draws a presence dot (green online / gray offline).
  final bool? online;

  /// The user's uploaded profile photo. When set (and it loads), it replaces
  /// the coloured initials circle; a load failure falls back to the initials.
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initialsAvatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
    final avatar = (imageUrl == null || imageUrl!.isEmpty)
        ? initialsAvatar
        : ClipOval(
            child: Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initialsAvatar,
            ),
          );
    if (online == null) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: online! ? const Color(0xFF2FAE5C) : ArdentColors.gray400,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Status chip, mirroring web `DsChip` status variants.
class DsChip extends StatelessWidget {
  const DsChip({
    super.key,
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
  });

  final String label;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ArdentRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercase section label, mirroring `.ds-overline`.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall);
  }
}

/// White bordered surface, mirroring the web card
/// (`background:#fff; border:1px solid var(--border); radius: md`).
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(ArdentSpacing.s4),
      decoration: BoxDecoration(
        color: ArdentColors.bgSurface,
        border: Border.all(color: ArdentColors.border),
        borderRadius: BorderRadius.circular(ArdentRadii.md),
      ),
      child: child,
    );
  }
}
