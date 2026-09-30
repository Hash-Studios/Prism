import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A pill for filters and choices. Selected chips invert: text colour fill, surface colour label.
class PrismChip extends StatelessWidget {
  const PrismChip({super.key, required this.label, this.selected = false, this.onTap, this.icon, this.leading});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Replaces [icon], for example a colour dot.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = selected ? cs.surface : cs.onSurface;
    return PressScale(
      enabled: onTap != null,
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: AnimatedContainer(
            duration: context.motion(PrismDurations.fast),
            curve: PrismCurves.enter,
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: PrismSpace.xs),
            decoration: BoxDecoration(
              color: selected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(PrismRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (leading != null) ...<Widget>[leading!, const SizedBox(width: 6)],
                if (leading == null && icon != null) ...<Widget>[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 14, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
