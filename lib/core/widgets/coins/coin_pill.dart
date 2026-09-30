import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The shell of the coin and streak pills: a hairline-bordered capsule. With [onTap] it is a 44 point tap target
/// that scales on press.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.onTap,
    this.tint,
    this.borderColor,
    this.compact = false,
  });

  final Widget child;
  final String semanticLabel;
  final VoidCallback? onTap;

  /// Fill colour. Defaults to no fill.
  final Color? tint;

  /// Border colour. Defaults to the hairline.
  final Color? borderColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget pill = DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(PrismRadius.pill),
        border: Border.all(color: borderColor ?? cs.onSurface.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? PrismSpace.xs : PrismSpace.sm, vertical: 7),
        child: child,
      ),
    );
    if (onTap == null) {
      return Semantics(label: semanticLabel, excludeSemantics: true, child: pill);
    }
    return PressScale(
      child: Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(widthFactor: 1, child: pill),
          ),
        ),
      ),
    );
  }
}

/// A coin balance in a pill. [delta] is the last change: it shows beside the balance until it clears.
class CoinBalancePill extends StatelessWidget {
  const CoinBalancePill({super.key, required this.balance, this.delta = 0, this.low = false, this.onTap});

  final int balance;
  final int delta;

  /// The balance is low: the border turns to the warning colour.
  final bool low;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool earned = delta > 0;
    final Color? accent = earned
        ? PrismColors.success
        : low
        ? PrismColors.warning
        : null;
    final Color deltaColor = earned ? Color.lerp(PrismColors.success, cs.onSurface, 0.25)! : cs.onSurfaceVariant;
    return AnimatedScale(
      scale: delta == 0 ? 1 : 1.06,
      duration: context.motion(PrismDurations.base),
      curve: PrismCurves.pop,
      child: StatPill(
        semanticLabel: '$balance Prism coins',
        onTap: onTap,
        tint: earned ? PrismColors.success.withValues(alpha: 0.12) : null,
        borderColor: accent?.withValues(alpha: 0.6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const PrismCoinIcon(size: 18),
            const SizedBox(width: 6),
            Text('$balance', style: PrismTextStyles.rowTitle(context)),
            if (delta != 0) ...<Widget>[
              const SizedBox(width: 6),
              Icon(earned ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: deltaColor),
              Text(
                '${delta.abs()}',
                style: PrismTextStyles.caption(context).copyWith(color: deltaColor, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
