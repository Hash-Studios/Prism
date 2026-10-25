import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import 'in_app_notification_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });
  tearDown(() {
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
      final item = notification('image-error').copyWith(imageUrl: 'https://example.test/$name.jpg');
      final imageLoad = Completer<ImageInfo>();
      final imageKey = await ResizeImage(
        CachedNetworkImageProvider(item.imageUrl),
        width: tester.view.physicalSize.width.round().clamp(1, 4096),
      ).obtainKey(ImageConfiguration.empty);
      PaintingBinding.instance.imageCache.putIfAbsent(imageKey, () => OneFrameImageStreamCompleter(imageLoad.future));

      await tester.pumpWidget(host(NotificationRow(notification: item)));
      await tester.pump();
      imageLoad.completeError(error);
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
