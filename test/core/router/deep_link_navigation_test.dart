import 'dart:convert';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('maps canonical user link to profile route', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.mapUriToRoute(Uri.parse('https://prismwalls.com/user/alice'));

    expect(route, isA<ProfileRoute>());
  });

  test('resolves /l short code and maps to share wallpaper route', () async {
    final http.Client client = MockClient((request) async {
      if (request.url.toString() == 'https://prismwalls.com/api/links/u5lmmUq0') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'canonical_url':
                'https://prismwalls.com/share?id=Z3EI&provider=Prism&thumb=https%3A%2F%2Fthumb&url=https%3A%2F%2Fimg',
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    final DeepLinkNavigation navigation = DeepLinkNavigation(httpClient: client);
    final route = await navigation.mapUriToRoute(Uri.parse('https://prismwalls.com/l/u5lmmUq0'));

    expect(route, isA<WallpaperDetailRoute>());
  });

  test('returns null for unknown links', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.mapUriToRoute(Uri.parse('https://prismwalls.com/unknown/path'));
    expect(route, isNull);
  });
}
