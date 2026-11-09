import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/hints/views/feature_hint.dart';
import 'package:Prism/features/readability/data/readability_render.dart';
import 'package:Prism/features/readability/data/readability_tips.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/features/readability/views/readability_views.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

final String _previewPath = File('assets/images/prism.webp').absolute.path;

const ValueKey<String> _clockChipKey = ValueKey<String>('readability-chip-clock');
const ValueKey<String> _iconsChipKey = ValueKey<String>('readability-chip-icons');
const ValueKey<String> _applyKey = ValueKey<String>('readability-apply');
const ValueKey<String> _keepKey = ValueKey<String>('readability-keep');
const ValueKey<String> _setKey = ValueKey<String>('set-screen-set');

const aw.WallpaperCapabilities _allCapabilities = aw.WallpaperCapabilities(
  supportsStaticWallpaper: true,
  supportsHomeWallpaper: true,
  supportsLockWallpaper: true,
  supportsBothWallpapers: true,
);

const ReadabilityResult _busyClock = ReadabilityResult(
  zone: ReadabilityZone.clock,
  lowContrastShare: 0.9,
  edgeShare: 0,
  fix: ReadabilityFixKind.dim,
);
const ReadabilityResult _okClock = ReadabilityResult(zone: ReadabilityZone.clock, lowContrastShare: 0, edgeShare: 0);
const ReadabilityResult _okIcons = ReadabilityResult(zone: ReadabilityZone.icons, lowContrastShare: 0, edgeShare: 0);
const ReadabilityResult _blurIcons = ReadabilityResult(
  zone: ReadabilityZone.icons,
  lowContrastShare: 0,
  edgeShare: 0.9,
  fix: ReadabilityFixKind.blur,
);

/// How many times the stub analyzer ran in the current test.
int _analyses = 0;

/// Every placement that Apply or Set asked the flow to render in the current test.
final List<WallpaperPlacement> _applied = <WallpaperPlacement>[];

/// Temp folders made for rendered fixes. Each test deletes its own.
final List<Directory> _tempDirs = <Directory>[];

class _Client implements WallpaperClient {
  @override
  Future<aw.LiveWallpaperScreens> getLiveWallpaperScreens() async => const aw.LiveWallpaperScreens();

  _Client({this.capabilities = const aw.WallpaperCapabilities()});

  final aw.WallpaperCapabilities capabilities;
  final List<aw.StaticWallpaperRequest> requests = <aw.StaticWallpaperRequest>[];

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async => capabilities;

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

Widget _withMedia(BuildContext context, Widget? child, EdgeInsets safeArea, bool reduceMotion, double textScale) {
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: safeArea,
      viewPadding: safeArea,
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  );
}

Map<ReadabilityZone, ReadabilityResult> _zones({required ReadabilityResult clock, required ReadabilityResult icons}) =>
    <ReadabilityZone, ReadabilityResult>{ReadabilityZone.clock: clock, ReadabilityZone.icons: icons};

/// Stubs the analyzer to return [zones] and counts its runs.
void _stubAnalyzer(Map<ReadabilityZone, ReadabilityResult> zones) {
  ReadabilityTips.analyzer =
      (
        ReadabilityFrame frame, {
        required TargetPlatform platform,
        Map<ReadabilityZone, Color> textColors = const <ReadabilityZone, Color>{},
      }) {
        _analyses++;
        return zones;
      };
}

/// Stubs the analyzer to fail, and counts its runs.
void _stubAnalyzerThrows() {
  ReadabilityTips.analyzer =
      (
        ReadabilityFrame frame, {
        required TargetPlatform platform,
        Map<ReadabilityZone, Color> textColors = const <ReadabilityZone, Color>{},
      }) {
        _analyses++;
        throw StateError('analysis failed');
      };
}

/// Renders the placement as a copy of the preview image in a temp folder, the way the studio render does.
Future<PlacedWallpaper?> _recordFix(BuildContext _, WallpaperPlacement placement) async {
  _applied.add(placement);
  final Directory dir = Directory.systemTemp.createTempSync('readability_placed_');
  _tempDirs.add(dir);
  final File copy = File(_previewPath).copySync('${dir.path}/placed.webp');
  return PlacedWallpaper(path: copy.path, placement: placement);
}

Future<StudioResult?> _noAdjust(BuildContext context) async => null;

SetScreenRequest _request({String? wallpaperId}) =>
    SetScreenRequest(url: _previewPath, wallpaperId: wallpaperId, onApplyFixes: _recordFix);

