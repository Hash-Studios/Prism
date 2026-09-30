import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The wallpaper's palette as a row of round swatches. The first swatch is the original wallpaper; the rest tint it.
class DetailPalette extends StatelessWidget {
  const DetailPalette({
    super.key,
    required this.thumbnailUrl,
    required this.colors,
    required this.selected,
    required this.onReset,
    required this.onSelect,
    required this.onCopy,
  });

  final String thumbnailUrl;
  final List<Color> colors;

  /// The tint in use, or null for the original wallpaper.
  final Color? selected;
  final VoidCallback onReset;
  final ValueChanged<Color> onSelect;
  final ValueChanged<Color> onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          children: <Widget>[
            _Swatch(
              semanticLabel: 'Original wallpaper colors',
              selected: selected == null,
              onTap: onReset,
              child: thumbnailUrl.isEmpty
                  ? const SizedBox.expand()
                  : CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: context.motion(PrismDurations.fast),
                      errorWidget: (_, _, _) => const SizedBox.expand(),
                    ),
            ),
            for (final Color color in colors)
              _Swatch(
                semanticLabel: 'Accent color #${color.rgbHex.toUpperCase()}',
                hint: 'Hold to copy the color code',
                selected: selected == color,
                onTap: () => onSelect(color),
                onLongPress: () => onCopy(color),
                child: ColoredBox(color: color),
              ),
          ],
        ),
        const SizedBox(height: PrismSpace.xxs),
        Text('Tap to tint the wallpaper. Hold a color to copy it.', style: PrismTextStyles.caption(context)),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
    required this.child,
    this.hint,
    this.onLongPress,
  });

  final String semanticLabel;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      hint: hint,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: AnimatedContainer(
                duration: context.motion(PrismDurations.fast),
                curve: PrismCurves.enter,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
                ),
                child: Container(
                  width: 32,
                  height: 32,
                  foregroundDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.onSurface.withValues(alpha: 0.16)),
                  ),
                  child: ClipOval(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
