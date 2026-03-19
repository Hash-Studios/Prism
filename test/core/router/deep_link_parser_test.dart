import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/deep_link/domain/entities/deep_link_action_entity.dart';
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

  test('parses canonical setup path without thumbnail query', () {
    final DeepLinkActionEntity action = parser.parse(Uri.parse('https://prismwalls.com/setup/minimal-desk'));

    expect(action, isA<SetupLinkIntent>());
    final SetupLinkIntent setup = action as SetupLinkIntent;
    expect(setup.setupName, 'minimal-desk');
    expect(setup.thumbnailUrl, isEmpty);
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
}
