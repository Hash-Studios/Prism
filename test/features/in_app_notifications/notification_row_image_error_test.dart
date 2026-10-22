import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import 'in_app_notification_fixture.dart';

class _Cache extends Mock implements BaseCacheManager {}

void main() {
  late BaseCacheManager previous;
  late Directory directory;
  late _Cache cache;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('notification-image-error-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    previous = CachedNetworkImageProvider.defaultCacheManager;
  });
  tearDownAll(() async {
    await previous.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await directory.delete(recursive: true);
  });
  setUp(() {
    cache = _Cache();
    CachedNetworkImageProvider.defaultCacheManager = cache;
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });
  tearDown(() {
    CachedNetworkImageProvider.defaultCacheManager = previous;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    AnalyticsRuntime.reset();
  });

  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  for (final (String name, Object error) in <(String, Object)>[
    ('HTTP 404', const HttpExceptionWithStatus(404, 'fixture missing')),
    ('transport', const SocketException('fixture offline')),
  ]) {
    testWidgets('a $name image failure shows a visible fallback in the media slot', (tester) async {
      when(
        () => cache.getFileStream(any(), withProgress: any(named: 'withProgress')),
      ).thenAnswer((_) => Stream<FileResponse>.error(error));
      final item = notification('image-error').copyWith(imageUrl: 'https://example.test/$name.jpg');

      await tester.pumpWidget(host(NotificationRow(notification: item)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final Finder image = find.byType(CachedNetworkImage);
      expect(tester.getSize(image).height, 180);
      expect(find.descendant(of: image, matching: find.byIcon(JamIcons.picture)), findsOneWidget);
      expect(find.descendant(of: image, matching: find.byType(ColoredBox)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a notification without an image has no media slot', (tester) async {
    await tester.pumpWidget(host(NotificationRow(notification: notification('no-image').copyWith(imageUrl: ''))));

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(JamIcons.picture), findsNothing);
  });
}
