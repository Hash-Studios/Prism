import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/l10n/generated/app_localizations_de.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart' as pkg_file;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

final String _previewPath = File('assets/images/prism.webp').absolute.path;

class _Client implements WallpaperClient {
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

Future<void> _openPreview(
  WidgetTester tester, {
  EdgeInsets safeArea = EdgeInsets.zero,
  bool reduceMotion = false,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      builder: (context, child) => _withMedia(context, child, safeArea, reduceMotion, textScale),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ClockOverlay(link: File('assets/images/prism.webp').path, file: true),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

bool _isLockDate(Widget widget) => widget is Text && widget.style?.fontFamily == 'CupertinoSystemText';

bool _isDockIcon(Widget widget) =>
    widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName.contains('playstore');

class _MockCacheManager extends Mock implements BaseCacheManager {}

class _MockFile extends Mock implements pkg_file.File {}

class _FailingSetLocalStore extends InMemoryLocalStore {
  @override
  Future<void> set(String key, Object? value) async => throw StateError('write failed');
}

class _DelayedLocalResolveStore extends OfflineAssetStore {
  _DelayedLocalResolveStore({
    required this.source,
    required this.result,
    required this.started,
    required super.directory,
    required super.cacheManager,
  });

  final String source;
  final Completer<File> result;
  final Completer<void> started;

  @override
  Future<File> resolve(String source, {bool allowNetwork = true}) {
    if (source != this.source) return super.resolve(source, allowNetwork: allowNetwork);
    if (!started.isCompleted) started.complete();
    return result.future;
  }
}

class _RetainedPreview {
  const _RetainedPreview({required this.root, required this.assets, required this.cache, required this.retained});

  final Directory root;
  final OfflineAssetStore assets;
  final _MockCacheManager cache;
  final File retained;
}

Future<File> _solidPng(Directory directory, Color color) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 40, 80), Paint()..color = color);
  final ui.Image image = await recorder.endRecording().toImage(40, 80);
  final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  final File file = File('${directory.path}/${color.toARGB32()}.png');
  await file.writeAsBytes(data.buffer.asUint8List());
  image.dispose();
  return file;
}

/// Image files load on the real event loop, so alternate real waits with frames.
Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

