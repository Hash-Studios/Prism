import 'package:Prism/features/theme_mode/data/theme_mode_migration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps Dark for an install that ran an older build and never stored a mode', () {
    expect(initialThemeModeToStore(storedMode: null, hasLegacyMarker: true), 'Dark');
  });

  test('gives a fresh install System', () {
    expect(initialThemeModeToStore(storedMode: null, hasLegacyMarker: false), 'System');
  });

  test('leaves a stored mode alone', () {
    expect(initialThemeModeToStore(storedMode: 'Light', hasLegacyMarker: true), isNull);
    expect(initialThemeModeToStore(storedMode: 'System', hasLegacyMarker: true), isNull);
  });
}