/// Opens the Set screen from a button, the way a caller does, and records what it returns in [results].
Future<void> _pumpSetScreen(
  WidgetTester tester,
  SetScreenRequest request,
  List<SetWallpaperChoice?> results, {
  bool reduceMotion = false,
  double textScale = 1,
  bool rtl = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final Widget media = _withMedia(context, child, EdgeInsets.zero, reduceMotion, textScale);
        return rtl ? Directionality(textDirection: TextDirection.rtl, child: media) : media;
      },
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await showSetScreen(context, request)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Lets the real event loop run image decodes, then draws a frame. Stops early when [done] is true.
Future<void> _waitUntil(WidgetTester tester, bool Function() done, {required String reason}) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  expect(done(), isTrue, reason: reason);
}

/// Lets the analysis and the image decodes finish, with a frame after each wait.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

bool Function() _shown(Key key) =>
    () => find.byKey(key).evaluate().isNotEmpty;

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();
  late SettingsLocalDataSource settings;

  setUp(() {
    ReadabilityTips.useIsolate = false;
    ReadabilityTips.budget = const Duration(minutes: 1);
    _stubAnalyzer(_zones(clock: _busyClock, icons: _okIcons));
    _analyses = 0;
    _applied.clear();
    app_state.prismUser = app_constants.createGuestPrismUser();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    aw.AsyncWallpaper.debugSetClient(_Client(capabilities: _allCapabilities));
  });

  tearDown(() async {
    aw.AsyncWallpaper.debugResetClient();
    readabilityFrameRenderer = renderReadabilityFrame;
    ReadabilityTips.analyzer = analyzeReadability;
    ReadabilityTips.useIsolate = true;
    ReadabilityTips.budget = const Duration(seconds: 2);
    ReadabilityTips.instance.reset();
    await getIt.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    // The Set screen discards a placed file itself, so the folder may already be gone.
    for (final Directory dir in _tempDirs) {
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Already deleted by the flow.
      }
    }
    _tempDirs.clear();
  });

  testWidgets('Lock mode with a busy clock shows the clock chip, and Home with ok icons shows none', (tester) async {
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(), results);

    await tester.tap(find.text('Lock screen'));
    await tester.pump();
    await _waitUntil(tester, _shown(_clockChipKey), reason: 'the clock chip shows in Lock mode');
    expect(find.text('Clock may be hard to read'), findsOneWidget);

    await tester.tap(find.text('Home screen'));
    await _settle(tester);
    expect(find.byKey(_clockChipKey), findsNothing);
    expect(find.byKey(_iconsChipKey), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Home with busy icons shows the icons chip, and Lock with an ok clock shows none', (tester) async {
    _stubAnalyzer(_zones(clock: _okClock, icons: _blurIcons));
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(), results);

    await _waitUntil(tester, _shown(_iconsChipKey), reason: 'the icons chip shows in Home mode');
    expect(find.text('Icons may be hard to read'), findsOneWidget);
    expect(find.byKey(_clockChipKey), findsNothing);

    await tester.tap(find.text('Lock screen'));
    await _settle(tester);
    expect(find.byKey(_clockChipKey), findsNothing);
    expect(find.byKey(_iconsChipKey), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('no chip shows when every zone is ok', (tester) async {
    _stubAnalyzer(_zones(clock: _okClock, icons: _okIcons));
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(), results);
    await _waitUntil(tester, () => _analyses > 0, reason: 'the analysis ran');
    await _settle(tester);
    expect(find.byKey(_clockChipKey), findsNothing);
    expect(find.byKey(_iconsChipKey), findsNothing);

    await tester.tap(find.text('Lock screen'));
    await _settle(tester);
    expect(find.byKey(_clockChipKey), findsNothing);
    expect(find.byKey(_iconsChipKey), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Apply renders the fix, hands it to the flow, and hides the clock chip', (tester) async {
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(), results);
    await tester.tap(find.text('Lock screen'));
    await tester.pump();
    await _waitUntil(tester, _shown(_clockChipKey), reason: 'the clock chip shows in Lock mode');

    await tester.tap(find.byKey(_clockChipKey));
    await tester.pumpAndSettle();
    expect(find.text('Dim behind the clock?'), findsOneWidget);
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);

    await _waitUntil(
      tester,
      () => tester.widget<PrismButton>(find.byKey(_applyKey)).onPressed != null,
      reason: 'the after preview renders and Apply enables',
    );
    await tester.tap(find.byKey(_applyKey));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(_applied, hasLength(1));
    expect(_applied.single.fixes, <ReadabilityFix>[
      const ReadabilityFix(ReadabilityZone.clock, ReadabilityFixKind.dim),
    ]);
    expect(find.byKey(_clockChipKey), findsNothing);
    expect(find.byType(ReadabilityFixSheet), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('set-screen-set')));
    await tester.pumpAndSettle();
    expect(results.single?.placed?.placement.fixes, <ReadabilityFix>[
      const ReadabilityFix(ReadabilityZone.clock, ReadabilityFixKind.dim),
    ]);
    expect(results.single?.placed?.fromStudio, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Keep as is closes the sheet, never renders a fix, and keeps the chip', (tester) async {
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(), results);
    await tester.tap(find.text('Lock screen'));
    await tester.pump();
    await _waitUntil(tester, _shown(_clockChipKey), reason: 'the clock chip shows in Lock mode');

    await tester.tap(find.byKey(_clockChipKey));
    await tester.pumpAndSettle();
    await _waitUntil(
      tester,
      () => tester.widget<PrismButton>(find.byKey(_applyKey)).onPressed != null,
      reason: 'the after preview renders',
    );
    await tester.tap(find.byKey(_keepKey));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(_applied, isEmpty);
    expect(find.byType(ReadabilityFixSheet), findsNothing);
    expect(find.byKey(_clockChipKey), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a failed after render disposes Before and keeps Apply disabled', (tester) async {
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    int renders = 0;
    ui.Image? before;
    readabilityFrameRenderer =
        (source, {required width, required height, required platform, tint, fixes = const []}) async {
          renders++;
          if (renders == 2) throw StateError('after render failed');
          before = await renderReadabilityFrame(
            source,
            width: width,
            height: height,
            platform: platform,
            tint: tint,
            fixes: fixes,
          );
          return before!;
        };
    await _pumpSetScreen(tester, _request(), results);
    await tester.tap(find.text('Lock screen'));
    await tester.pump();
    await _waitUntil(tester, _shown(_clockChipKey), reason: 'the clock chip shows in Lock mode');
    await tester.tap(find.byKey(_clockChipKey));
    await tester.pumpAndSettle();
    await _waitUntil(tester, () => renders == 2 && before?.debugDisposed == true, reason: 'Before is disposed');
    await _waitUntil(tester, () => find.text('Before').evaluate().isEmpty, reason: 'the failed preview clears');

    expect(tester.widget<PrismButton>(find.byKey(_applyKey)).onPressed, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the 3D live preview hides the clock chip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClockOverlay(
          link: _previewPath,
          file: true,
          wallpaperId: 'wall-3d',
          request: _request(wallpaperId: 'wall-3d'),
          spatialMapUrl: 'https://example.test/map.jpg',
        ),
      ),
    );
    await tester.tap(find.text('Lock screen'));
    await tester.pump();
    await _waitUntil(tester, _shown(_clockChipKey), reason: 'the clock chip shows before 3D is on');

    await tester.tap(find.byTooltip(l10n.wallpaperSpatialPreviewOn));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip(l10n.wallpaperSpatialPreviewOff), findsOneWidget);
    expect(find.byKey(_clockChipKey), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('no chip without onApplyFixes', (tester) async {
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, SetScreenRequest(url: _previewPath, onAdjust: _noAdjust), results);
    await tester.tap(find.text('Lock screen'));
    await _settle(tester);

    expect(_analyses, 0);
    expect(find.byKey(_clockChipKey), findsNothing);
    expect(find.byKey(_iconsChipKey), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the Readability tips switch turns the tips off for the next Set screen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReadabilityTipsRow()),
      ),
    );
    expect(find.text('Readability tips'), findsOneWidget);
    expect(tester.widget<PrismSwitchRow>(find.byType(PrismSwitchRow)).value, isTrue);

    await tester.tap(find.text('Readability tips'));
    await tester.pump();
    expect(tester.widget<PrismSwitchRow>(find.byType(PrismSwitchRow)).value, isFalse);
    expect(settings.get<bool>(ReadabilityTips.enabledKey, defaultValue: true), isFalse);

    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(), results);
    await tester.tap(find.text('Lock screen'));
    await _settle(tester);

    expect(_analyses, 0);
    expect(find.byKey(_clockChipKey), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the clock chip shows once per wall per session', (tester) async {
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(wallpaperId: 'wall-once'), results);
    await tester.tap(find.text('Lock screen'));
    await tester.pump();
    await _waitUntil(tester, _shown(_clockChipKey), reason: 'the first chip shows');
    final int analysesBeforeClose = _analyses;

    await tester.tap(find.byTooltip(l10n.setScreenClose));
    await tester.pumpAndSettle();
    expect(results.single, isNull);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lock screen'));
    await _settle(tester);

    expect(find.byKey(_clockChipKey), findsNothing);
    expect(_analyses, analysesBeforeClose);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the clock chip keeps its label at 2x text without an overflow', (tester) async {
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(), results, textScale: 2);
    await tester.tap(find.text('Lock screen'));
    await tester.pump();
    await _waitUntil(tester, _shown(_clockChipKey), reason: 'the clock chip shows at 2x text');

    expect(find.text('Clock may be hard to read'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the clock chip shows in a right-to-left layout without an exception', (tester) async {
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(), results, rtl: true);
    await tester.tap(find.text('Lock screen'));
    await tester.pump();
    await _waitUntil(tester, _shown(_clockChipKey), reason: 'the clock chip shows right-to-left');

    expect(find.text('Clock may be hard to read'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byKey(_clockChipKey))), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('under reduced motion the clock chip is fully opaque after one frame', (tester) async {
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(), results, reduceMotion: true);
    await tester.tap(find.text('Lock screen'));
    await tester.pump();
    await _waitUntil(tester, _shown(_clockChipKey), reason: 'the clock chip shows with reduced motion');
    await tester.pump();

    final Opacity opacity = tester.widget<Opacity>(
      find.descendant(of: find.byType(ReadabilityChip), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 1.0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a result that arrives after the budget shows no tip', (tester) async {
    ReadabilityTips.budget = Duration.zero;
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(), results);
    await tester.tap(find.text('Lock screen'));
    await tester.pump();
    await _settle(tester);

    expect(_analyses, greaterThan(0));
    expect(find.byKey(_clockChipKey), findsNothing);
  });

  testWidgets('a failing analysis shows no tip and Set still pops the chosen target', (tester) async {
    _stubAnalyzerThrows();
    final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
    await _pumpSetScreen(tester, _request(), results);
    await tester.tap(find.text('Lock screen'));
    await tester.pump();
    await _waitUntil(tester, () => _analyses > 0, reason: 'the analysis ran and threw');
    await _settle(tester);

    expect(find.byKey(_clockChipKey), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(_setKey));
    await tester.pumpAndSettle();
    expect(results.single?.target, WallpaperTarget.lock);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on iOS the Live Photo hint waits while the clock tip shows, and Save gets the applied fix', (
    tester,
  ) async {
    final List<List<ReadabilityFix>> saved = <List<ReadabilityFix>>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => pushClockPreview(
              context,
              link: _previewPath,
              file: true,
              wallpaperId: 'ios-wall',
              saveAction: (label, fixes) => PrismButton(label: label, onPressed: () => saved.add(fixes)),
              livePhotoAction: (_, _) {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _waitUntil(tester, _shown(_clockChipKey), reason: 'the clock tip shows on iOS');

    expect(tester.widget<FeatureHint>(find.byType(FeatureHint)).enabled, isFalse);

    await tester.tap(find.byKey(_clockChipKey));
    await tester.pump();
    await _waitUntil(
      tester,
      () =>
          find.byKey(const ValueKey<String>('readability-apply')).evaluate().isNotEmpty &&
          tester.widget<PrismButton>(find.byKey(const ValueKey<String>('readability-apply'))).onPressed != null,
      reason: 'Apply is ready',
    );
    // The 800 x 600 test screen puts Apply below the fold of the sheet, so press it the way the button does.
    tester.widget<PrismButton>(find.byKey(const ValueKey<String>('readability-apply'))).onPressed!();
    await tester.pump();
    await _waitUntil(tester, () => find.byKey(_clockChipKey).evaluate().isEmpty, reason: 'the tip leaves after Apply');
    await _settle(tester);

    expect(tester.widget<FeatureHint>(find.byType(FeatureHint)).enabled, isTrue);
    await tester.tap(find.text(l10n.wallpaperSaveToPhotos));
    expect(saved, <List<ReadabilityFix>>[
      <ReadabilityFix>[const ReadabilityFix(ReadabilityZone.clock, ReadabilityFixKind.dim)],
    ]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
