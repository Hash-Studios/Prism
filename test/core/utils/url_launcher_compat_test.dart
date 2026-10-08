import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('opensInApp', () {
    test('Prism links that the app has a screen for open in the app', () {
      for (final String link in <String>[
        'https://prismwalls.com/share?id=a&thumb=https%3A%2F%2Fthumb',
        'https://prismwalls.com/user/x',
        'https://prismwalls.com/l/abc',
        'https://prismwalls.com/refer/u1',
        'https://www.prismwalls.com/user/x',
        'prism://share/x',
        'prism://user/x',
      ]) {
        expect(opensInApp(Uri.parse(link)), isTrue, reason: link);
      }
    });

    test('the privacy and terms pages and other web paths open in the browser', () {
      for (final String link in <String>[
        'https://prismwalls.com/privacy',
        'https://prismwalls.com/terms',
        'https://www.prismwalls.com/privacy',
        'https://prismwalls.com/',
        'https://prismwalls.com/share',
      ]) {
        expect(opensInApp(Uri.parse(link)), isFalse, reason: link);
      }
    });

    test('links to other sites are never opened in the app', () {
      expect(opensInApp(Uri.parse('https://example.com/user/x')), isFalse);
      expect(opensInApp(Uri.parse('mailto:hi@prismwalls.com')), isFalse);
    });
  });
}
