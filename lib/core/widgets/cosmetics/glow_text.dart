import 'package:Prism/features/shop/domain/cosmetic_styles.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:flutter/material.dart';

/// [color] moved towards [ink] in small steps until it reaches 6:1 on [surface], so a light gold stays readable on a
/// white page, also at the edge of the gradient. A colour that already reads is kept as it is.
@visibleForTesting
Color readableGlowStop(Color color, Color ink, Color surface) {
  for (double t = 0; t < 1; t += 0.04) {
    final Color candidate = Color.lerp(color, ink, t)!;
    if (contrastRatio(candidate, surface) >= 6.0) return candidate;
  }
  return ink;
}

/// Text with the equipped name glow: a gradient fill and a soft shadow. Plain text when [glowId] is null or unknown.
class GlowText extends StatelessWidget {
  const GlowText(this.text, {super.key, this.style, this.glowId, this.maxLines, this.overflow, this.textAlign});

  final String text;
  final TextStyle? style;
  final String? glowId;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final String? id = glowId;
    final ShopItem? item = id == null ? null : shopItem(id);
    if (id == null || item == null || item.kind != ShopItemKind.nameGlow) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<Color> colors = <Color>[
      for (final Color c in glowStyle(id).colors) readableGlowStop(c, cs.onSurface, cs.surface),
    ];
    final TextStyle base = style ?? DefaultTextStyle.of(context).style;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => LinearGradient(colors: colors).createShader(bounds),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        // The mask replaces the colour; the text only has to be opaque.
        style: base.copyWith(
          color: Colors.white,
          shadows: <Shadow>[Shadow(color: colors.first.withValues(alpha: 0.3), blurRadius: 6)],
        ),
      ),
    );
  }
}
