import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/watch_set/data/watch_type_store.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:Prism/features/watch_set/views/watch_guide.dart';
import 'package:Prism/features/watch_set/views/watch_set_sheet.dart';
import 'package:Prism/features/watch_set/views/widgets/watch_previews.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';

final PrismThemeOption _frost = prismLightThemes.first;
final ThemeData _theme = withPrismAccent(_frost.theme, _frost.defaultAccentValue);

const WatchSetWall _wall = WatchSetWall(
  id: 'w1',
  source: WallpaperSource.prism,
  link: 'https://example.com/w1.jpg',
  previewUrl: '/nonexistent/preview.jpg',
  isPremium: false,
);

Widget _host(void Function(BuildContext context) open, {TextScaler? textScaler}) => MaterialApp(
  theme: _theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: textScaler == null
      ? null
      : (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(onPressed: () => open(context), child: const Text('open')),
    ),
  ),
);

void Function(BuildContext context) _sheet() =>
    (context) => showWatchSetSheet(context, _wall);

void Function(BuildContext context) _guideOf(WatchFormat format, {VoidCallback? onShare}) =>
    (context) => showPrismSheet<void>(
      context,
      builder: (_) => WatchGuide(format: format, onShare: onShare),
    );

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUp(() {
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() {
    if (getIt.isRegistered<SettingsLocalDataSource>()) getIt.unregister<SettingsLocalDataSource>();
    AnalyticsRuntime.reset();
  });

  testWidgets('the first open asks which watch the user has, and a pick is remembered', (tester) async {
    await tester.pumpWidget(_host(_sheet()));
    await _openSheet(tester);

    expect(find.text('Which watch do you have?'), findsOneWidget);

    final Finder apple46 = find.byKey(const ValueKey<String>('watch-format-apple_46'));
    await tester.ensureVisible(apple46);
    await tester.tap(apple46);
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(getIt<SettingsLocalDataSource>().get<String?>(watchFormatSettingsKey, hasDefault: true), 'apple_46');
    expect(find.text('Watch set'), findsOneWidget);
  });

  testWidgets('a remembered watch type skips the picker on the next open', (tester) async {
    await getIt<SettingsLocalDataSource>().set(watchFormatSettingsKey, 'galaxy_large');
    await tester.pumpWidget(_host(_sheet()));
    await _openSheet(tester);

    expect(find.text('Which watch do you have?'), findsNothing);
    expect(find.text('Watch set'), findsWidgets);
  });

  testWidgets('the picker lists Wear OS first on Android and Apple Watch first on iOS', (tester) async {
    await tester.pumpWidget(_host(_sheet()));
    await _openSheet(tester);

    expect(tester.getTopLeft(find.text('Wear OS')).dy < tester.getTopLeft(find.text('Apple Watch')).dy, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(_host(_sheet()));
    await _openSheet(tester);

    expect(tester.getTopLeft(find.text('Apple Watch')).dy < tester.getTopLeft(find.text('Wear OS')).dy, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Change watch goes back to the picker', (tester) async {
    await getIt<SettingsLocalDataSource>().set(watchFormatSettingsKey, 'apple_46');
    await tester.pumpWidget(_host(_sheet()));
    await _openSheet(tester);

    await tester.tap(find.text('Change watch'));
    await tester.pump();

    expect(find.text('Which watch do you have?'), findsOneWidget);
  });

  testWidgets('the Apple guide shows the three iPhone steps and the Apple notes', (tester) async {
    await tester.pumpWidget(_host(_guideOf(WatchFormat.apple46)));
    await _openSheet(tester);

    expect(find.text('Open Photos and tap the watch image.'), findsOneWidget);
    expect(find.text('Tap Share, swipe up, then tap Create Watch Face.'), findsOneWidget);
    expect(find.text('Tap Photos Watch Face, then tap Add.'), findsOneWidget);
    expect(find.text("Prism can't put the image on your watch. Your watch app does that."), findsOneWidget);
    expect(
      find.text("Create Watch Face is only in the Photos app. Prism can't add it to its own share sheet."),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('watch-guide-share')), findsNothing);
  });

  testWidgets('the Apple guide shows the share button when a share handler is given', (tester) async {
    await tester.pumpWidget(_host(_guideOf(WatchFormat.apple46, onShare: () {})));
    await _openSheet(tester);

    expect(find.byKey(const ValueKey<String>('watch-guide-share')), findsOneWidget);
    expect(find.text('Share watch image'), findsOneWidget);
  });

  testWidgets('the Wear OS guide shows its headings and the Google Photos note', (tester) async {
    await tester.pumpWidget(_host(_guideOf(WatchFormat.pixelWatch)));
    await _openSheet(tester);

    expect(find.text('Pixel Watch'), findsOneWidget);
    expect(find.text('Galaxy Watch'), findsOneWidget);
    expect(find.text('Tap My Photo+, then tap Customize.'), findsOneWidget);
    expect(
      find.text("Pixel Watch reads Google Photos. If the image doesn't show, back it up to Google Photos first."),
      findsOneWidget,
    );
    expect(
      find.text("Create Watch Face is only in the Photos app. Prism can't add it to its own share sheet."),
      findsNothing,
    );
  });

  testWidgets('the picker lays out at large text on a phone-sized surface', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_sheet(), textScaler: const TextScaler.linear(2.0)));
    await _openSheet(tester);

    expect(find.text('Which watch do you have?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the set step lays out at large text on a phone-sized surface', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await getIt<SettingsLocalDataSource>().set(watchFormatSettingsKey, 'apple_46');

    await tester.pumpWidget(_host(_sheet(), textScaler: const TextScaler.linear(2.0)));
    await _openSheet(tester);

    expect(find.text('Change watch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Apple guide lays out at large text with its share button', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(_guideOf(WatchFormat.apple46, onShare: () {}), textScaler: const TextScaler.linear(2.0)),
    );
    await _openSheet(tester);

    final Finder share = find.byKey(const ValueKey<String>('watch-guide-share'));
    await tester.ensureVisible(share);
    expect(share, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Wear OS guide lays out at large text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_guideOf(WatchFormat.galaxySmall), textScaler: const TextScaler.linear(2.0)));
    await _openSheet(tester);

    expect(find.text('Galaxy Watch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loaded wall shows the watch crop, and How to use opens the guide and counts it', (tester) async {
    final FakeAppAnalytics analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    await getIt<SettingsLocalDataSource>().set(watchFormatSettingsKey, 'galaxy_large');
    final Directory dir = Directory.systemTemp.createTempSync('watch_set_sheet');
    addTearDown(() => dir.deleteSync(recursive: true));
    final File preview = File('${dir.path}/preview.png');
    await tester.runAsync(() async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 90, 160), Paint()..color = const Color(0xFF336699));
      final ui.Image image = await recorder.endRecording().toImage(90, 160);
      final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await preview.writeAsBytes(png!.buffer.asUint8List());
    });
    final WatchSetWall wall = WatchSetWall(
      id: 'w1',
      source: WallpaperSource.wallhaven,
      link: 'https://example.com/w1.jpg',
      previewUrl: preview.path,
      isPremium: false,
    );

    await tester.pumpWidget(_host((context) => showWatchSetSheet(context, wall)));
    await tester.tap(find.text('open'));
    for (int i = 0; i < 10 && find.byType(WatchFacePreview).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(WatchFacePreview), findsOneWidget);
    expect(find.text('480 × 480 px'), findsOneWidget);
    expect(find.text('Galaxy Watch, 44 mm or Ultra'), findsOneWidget);
    await tester.ensureVisible(find.text('How to use it on your watch'));
    await tester.tap(find.text('How to use it on your watch'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Put it on your watch'), findsOneWidget);
    final WatchGuideOpenedEvent opened = analytics.events.whereType<WatchGuideOpenedEvent>().single;
    expect(opened.watchType, WatchFormat.galaxyLarge);
    expect(opened.source, WatchGuideSourceValue.sheet);
  });
}
