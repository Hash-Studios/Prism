import 'dart:convert';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final List<String> toastMessages = <String>[];
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    toastMessages.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  test('maps canonical user link to profile route', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.mapUriToRoute(Uri.parse('https://prismwalls.com/user/alice'));

    expect(route, isA<ProfileRoute>());
  });

  test('maps a legacy setup link to the home tab', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.mapUriToRoute(Uri.parse('https://prismwalls.com/setup/minimal-desk'));

    expect(route, isA<HomeTabRoute>());
    expect(toastMessages, <String>['Home screen setups are no longer available.']);
  });

  test('custom-scheme setup links map to home and show the legacy link toast', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.mapUriToRoute(Uri.parse('prism://setup/minimal-desk'));

    expect(route, isA<HomeTabRoute>());
    expect(toastMessages, <String>['Home screen setups are no longer available.']);
  });

  test('setup short links map to home without resolving recursively', () async {
    final http.Client client = MockClient((request) async {
      expect(request.url.path, '/api/links/setup123');
      return http.Response('{"canonical_url":"https://prismwalls.com/share-setup?name=desk"}', 200);
    });
    final DeepLinkNavigation navigation = DeepLinkNavigation(httpClient: client);
    final route = await navigation.mapUriToRoute(Uri.parse('prism://l/setup123'));

    expect(route, isA<HomeTabRoute>());
    expect(toastMessages, <String>['Home screen setups are no longer available.']);
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
