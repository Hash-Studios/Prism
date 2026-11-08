import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const DeepLinkParser parser = DeepLinkParser();

  test('parses a shared image id with its source app', () {
    final DeepLinkActionEntity action = parser.parse(
      Uri.parse('prism://share-in?id=123e4567-e89b-12d3-a456-426614174000&src=com.android.chrome'),
    );

    expect(action, isA<ShareInIntent>());
    final ShareInIntent share = action as ShareInIntent;
    expect(share.inboxId, '123e4567-e89b-12d3-a456-426614174000');
    expect(share.text, isNull);
    expect(share.sourceApp, 'com.android.chrome');
  });

  test('decodes shared text from the query', () {
    final DeepLinkActionEntity action = parser.parse(
      Uri.parse('prism://share-in?text=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1%26c%3Dd%2Be'),
    );

    expect(action, isA<ShareInIntent>());
    final ShareInIntent share = action as ShareInIntent;
    expect(share.text, 'https://example.com/a?b=1&c=d+e');
    expect(share.inboxId, isNull);
  });

  test('rejects shares that are not one valid id or one text', () {
    for (final String link in <String>[
      'prism://share-in?id=123e4567-e89b-12d3-a456-426614174000&text=x',
      'prism://share-in',
      'prism://share-in?id=../etc',
      'prism://share-in?id=123E4567-E89B-12D3-A456-426614174000',
      'prism://share-in?text=x&extra=1',
      'prism://share-in?text=${'a' * 2049}',
      'https://prismwalls.com/share-in?text=x',
      'prism://share-in/extra?text=x',
    ]) {
      expect(parser.parse(Uri.parse(link)), isA<UnknownIntent>(), reason: link);
    }
  });

  test('drops a source app that is not a package name, but keeps the share', () {
    for (final String source in <String>['com.android%20chrome', 'com%2Fandroid']) {
      final DeepLinkActionEntity action = parser.parse(Uri.parse('prism://share-in?text=x&src=$source'));

      expect(action, isA<ShareInIntent>(), reason: source);
      expect((action as ShareInIntent).sourceApp, isNull, reason: source);
    }
  });

  test('maps a share to the shared item target type', () {
    expect(
      DeepLinkNavigation.targetType(const ShareInIntent(text: 'x', rawUri: 'prism://share-in?text=x')),
      TargetTypeValue.sharedItem,
    );
  });
}
