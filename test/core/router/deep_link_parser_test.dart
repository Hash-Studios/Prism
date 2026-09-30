import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const DeepLinkParser parser = DeepLinkParser();

  test('parses canonical share link', () {
    final DeepLinkActionEntity action = parser.parse(
      Uri.parse('https://prismwalls.com/share?id=abc&provider=Prism&url=https%3A%2F%2Fimg&thumb=https%3A%2F%2Fthumb'),
    );

    expect(action, isA<ShareLinkIntent>());
    final ShareLinkIntent share = action as ShareLinkIntent;
    expect(share.wallId, 'abc');
    expect(share.source, WallpaperSource.prism);
    expect(share.wallpaperUrl, 'https://img');
    expect(share.thumbnailUrl, 'https://thumb');
  });

  test('parses canonical user path link', () {
    final DeepLinkActionEntity action = parser.parse(Uri.parse('https://prismwalls.com/user/alice'));

    expect(action, isA<UserLinkIntent>());
    expect((action as UserLinkIntent).profileIdentifier, 'alice');
  });

  test('parses legacy user alias link', () {
    final DeepLinkActionEntity action = parser.parse(Uri.parse('https://prismwalls.com/fprofile?username=bob'));

    expect(action, isA<UserLinkIntent>());
    expect((action as UserLinkIntent).profileIdentifier, 'bob');
  });

  test('parses legacy setup links as a setup intent', () {
    expect(parser.parse(Uri.parse('https://prismwalls.com/setup/minimal-desk')), isA<SetupLinkIntent>());
    expect(parser.parse(Uri.parse('prism://share-setup?name=desk')), isA<SetupLinkIntent>());
    expect(parser.parse(parser.transform(Uri.parse('https://prismwalls.com/setup/%FF'))), isA<SetupLinkIntent>());
  });

  test('parses legacy refer query link', () {
    final DeepLinkActionEntity action = parser.parse(Uri.parse('https://prismwalls.com/refer?userID=u123'));

    expect(action, isA<ReferLinkIntent>());
    expect((action as ReferLinkIntent).inviterId, 'u123');
  });

  test('returns unknown intent for unsupported path', () {
    final DeepLinkActionEntity action = parser.parse(Uri.parse('https://prismwalls.com/something-else'));

    expect(action, isA<UnknownIntent>());
  });

  test('normalizes custom-scheme deep links for router', () {
    final Uri transformed = parser.transform(Uri.parse('prism://user/alice'));
    expect(transformed.path, '/user/alice');
    expect(parser.parse(transformed), isA<UserLinkIntent>());
    final action = parser.parse(parser.transform(Uri.parse('prism://l/abc')));
    expect((action as ShortCodeIntent).code, 'abc');
    expect(parser.transform(transformed), transformed);
  });

  test('normalization preserves an escaped slash inside a path component', () {
    final uri = Uri.parse('prism://user/alice%2Fsmith');
    final transformed = parser.transform(uri);
    expect(transformed.path, '/user/alice%2Fsmith');
    expect((parser.parse(transformed) as UserLinkIntent).profileIdentifier, 'alice/smith');
  });

  test('decodes percent signs only once in short codes and wallpaper URLs', () {
    final code = parser.parse(parser.transform(Uri.parse('https://prismwalls.com/l/%25')));
    expect((code as ShortCodeIntent).code, '%');
    const url = 'https://img.example/wall%20name.jpg';
    final share = parser.parse(Uri.https('prismwalls.com', '/share', <String, String>{'id': 'wall', 'url': url}));
    expect((share as ShareLinkIntent).wallpaperUrl, url);
  });

  test('malformed short-code query data returns unknown without throwing', () {
    expect(parser.parse(Uri.parse('https://prismwalls.com/l?code=%FF')), isA<UnknownIntent>());
  });

  test('malformed custom-scheme setup suffix still opens the legacy setup intent', () {
    expect(parser.parse(parser.transform(Uri.parse('prism://setup/%FF'))), isA<SetupLinkIntent>());
  });
}
