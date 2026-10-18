import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

class OddsPill extends StatelessWidget {
  const OddsPill({super.key, required this.onTap});

  static const double height = 44;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PressScale(
      child: Semantics(
        button: true,
        label: 'See the odds',
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: height),
            child: Center(
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PrismRadius.pill),
                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurface),
                      const SizedBox(width: 6),
                      Text('See the odds', style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
