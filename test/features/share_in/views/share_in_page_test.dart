import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/share_in/biz/share_in_resolver.dart';
import 'package:Prism/features/share_in/views/widgets/share_in_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/wait_for_real_io.dart';

class _ShareRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('Host', builder: (_) => const Scaffold(body: Text('Host'))),
    ),
    AutoRoute(
      path: '/wallpaper-filter',
      page: PageInfo(WallpaperFilterRoute.name, builder: (_) => const Text('Editor')),
    ),
    AutoRoute(
      path: '/edit-wall',
      page: PageInfo(EditWallRoute.name, builder: (_) => const Text('Edit upload')),
    ),
    AutoRoute(
      path: '/upload-wall',
      page: PageInfo(UploadWallRoute.name, builder: (_) => const Text('Upload')),
    ),
    CustomRoute(
      path: '/share-in',
      page: ShareInRoute.page,
      opaque: false,
      duration: Duration.zero,
      reverseDuration: Duration.zero,
    ),
  ];
}

/// Advances the fake clock past the sheet's entrance and exit animations. The sheet's loading and failed states
/// animate forever, so pumpAndSettle would never return while the sheet is open.
Future<void> _settleSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  const MethodChannel channel = MethodChannel('prism/shared_inbox');
  const MethodChannel paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  late _ShareRouter router;
  late File file;

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()..loggedIn = true;
    directory = Directory.systemTemp.createTempSync('share_page_');
    file = File('${directory.path}/unreadable.png')..writeAsBytesSync(<int>[1, 2, 3]);
    router = _ShareRouter();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'take') return file.path;
      return directory.path;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      paths,
      (_) async => directory.path,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    directory.deleteSync(recursive: true);
    router.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, ShareInIntent intent) async {
    final DeepLinkRouteResolution? result = await tester.runAsync(
      () => resolveShareIn(intent, const DeepLinkNavigation()),
    );
    unawaited(router.navigate(result!.route!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a second share replaces the old sheet and deletes its unreadable image', (tester) async {
    await mount(tester);
    await open(tester, const ShareInIntent(inboxId: '123e4567-e89b-12d3-a456-426614174000', rawUri: 'image'));
    await waitForRealIo(
      tester,
      () => find.text('Prism cannot open this image.').evaluate().isNotEmpty,
      reason: 'unreadable image sheet',
    );

    await open(tester, const ShareInIntent(text: 'not a link', rawUri: 'text'));
    await waitForRealIo(tester, () => !file.existsSync(), reason: 'superseded share cleanup');
    await waitForRealIo(
      tester,
      () => find.text('Prism cannot use this link.').evaluate().isNotEmpty,
      reason: 'link sheet',
    );
    await _settleSheet(tester);

    expect(find.byType(ShareInSheet), findsOneWidget);
    expect(find.text('Prism cannot use this link.'), findsOneWidget);
    expect(find.text('Prism cannot open this image.'), findsNothing);
    await router.navigatorKey.currentState!.maybePop();
    await _settleSheet(tester);
    expect(router.topRoute.name, 'Host');
  });

  testWidgets('a missing native image keeps the image error message', (tester) async {
    await mount(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'take') throw PlatformException(code: 'missing');
      return directory.path;
    });
    await open(tester, const ShareInIntent(inboxId: '123e4567-e89b-12d3-a456-426614174000', rawUri: 'image'));
    await waitForRealIo(
      tester,
      () => find.text('Prism cannot open this image.').evaluate().isNotEmpty,
      reason: 'unreadable image sheet',
    );
    expect(find.text('Prism cannot open this image.'), findsOneWidget);
    expect(find.text('Prism cannot use this link.'), findsNothing);
    await router.navigatorKey.currentState!.maybePop();
    await _settleSheet(tester);
  });

  testWidgets('Set keeps the shared-image privacy flag and deletes its file after the editor closes', (tester) async {
    file.writeAsBytesSync(
      base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='),
    );
    await mount(tester);
    await open(tester, const ShareInIntent(inboxId: '123e4567-e89b-12d3-a456-426614174000', rawUri: 'image'));
    await waitForRealIo(
      tester,
      () => find.text('Set as wallpaper').evaluate().isNotEmpty,
      reason: 'shared image decode',
    );
    await _settleSheet(tester);
    await tester.tap(find.text('Set as wallpaper'));
    await _settleSheet(tester);
    await waitForRealIo(tester, () => router.topRoute.name == WallpaperFilterRoute.name, reason: 'image hand-off');
    final WallpaperFilterRouteArgs args = router.topRoute.argsAs<WallpaperFilterRouteArgs>();
    expect(args.guestShare, isTrue);
    final String path = args.filePath;
    expect(file.existsSync(), isFalse);
    expect(File(path).existsSync(), isTrue);
    expect(find.byType(ShareInSheet), findsNothing);
    await router.maybePop();
    await _settleSheet(tester);
    await waitForRealIo(tester, () => !File(path).existsSync(), reason: 'completed hand-off cleanup');
  });
  for (final bool proceedToUpload in <bool>[false, true]) {
    testWidgets('Upload cleans its source after ${proceedToUpload ? 'Upload' : 'Edit'} closes', (tester) async {
      file.writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        ),
      );
      await mount(tester);
      await open(tester, const ShareInIntent(inboxId: '123e4567-e89b-12d3-a456-426614174000', rawUri: 'image'));
      await waitForRealIo(
        tester,
        () => find.text('Upload to Prism').evaluate().isNotEmpty,
        reason: 'shared image decode',
      );
      await _settleSheet(tester);
      await tester.tap(find.text('Upload to Prism'));
      await _settleSheet(tester);
      await waitForRealIo(tester, () => router.topRoute.name == EditWallRoute.name, reason: 'upload hand-off');
      final File source = router.topRoute.argsAs<EditWallRouteArgs>().image;
      expect(source.existsSync(), isTrue);
      if (proceedToUpload) {
        unawaited(router.replace(UploadWallRoute(image: source)));
        await _settleSheet(tester);
        expect(source.existsSync(), isTrue, reason: 'Upload still needs the same source after Edit is replaced');
      }
      await router.maybePop();
      await _settleSheet(tester);
      await waitForRealIo(tester, () => !source.existsSync(), reason: 'upload source cleanup');
    });
  }
}
