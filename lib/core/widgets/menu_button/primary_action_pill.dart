import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The labelled accent button at the end of the action row on the wallpaper detail screen. A spinner takes the place
/// of the label while [isLoading], and the button keeps its width.
class PrimaryActionPill extends StatelessWidget {
  const PrimaryActionPill({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.isLoading,
    this.cost,
  });

  final String label;
  final String semanticLabel;
  final bool isLoading;

  /// Coins the action spends, shown after the label with a coin icon.
  final int? cost;

  @override
  Widget build(BuildContext context) {
    final Color background = Theme.of(context).colorScheme.primary;
    final Color foreground = onColor(background);
    final TextStyle style = TextStyle(
      color: foreground,
      fontFamily: PrismFonts.proximaNova,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: background,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(PrismRadius.md))),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Opacity(
                opacity: isLoading ? 0 : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(child: Text(label, style: style)),
                    if (cost case final int cost) ...<Widget>[
                      const SizedBox(width: PrismSpace.xs),
                      const PrismCoinIcon(size: 14),
                      const SizedBox(width: PrismSpace.xxs),
                      Text('$cost', style: style),
                    ],
                  ],
                ),
              ),
              if (isLoading)
                Positioned.fill(
                  child: Center(
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
