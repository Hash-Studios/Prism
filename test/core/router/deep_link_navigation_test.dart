import 'dart:convert';

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final List<String> toastMessages = <String>[];
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toastMessages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    toastMessages.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  test('maps canonical user link to profile route', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.routeForUri(Uri.parse('https://prismwalls.com/user/alice'));

    expect(route, isA<ProfileRoute>());
  });

  test('maps a legacy setup link to the home tab', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.routeForUri(Uri.parse('https://prismwalls.com/setup/minimal-desk'));

    expect(route, isA<HomeTabRoute>());
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, <String>['Home screen setups are no longer available.']);
  });

  test('custom-scheme setup links map to home and show the legacy link toast', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.routeForUri(Uri.parse('prism://setup/minimal-desk'));

    expect(route, isA<HomeTabRoute>());
    await Future<void>.delayed(Duration.zero);
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
    final route = await navigation.routeForUri(Uri.parse('https://prismwalls.com/l/u5lmmUq0'));

    expect(route, isA<WallpaperDetailRoute>());
  });

  test('id-only short links open the exact wallpaper detail route args', () async {
    final http.Client client = MockClient((request) async {
      expect(request.url.toString(), 'https://prismwalls.com/api/links/short-code');
      return http.Response(
        jsonEncode(<String, dynamic>{'canonical_url': 'https://prismwalls.com/share?id=short-wall&provider=Prism'}),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    addTearDown(client.close);

    final route = await DeepLinkNavigation(
      httpClient: client,
    ).routeForUri(Uri.parse('https://prismwalls.com/l/short-code'));

    expect(route, isA<WallpaperDetailRoute>());
    final WallpaperDetailRouteArgs args = (route! as WallpaperDetailRoute).args!;
    expect(args.wallId, 'short-wall');
    expect(args.source, WallpaperSource.prism);
    expect(args.thumbnailUrl, isEmpty);
    expect(args.analyticsSurface, AnalyticsSurfaceValue.shareWallpaperView);
    expect(args.entity, isNull);
    expect(args.localFile, isNull);
  });

  test('direct share links route by id with the exact provider source', () async {
    for (final (String provider, String wallId, WallpaperSource source) in <(String, String, WallpaperSource)>[
      ('Prism', 'prism-wall', WallpaperSource.prism),
      ('Wallhaven', 'wallhaven-wall', WallpaperSource.wallhaven),
      ('Pexels', 'pexels-wall', WallpaperSource.pexels),
    ]) {
      final route = await const DeepLinkNavigation().routeForUri(
        Uri.parse('https://prismwalls.com/share?id=$wallId&provider=$provider'),
      );

      expect(route, isA<WallpaperDetailRoute>(), reason: provider);
      final WallpaperDetailRouteArgs args = (route! as WallpaperDetailRoute).args!;
      expect(args.wallId, wallId, reason: provider);
      expect(args.source, source, reason: provider);
      expect(args.thumbnailUrl, isEmpty, reason: provider);
      expect(args.analyticsSurface, AnalyticsSurfaceValue.shareWallpaperView, reason: provider);
      expect(args.entity, isNull, reason: provider);
      expect(args.localFile, isNull, reason: provider);
    }
  });

  test('a supplied full image URL cannot become a wallpaper entity or local-file route', () async {
    final route = await const DeepLinkNavigation().routeForUri(
      Uri.parse(
        'https://prismwalls.com/share?id=hostile-wall&source=wallhaven&url=https%3A%2F%2Fevil.example%2Ffull.jpg',
      ),
    );

    expect(route, isA<WallpaperDetailRoute>());
    final WallpaperDetailRouteArgs args = (route! as WallpaperDetailRoute).args!;
    expect(args.wallId, 'hostile-wall');
    expect(args.source, WallpaperSource.wallhaven);
    expect(args.entity, isNull);
    expect(args.localFile, isNull);
  });

  test('returns null for unknown links', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.routeForUri(Uri.parse('https://prismwalls.com/unknown/path'));
    expect(route, isNull);
  });

  test('a nested canonical short link stops after one request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(jsonEncode(<String, String>{'canonical_url': 'prism://l/other'}), 200);
    });
    final navigation = DeepLinkNavigation(httpClient: client);
    expect(await navigation.routeForUri(Uri.parse('prism://l/abc')), isNull);
    expect(calls, 1);
  });

  test('resolves a canonical custom-scheme user link', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(<String, String>{'canonical_url': 'prism://user/alice'}), 200),
    );
    final navigation = DeepLinkNavigation(httpClient: client);
    final route = await navigation.routeForUri(Uri.parse('prism://l/abc'));
    expect(route, isA<ProfileRoute>());
    expect((route! as ProfileRoute).args?.profileIdentifier, 'alice');
    client.close();
  });

  test('economy screen links open their routes', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    expect(await navigation.routeForUri(Uri.parse('https://prismwalls.com/shop')), isA<ShopRoute>());
    expect(await navigation.routeForUri(Uri.parse('prism://drops')), isA<DropsRoute>());
    expect(await navigation.routeForUri(Uri.parse('prism://leaderboard')), isA<LeaderboardRoute>());
    expect(await navigation.routeForUri(Uri.parse('https://prismwalls.com/draw')), isA<DrawRoute>());
  });

  test('a referral link keeps the inviter and opens Rewards instead of Not found', () async {
    final List<String> inviters = <String>[];
    final DeepLinkNavigation navigation = DeepLinkNavigation(onReferral: (String id) async => inviters.add(id));

    for (final String link in <String>['https://prismwalls.com/refer/inviter1', 'prism://refer/inviter1']) {
      expect(await navigation.routeForUri(Uri.parse(link)), isA<RewardsTabRoute>());
    }

    expect(inviters, <String>['inviter1', 'inviter1']);
  });

  test('a referral link opened by a guest is saved for sign-in', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);

    final route = await const DeepLinkNavigation().routeForUri(Uri.parse('https://prismwalls.com/refer/inviter1'));

    expect(route, isA<RewardsTabRoute>());
    expect(settings.get<String>('pendingReferralInviterId', defaultValue: ''), 'inviter1');
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages.single, startsWith('Referral saved. Sign in to claim'));
  });
}

extension on DeepLinkNavigation {
  Future<PageRouteInfo?> routeForUri(Uri uri) async => (await resolveAction(parser.parse(uri))).route;
}
