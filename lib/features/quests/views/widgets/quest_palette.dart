import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The fill, lip and outline of one game panel.
class PanelColors {
  const PanelColors({required this.top, required this.bottom, required this.lip, required this.ink});

  final Color top;
  final Color bottom;

  /// The thick edge under the panel that makes it look raised.
  final Color lip;

  /// The outline, the text stroke and the dark chips on the panel.
  final Color ink;

  @override
  bool operator ==(Object other) =>
      other is PanelColors && other.top == top && other.bottom == bottom && other.lip == lip && other.ink == ink;

  @override
  int get hashCode => Object.hash(top, bottom, lip, ink);
}

/// Every colour of the quest board. Daily panels take the accent's hue, the weekly panel is gold, a done panel goes grey.
class QuestPalette {
  QuestPalette._({required this.dark, required this.hue, required this.gold});

  factory QuestPalette.of(ColorScheme colorScheme) {
    final HSLColor accent = HSLColor.fromColor(colorScheme.primary);
    return QuestPalette._(
      dark: colorScheme.brightness == Brightness.dark,
      hue: accent.saturation < _greyAccentSaturation ? _fallbackHue : accent.hue,
      gold: WheelGold(),
    );
  }

  /// An accent below this saturation is grey (AMOLED white, Frost) and has no hue to take.
  static const double _greyAccentSaturation = 0.12;

  /// The hue of the default pink accent, used when the accent is grey.
  static const double _fallbackHue = 340;

  final bool dark;
  final double hue;
  final WheelGold gold;

  Color _hsl(double saturation, double lightness) => HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();

  PanelColors get daily => PanelColors(
    top: _hsl(0.78, dark ? 0.62 : 0.66),
    bottom: _hsl(0.72, dark ? 0.44 : 0.5),
    lip: _hsl(0.7, dark ? 0.26 : 0.34),
    ink: _hsl(0.6, 0.1),
  );

  PanelColors get weekly => PanelColors(top: gold.light, bottom: gold.deep, lip: gold.dark, ink: gold.ink);

  PanelColors get done => PanelColors(
    top: _hsl(0.14, dark ? 0.36 : 0.7),
    bottom: _hsl(0.12, dark ? 0.26 : 0.6),
    lip: _hsl(0.12, dark ? 0.16 : 0.45),
    ink: _hsl(0.2, 0.1),
  );

  PanelColors panelFor(QuestTileModel quest) => quest.done
      ? done
      : quest.scope == QuestScope.weekly
      ? weekly
      : daily;

  /// Title text on a panel. It always has an [PanelColors.ink] stroke under it.
  Color get title => Colors.white;

  Color get gloss => Colors.white.withValues(alpha: 0.28);

  Color get fillTop => HSLColor.fromColor(PrismColors.success).withLightness(0.68).toColor();

  Color get fillBottom => PrismColors.success;

  /// The tag on the weekly panel: the accent, so it stands out on gold.
  Color get ribbon => _hsl(0.82, dark ? 0.52 : 0.48);
}
