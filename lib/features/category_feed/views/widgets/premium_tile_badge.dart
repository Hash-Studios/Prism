import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

/// A small "Pro" lock for a wallpaper or collection tile. It sits on a surface-coloured pill so it stays readable on
/// any image and any theme.
class PremiumTileBadge extends StatelessWidget {
  const PremiumTileBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(PrismRadius.pill),
      ),
      child: const PrismTag(label: 'Pro', tone: PrismTone.warning, icon: Icons.lock_rounded),
    );
  }
}
