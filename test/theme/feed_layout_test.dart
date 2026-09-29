import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallpaperGridColumns keeps phones at 3/5 and gives tablets more columns', () {
    expect(wallpaperGridColumns(375), 3); // small iPhone, portrait
    expect(wallpaperGridColumns(440), 3); // iPhone Pro Max, portrait
    expect(wallpaperGridColumns(956), 5); // iPhone Pro Max, landscape
    expect(wallpaperGridColumns(1032), 6); // iPad Pro 13, portrait
    expect(wallpaperGridColumns(1376), 8); // iPad Pro 13, landscape
    expect(wallpaperGridColumns(3000), 8); // capped
  });
}
