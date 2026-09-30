import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Fill, hairline and soft shadow shared by the floating pill, the create button and the back-to-top button.
BoxDecoration navBarDecoration(BuildContext context, {bool circle = false}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: cs.surfaceContainerHigh,
    shape: circle ? BoxShape.circle : BoxShape.rectangle,
    borderRadius: circle ? null : BorderRadius.circular(PrismRadius.pill),
    border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
    boxShadow: <BoxShadow>[
      BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10)),
    ],
  );
}
