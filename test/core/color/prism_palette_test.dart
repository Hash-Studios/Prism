import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the palette has the twelve contract colours in order', () {
    expect(prismPalette.map((c) => (c.id, c.hex, c.pexelsName)), <(String, String, String)>[
      ('red', 'cc0000', 'red'),
      ('orange', 'ff6600', 'orange'),
      ('yellow', 'ffcc33', 'yellow'),
      ('green', '669900', 'green'),
      ('teal', '66cccc', 'turquoise'),
      ('blue', '0066cc', 'blue'),
      ('purple', '663399', 'violet'),
      ('pink', 'ea4c88', 'pink'),
      ('brown', '663300', 'brown'),
      ('black', '000000', 'black'),
      ('grey', '999999', 'gray'),
      ('white', 'ffffff', 'white'),
    ]);
  });

  test('color is the opaque colour of the hex', () {
    expect(paletteColorById('blue')!.color, const Color(0xFF0066CC));
    expect(paletteColorById('black')!.color, const Color(0xFF000000));
  });

  test('paletteColorById finds a colour and returns null for an unknown id', () {
    expect(paletteColorById('teal')!.name, 'Teal');
    expect(paletteColorById('cyan'), isNull);
    expect(paletteColorById(null), isNull);
  });

  test('palette display names come from localized color copy without changing ids', () {
    final AppLocalizations l10n = AppLocalizationsEn();

    expect(prismPaletteColorDisplayName(paletteColorById('red')!, l10n), 'Red');
    expect(prismPaletteColorDisplayName(paletteColorById('grey')!, l10n), 'Grey');
    expect(paletteColorById('red')!.id, 'red');
  });

  test('every palette colour is its own nearest colour', () {
    for (final PrismPaletteColor entry in prismPalette) {
      expect(nearestPaletteColor(entry.color), entry, reason: entry.id);
    }
  });

  test('typical accent colours map to the colour a person would name', () {
    expect(nearestPaletteColor(const Color(0xFFE53935)).id, 'red');
    expect(nearestPaletteColor(const Color(0xFF1E88E5)).id, 'blue');
    expect(nearestPaletteColor(const Color(0xFF43A047)).id, 'green');
    expect(nearestPaletteColor(const Color(0xFF8E24AA)).id, 'purple');
    expect(nearestPaletteColor(const Color(0xFFFB8C00)).id, 'orange');
    expect(nearestPaletteColor(const Color(0xFFFFEB3B)).id, 'yellow');
    expect(nearestPaletteColor(const Color(0xFFF06292)).id, 'pink');
    expect(nearestPaletteColor(const Color(0xFF26C6DA)).id, 'teal');
    expect(nearestPaletteColor(const Color(0xFF5D4037)).id, 'brown');
  });

  test('neutrals map to black, grey and white', () {
    expect(nearestPaletteColor(const Color(0xFF111111)).id, 'black');
    expect(nearestPaletteColor(const Color(0xFF808080)).id, 'grey');
    expect(nearestPaletteColor(const Color(0xFFB0B0B0)).id, 'grey');
    expect(nearestPaletteColor(const Color(0xFFF4F4F4)).id, 'white');
  });

  test('alpha does not change the result', () {
    expect(nearestPaletteColor(const Color(0x331E88E5)).id, 'blue');
  });
}
