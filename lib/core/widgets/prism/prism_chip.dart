import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A pill for filters and choices. Selected chips invert: text colour fill, surface colour label.
class PrismChip extends StatelessWidget {
  const PrismChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.leading,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Replaces [icon], for example a colour dot.
  final Widget? leading;

  /// A smaller pill (34 tall, 13 pt label) for a scrolling row of shortcuts. The tap area stays 44 tall.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = selected ? cs.surface : cs.onSurface;
    return PressScale(
      enabled: onTap != null,
      child: Semantics(
        container: true,
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () {
                  PrismHaptics.selection();
                  onTap!();
                },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 5 : 0),
            child: AnimatedContainer(
              duration: context.motion(PrismDurations.fast),
              curve: PrismCurves.enter,
              constraints: BoxConstraints(minWidth: 44, minHeight: compact ? 34 : 44),
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 6 : PrismSpace.xs),
              decoration: BoxDecoration(
                color: selected ? cs.onSurface : cs.onSurface.withValues(alpha: compact ? 0.08 : 0.06),
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
                      style: PrismTextStyles.rowTitle(context).copyWith(fontSize: compact ? 13 : 14, color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