Future<void> _expectFileExists(WidgetTester tester, File file, bool expected) async {
  final bool? actual = await tester.runAsync(() async {
    for (var i = 0; i < 20; i++) {
      final bool exists = await file.exists();
      if (exists == expected) return exists;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return file.exists();
  });
  expect(actual, expected);
}

Future<void> _waitForFinder(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  expect(finder, findsOneWidget);
}

Future<void> _waitForCompleter(WidgetTester tester, Completer<void> completer) async {
  for (var i = 0; i < 50 && !completer.isCompleted; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  expect(completer.isCompleted, isTrue);
}

ImageProvider _unwrapResizeImage(ImageProvider provider) => provider is ResizeImage ? provider.imageProvider : provider;

Future<void> _waitForImageDecode(WidgetTester tester, ImageProvider provider) async {
  final Completer<void> decoded = Completer<void>();
  await tester.runAsync(() async {
    final ImageStream stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        if (!decoded.isCompleted) decoded.complete();
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!decoded.isCompleted) decoded.completeError(error, stackTrace);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  });
  for (var i = 0; i < 50 && !decoded.isCompleted; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  expect(decoded.isCompleted, isTrue, reason: 'The retained local file image must finish decoding.');
  await decoded.future;
}

const aw.WallpaperCapabilities _allCapabilities = aw.WallpaperCapabilities(
  supportsStaticWallpaper: true,
  supportsHomeWallpaper: true,
  supportsLockWallpaper: true,
  supportsBothWallpapers: true,
);

const ValueKey<String> _setKey = ValueKey<String>('set-screen-set');
const ValueKey<String> _adjustKey = ValueKey<String>('set-screen-adjust');
const ValueKey<String> _moreKey = ValueKey<String>('set-screen-more');

/// The segment that shows the lock layer: "Lock" on iOS, "Lock screen" on the Android target control.
String _lockSegment() => hideSetWallpaperUi ? 'Lock' : 'Lock screen';

/// The segment that shows the home layer: "Home" on iOS, "Home screen" on the Android target control.
String _homeSegment() => hideSetWallpaperUi ? 'Home' : 'Home screen';

/// The button-role semantics node around the segment that holds [label].
Finder _segment(String label) => find
    .ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((Widget widget) => widget is Semantics && widget.properties.button == true),
    )
    .first;

Iterable<String> _filePaths(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((Image image) => _unwrapResizeImage(image.image))
    .whereType<FileImage>()
    .map((FileImage image) => image.file.path);

SetScreenRequest _request({
  Future<StudioResult?> Function(BuildContext context)? onAdjust,
  List<String> notes = const <String>[],
}) => SetScreenRequest(url: _previewPath, notes: notes, onAdjust: onAdjust);

Future<StudioResult?> _noAdjust(BuildContext context) async => null;

/// Opens the Set screen from a button, the way a caller does, and records what it returns in [results].
Future<void> _openSetScreen(
  WidgetTester tester,
  SetScreenRequest request,
  List<SetWallpaperChoice?> results, {
  Locale? locale,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
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

void _mockSetChannels(WidgetTester tester) {
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final TestDefaultBinaryMessenger messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(toastChannel, (call) async => true);
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  addTearDown(() {
    messenger.setMockMethodCallHandler(toastChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
  });
}

Future<void> _pumpPreview(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => pushClockPreview(context, link: _previewPath, file: true),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('iOS previews a lock screen without the Android dock', (WidgetTester tester) async {
    await _openPreview(tester);

    expect(find.byWidgetPredicate(_isDockIcon), findsNothing);
    expect(find.textContaining('27°C'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android keeps the launcher preview', (WidgetTester tester) async {
    await _openPreview(tester);

    expect(find.byKey(previewDockKey), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the preview closes from a labelled button', (WidgetTester tester) async {
    await _openPreview(tester);

    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();

    expect(find.byType(ClockOverlay), findsNothing);
  });

  testWidgets('tapping the wallpaper hides the controls and tapping again shows them', (tester) async {
    await _openPreview(tester);
    final Finder controls = find.ancestor(of: find.byTooltip('Close preview'), matching: find.byType(AnimatedOpacity));

    await tester.tap(find.bySemanticsLabel('Hide controls'));
    await tester.pumpAndSettle();
    expect(find.byType(ClockOverlay), findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(controls).opacity, 0);

    await tester.tap(find.bySemanticsLabel('Show controls'));
    await tester.pumpAndSettle();
    expect(find.byType(ClockOverlay), findsOneWidget);
    expect(tester.widget<AnimatedOpacity>(controls).opacity, 1);
  });

  testWidgets('the target control uses the localized lock and home labels', (WidgetTester tester) async {
    await _openPreview(tester);

    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(find.text(hideSetWallpaperUi ? l10n.wallpaperPreviewLock : l10n.setScreenTargetLock), findsOneWidget);
    expect(find.text(hideSetWallpaperUi ? l10n.wallpaperPreviewHome : l10n.setScreenTargetHome), findsOneWidget);
  });

  testWidgets('without a tint the image is shown as it is', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClockOverlay(link: File('assets/images/prism.webp').path, file: true),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.color, isNull);
    expect(image.colorBlendMode, isNull);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('lock preview uses a retained original after temporary cache cleanup', (tester) async {
    const String url = 'https://images.example/clock-preview.jpg';
    final _MockCacheManager thumbnailCache = _MockCacheManager();
    when(() => thumbnailCache.getFileFromCache(any())).thenAnswer((_) async => null);
    final _RetainedPreview setup = (await tester.runAsync(() async {
      final Directory root = await Directory.systemTemp.createTemp('clock-retained-preview-');
      final File original = await _solidPng(root, Colors.indigo);
      final _MockCacheManager cache = _MockCacheManager();
      when(() => cache.getFileFromCache(url)).thenAnswer((_) async => null);
      final OfflineAssetStore assets = OfflineAssetStore(
        directory: Directory('${root.path}/retained'),
        cacheManager: cache,
      );
      final File retained = await assets.retain(url, file: original);
      return _RetainedPreview(root: root, assets: assets, cache: cache, retained: retained);
    }))!;
    addTearDown(() async {
      OfflineAssetStore.testOverride = null;
      await tester.runAsync(() => setup.root.delete(recursive: true));
    });
    OfflineAssetStore.testOverride = setup.assets;
    PrismFullImageCache.testOverride = setup.cache;
    PrismImageCache.testOverride = thumbnailCache;
    addTearDown(() {
      PrismFullImageCache.testOverride = null;
      PrismImageCache.testOverride = null;
    });
    final File resolvedByWallpaperService =
        await tester.runAsync(
              () => WallpaperService.resolveToLocalFile(
                url,
                allowNetwork: false,
                wallpaperId: 'clock-wall',
                wallpaperSource: WallpaperSource.prism,
              ),
            )
            as File;
    expect(resolvedByWallpaperService.path, setup.retained.path);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: ClockOverlay(link: url, file: false, wallpaperId: 'clock-wall', wallpaperSource: WallpaperSource.prism),
      ),
    );
    expect(find.byType(CachedNetworkImage), findsNothing);
    final File? resolved = await tester.runAsync<File?>(() => setup.assets.lookup(url));
    expect(resolved?.path, setup.retained.path);
    final Finder retainedImageFinder = find.byWidgetPredicate((Widget widget) {
      if (widget is! Image) return false;
      final ImageProvider provider = _unwrapResizeImage(widget.image);
      return provider is FileImage && provider.file.path == setup.retained.path;
    });
    await _waitForFinder(tester, retainedImageFinder);
    final ImageProvider retainedProvider = tester
        .widgetList<Image>(find.byType(Image))
        .map((Image image) => image.image)
        .firstWhere((ImageProvider image) {
          final ImageProvider unwrapped = _unwrapResizeImage(image);
          return unwrapped is FileImage && unwrapped.file.path == setup.retained.path;
        });
    await _waitForImageDecode(tester, retainedProvider);
    await tester.pump();

    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .map((Image image) => _unwrapResizeImage(image.image))
          .whereType<FileImage>()
          .any((FileImage image) => image.file.path == setup.retained.path),
      isTrue,
    );
    verifyNever(() => setup.cache.getSingleFile(any()));
    verifyNever(() => setup.cache.getFileFromCache(any()));
    verifyNever(() => setup.cache.getFileStream(any(), withProgress: any(named: 'withProgress')));
    verifyNever(() => thumbnailCache.getSingleFile(any()));
    verifyNever(() => thumbnailCache.getFileFromCache(any()));
    verifyNever(() => thumbnailCache.getFileStream(any(), withProgress: any(named: 'withProgress')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tint puts a hue filter of that colour over the image', (tester) async {
    const Color tint = Color(0xFF3366CC);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: ClockOverlay(link: File('assets/images/prism.webp').path, file: true, tint: tint),
      ),
    );

    expect(
      tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
      const ColorFilter.mode(tint, BlendMode.hue),
    );
    expect(find.descendant(of: find.byType(ColorFiltered), matching: find.byType(Image)), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the Android lock view shows the device time style and no dock', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: ClockOverlay(link: File('assets/images/prism.webp').path, file: true),
          ),
        ),
      ),
    );

    await tester.tap(find.text(_lockSegment()));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate(_isDockIcon), findsNothing);
    expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the Home toggle hides the big clock on iOS', (tester) async {
    await _openPreview(tester);
    expect(find.textContaining(RegExp(r'^\d{1,2}:\d{2}$')), findsOneWidget);

    await tester.tap(find.text(_homeSegment()));
    await tester.pumpAndSettle();

    expect(find.textContaining(RegExp(r'^\d{1,2}:\d{2}$')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('image loading', () {
    late _MockCacheManager cache;
    late _MockCacheManager thumbnailCache;
    late Directory offlineDirectory;
    late Completer<void> cacheRequestStarted;
    late Completer<void> cacheRequestFailed;

    setUp(() {
      cache = _MockCacheManager();
      thumbnailCache = _MockCacheManager();
      offlineDirectory = Directory.systemTemp.createTempSync('clock-overlay-offline-resolver-');
      cacheRequestStarted = Completer<void>();
      cacheRequestFailed = Completer<void>();
      when(() => cache.getFileFromCache(any())).thenAnswer((_) async => null);
      when(() => thumbnailCache.getFileFromCache(any())).thenAnswer((_) async => null);
      when(
        () => thumbnailCache.getFileStream(any(), withProgress: any(named: 'withProgress')),
      ).thenAnswer((_) => StreamController<FileResponse>().stream);
      OfflineAssetStore.testOverride = OfflineAssetStore(
        directory: Directory('${offlineDirectory.path}/retained'),
        cacheManager: cache,
      );
      PrismFullImageCache.testOverride = cache;
      PrismImageCache.testOverride = thumbnailCache;
      when(() => cache.getFileStream(any(), withProgress: any(named: 'withProgress'))).thenAnswer((_) {
        if (!cacheRequestStarted.isCompleted) cacheRequestStarted.complete();
        return Stream<FileResponse>.error(const SocketException('offline')).transform(
          StreamTransformer<FileResponse, FileResponse>.fromHandlers(
            handleError: (Object error, StackTrace stackTrace, EventSink<FileResponse> sink) {
              if (!cacheRequestFailed.isCompleted) cacheRequestFailed.complete();
              sink.addError(error, stackTrace);
            },
          ),
        );
      });
    });

    tearDown(() {
      PrismFullImageCache.testOverride = null;
      PrismImageCache.testOverride = null;
      OfflineAssetStore.testOverride = null;
      offlineDirectory.deleteSync(recursive: true);
    });

    testWidgets('the full image uses the full-size cache and a screen-width decode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: ClockOverlay(link: 'https://img.test/full.jpg', file: false, thumbnailUrl: 'https://img.test/t.jpg'),
        ),
      );
      await _waitForCompleter(tester, cacheRequestStarted);
      await _waitForCompleter(tester, cacheRequestFailed);
      await _settleImages(tester);

      final CachedNetworkImage image = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).first;
      expect(image.cacheManager, same(cache));
      expect(image.memCacheWidth, isNotNull);
      expect(image.memCacheWidth, lessThanOrEqualTo(2160));
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a stale local-file lookup cannot replace a newer preview after it completes', (tester) async {
      final Completer<void> lookupStarted = Completer<void>();
      final Completer<File> staleLookup = Completer<File>();
      OfflineAssetStore.testOverride = _DelayedLocalResolveStore(
        source: 'https://img.test/stale.jpg',
        result: staleLookup,
        started: lookupStarted,
        directory: Directory('${offlineDirectory.path}/late'),
        cacheManager: cache,
      );
      final File stale = (await tester.runAsync(() => _solidPng(offlineDirectory, const Color(0xFFFF0000))))!;
      final File current = (await tester.runAsync(() => _solidPng(offlineDirectory, const Color(0xFF00CC00))))!;

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClockOverlay(link: 'https://img.test/stale.jpg', file: false),
        ),
      );
      await _waitForCompleter(tester, lookupStarted);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClockOverlay(link: current.path, file: true),
        ),
      );
      await _settleImages(tester);
      staleLookup.complete(stale);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.tap(find.text(_lockSegment()));
      await tester.pumpAndSettle();

      final Image image = tester.widget<Image>(find.byType(Image).first);
      expect(
        _unwrapResizeImage(image.image),
        isA<FileImage>().having((provider) => provider.file.path, 'path', current.path),
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('disposing during a local-file lookup ignores its late completion', (tester) async {
      final Completer<void> lookupStarted = Completer<void>();
      final Completer<File> staleLookup = Completer<File>();
      OfflineAssetStore.testOverride = _DelayedLocalResolveStore(
        source: 'https://img.test/disposed.jpg',
        result: staleLookup,
        started: lookupStarted,
        directory: Directory('${offlineDirectory.path}/late'),
        cacheManager: cache,
      );
      final File stale = (await tester.runAsync(() => _solidPng(offlineDirectory, const Color(0xFFFF0000))))!;

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClockOverlay(link: 'https://img.test/disposed.jpg', file: false),
        ),
      );
      await _waitForCompleter(tester, lookupStarted);
      await tester.pumpWidget(const SizedBox.shrink());
      staleLookup.complete(stale);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a failed load shows a message icon instead of an empty screen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClockOverlay(link: 'https://img.test/full.jpg', file: false),
        ),
      );
      await _waitForCompleter(tester, cacheRequestStarted);
      await _waitForCompleter(tester, cacheRequestFailed);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a plain preview of a network link shows no Set button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClockOverlay(link: 'https://img.test/full.jpg', file: false),
        ),
      );
      await tester.pump();

      expect(find.byKey(_setKey), findsNothing);
      expect(find.textContaining('Set on'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a missing local file shows the same fallback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClockOverlay(link: '/nonexistent/wall.png', file: true),
        ),
      );
      await _settleImages(tester);

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('tint pixels', () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync('clock_overlay_pixels_'));
    tearDown(() => directory.deleteSync(recursive: true));

    Future<Color> wallPixel(WidgetTester tester, {Color? tint}) async {
      final File file = (await tester.runAsync(() => _solidPng(directory, const Color(0xFFCC3333))))!;
      final GlobalKey boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: RepaintBoundary(
            key: boundary,
            child: ClockOverlay(link: file.path, file: true, tint: tint),
          ),
        ),
      );
      await _settleImages(tester);
      final ui.Image shot = (await tester.runAsync(
        () => (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(),
      ))!;
      final ByteData data = (await tester.runAsync(() async => (await shot.toByteData())!))!;
      final int offset = ((shot.height ~/ 2) * shot.width + 16) * 4;
      final Color pixel = Color.fromARGB(
        255,
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      );
      shot.dispose();
      return pixel;
    }

    testWidgets('a blue tint turns a red wall blue and no tint leaves it red', (tester) async {
      final Color plain = await wallPixel(tester);
      expect(plain.r, greaterThan(plain.b));

      final Color tinted = await wallPixel(tester, tint: const Color(0xFF2255EE));
      expect(tinted.b, greaterThan(tinted.r));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('tint on a network image', () {
    const Color tint = Color(0xFF3366CC);
    late Directory directory;
    late _MockCacheManager fullCache;
    late _MockCacheManager thumbnailCache;
    late OfflineAssetStore offlineAssets;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('clock_overlay_tint_');
      fullCache = _MockCacheManager();
      thumbnailCache = _MockCacheManager();
      when(() => fullCache.getFileFromCache(any())).thenAnswer((_) async => null);
      when(() => thumbnailCache.getFileFromCache(any())).thenAnswer((_) async => null);
      offlineAssets = OfflineAssetStore(directory: Directory('${directory.path}/retained'), cacheManager: fullCache);
      OfflineAssetStore.testOverride = offlineAssets;
      PrismFullImageCache.testOverride = fullCache;
      PrismImageCache.testOverride = thumbnailCache;
    });

    tearDown(() {
      OfflineAssetStore.testOverride = null;
      PrismFullImageCache.testOverride = null;
      PrismImageCache.testOverride = null;
      directory.deleteSync(recursive: true);
    });

    void serve(_MockCacheManager cache, Uint8List? bytes) {
      final _MockFile file = _MockFile();
      if (bytes != null) when(() => file.readAsBytes()).thenAnswer((_) async => bytes);
      when(() => cache.getFileStream(any(), withProgress: any(named: 'withProgress'))).thenAnswer(
        (_) => bytes == null
            ? StreamController<FileResponse>().stream
            : Stream<FileResponse>.value(
                FileInfo(file, FileSource.Cache, DateTime.now().add(const Duration(days: 1)), 'https://img.test/x'),
              ),
      );
    }

    Future<void> pumpTinted(WidgetTester tester, {required bool fullLoads, required bool thumbnailLoads}) async {
      final File png = (await tester.runAsync(() => _solidPng(directory, const Color(0xFFCC3333))))!;
      final Uint8List bytes = (await tester.runAsync(png.readAsBytes))!;
      serve(fullCache, fullLoads ? bytes : null);
      serve(thumbnailCache, thumbnailLoads ? bytes : null);
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: ClockOverlay(
            link: 'https://img.test/full.jpg',
            file: false,
            thumbnailUrl: 'https://img.test/t.jpg',
            tint: tint,
          ),
        ),
      );
      await _waitForFinder(tester, find.descendant(of: find.byType(ColorFiltered), matching: find.byType(Image)));
    }

    testWidgets('covers the full image', (tester) async {
      await pumpTinted(tester, fullLoads: true, thumbnailLoads: false);

      expect(
        tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
        const ColorFilter.mode(tint, BlendMode.hue),
      );
      expect(find.descendant(of: find.byType(ColorFiltered), matching: find.byType(Image)), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('covers the thumbnail while the full image loads', (tester) async {
      await pumpTinted(tester, fullLoads: false, thumbnailLoads: true);

      expect(
        tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
        const ColorFilter.mode(tint, BlendMode.hue),
      );
      expect(find.descendant(of: find.byType(ColorFiltered), matching: find.byType(Image)), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('status bar and framing', () {
    const EdgeInsets deviceInsets = EdgeInsets.only(top: 40, bottom: 34);

    testWidgets('the iOS lock date starts 24 below the status bar', (tester) async {
      await _openPreview(tester, safeArea: deviceInsets);

      expect(tester.getTopLeft(find.byWidgetPredicate(_isLockDate)).dy, 64);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the Android lock clock sits below the status bar', (tester) async {
      await _openPreview(tester, safeArea: deviceInsets);
      await tester.tap(find.text(_lockSegment()));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.textContaining(RegExp(r'^\d{1,2}:\d{2}$'))).dy, greaterThan(40));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the Android dock stays above the target control', (tester) async {
      await _openPreview(tester, safeArea: deviceInsets);

      expect(
        tester.getBottomLeft(find.byKey(previewDockKey)).dy,
        lessThan(tester.getTopLeft(find.byType(PrismSegmented<WallpaperTarget>)).dy),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the image fills the screen from the top left whatever the safe area', (tester) async {
      await _openPreview(tester, safeArea: deviceInsets);

      expect(tester.getRect(find.byType(Image).first), const Rect.fromLTWH(0, 0, 800, 600));
    });
  });

  group('Lock and Home toggle', () {
    double layerOpacity(WidgetTester tester, Type layer) => tester
        .widget<FadeTransition>(find.ancestor(of: find.byType(layer), matching: find.byType(FadeTransition)).first)
        .opacity
        .value;

    testWidgets('a tap swaps the layer and never closes the preview', (tester) async {
      await _openPreview(tester);

      await tester.tap(find.text(_homeSegment()));
      await tester.pumpAndSettle();
      expect(find.byType(HomePreviewLayer), findsOneWidget);
      expect(find.byType(LockPreviewLayer), findsNothing);
      expect(find.byType(ClockOverlay), findsOneWidget);

      await tester.tap(find.text(_lockSegment()));
      await tester.pumpAndSettle();
      expect(find.byType(LockPreviewLayer), findsOneWidget);
      expect(find.byType(HomePreviewLayer), findsNothing);
      expect(find.byType(ClockOverlay), findsOneWidget);

      await tester.tap(find.text(_lockSegment()));
      await tester.pumpAndSettle();
      expect(find.byType(LockPreviewLayer), findsOneWidget);
      expect(find.byType(ClockOverlay), findsOneWidget);
    }, variant: TargetPlatformVariant.all());

    testWidgets('the two layers cross-fade for 160 ms and then only the new one is left', (tester) async {
      await _openPreview(tester);

      await tester.tap(find.text(_lockSegment()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.byType(HomePreviewLayer), findsOneWidget);
      expect(find.byType(LockPreviewLayer), findsOneWidget);
      expect(layerOpacity(tester, LockPreviewLayer), inExclusiveRange(0, 1));
      expect(layerOpacity(tester, HomePreviewLayer), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HomePreviewLayer), findsNothing);
      expect(layerOpacity(tester, LockPreviewLayer), 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the layers swap without a fade when the system asks for less motion', (tester) async {
      await _openPreview(tester, reduceMotion: true);

      await tester.tap(find.text(_lockSegment()));
      await tester.pump();

      expect(find.byType(HomePreviewLayer), findsNothing);
      expect(find.byType(LockPreviewLayer), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the selected segment is announced as selected', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openPreview(tester);

      await tester.tap(find.text(_lockSegment()));
      await tester.pumpAndSettle();

      expect(tester.getSemantics(_segment(_lockSegment())), isSemantics(isButton: true, isSelected: true));
      expect(tester.getSemantics(_segment(_homeSegment())), isSemantics(isButton: true, isSelected: false));
      handle.dispose();
    });
  });

  group('clock text colour', () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync('clock_overlay_test_'));
    tearDown(() => directory.deleteSync(recursive: true));

    Future<Color> sampledClockColor(WidgetTester tester, Color wall, {Color? tint}) async {
      final File file = (await tester.runAsync(() => _solidPng(directory, wall)))!;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: ClockOverlay(link: file.path, file: true, tint: tint),
        ),
      );
      await tester.tap(find.text(_lockSegment()));
      await tester.pumpAndSettle();
      final Finder clock = find.textContaining(RegExp(r'^\d{1,2}:\d{2}$'));
      final Color beforeSample = Theme.of(tester.element(clock)).colorScheme.secondary;
      final Stopwatch waited = Stopwatch()..start();
      while (tester.widget<Text>(clock).style!.color == beforeSample && waited.elapsed < const Duration(seconds: 30)) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      return tester.widget<Text>(clock).style!.color!;
    }

    testWidgets('is white over a dark wall', (tester) async {
      expect(await sampledClockColor(tester, const Color(0xFF0A0A12)), Colors.white);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('is black over a bright wall', (tester) async {
      expect(await sampledClockColor(tester, const Color(0xFFF2F2F2)), Colors.black);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('is black over a red wall', (tester) async {
      expect(await sampledClockColor(tester, const Color(0xFFFF0000)), Colors.black);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('follows the tint: the red wall shown in blue gets white text', (tester) async {
      expect(await sampledClockColor(tester, const Color(0xFFFF0000), tint: const Color(0xFF0000FF)), Colors.white);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('follows the tint: the bright wall shown in blue keeps black text', (tester) async {
      expect(await sampledClockColor(tester, const Color(0xFFF2F2F2), tint: const Color(0xFF0000FF)), Colors.black);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('Set screen', () {
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    late SettingsLocalDataSource settings;

    setUp(() {
      app_state.prismUser = app_constants.createGuestPrismUser();
      settings = SettingsLocalDataSource(InMemoryLocalStore());
      getIt.registerSingleton<SettingsLocalDataSource>(settings);
      aw.AsyncWallpaper.debugSetClient(_Client(capabilities: _allCapabilities));
    });

    tearDown(() async {
      aw.AsyncWallpaper.debugResetClient();
      await getIt.reset();
      app_state.prismUser = app_constants.createGuestPrismUser();
    });

    testWidgets('Android Set screen pops the picked target, and its button names it', (tester) async {
      final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
      await _openSetScreen(tester, _request(), results);

      for (final (String segment, String button, WallpaperTarget target) in <(String, String, WallpaperTarget)>[
        ('Home screen', 'Set on home screen', WallpaperTarget.home),
        ('Lock screen', 'Set on lock screen', WallpaperTarget.lock),
        ('Both', 'Set on both screens', WallpaperTarget.both),
      ]) {
        await tester.tap(find.text(segment));
        await tester.pumpAndSettle();
        expect(find.text(button), findsOneWidget);
        await tester.tap(find.byKey(_setKey));
        await tester.pumpAndSettle();
        expect(results.last?.target, target);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }
      expect(results.map((choice) => choice?.target), <WallpaperTarget>[
        WallpaperTarget.home,
        WallpaperTarget.lock,
        WallpaperTarget.both,
      ]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('an empty original URL previews the available thumbnail', (tester) async {
      await _openSetScreen(tester, SetScreenRequest(url: '', thumbnailUrl: _previewPath), <SetWallpaperChoice?>[]);
      await _settleImages(tester);

      expect(tester.widget<ClockOverlay>(find.byType(ClockOverlay)).link, _previewPath);
      expect(_filePaths(tester), contains(_previewPath));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Remember this choice starts unchecked and shows its hint once checked', (tester) async {
      await _openSetScreen(tester, _request(), <SetWallpaperChoice?>[]);

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(find.text(l10n.setScreenRememberHint), findsNothing);

      await tester.tap(find.text(l10n.setScreenRemember));
      await tester.pumpAndSettle();

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(find.text(l10n.setScreenRememberHint), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Set with Remember this choice checked saves the target as the default', (tester) async {
      final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
      await _openSetScreen(tester, _request(), results);

      await tester.tap(find.text('Lock screen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.setScreenRemember));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_setKey));
      await tester.pumpAndSettle();

      expect(results.single?.target, WallpaperTarget.lock);
      expect(settings.get<String>(PersistenceKeys.defaultApplyTarget, defaultValue: 'ask'), 'lock');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a saved Lock default opens the Set screen on Lock with Remember checked', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'lock');
      await _openSetScreen(tester, _request(), <SetWallpaperChoice?>[]);

      expect(find.text('Set on lock screen'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(find.text(l10n.setScreenRememberHint), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Adjust and More are hidden when the request has no onAdjust', (tester) async {
      await _openSetScreen(tester, _request(), <SetWallpaperChoice?>[]);

      expect(find.byKey(_adjustKey), findsNothing);
      expect(find.byKey(_moreKey), findsNothing);
      expect(find.text('Lock screen'), findsOneWidget);
      expect(find.byKey(_setKey), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Both is hidden when the device cannot set both screens', (tester) async {
      aw.AsyncWallpaper.debugSetClient(
        _Client(
          capabilities: const aw.WallpaperCapabilities(
            supportsStaticWallpaper: true,
            supportsHomeWallpaper: true,
            supportsLockWallpaper: true,
          ),
        ),
      );
      await _openSetScreen(tester, _request(), <SetWallpaperChoice?>[]);

      expect(find.text('Both'), findsNothing);
      expect(find.text('Home screen'), findsOneWidget);
      expect(find.text('Lock screen'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('More is hidden when the device cannot set the lock screen', (tester) async {
      aw.AsyncWallpaper.debugSetClient(
        _Client(
          capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true),
        ),
      );
      await _openSetScreen(tester, _request(onAdjust: _noAdjust), <SetWallpaperChoice?>[]);

      expect(find.byKey(_adjustKey), findsOneWidget);
      expect(find.byKey(_moreKey), findsNothing);
      expect(find.text('Lock screen'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a device that only supports Lock opens on Lock and never offers Home', (tester) async {
      aw.AsyncWallpaper.debugSetClient(
        _Client(
          capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsLockWallpaper: true),
        ),
      );
      final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
      await _openSetScreen(tester, _request(), results);

      expect(find.text('Home screen'), findsNothing);
      expect(find.text('Set on lock screen'), findsOneWidget);
      expect(find.byType(LockPreviewLayer), findsOneWidget);
      await tester.tap(find.byKey(_setKey));
      await tester.pumpAndSettle();
      expect(results.single?.target, WallpaperTarget.lock);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Set is disabled when no static target is supported', (tester) async {
      aw.AsyncWallpaper.debugSetClient(
        _Client(capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true)),
      );
      await _openSetScreen(tester, _request(), <SetWallpaperChoice?>[]);

      expect(tester.widget<PrismButton>(find.byKey(_setKey)).onPressed, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a local preview Set action is disabled when no target is supported', (tester) async {
      aw.AsyncWallpaper.debugSetClient(
        _Client(capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true)),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClockOverlay(link: _previewPath, file: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<PrismButton>(find.byKey(_setKey)).onPressed, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('an unsupported saved Lock target falls back to the Home preview and action', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'lock');
      aw.AsyncWallpaper.debugSetClient(
        _Client(
          capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true),
        ),
      );
      await _openSetScreen(tester, _request(), <SetWallpaperChoice?>[]);

      expect(find.text('Set on home screen'), findsOneWidget);
      expect(find.byType(HomePreviewLayer), findsOneWidget);
      expect(find.byType(LockPreviewLayer), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a Lock fallback reads the saved themed icon scheme for Home', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'lock');
      await settings.set(PersistenceKeys.previewIconStyle, 'themed');
      aw.AsyncWallpaper.debugSetClient(
        _Client(
          capabilities: const aw.WallpaperCapabilities(supportsStaticWallpaper: true, supportsHomeWallpaper: true),
        ),
      );
      await _openSetScreen(tester, _request(), <SetWallpaperChoice?>[]);
      await _settleImages(tester);
      // The wallpaper colours decode on the real event loop, which can take longer than a settle.
      for (var i = 0; i < 40; i++) {
        if (tester.widget<HomePreviewLayer>(find.byType(HomePreviewLayer)).scheme != null) break;
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }

      final HomePreviewLayer home = tester.widget<HomePreviewLayer>(find.byType(HomePreviewLayer));
      expect(home.iconStyle, PreviewIconStyle.themed);
      expect(home.scheme, isNotNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('two Set taps before the next frame keep the calling page open', (tester) async {
      final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async => results.add(await showSetScreen(context, _request())),
                      child: const Text('open Set'),
                    ),
                  ),
                ),
              ),
              child: const Text('open detail'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open detail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open Set'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_setKey));
      await tester.tap(find.byKey(_setKey));
      await tester.pumpAndSettle();

      expect(find.text('open Set'), findsOneWidget);
      expect(results, hasLength(1));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a repeated Set tap keeps the placed file owned by the returned choice', (tester) async {
      final Directory directory = Directory.systemTemp.createTempSync('set_screen_double_set_');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final File placed = (await tester.runAsync(() => _solidPng(directory, const Color(0xFF00CC00))))!;
      final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
      await _openSetScreen(
        tester,
        _request(
          onAdjust: (_) async => PlacedWallpaper(path: placed.path, placement: const WallpaperPlacement()),
        ),
        results,
      );
      await tester.tap(find.byKey(_adjustKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_setKey));
      await tester.tap(find.byKey(_setKey));
      await tester.pumpAndSettle();

      expect(results, hasLength(1));
      expect(results.single?.placed?.path, placed.path);
      await _expectFileExists(tester, placed, true);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('two Adjust taps while the studio is opening call it once', (tester) async {
      final Completer<StudioResult?> adjusted = Completer<StudioResult?>();
      int calls = 0;
      await _openSetScreen(
        tester,
        _request(
          onAdjust: (_) {
            calls++;
            return adjusted.future;
          },
        ),
        <SetWallpaperChoice?>[],
      );

      await tester.tap(find.byKey(_adjustKey));
      await tester.tap(find.byKey(_adjustKey));
      expect(calls, 1);
      adjusted.complete(null);
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Adjust with a placed wall shows it on the preview, and Set returns it', (tester) async {
      final Directory directory = Directory.systemTemp.createTempSync('set_screen_placed_');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final File placed = (await tester.runAsync(() => _solidPng(directory, const Color(0xFF00CC00))))!;
      final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
      await _openSetScreen(
        tester,
        _request(
          onAdjust: (_) async => PlacedWallpaper(path: placed.path, placement: const WallpaperPlacement()),
        ),
        results,
      );

      await tester.tap(find.byKey(_adjustKey));
      await tester.pumpAndSettle();
      await _settleImages(tester);
      expect(_filePaths(tester), contains(placed.path));

      await tester.tap(find.byKey(_setKey));
      await tester.pumpAndSettle();
      expect(results.single?.placed?.path, placed.path);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Adjust that asks for the system editor pops a choice that uses it', (tester) async {
      final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
      await _openSetScreen(tester, _request(onAdjust: (_) async => const SystemEditorRequested()), results);

      await tester.tap(find.byKey(_adjustKey));
      await tester.pumpAndSettle();

      expect(results.single?.useSystemCropper, isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('replacing the wallpaper discards its earlier studio placement', (tester) async {
      final Directory directory = Directory.systemTemp.createTempSync('set_screen_replace_');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final File placed = (await tester.runAsync(() => _solidPng(directory, const Color(0xFF00CC00))))!;
      final ValueNotifier<String> link = ValueNotifier<String>(_previewPath);
      addTearDown(link.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<String>(
            valueListenable: link,
            builder: (context, value, _) => ClockOverlay(
              link: value,
              file: true,
              request: SetScreenRequest(
                url: value,
                onAdjust: (_) async => PlacedWallpaper(path: placed.path, placement: const WallpaperPlacement()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_adjustKey));
      await tester.pumpAndSettle();
      await _settleImages(tester);
      expect(_filePaths(tester), contains(placed.path));

      link.value = File('assets/images/prism.webp').uri.toString();
      await tester.pumpAndSettle();
      await _settleImages(tester);

      expect(_filePaths(tester), isNot(contains(placed.path)));
      await _expectFileExists(tester, placed, false);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('closing the Set screen discards its studio placement', (tester) async {
      final Directory directory = Directory.systemTemp.createTempSync('set_screen_close_');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final File placed = (await tester.runAsync(() => _solidPng(directory, const Color(0xFF00CC00))))!;
      await _openSetScreen(
        tester,
        _request(
          onAdjust: (_) async => PlacedWallpaper(path: placed.path, placement: const WallpaperPlacement()),
        ),
        <SetWallpaperChoice?>[],
      );

      await tester.tap(find.byKey(_adjustKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.setScreenClose));
      await tester.pumpAndSettle();

      await _expectFileExists(tester, placed, false);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('an Adjust placement that completes during close is discarded', (tester) async {
      final Directory directory = Directory.systemTemp.createTempSync('set_screen_close_pending_');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final File placed = (await tester.runAsync(() => _solidPng(directory, const Color(0xFF00CC00))))!;
      final Completer<StudioResult?> adjusted = Completer<StudioResult?>();
      await _openSetScreen(tester, _request(onAdjust: (_) => adjusted.future), <SetWallpaperChoice?>[]);

      await tester.tap(find.byKey(_adjustKey));
      await tester.pump();
      await tester.tap(find.byTooltip(l10n.setScreenClose));
      await tester.pump();
      adjusted.complete(PlacedWallpaper(path: placed.path, placement: const WallpaperPlacement()));
      await tester.pumpAndSettle();

      await _expectFileExists(tester, placed, false);
      expect(find.text('open'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a system editor result that completes during close keeps the caller open', (tester) async {
      final Completer<StudioResult?> adjusted = Completer<StudioResult?>();
      final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async =>
                          results.add(await showSetScreen(context, _request(onAdjust: (_) => adjusted.future))),
                      child: const Text('open Set'),
                    ),
                  ),
                ),
              ),
              child: const Text('open detail'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open detail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open Set'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_adjustKey));
      await tester.pump();
      await tester.tap(find.byTooltip(l10n.setScreenClose));
      await tester.pump();
      adjusted.complete(const SystemEditorRequested());
      await tester.pumpAndSettle();

      expect(find.text('open Set'), findsOneWidget);
      expect(results, <SetWallpaperChoice?>[null]);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('system back invalidates a pending Adjust result', (tester) async {
      final Completer<StudioResult?> adjusted = Completer<StudioResult?>();
      await _openSetScreen(tester, _request(onAdjust: (_) => adjusted.future), <SetWallpaperChoice?>[]);

      await tester.tap(find.byKey(_adjustKey));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      adjusted.complete(const SystemEditorRequested());
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('an Adjust result for a replaced wallpaper is discarded', (tester) async {
      final Directory directory = Directory.systemTemp.createTempSync('set_screen_stale_adjust_');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final File placed = (await tester.runAsync(() => _solidPng(directory, const Color(0xFF00CC00))))!;
      final Completer<StudioResult?> adjusted = Completer<StudioResult?>();
      final ValueNotifier<String> link = ValueNotifier<String>(_previewPath);
      addTearDown(link.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<String>(
            valueListenable: link,
            builder: (context, value, _) => ClockOverlay(
              link: value,
              file: true,
              request: SetScreenRequest(url: value, onAdjust: (_) => adjusted.future),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_adjustKey));
      await tester.pump();
      link.value = File('assets/images/prism.webp').uri.toString();
      await tester.pump();
      adjusted.complete(PlacedWallpaper(path: placed.path, placement: const WallpaperPlacement()));
      await tester.pumpAndSettle();
      await _settleImages(tester);

      expect(_filePaths(tester), isNot(contains(placed.path)));
      await _expectFileExists(tester, placed, false);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('More pops a pair choice for the lock screen', (tester) async {
      final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
      await _openSetScreen(tester, _request(onAdjust: _noAdjust), results);

      await tester.tap(find.byKey(_moreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.setScreenPairLock));
      await tester.pumpAndSettle();

      expect(results.single?.kind, SetChoiceKind.pair);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Close pops null', (tester) async {
      final List<SetWallpaperChoice?> results = <SetWallpaperChoice?>[];
      await _openSetScreen(tester, _request(), results);

      await tester.tap(find.byTooltip(l10n.setScreenClose));
      await tester.pumpAndSettle();

      expect(results, <SetWallpaperChoice?>[null]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('iOS Set screen shows Save to Photos and Lock | Home, with no Android set controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClockOverlay(
            link: _previewPath,
            file: true,
            request: _request(onAdjust: _noAdjust),
            saveAction: (label) => PrismButton(label: label, onPressed: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Save to Photos'), findsOneWidget);
      expect(find.text(_lockSegment()), findsOneWidget);
      expect(find.text(_homeSegment()), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(_lockSegment()),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is Semantics && widget.properties.selected == true,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(LockPreviewLayer), findsOneWidget);
      expect(find.text('Both'), findsNothing);
      expect(find.text(l10n.setScreenRemember), findsNothing);
      expect(find.byKey(_adjustKey), findsNothing);
      expect(find.byKey(_moreKey), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('every target segment and the Set button are at least 48 by 48', (tester) async {
      await _openSetScreen(tester, _request(), <SetWallpaperChoice?>[]);

      for (final String label in <String>['Home screen', 'Lock screen', 'Both']) {
        final Size segment = tester.getSize(_segment(label));
        expect(segment.width, greaterThanOrEqualTo(48), reason: label);
        expect(segment.height, greaterThanOrEqualTo(48), reason: label);
      }
      final Size set = tester.getSize(find.byKey(_setKey));
      expect(set.width, greaterThanOrEqualTo(48));
      expect(set.height, greaterThanOrEqualTo(48));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a plain preview of a local file shows the Set button for the chosen screen', (tester) async {
      await _pumpPreview(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(_setKey), findsOneWidget);
      expect(find.text('Set on home screen'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('set and style controls', () {
    late SettingsLocalDataSource settings;
    late OfflineAssetFixture assets;

    setUp(() async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      settings = SettingsLocalDataSource(InMemoryLocalStore());
      getIt.registerSingleton<SettingsLocalDataSource>(settings);
      AnalyticsRuntime.instance = FakeAppAnalytics();
      assets = await OfflineAssetFixture.create();
      assets.install(immediateResolver: true);
      assets.mapSource(_previewPath, File(_previewPath));
      aw.AsyncWallpaper.debugSetClient(_Client());
    });

    tearDown(() async {
      aw.AsyncWallpaper.debugResetClient();
      AnalyticsRuntime.reset();
      await getIt.reset();
      await assets.dispose();
      app_state.prismUser = app_constants.createGuestPrismUser();
    });

    testWidgets('Android plain preview sets lock, home and both through the Set button', (tester) async {
      _mockSetChannels(tester);
      final _Client client = _Client(capabilities: _allCapabilities);
      aw.AsyncWallpaper.debugSetClient(client);
      await _pumpPreview(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lock screen'));
      await tester.pumpAndSettle();
      expect(find.text('Set on lock screen'), findsOneWidget);
      await tester.tap(find.text('Set on lock screen'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(client.requests.map((r) => r.target), [aw.WallpaperTarget.lock]);

      await tester.tap(find.text('Home screen'));
      await tester.pumpAndSettle();
      expect(find.text('Set on home screen'), findsOneWidget);
      await tester.tap(find.text('Set on home screen'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(client.requests.map((r) => r.target), [aw.WallpaperTarget.lock, aw.WallpaperTarget.home]);

      await tester.tap(find.text('Both'));
      await tester.pumpAndSettle();
      expect(find.text('Set on both screens'), findsOneWidget);
      await tester.tap(find.text('Set on both screens'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(client.requests.length, 3);
      expect(client.requests.last.target, aw.WallpaperTarget.both);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a set result snack bar, with its Undo, shows on the preview and not under it', (tester) async {
      await _pumpPreview(tester);
      ScaffoldMessenger.of(tester.element(find.byType(ClockOverlay))).showSnackBar(
        SnackBar(
          content: const Text('Wallpaper set'),
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(ClockOverlay), matching: find.text('Undo')), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(ClockOverlay), matching: find.text('Undo')));
    });

    testWidgets('iOS without a saveAction shows no save button and no set labels', (tester) async {
      await _pumpPreview(tester);
      await tester.pumpAndSettle();

      expect(find.text('Save to Photos'), findsNothing);
      expect(find.textContaining('Set on'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the icon style pill is absent in Lock mode and shows Default and Themed on Android', (tester) async {
      await _pumpPreview(tester);
      await tester.pumpAndSettle();

      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Themed'), findsOneWidget);
      expect(find.text('Dark'), findsNothing);
      expect(find.text('Clear'), findsNothing);
      expect(find.text('Tinted'), findsNothing);

      await tester.tap(find.text(_lockSegment()));
      await tester.pumpAndSettle();
      expect(find.text('Default'), findsNothing);
      expect(find.text('Themed'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('iOS offers Default, Dark, Clear and Tinted in Home mode only', (tester) async {
      await _pumpPreview(tester);
      await tester.pumpAndSettle();
      expect(find.text('Default'), findsNothing);

      await tester.tap(find.text(_homeSegment()));
      await tester.pumpAndSettle();
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Tinted'), findsOneWidget);
      expect(find.text('Themed'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the compact icon style keeps a 44 point tappable control', (tester) async {
      await _pumpPreview(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_homeSegment()));
      await tester.pumpAndSettle();

      final Finder clear = find.bySemanticsLabel('Clear');
      final Rect clearTarget = tester.getRect(clear);
      expect(clearTarget.height, greaterThanOrEqualTo(44));
      await tester.tapAt(clearTarget.bottomLeft + const Offset(8, -2));
      await tester.pumpAndSettle();

      expect(tester.widget<HomePreviewLayer>(find.byType(HomePreviewLayer)).iconStyle, PreviewIconStyle.clear);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('picking Dark on iOS saves it and a new preview starts with Dark', (tester) async {
      await _pumpPreview(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_homeSegment()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(tester.widget<HomePreviewLayer>(find.byType(HomePreviewLayer)).iconStyle, PreviewIconStyle.dark);
      expect(settings.get<String>(PersistenceKeys.previewIconStyle, defaultValue: ''), 'dark');

      await tester.pumpWidget(const SizedBox());
      await _pumpPreview(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_homeSegment()));
      await tester.pumpAndSettle();
      expect(tester.widget<HomePreviewLayer>(find.byType(HomePreviewLayer)).iconStyle, PreviewIconStyle.dark);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a saved style the platform does not offer falls back to standard', (tester) async {
      await settings.set(PersistenceKeys.previewIconStyle, 'themed');
      await _pumpPreview(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_homeSegment()));
      await tester.pumpAndSettle();

      expect(tester.widget<HomePreviewLayer>(find.byType(HomePreviewLayer)).iconStyle, PreviewIconStyle.standard);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('updating the preview image and tint refreshes its image and filter', (tester) async {
      await settings.set(PersistenceKeys.previewIconStyle, 'tinted');
      final Directory directory = Directory.systemTemp.createTempSync('clock_overlay_update_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final File first = (await tester.runAsync(() => _solidPng(directory, const Color(0xFFFF0000))))!;
      final File second = (await tester.runAsync(() => _solidPng(directory, const Color(0xFF00CC00))))!;

      Widget preview(String link, Color tint) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClockOverlay(link: link, file: true, tint: tint),
      );

      await tester.pumpWidget(preview(first.path, const Color(0xFFFF0000)));
      await _settleImages(tester);
      await tester.tap(find.text(_homeSegment()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(preview(second.uri.toString(), const Color(0xFF0000FF)));
      await _settleImages(tester);
      await tester.pumpAndSettle();

      final Image image = tester.widget<Image>(find.byType(Image).first);
      expect(
        _unwrapResizeImage(image.image),
        isA<FileImage>().having((provider) => provider.file.path, 'path', second.path),
      );
      expect(
        tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
        const ColorFilter.mode(Color(0xFF0000FF), BlendMode.hue),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a file URI resolves to the local image path on first mount', (tester) async {
      final Directory directory = Directory.systemTemp.createTempSync('clock_overlay_file_uri_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final File file = (await tester.runAsync(() => _solidPng(directory, const Color(0xFF224466))))!;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClockOverlay(link: file.uri.toString(), file: true),
        ),
      );
      await _settleImages(tester);

      final Image image = tester.widget<Image>(find.byType(Image).first);
      expect(
        _unwrapResizeImage(image.image),
        isA<FileImage>().having((provider) => provider.file.path, 'path', file.path),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed icon style save does not escape as an unhandled future error', (tester) async {
      await getIt.reset();
      getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(_FailingSetLocalStore()));
      await _pumpPreview(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_homeSegment()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(tester.widget<HomePreviewLayer>(find.byType(HomePreviewLayer)).iconStyle, PreviewIconStyle.dark);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the Portuguese icon style controls fit a narrow screen at large text', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: ClockOverlay(link: _previewPath, file: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tela inicial'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final Rect clearLabel = tester.getRect(find.text('Transparente'));
      final Rect clearSegment = tester.getRect(find.bySemanticsLabel('Transparente'));
      final RenderParagraph paragraph = tester.renderObject(find.text('Transparente'));
      final List<TextBox> glyphs = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: paragraph.text.toPlainText().length),
      );
      final Rect glyphBounds = glyphs
          .map((glyph) => MatrixUtils.transformRect(paragraph.getTransformTo(null), glyph.toRect()))
          .reduce((bounds, glyph) => bounds.expandToInclude(glyph));
      expect(clearLabel.left, greaterThanOrEqualTo(0));
      expect(clearLabel.right, lessThanOrEqualTo(320));
      expect(glyphBounds.left, greaterThanOrEqualTo(clearSegment.left));
      expect(glyphBounds.right, lessThanOrEqualTo(clearSegment.right));
      expect(glyphBounds.top, greaterThanOrEqualTo(clearSegment.top));
      expect(glyphBounds.bottom, lessThanOrEqualTo(clearSegment.bottom));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the German Set screen at 2x text keeps the Set button, Remember and Adjust on a narrow screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      aw.AsyncWallpaper.debugSetClient(_Client(capabilities: _allCapabilities));
      await _openSetScreen(
        tester,
        _request(onAdjust: _noAdjust),
        <SetWallpaperChoice?>[],
        locale: const Locale('de'),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      final AppLocalizationsDe l10n = AppLocalizationsDe();
      for (final Finder finder in <Finder>[
        find.byKey(_setKey),
        find.text(l10n.setScreenRemember),
        find.byKey(_adjustKey),
      ]) {
        final Rect rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
        expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder');
        expect(rect.right, lessThanOrEqualTo(320), reason: '$finder');
        expect(rect.bottom, lessThanOrEqualTo(640), reason: '$finder');
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('the tap area says Hide controls, then Show controls after a tap', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpPreview(tester);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Hide controls'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Hide controls'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Show controls'), findsOneWidget);
      handle.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
