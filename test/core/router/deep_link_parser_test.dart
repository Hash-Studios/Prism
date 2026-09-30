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
  });

  test('custom-scheme links keep their ids after the router transform', () {
    final Uri transformed = parser.transform(Uri.parse('prism://share/abc?url=https%3A%2F%2Fimg'));
    expect((parser.parse(transformed) as ShareLinkIntent).wallId, 'abc');
    expect(parser.transform(transformed), transformed);
  });

  test('share link thumbnail keeps its escaped characters (Firebase Storage path)', () {
    const String thumb = 'https://firebasestorage.googleapis.com/v0/b/x/o/walls%2Fa.png?alt=media';
    final ShareLinkIntent share =
        parser.parse(Uri.https('prismwalls.com', '/share', <String, String>{'id': 'abc', 'thumb': thumb}))
            as ShareLinkIntent;
    expect(share.thumbnailUrl, thumb);
  });

  test('a short code with an escaped percent sign parses without throwing', () {
    final DeepLinkActionEntity action = parser.parse(parser.transform(Uri.parse('https://prismwalls.com/l/%25')));
    expect((action as ShortCodeIntent).code, '%');
  });

  test('malformed percent encoding returns unknown without throwing', () {
    expect(parser.parse(Uri.parse('https://prismwalls.com/l?code=%FF')), isA<UnknownIntent>());
    expect(parser.parse(Uri.parse('https://prismwalls.com/user/%FF')), isA<UnknownIntent>());
  });

  test('the router transform sends malformed links to not-found before auto_route decodes them', () {
    expect(parser.transform(Uri.parse('https://prismwalls.com/user/%FF')), Uri(path: '/not-found'));
    expect(parser.transform(Uri.parse('https://prismwalls.com/l?code=%FF')), Uri(path: '/not-found'));
  });

  test('the router transform rejects a malformed custom-scheme host moved into the path', () {
    final Uri transformed = parser.transform(Uri.parse('prism://%FF/alice'));

    expect(transformed.pathSegments, <String>['not-found']);
    expect(transformed.queryParameters, isEmpty);
    expect(transformed, Uri(path: '/not-found'));
  });
}
