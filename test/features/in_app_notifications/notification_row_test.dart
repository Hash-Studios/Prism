import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_row.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_visuals.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/wait_for_real_io.dart';

class _Router extends Mock implements RootStackRouter {
  @override
  RootStackRouter get root => this;
}

class _Cache extends Mock implements BaseCacheManager {}

void main() {
  late FakeAppAnalytics analytics;
  setUpAll(() => CachedNetworkImageProvider.defaultCacheManager = _Cache());
  late BaseCacheManager original;
  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    original = CachedNetworkImageProvider.defaultCacheManager;
    final cache = _Cache();
    when(
      () => cache.getFileStream(any(), withProgress: true),
    ).thenAnswer((_) => Stream<FileResponse>.error(StateError('offline')));
    CachedNetworkImageProvider.defaultCacheManager = cache;
  });
  tearDown(() {
    AnalyticsRuntime.reset();
    CachedNetworkImageProvider.defaultCacheManager = original;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  InAppNotificationEntity notice({String body = 'A new wallpaper is ready', String image = '', bool read = false}) =>
      InAppNotificationEntity(
        id: 'n1',
        title: 'Collection update',
        pageName: ' /collections ',
        body: body,
        imageUrl: image,
        arguments: const [],
        url: '',
        createdAt: DateTime.now(),
        read: read,
      );

  Future<void> pump(WidgetTester tester, NotificationRow row) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: _Router(),
        stateHash: 0,
        child: Scaffold(body: row),
      ),
    ),
  );

  testWidgets('opening a route notification marks it read and records the trimmed destination', (tester) async {
    var reads = 0;
    await pump(tester, NotificationRow(notification: notice(), onMarkRead: () => reads++));
    await tester.tap(find.text('Collection update'));
    await tester.pump();
    expect(reads, 1);
    final event = analytics.events.single;
    expect(event.eventName, 'notification_item_opened');
    expect(event.toWireParameters(), containsPair('destination', '/collections'));
    expect(event.toWireParameters(), containsPair('has_external_url', 0));
  });

  testWidgets('compact child uses override, body, then title and omits unread dot after reading', (tester) async {
    await pump(tester, NotificationRow(notification: notice(), compactInGroup: true, compactBodyOverride: '  Ana  '));
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('A new wallpaper is ready'), findsNothing);
    expect(find.byType(UnreadDot), findsOneWidget);
    await pump(tester, NotificationRow(notification: notice(), compactInGroup: true, compactBodyOverride: '  '));
    expect(find.text('A new wallpaper is ready'), findsOneWidget);
    await pump(tester, NotificationRow(notification: notice(body: '', read: true), compactInGroup: true));
    expect(find.text('Collection update'), findsOneWidget);
    expect(find.byType(UnreadDot), findsNothing);
  });

  testWidgets('valid attachment reserves preview space and failed image keeps notification text usable', (
    tester,
  ) async {
    await pump(tester, NotificationRow(notification: notice(image: 'https://example.test/photo.jpg')));
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(tester.getSize(find.byType(CachedNetworkImage)).height, greaterThan(0));
    await waitForRealIo(
      tester,
      () => find
          .descendant(of: find.byType(CachedNetworkImage), matching: find.byIcon(JamIcons.picture))
          .evaluate()
          .isNotEmpty,
      reason: 'failed attachment to render its fallback',
    );
    expect(find.text('A new wallpaper is ready'), findsOneWidget);
    await pump(tester, NotificationRow(notification: notice(image: 'not a URL')));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('Collection update'), findsOneWidget);
  });
}
