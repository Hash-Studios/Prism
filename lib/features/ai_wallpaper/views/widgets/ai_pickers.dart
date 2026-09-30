import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A horizontal row of style tiles. The selected tile has an accent ring and a tick.
class AiStylePicker extends StatelessWidget {
  const AiStylePicker({super.key, required this.selected, required this.onSelected, this.enabled = true});

  final AiStylePreset selected;
  final ValueChanged<AiStylePreset> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
        itemCount: AiStylePreset.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: PrismSpace.xs),
        itemBuilder: (_, int index) {
          final AiStylePreset style = AiStylePreset.values[index];
          return _StyleTile(
            style: style,
            selected: style == selected,
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    onSelected(style);
                  }
                : null,
          );
        },
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({required this.style, required this.selected, required this.onTap});

  final AiStylePreset style;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.md);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Style: ${style.label}',
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        enabled: onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: context.motion(PrismDurations.fast),
            curve: PrismCurves.enter,
            width: 96,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: style.swatchColors,
              ),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.08),
                width: selected ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: PrismSpace.sm,
                    right: PrismSpace.sm,
                    bottom: PrismSpace.sm,
                    child: Text(
                      style.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 13, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    top: PrismSpace.xs,
                    right: PrismSpace.xs,
                    child: AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: context.motion(PrismDurations.fast),
                      child: AnimatedScale(
                        scale: selected ? 1 : 0.8,
                        duration: context.motion(PrismDurations.fast),
                        curve: PrismCurves.pop,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(Icons.check_rounded, size: 14, color: cs.onPrimary),
                          ),
                        ),
                      ),
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

/// Three quality options with the coin cost of each.
class AiQualityPicker extends StatelessWidget {
  const AiQualityPicker({super.key, required this.selected, required this.onSelected, this.enabled = true});

  final AiQualityTier selected;
  final ValueChanged<AiQualityTier> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < AiQualityTier.values.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: PrismSpace.xs),
          Expanded(
            child: _QualityOption(
              tier: AiQualityTier.values[i],
              selected: AiQualityTier.values[i] == selected,
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onSelected(AiQualityTier.values[i]);
                    }
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _QualityOption extends StatelessWidget {
  const _QualityOption({required this.tier, required this.selected, required this.onTap});

  final AiQualityTier tier;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${tier.label}, ${tier.coinCost} coins',
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        enabled: onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: context.motion(PrismDurations.fast),
            curve: PrismCurves.enter,
            padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
            decoration: BoxDecoration(
              color: selected ? cs.primary.withValues(alpha: 0.1) : cs.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(PrismRadius.md),
              border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(tier.label, style: PrismTextStyles.rowTitle(context)),
                const SizedBox(height: PrismSpace.xxs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const PrismCoinIcon(size: 14),
                    const SizedBox(width: PrismSpace.xxs),
                    Text('${tier.coinCost}', style: PrismTextStyles.caption(context)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
