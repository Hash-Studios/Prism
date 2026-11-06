import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/shop/domain/cosmetic_styles.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Stands in for another user's profile while it loads: cover, avatar and text blocks in the final, centred layout.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Size screen = MediaQuery.sizeOf(context);
    final double top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: <Widget>[
          PrismSkeleton(
            child: Column(
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    PrismBone(height: screen.height * 0.19, radius: 0),
                    Positioned(
                      bottom: -37,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
                        child: const Padding(padding: EdgeInsets.all(4), child: PrismBone.circle(size: 78)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 37 + PrismSpace.md),
                const PrismBone(width: 160, height: 24),
                const SizedBox(height: PrismSpace.xs),
                const PrismBone(width: 100),
                const SizedBox(height: PrismSpace.sm),
                const PrismBone(width: 220),
                const SizedBox(height: PrismSpace.md),
                const PrismBone(width: 180, height: 20),
              ],
            ),
          ),
          Positioned(
            top: top + PrismSpace.xxs,
            left: PrismSpace.xs,
            child: PrismIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onImage: true,
              onPressed: () => context.router.maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The equipped name glow as a short gradient line under the profile name. Nothing when no glow is equipped.
class NameGlowUnderline extends StatelessWidget {
  const NameGlowUnderline({super.key, required this.glowId});

  final String? glowId;

  @override
  Widget build(BuildContext context) {
    final String? id = glowId;
    if (id == null || shopItem(id)?.kind != ShopItemKind.nameGlow) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: PrismSpace.xxs),
      child: Container(
        key: const ValueKey<String>('name-glow-underline'),
        width: 40,
        height: 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          gradient: LinearGradient(colors: glowStyle(id).colors),
        ),
      ),
    );
  }
}
