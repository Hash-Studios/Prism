import 'package:Prism/core/constants/profile_links.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileLinkKind _kind(String name) => profileLinkKinds.firstWhere((kind) => kind.name == name);

void main() {
  group('sanitizeProfileLink', () {
    test('keeps an https link and adds https to a bare domain', () {
      expect(sanitizeProfileLink(_kind('github'), 'https://github.com/prism'), 'https://github.com/prism');
      expect(sanitizeProfileLink(_kind('github'), ' github.com/prism '), 'https://github.com/prism');
    });

    test('allows http', () {
      expect(sanitizeProfileLink(_kind('custom link'), 'http://example.com/me'), 'http://example.com/me');
    });

    test('refuses schemes other than https, http and mailto', () {
      for (final String raw in <String>[
        'javascript:alert(1)//github',
        'file:///etc/passwd',
        'tel:+123456789',
        'intent://scan/#Intent;scheme=zxing;end',
        'prism://user/github',
        'data:text/html,github',
      ]) {
        expect(sanitizeProfileLink(_kind('custom link'), raw), isNull, reason: raw);
        expect(sanitizeProfileLink(_kind('github'), raw), isNull, reason: raw);
      }
    });

    test('needs a host', () {
      expect(sanitizeProfileLink(_kind('custom link'), 'https://'), isNull);
      expect(sanitizeProfileLink(_kind('custom link'), 'http:///path'), isNull);
    });

    test('refuses a link that does not match its kind', () {
      expect(sanitizeProfileLink(_kind('github'), 'https://example.com/me'), isNull);
    });

    test('accepts current and legacy Buy Me a Coffee hosts', () {
      for (final String host in <String>[
        'buymeacoffee.com',
        'www.buymeacoffee.com',
        'buymeacoff.ee',
        'www.buymeacoff.ee',
      ]) {
        for (final String scheme in <String>['https', 'http']) {
          final String url = '$scheme://$host/prism?ref=profile#support';
          expect(sanitizeProfileLink(_kind('buymeacoffee'), url), url, reason: url);
        }
        expect(sanitizeProfileLink(_kind('buymeacoffee'), ' $host/prism '), 'https://$host/prism');
        expect(
          sanitizeProfileLink(_kind('buymeacoffee'), 'https://${host.toUpperCase()}/prism'),
          'https://$host/prism',
        );
      }
    });

    test('Buy Me a Coffee matches the host rather than text elsewhere in the URL', () {
      for (final String host in <String>['buymeacoffee.com', 'buymeacoff.ee']) {
        for (final String raw in <String>[
          'https://$host.example.com/prism',
          'https://not$host/prism',
          'https://creator.$host/prism',
          'https://$host@example.com/prism',
          'https://example.com/$host/prism',
          'https://example.com/prism?ref=$host',
          'https://example.com/prism#$host',
        ]) {
          expect(sanitizeProfileLink(_kind('buymeacoffee'), raw), isNull, reason: raw);
        }
      }
    });

    test('Buy Me a Coffee still refuses unsafe schemes and mailto', () {
      for (final String raw in <String>[
        'javascript:alert(1)//buymeacoffee.com',
        'file://buymeacoff.ee/prism',
        'mailto:prism@buymeacoffee.com',
        'https://',
      ]) {
        expect(sanitizeProfileLink(_kind('buymeacoffee'), raw), isNull, reason: raw);
      }
    });

    test('empty text is not a link', () {
      expect(sanitizeProfileLink(_kind('custom link'), '   '), isNull);
    });

    test('email links stay a bare address and work for any provider', () {
      expect(sanitizeProfileLink(_kind('email'), 'me@example.com'), 'me@example.com');
      expect(sanitizeProfileLink(_kind('email'), 'mailto:me@proton.me'), 'me@proton.me');
      expect(sanitizeProfileLink(_kind('email'), 'not-an-email'), isNull);
      expect(sanitizeProfileLink(_kind('email'), 'https://example.com'), isNull);
    });

    test('a mailto link is only valid as a custom link', () {
      expect(sanitizeProfileLink(_kind('custom link'), 'mailto:me@example.com'), 'mailto:me@example.com');
      expect(sanitizeProfileLink(_kind('github'), 'mailto:me@github.com'), isNull);
    });
  });

  group('safeProfileLinkUri', () {
    test('opens a bare email address as mailto, whatever the provider', () {
      expect(safeProfileLinkUri('me@example.com').toString(), 'mailto:me@example.com');
      expect(safeProfileLinkUri('me@outlook.com')!.scheme, 'mailto');
    });

    test('accepts links saved before the scheme was required', () {
      expect(safeProfileLinkUri('instagram.com/prism').toString(), 'https://instagram.com/prism');
    });

    test('refuses unsafe schemes and missing hosts', () {
      expect(safeProfileLinkUri('javascript:alert(1)'), isNull);
      expect(safeProfileLinkUri('https://'), isNull);
      expect(safeProfileLinkUri(''), isNull);
    });
  });
}
