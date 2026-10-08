import 'dart:convert';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
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
    final route = await navigation.mapUriToRoute(Uri.parse('https://prismwalls.com/user/alice'));

    expect(route, isA<ProfileRoute>());
  });

  test('maps a legacy setup link to the home tab', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.mapUriToRoute(Uri.parse('https://prismwalls.com/setup/minimal-desk'));

    expect(route, isA<HomeTabRoute>());
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages, <String>['Home screen setups are no longer available.']);
  });

  test('custom-scheme setup links map to home and show the legacy link toast', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.mapUriToRoute(Uri.parse('prism://setup/minimal-desk'));

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
    final route = await navigation.mapUriToRoute(Uri.parse('https://prismwalls.com/l/u5lmmUq0'));

    expect(route, isA<WallpaperDetailRoute>());
  });

  test('returns null for unknown links', () async {
    const DeepLinkNavigation navigation = DeepLinkNavigation();
    final route = await navigation.mapUriToRoute(Uri.parse('https://prismwalls.com/unknown/path'));
    expect(route, isNull);
  });

  test('a referral link keeps the inviter and opens Rewards instead of Not found', () async {
    final List<String> inviters = <String>[];
    final DeepLinkNavigation navigation = DeepLinkNavigation(onReferral: (String id) async => inviters.add(id));

    for (final String link in <String>['https://prismwalls.com/refer/inviter1', 'prism://refer/inviter1']) {
      expect(await navigation.mapUriToRoute(Uri.parse(link)), isA<RewardsTabRoute>());
    }

    expect(inviters, <String>['inviter1', 'inviter1']);
  });

  test('a referral link opened by a guest is saved for sign-in', () async {
    await getIt.reset();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(getIt.reset);

    final route = await const DeepLinkNavigation().mapUriToRoute(Uri.parse('https://prismwalls.com/refer/inviter1'));

    expect(route, isA<RewardsTabRoute>());
    expect(settings.get<String>('pendingReferralInviterId', defaultValue: ''), 'inviter1');
    await Future<void>.delayed(Duration.zero);
    expect(toastMessages.single, startsWith('Referral saved. Sign in to claim'));
  });
}
