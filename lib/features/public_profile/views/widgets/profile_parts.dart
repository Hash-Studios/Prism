import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

enum ProfileMenuAction { report, block }

/// The report and block menu of another user's profile. The menu itself is themed globally.
class ProfileOverflowMenu extends StatelessWidget {
  const ProfileOverflowMenu({required this.onSelected});

  final ValueChanged<ProfileMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PressScale(
      child: PopupMenuButton<ProfileMenuAction>(
        tooltip: 'More options',
        onSelected: onSelected,
        icon: const Icon(Icons.more_horiz_rounded, size: 22),
        iconColor: Colors.white,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.38),
          fixedSize: const Size.square(44),
          minimumSize: const Size.square(44),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<ProfileMenuAction>>[
          const PopupMenuItem<ProfileMenuAction>(
            value: ProfileMenuAction.report,
            child: _MenuLabel(icon: Icons.flag_outlined, label: 'Report user'),
          ),
          PopupMenuItem<ProfileMenuAction>(
            value: ProfileMenuAction.block,
            child: _MenuLabel(icon: Icons.block_rounded, label: 'Block user', color: cs.error),
          ),
        ],
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color fg = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 20, color: fg),
        const SizedBox(width: PrismSpace.sm),
        Text(label, style: PrismTextStyles.rowTitle(context).copyWith(color: fg)),
      ],
    );
  }
}

/// Stands in for another user's profile while it loads: cover, avatar and text blocks in the final layout.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: <Widget>[
          PrismSkeleton(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    PrismBone(height: 170 + top, radius: 0),
                    Positioned(
                      left: PrismSpace.page,
                      bottom: -45,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
                        child: const Padding(padding: EdgeInsets.all(3), child: PrismBone.circle(size: 84)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 45 + PrismSpace.xs),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: PrismSpace.page),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(height: PrismSpace.sm),
                      PrismBone(width: 140, height: 28),
                      SizedBox(height: PrismSpace.xs),
                      PrismBone(width: 100),
                      SizedBox(height: PrismSpace.md),
                      PrismBone(width: 240),
                      SizedBox(height: PrismSpace.md),
                      Row(
                        children: <Widget>[
                          PrismBone(width: 56, height: 36),
                          SizedBox(width: PrismSpace.lg),
                          PrismBone(width: 56, height: 36),
                          SizedBox(width: PrismSpace.lg),
                          PrismBone(width: 56, height: 36),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: top + PrismSpace.xxs,
            left: PrismSpace.xs,
            child: PrismIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onImage: true,
              onPressed: () => context.router.maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
