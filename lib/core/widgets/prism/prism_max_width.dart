import 'dart:math' as math;

import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/widgets.dart';

/// Centres [child] in a column no wider than [maxWidth]. When the space is narrower, as on a phone, [child] gets the
/// same constraints it would get without this widget.
class PrismMaxWidth extends StatelessWidget {
  const PrismMaxWidth({super.key, this.maxWidth = PrismLayout.readableWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double side = constraints.hasBoundedWidth ? math.max(0, (constraints.maxWidth - maxWidth) / 2) : 0;
        // One tree at every width, so a rotation across the cap keeps the child's state.
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: side),
          child: child,
        );
      },
    );
  }
}
