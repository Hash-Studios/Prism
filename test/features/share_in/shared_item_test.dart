import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/features/share_in/domain/shared_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sharedItemFromText', () {
    test('reads a short link from the text around it', () {
      final SharedItem? item = sharedItemFromText('Look at this https://prismwalls.com/l/AbC123');

      expect(item, isA<SharedPrismLink>());
      final SharedPrismLink link = item! as SharedPrismLink;
      expect(link.action, isA<ShortCodeIntent>());
      expect((link.action as ShortCodeIntent).code, 'AbC123');
      expect(link.kind, SharedItemKind.prismLink);
    });

    test('reads Prism wall, folder and share pages as Prism links', () {
      final SharedItem? wall = sharedItemFromText('https://prismwalls.com/wallpaper/wall1');
      expect(wall, isA<SharedPrismLink>());
      expect((wall! as SharedPrismLink).action, isA<PageLinkIntent>());

      final SharedItem? folder = sharedItemFromText('https://prismwalls.com/folder/abc123');
      expect(folder, isA<SharedPrismLink>());

      final SharedItem? share = sharedItemFromText('https://www.prismwalls.com/share/w1?source=prism');
      expect(share, isA<SharedPrismLink>());
      expect((share! as SharedPrismLink).action, isA<ShareLinkIntent>());
    });

    test('treats a Prism page that the app does not open as a plain URL', () {
      final SharedItem? item = sharedItemFromText('https://prismwalls.com/privacy');

      expect(item, isA<SharedUrl>());
      expect(item!.kind, SharedItemKind.url);
    });

    test('removes trailing punctuation from a link', () {
      final SharedItem? period = sharedItemFromText('Great read: https://example.com/a/b?x=1.');
      expect(period, isA<SharedUrl>());
      expect((period! as SharedUrl).uri, Uri.parse('https://example.com/a/b?x=1'));

      final SharedItem? paren = sharedItemFromText('(see https://example.com/a/b?x=1)');
      expect(paren, isA<SharedUrl>());
      expect((paren! as SharedUrl).uri, Uri.parse('https://example.com/a/b?x=1'));
    });

    test('returns null when the text has no usable link', () {
      expect(sharedItemFromText('no links here'), isNull);
      expect(sharedItemFromText(''), isNull);
    });

    test('ignores a share link that would nest a share', () {
      expect(sharedItemFromText('prism://share-in?text=x'), isNull);
    });

    test('maps each item to its kind', () {
      final Uri uri = Uri.parse('https://example.com');
      expect(SharedPrismLink(uri, const UnknownIntent(rawUri: 'x')).kind, SharedItemKind.prismLink);
      expect(const SharedImage('/tmp/a.png').kind, SharedItemKind.image);
      expect(SharedUrl(uri).kind, SharedItemKind.url);
    });
  });
}
