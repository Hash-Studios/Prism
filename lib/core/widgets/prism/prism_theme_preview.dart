import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A small picture of the app in [theme]'s colours: the page, an ink title bar, two wallpaper tiles and an accent
/// pill. Theme pickers and the shop use it so a theme shows as the app, not as a swatch.
///
/// It fills the width it gets at a phone's proportions. It is decorative: the caller labels it, for example with the
/// theme name below it.
class PrismThemePreview extends StatelessWidget {
  const PrismThemePreview({super.key, required this.theme});

  final ThemeData theme;

  static const List<String> _walls = <String>['assets/images/wallpaper.jpg', 'assets/images/onboarding_bg_primary.jpg'];

  /// Decode width for the tiles. A tile is about 50 points wide in a three-column grid.
  static const int _cacheWidth = 240;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = theme.colorScheme;
    const BorderRadius shape = BorderRadius.all(Radius.circular(PrismRadius.sm));
    const BorderRadius tile = BorderRadius.all(Radius.circular(PrismRadius.xs - 2));
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 0.62,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          child: ClipRRect(
            borderRadius: shape,
            child: ColoredBox(
              color: cs.surface,
              child: Padding(
                padding: const EdgeInsets.all(PrismSpace.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FractionallySizedBox(
                      widthFactor: 0.55,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: cs.onSurface,
                          borderRadius: BorderRadius.circular(PrismRadius.pill),
                        ),
                      ),
                    ),
                    const SizedBox(height: PrismSpace.xs),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (int i = 0; i < _walls.length; i++) ...<Widget>[
                            if (i > 0) const SizedBox(width: PrismSpace.xxs + 2),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: tile,
                                child: Image.asset(
                                  _walls[i],
                                  fit: BoxFit.cover,
                                  cacheWidth: _cacheWidth,
                                  errorBuilder: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: PrismSpace.xs),
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(PrismRadius.pill),
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
      ),
    );
  }
}
