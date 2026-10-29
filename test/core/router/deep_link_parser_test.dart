import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/router/deep_link_route_catalog.dart';
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

  test('parses share ids and provider aliases without requiring image URLs', () {
    for (final (String provider, String wallId, WallpaperSource source) in <(String, String, WallpaperSource)>[
      ('Prism', 'prism-id', WallpaperSource.prism),
      ('Wallhaven', 'wallhaven-id', WallpaperSource.wallhaven),
      ('Pexels', 'pexels-id', WallpaperSource.pexels),
    ]) {
      final String link = 'https://prismwalls.com/share?id=$wallId&provider=$provider';
      final ShareLinkIntent share = parser.parse(Uri.parse(link)) as ShareLinkIntent;

      expect(share.wallId, wallId, reason: link);
      expect(share.source, source, reason: link);
      expect(share.wallpaperUrl, isEmpty, reason: link);
      expect(share.thumbnailUrl, isEmpty, reason: link);
    }

    final Uri transformed = parser.transform(Uri.parse('prism://share/custom-id'));
    final ShareLinkIntent customScheme = parser.parse(transformed) as ShareLinkIntent;
    expect(customScheme.wallId, 'custom-id');
    expect(customScheme.wallpaperUrl, isEmpty);
    expect(customScheme.thumbnailUrl, isEmpty);
  });

  test('image URLs cannot make a share link valid without a non-blank id', () {
    for (final String link in <String>[
      'https://prismwalls.com/share?thumb=https%3A%2F%2Fevil.example%2Fthumb.jpg',
      'https://prismwalls.com/share?id=%20%20&url=https%3A%2F%2Fevil.example%2Ffull.jpg',
      'prism://share?thumb=https%3A%2F%2Fevil.example%2Fthumb.jpg&url=https%3A%2F%2Fevil.example%2Ffull.jpg',
    ]) {
      expect(parser.parse(Uri.parse(link)), isA<UnknownIntent>(), reason: link);
    }
  });

  test('parses canonical user path link', () {
    final DeepLinkActionEntity action = parser.parse(Uri.parse('https://prismwalls.com/user/alice'));

    expect(action, isA<PageLinkIntent>());
    expect((action as PageLinkIntent).path, '/user/alice');
  });

  test('parses canonical folder path link', () {
    final DeepLinkActionEntity action = parser.parse(Uri.parse('https://prismwalls.com/folder/AbC123_x-9'));

    expect(action, isA<PageLinkIntent>());
    expect((action as PageLinkIntent).path, '/folder/AbC123_x-9');
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

  test('parses the economy screen links', () {
    const Set<String> expected = <String>{'shop', 'drops', 'leaderboard', 'draw'};
    for (final String root in expected) {
      for (final String link in <String>[
        'https://prismwalls.com/$root',
        'prism://$root',
        'https://prismwalls.com/${root.toUpperCase()}',
      ]) {
        final DeepLinkActionEntity action = parser.parse(parser.transform(Uri.parse(link)));
        expect(action, isA<PageLinkIntent>(), reason: link);
        expect((action as PageLinkIntent).path.toLowerCase(), '/$root', reason: link);
      }
    }
  });

  test('returns unknown intent for unsupported path', () {
    final DeepLinkActionEntity action = parser.parse(Uri.parse('https://prismwalls.com/something-else'));

    expect(action, isA<UnknownIntent>());
  });

  test('all catalog examples become validated page intents', () {
    for (final DeepLinkRouteExample example in DeepLinkRouteCatalog.examples) {
      final DeepLinkActionEntity action = parser.parse(Uri.parse(example.uri));
      expect(action, isA<PageLinkIntent>(), reason: example.uri);
      final DeepLinkRouteMatch? match = DeepLinkRouteCatalog.match(Uri.parse((action as PageLinkIntent).path));
      expect(match?.target, example.target, reason: example.uri);
    }
  });

  test('invalid catalog routes cannot fall through to permissive legacy parsing', () {
    for (final String link in <String>[
      'https://prismwalls.com/drops/week-1?ignored=x',
      'https://prismwalls.com/user/alice/followers?ignored=x',
      'https://prismwalls.com/user/alice/unknown',
      'https://prismwalls.com/shop?url=https%3A%2F%2Fevil.example',
      'https://prismwalls.com/wallpaper-position?filePath=%2Fetc%2Fpasswd',
      'https://prismwalls.com/wallpaper-detail?wallId=a&wallId=b',
      'https://evil.example/user/alice',
      'file:///etc/passwd',
    ]) {
      expect(parser.parse(Uri.parse(link)), isA<UnknownIntent>(), reason: link);
    }
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
    for (final link in <String>['https://prismwalls.com/l?code=%FF', 'https://prismwalls.com/user/%FF']) {
      expect(parser.parse(Uri.parse(link)), isA<UnknownIntent>().having((action) => action.rawUri, 'rawUri', link));
    }
  });

  test('the router transform safely transports malformed links while preserving their invalid outcome', () {
    for (final link in <String>[
      'https://prismwalls.com/user/%FF',
      'https://prismwalls.com/l?code=%FF',
      'prism://%FF/alice',
    ]) {
      final Uri transformed = parser.transform(Uri.parse(link));
      expect(parser.parse(Uri.parse(link)), isA<UnknownIntent>().having((action) => action.rawUri, 'rawUri', link));
      expect(transformed.pathSegments, <String>['not-found']);
      expect(transformed.queryParameters.values, <String>['1']);
      expect(parser.parse(transformed), isA<UnknownIntent>());
      expect(parser.transform(transformed), transformed);
    }
    expect(parser.parse(Uri.parse('/not-found')), isA<PageLinkIntent>());
  });

  group('roots that the Android manifest and the iOS association file claim', () {
    test('share, user, setup, refer and l each parse', () {
      expect(parser.parse(Uri.parse('https://prismwalls.com/share?id=a&thumb=t')), isA<ShareLinkIntent>());
      expect(parser.parse(Uri.parse('https://prismwalls.com/user/alice')), isA<PageLinkIntent>());
      expect(parser.parse(Uri.parse('https://prismwalls.com/setup/desk')), isA<SetupLinkIntent>());
      expect(parser.parse(Uri.parse('https://prismwalls.com/refer/u1')), isA<ReferLinkIntent>());
      expect(parser.parse(Uri.parse('https://prismwalls.com/l/abc')), isA<ShortCodeIntent>());
    });

    test('older aliases still resolve', () {
      expect(parser.parse(Uri.parse('https://prismwalls.com/profile/alice')), isA<UserLinkIntent>());
      expect(parser.parse(Uri.parse('https://prismwalls.com/follower-profile?email=a%40b.c')), isA<UserLinkIntent>());
      expect(parser.parse(Uri.parse('https://prismwalls.com/share-setup/desk')), isA<SetupLinkIntent>());
      expect(parser.parse(Uri.parse('https://prismwalls.com/referral/u1')), isA<ReferLinkIntent>());
    });

    test('www.prismwalls.com parses like the bare domain', () {
      final DeepLinkActionEntity action = parser.parse(Uri.parse('https://www.prismwalls.com/user/alice'));

      expect(action, isA<PageLinkIntent>());
      expect((action as PageLinkIntent).path, '/user/alice');
    });

    test('the prism scheme parses every root', () {
      expect(parser.parse(parser.transform(Uri.parse('prism://share/abc?thumb=t'))), isA<ShareLinkIntent>());
      expect(parser.parse(parser.transform(Uri.parse('prism://user/alice'))), isA<PageLinkIntent>());
      expect(parser.parse(parser.transform(Uri.parse('prism://refer/u1'))), isA<ReferLinkIntent>());
      expect(parser.parse(parser.transform(Uri.parse('prism://l/abc'))), isA<ShortCodeIntent>());
    });

    test('web pages and look-alike paths stay unknown', () {
      for (final String path in <String>['privacy', 'terms', 'legal', 'u/alice', 'shared']) {
        expect(parser.parse(Uri.parse('https://prismwalls.com/$path')), isA<UnknownIntent>(), reason: path);
      }
      expect(parser.parse(Uri.parse('https://prismwalls.com/')), isA<PageLinkIntent>());
      expect(parser.parse(Uri.parse('https://prismwalls.com/l')), isA<UnknownIntent>());
    });
  });

  test('the Wall of the Day tile link for a protected wall opens that wall', () {
    final ShareLinkIntent share =
        parser.parse(Uri.parse('prism://share?id=protected-doc&source=prism&url&thumb=preview')) as ShareLinkIntent;

    expect(share.wallId, 'protected-doc');
    expect(share.source, WallpaperSource.prism);
    expect(share.wallpaperUrl, '');
    expect(share.thumbnailUrl, 'preview');
  });
}
