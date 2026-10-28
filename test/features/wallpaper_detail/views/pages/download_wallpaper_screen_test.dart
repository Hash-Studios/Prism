import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_wallpaper_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_app_analytics.dart';

class _Client implements WallpaperClient {
  final List<aw.StaticWallpaperRequest> requests = <aw.StaticWallpaperRequest>[];

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async => const aw.WallpaperCapabilities();

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async {
    requests.add(request);
    return aw.WallpaperOperationResult(status: aw.WallpaperOperationStatus.applied, requestedTarget: request.target);
  }

  @override
  Future<aw.WallpaperOperationResult> prepareVideoWallpaper(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> openLiveWallpaperPreview(aw.VideoWallpaperRequest request) =>
      throw UnimplementedError();

  @override
  Future<aw.WallpaperOperationResult> applyOpenGlWallpaper(aw.OpenGlLiveWallpaperRequest request) =>
      throw UnimplementedError();
}

void main() {
  final File file = File('assets/images/prism.webp').absolute;
  late FakeAppAnalytics analytics;
  late _Client client;
  late List<SetScreenRequest> opened;
  late Future<SetWallpaperChoice?> Function(BuildContext context, SetScreenRequest request) originalOpener;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    opened = <SetScreenRequest>[];
    originalOpener = SetWallpaperFlow.screenOpener;
    SetWallpaperFlow.screenOpener = (context, request) async {
      opened.add(request);
      return const SetWallpaperChoice(WallpaperTarget.home);
    };
  });

  tearDown(() {
    SetWallpaperFlow.screenOpener = originalOpener;
    aw.AsyncWallpaper.debugResetClient();
    AnalyticsRuntime.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DownloadWallpaperScreen(source: WallpaperSource.downloaded, file: file),
      ),
    );
    await tester.pump();
  }

  Future<void> waitForSetEvent(WidgetTester tester) async {
    for (int i = 0; i < 80 && analytics.events.whereType<SetWallEvent>().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  testWidgets('the Set button opens the Set screen as download_wallpaper', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Set as wallpaper'));
    await tester.pump();
    await waitForSetEvent(tester);

    expect(opened, hasLength(1));
    expect(opened.single.url, file.path);
    expect(opened.single.onAdjust, isNotNull);
    expect(client.requests, hasLength(1));
    final List<SetWallEvent> events = analytics.events.whereType<SetWallEvent>().toList();
    expect(events, hasLength(1));
    expect(events.single.entryPoint, 'download_wallpaper');
    expect(events.single.wallpaperTarget, WallpaperTarget.home);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Preview on your screen opens the Set screen as wallpaper_preview', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Preview on your screen'));
    await tester.pump();
    await waitForSetEvent(tester);

    expect(opened, hasLength(1));
    expect(opened.single.url, file.path);
    expect(opened.single.onAdjust, isNotNull);
    expect(client.requests, hasLength(1));
    final List<SetWallEvent> events = analytics.events.whereType<SetWallEvent>().toList();
    expect(events, hasLength(1));
    expect(events.single.entryPoint, 'wallpaper_preview');
    expect(events.single.wallpaperTarget, WallpaperTarget.home);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
