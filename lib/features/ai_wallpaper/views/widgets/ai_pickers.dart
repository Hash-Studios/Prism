import 'dart:math' as math;

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_wallpaper_helpers.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A horizontal row of style tiles. The selected tile has an accent ring and a tick. When [selected] changes, the row
/// scrolls the tile into view.
class AiStylePicker extends StatefulWidget {
  const AiStylePicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: PrismSpace.page),
  });

  static const double tileWidth = 96;
  static const double tileHeight = 120;
  static const double _gap = PrismSpace.xs;

  final AiStylePreset selected;
  final ValueChanged<AiStylePreset> onSelected;
  final bool enabled;
  final EdgeInsets padding;

  @override
  State<AiStylePicker> createState() => _AiStylePickerState();
}

class _AiStylePickerState extends State<AiStylePicker> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(AiStylePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _reveal(animate: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Centres the selected tile when any part of it is out of view.
  void _reveal({required bool animate}) {
    if (!mounted || !_scroll.hasClients) return;
    final ScrollPosition position = _scroll.position;
    final double start = widget.padding.left + widget.selected.index * (AiStylePicker.tileWidth + AiStylePicker._gap);
    final double end = start + AiStylePicker.tileWidth;
    if (start >= position.pixels && end <= position.pixels + position.viewportDimension) return;
    final double target = (start - (position.viewportDimension - AiStylePicker.tileWidth) / 2).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (!animate) {
      position.jumpTo(target);
      return;
    }
    _scroll.animateOrJump(target, duration: context.motion(PrismDurations.base), curve: PrismCurves.move);
  }

  @override
  Widget build(BuildContext context) {
    // A fixed extent per tile keeps maxScrollExtent exact before the far tiles are built, so _reveal can reach them.
    return SizedBox(
      height: AiStylePicker.tileHeight,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: widget.padding.copyWith(right: math.max(0, widget.padding.right - AiStylePicker._gap)),
        itemExtent: AiStylePicker.tileWidth + AiStylePicker._gap,
        itemCount: AiStylePreset.values.length,
        itemBuilder: (_, int index) {
          final AiStylePreset style = AiStylePreset.values[index];
          return Align(
            alignment: Alignment.centerLeft,
            child: _StyleTile(
              style: style,
              selected: style == widget.selected,
              onTap: widget.enabled
                  ? () {
                      PrismHaptics.selection();
                      widget.onSelected(style);
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }
}

/// The sample image of [style] over its gradient. The gradient shows while the image loads and stays when the image
/// fails or the device is offline. The image fills the parent's box, so nothing moves when it arrives.
class AiStyleSample extends StatelessWidget {
  const AiStyleSample({super.key, required this.style, required this.size});

  final AiStylePreset style;
  final AiStyleSampleSize size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: style.swatchColors),
      ),
      child: CachedNetworkImage(
        imageUrl: style.sampleUrl(size),
        cacheManager: PrismImageCache.instance,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: context.motion(PrismDurations.base),
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// The accent tick on a selected style. It pops in and fades out.
class AiStyleTick extends StatelessWidget {
  const AiStyleTick({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return AnimatedOpacity(
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.md);
    return Semantics(
      button: true,
      selected: selected,
      label: l10n.economyAiStyleSemantics(aiStyleLabel(l10n, style)),
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
            width: AiStylePicker.tileWidth,
            height: AiStylePicker.tileHeight,
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
                  AiStyleSample(style: style, size: AiStyleSampleSize.tile),
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
                      aiStyleLabel(l10n, style),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 13, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    top: PrismSpace.xs,
                    right: PrismSpace.xs,
                    child: AiStyleTick(selected: selected),
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
                      PrismHaptics.selection();
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: l10n.economyAiQualitySemantics(
        aiQualityLabel(l10n, tier),
        tier.costFor(isPro: app_state.prismUser.premium),
      ),
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
                Text(aiQualityLabel(l10n, tier), style: PrismTextStyles.rowTitle(context)),
                const SizedBox(height: PrismSpace.xxs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const PrismCoinIcon(size: 14),
                    const SizedBox(width: PrismSpace.xxs),
                    Text(
                      '${tier.costFor(isPro: app_state.prismUser.premium)}',
                      style: PrismTextStyles.caption(context),
                    ),
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
