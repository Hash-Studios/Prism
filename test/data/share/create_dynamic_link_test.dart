import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_app_analytics.dart';

class _ThrowingAnalytics extends FakeAppAnalytics {
  @override
  Future<void> track(AnalyticsEvent event) => throw StateError('analytics down');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async => true,
    );
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    AnalyticsRuntime.reset();
  });

  Future<T> withApi<T>(Future<T> Function() body, http.Client client) => http.runWithClient(body, () => client);

  bool copiedToClipboard() => platformCalls.any((call) => call.method == 'Clipboard.setData');

  test('returns the short link without touching the clipboard', () async {
    final client = MockClient((_) async => http.Response('{"short_url":"https://prismwalls.com/s/abc"}', 200));

    final link = await withApi(
      () => createDynamicLink('wall1', WallpaperSource.prism, 'https://img/full.jpg', 'https://img/thumb.jpg'),
      client,
    );

    expect(link, 'https://prismwalls.com/s/abc');
    expect(copiedToClipboard(), isFalse);
  });

  test('falls back to the canonical link when the link service is down', () async {
    final client = MockClient((_) async => throw http.ClientException('offline'));

    final link = await withApi(
      () => createDynamicLink('wall1', WallpaperSource.prism, null, 'https://img/thumb.jpg'),
      client,
    );

    expect(link, startsWith('https://prismwalls.com/share?'));
    expect(link, contains('id=wall1'));
  });

  test('sends the title, or a default, in the link preview', () async {
    final bodies = <String>[];
    final client = MockClient((request) async {
      bodies.add(request.body);
      return http.Response('{}', 200);
    });

    await withApi(() => createDynamicLink('w', WallpaperSource.prism, null, 't', title: 'Wallpaper by Akshay'), client);
    await withApi(() => createDynamicLink('w', WallpaperSource.prism, null, 't'), client);

    expect(bodies[0], contains('"title":"Wallpaper by Akshay"'));
    expect(bodies[1], contains('"title":"Wallpaper on Prism"'));
  });

  test('does not throw when analytics fails', () async {
    AnalyticsRuntime.instance = _ThrowingAnalytics();
    final client = MockClient((_) async => http.Response('{"short_url":"https://prismwalls.com/s/abc"}', 200));

    final link = await withApi(() => createDynamicLink('wall1', WallpaperSource.prism, null, 't'), client);

    expect(link, isNotNull);
  });

  test('copyWallpaperLink copies the link with the invite text', () async {
    final client = MockClient((_) async => http.Response('{"short_url":"https://prismwalls.com/s/abc"}', 200));

    final copied = await withApi(() => copyWallpaperLink('wall1', WallpaperSource.prism, null, 't'), client);

    expect(copied, isTrue);
    final call = platformCalls.singleWhere((c) => c.method == 'Clipboard.setData');
    expect((call.arguments as Map)['text'], 'Hey check this out ➜ https://prismwalls.com/s/abc');
  });

  test('records the success event once', () async {
    final fake = FakeAppAnalytics();
    AnalyticsRuntime.instance = fake;
    final client = MockClient((_) async => http.Response('{"short_url":"https://prismwalls.com/s/abc"}', 200));

    await withApi(() => createDynamicLink('wall1', WallpaperSource.prism, null, 't'), client);

    expect(fake.events.whereType<DynamicLinkCreateResultEvent>().single.result, EventResultValue.success);
  });
}
