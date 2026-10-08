import 'package:Prism/core/share/share_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shareSafeText', () {
    test('keeps a creator name or title and trims it', () {
      expect(shareSafeText('  Wallpaper by Ana Lee '), 'Wallpaper by Ana Lee');
      expect(shareSafeText('by @ana'), 'by @ana');
    });

    test('drops text with an email address in it', () {
      expect(shareSafeText('ana@example.com'), isNull);
      expect(shareSafeText('Wallpaper by ana.lee+art@example.co.uk'), isNull);
      expect(shareSafeText('by ANA@EXAMPLE.COM'), isNull);
    });

    test('drops empty text', () {
      expect(shareSafeText(null), isNull);
      expect(shareSafeText('   '), isNull);
    });
  });
}
