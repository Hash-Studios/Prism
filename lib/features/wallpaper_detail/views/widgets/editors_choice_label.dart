import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The Editors' Choice pill shown on a wall the editors picked.
class EditorsChoiceLabel extends StatelessWidget {
  const EditorsChoiceLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = cs.onSecondaryContainer;
    return Semantics(
      label: context.l10n.editorsChoiceLabelSemantics,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(PrismRadius.pill)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  context.l10n.editorsChoiceTitle,
                  style: PrismTextStyles.caption(context).copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
