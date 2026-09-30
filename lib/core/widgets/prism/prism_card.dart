import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The app's card: a raised surface with a hairline border. Do not nest a [PrismCard] in a [PrismCard].
class PrismCard extends StatelessWidget {
  const PrismCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.radius = PrismRadius.lg,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Defaults to `surfaceContainerHigh`.
  final Color? color;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius br = BorderRadius.circular(radius);
    final Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerHigh,
        borderRadius: br,
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return PressScale(
      scale: 0.98,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card),
      ),
    );
  }
}

/// A [PrismCard] that holds rows (usually [PrismRow]s) with a hairline between them. Used for settings lists.
class PrismGroup extends StatelessWidget {
  const PrismGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PrismCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PrismRadius.lg - 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) Divider(height: 1, indent: 60, color: cs.onSurface.withValues(alpha: 0.06)),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
