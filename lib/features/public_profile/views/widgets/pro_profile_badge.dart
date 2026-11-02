import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Compact Pro pill under the profile header. Grows with large text.
class ProProfileBadge extends StatelessWidget {
  const ProProfileBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      label: context.l10n.profileProBadgeSemantics,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(PrismRadius.pill)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.workspace_premium_rounded, size: 14, color: cs.onPrimaryContainer),
              const SizedBox(width: PrismSpace.xxs),
              Flexible(
                child: Text(
                  context.l10n.profileProBadge,
                  style: text.labelMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
