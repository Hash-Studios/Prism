import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/favourite_icon.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/coins_test_backend.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';
import '../../../../support/wait_for_real_io.dart';

class _DetailTestAssetStore extends OfflineAssetStore {
  _DetailTestAssetStore({required super.directory, required this.sourceFile});

  final File sourceFile;
  final Map<String, File> _retainedFiles = <String, File>{};

  @override
  Future<File?> lookup(String source) async => _retainedFiles[source];

  @override
  Future<File> retain(String source, {File? file}) async {
    final File retained = await super.retain(source, file: file);
    _retainedFiles[source] = retained;
    return retained;
  }

  @override
  Future<File> resolve(String source, {bool allowNetwork = true}) async {
    if (source == 'https://img.test/full.jpg' || source == 'https://signed.test/prism-1') return sourceFile;
    throw OfflineAssetUnavailableException(source);
  }
}

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

class _MockImageCacheManager extends Mock implements BaseCacheManager {}

Future<void> _installEmptyOfflineAssetStore() async {
  final Directory directory = Directory.systemTemp.createTempSync('detail_empty_offline_assets');
  final _MockImageCacheManager cacheManager = _MockImageCacheManager();
  when(() => cacheManager.getFileFromCache(any())).thenAnswer((_) async => null);
  when(
    () => cacheManager.getFileStream(any(), withProgress: true),
  ).thenAnswer((_) => const Stream<FileResponse>.empty());
  final OfflineAssetStore store = OfflineAssetStore(
    directory: Directory('${directory.path}/retained'),
    cacheManager: cacheManager,
  );
  OfflineAssetStore.testOverride = store;
  PrismImageCache.testOverride = cacheManager;
  PrismFullImageCache.testOverride = cacheManager;
  addTearDown(() async {
    OfflineAssetStore.testOverride = null;
    PrismImageCache.testOverride = null;
    PrismFullImageCache.testOverride = null;
    if (directory.existsSync()) await directory.delete(recursive: true);
  });
}

Future<Finder> _waitForThumbnailFallback(WidgetTester tester) async {
  final Finder thumbnail = find.descendant(
    of: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Wallpaper'),
    matching: find.byWidgetPredicate((widget) => widget is CachedNetworkImage && widget.imageUrl.endsWith('thumb.jpg')),
  );
  for (int attempt = 0; attempt < 40 && thumbnail.evaluate().isEmpty; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(thumbnail, findsOneWidget, reason: 'the empty offline lookup completes and mounts the network thumbnail');
  return thumbnail;
}

FeedItemEntity _prism({List<String> collections = const <String>[], int? width, int? height}) => FeedItemEntity.prism(
  id: 'prism-1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'prism-1',
      source: WallpaperSource.prism,
      fullUrl: 'https://img.test/full.jpg',
      thumbnailUrl: 'https://img.test/thumb.jpg',
      authorName: 'Akshay',
      width: width,
      height: height,
    ),
    collections: collections,
    tags: const <String>['space', 'stars'],
  ),
);

Future<List<double>> _hues(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.Image image = (await codec.getNextFrame()).image;
  final ByteData data = (await image.toByteData())!;
  return <double>[
    for (int x = 0; x < image.width; x++)
      HSVColor.fromColor(
        Color.fromARGB(255, data.getUint8(x * 4), data.getUint8(x * 4 + 1), data.getUint8(x * 4 + 2)),
      ).hue,
  ];
}

Future<Uint8List> _redAndBluePng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = const Color(0xFFFF0000))
    ..drawRect(const Rect.fromLTWH(1, 0, 1, 1), Paint()..color = const Color(0xFF0000FF));
  final ui.Image image = await recorder.endRecording().toImage(2, 1);
  return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void main() {
  setUpAll(() => registerFallbackValue(const SelectAccentColor(color: Colors.black)));

  late DownloadedWallIndex downloaded;
  late SettingsLocalDataSource settings;
  late OfflineAssetFixture offlineAssets;

  setUp(() async {
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    downloaded = DownloadedWallIndex(settings);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
    getIt.registerSingleton<DownloadedWallIndex>(downloaded);
  });

  tearDown(() async {
    await offlineAssets.dispose();
    await getIt.reset();
  });

  Future<_MockWallpaperDetailBloc> pumpDetail(WidgetTester tester, WallpaperDetailLoaded state) async {
    final bloc = _MockWallpaperDetailBloc();
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: state.entity),
        ),
      ),
    );
    await tester.pump();
    return bloc;
  }

  testWidgets('Android shows a labelled Set action and icon actions with tooltips, on the details panel', (
    tester,
  ) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    expect(find.text('Set'), findsOneWidget);
    expect(find.byType(SetWallpaperButton), findsOneWidget);
    expect(find.byType(DownloadButton), findsOneWidget);
    expect(find.byType(FavouriteWallpaperButton), findsOneWidget);
    expect(find.byType(ShareButton), findsOneWidget);
    expect(find.byType(EditButton), findsOneWidget);
    for (final String tooltip in <String>['Set as wallpaper', 'Download', 'Favourite', 'Share', 'Edit']) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
    }
    expect(
      tester.getRect(find.byType(SetWallpaperButton)).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the action icons keep the current look: bare 20 point icons and the 30 point heart', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    for (final Type button in <Type>[EditButton, ShareButton, DownloadButton]) {
      final IconThemeData icon = IconTheme.of(
        tester.element(find.descendant(of: find.byType(button), matching: find.byType(Icon)).first),
      );
      expect(icon.size, 20, reason: '$button');
      expect(
        tester.getSize(find.descendant(of: find.byType(button), matching: find.byType(CircularMenuButton))),
        const Size.square(54),
      );
    }
    final FavoriteIcon heart = tester.widget<FavoriteIcon>(find.byType(FavoriteIcon));
    expect(heart.iconSize, 30);
    expect(heart.tapTargetExtent, 53);
    expect(heart.iconColor, Theme.of(tester.element(find.byType(FavoriteIcon))).colorScheme.onSurface);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the action bar stays at the bottom when the details panel opens', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
    final Rect before = tester.getRect(find.byType(SetWallpaperButton));
    final double chipTopBefore = tester.getRect(find.widgetWithText(ActionChip, 'space')).top;

    await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.getRect(find.byType(SetWallpaperButton)), before);
    expect(tester.getRect(find.widgetWithText(ActionChip, 'space')).top, lessThan(chipTopBefore));
    expect(tester.getRect(find.widgetWithText(ActionChip, 'space')).bottom, lessThanOrEqualTo(before.top));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('collapsed panel content is faded out and returns when the panel opens', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    expect(find.bySemanticsLabel('Original wallpaper colors'), findsNothing);
    final Opacity chipFade = tester.widget<Opacity>(
      find.ancestor(of: find.widgetWithText(ActionChip, 'space'), matching: find.byType(Opacity)).first,
    );
    expect(chipFade.opacity, 0);
    expect(tester.getSemantics(find.bySemanticsLabel('Expand wallpaper details')).rect.height, lessThan(100));

    await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.bySemanticsLabel('Original wallpaper colors'), findsOneWidget);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('collapsed palette ignores taps and an expanded palette selects its colour', (tester) async {
    final _MockWallpaperDetailBloc bloc = await pumpDetail(
      tester,
      WallpaperDetailLoaded(entity: _prism(), paletteLoading: false, colors: const <Color>[Colors.teal]),
    );
    final Finder tealSwatch = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Accent color',
    );

    expect(tealSwatch, findsOneWidget);
    await tester.tapAt(tester.getCenter(tealSwatch));
    await tester.pump();
    verifyNever(() => bloc.add(any(that: isA<SelectAccentColor>())));

    await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
    await tester.pumpAndSettle();
    await tester.tap(tealSwatch);

    verify(() => bloc.add(const SelectAccentColor(color: Colors.teal))).called(1);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('every button in the bar shrinks to 0.96 under the finger, not twice over', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
    Finder glyph(Type button) => find.descendant(of: find.byType(button), matching: find.byType(Icon)).first;
    final Map<String, Finder> buttons = <String, Finder>{
      'Set': find.byType(SetWallpaperButton),
      'Download': glyph(DownloadButton),
      'Favourite': glyph(FavouriteWallpaperButton),
      'Share': glyph(ShareButton),
      'Edit': glyph(EditButton),
    };

    for (final MapEntry<String, Finder> button in buttons.entries) {
      final double width = tester.getSize(button.value).width;
      final TestGesture finger = await tester.startGesture(tester.getCenter(button.value));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final double shown = tester.getBottomRight(button.value).dx - tester.getTopLeft(button.value).dx;
      await finger.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(shown / width, closeTo(0.96, 0.002), reason: button.key);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('dragging the collapsed handle opens the panel without moving the action bar', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
    final Rect actionBarBefore = tester.getRect(find.byType(WallpaperActionBar));

    await tester.drag(find.bySemanticsLabel('Expand wallpaper details'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Original wallpaper colors'), findsOneWidget);
    expect(tester.getRect(find.byType(WallpaperActionBar)), actionBarBefore);
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('iOS shows Save as the primary action and no Set action', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    expect(find.text('Save'), findsOneWidget);
    expect(find.byType(SetWallpaperButton), findsNothing);
    expect(find.byType(DownloadButton), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a wall in a premium collection is a premium download', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(entity: _prism(collections: <String>['space']), paletteLoading: false),
    );
    final DownloadButton premium = tester.widget<DownloadButton>(find.byType(DownloadButton));

    expect(premium.isPremiumContent, isTrue);
    expect(premium.contentId, 'prism-1');
  });

  testWidgets('a wall in a free collection is a normal download', (tester) async {
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(entity: _prism(collections: <String>['Nature']), paletteLoading: false),
    );

    expect(tester.widget<DownloadButton>(find.byType(DownloadButton)).isPremiumContent, isFalse);
  });

  testWidgets('a colour picked on the colour bar tints the wallpaper with its hue', (tester) async {
    await _installEmptyOfflineAssetStore();
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        entity: _prism(),
        paletteLoading: false,
        colors: const <Color>[Colors.teal],
        accent: Colors.teal,
        colorChanged: true,
      ),
    );
    final Finder thumbnail = await _waitForThumbnailFallback(tester);
    final Finder tinted = find.ancestor(of: thumbnail, matching: find.byType(ColorFiltered));
    expect(tinted, findsOneWidget);
    expect(tester.widget<ColorFiltered>(tinted).colorFilter, const ColorFilter.mode(Colors.teal, BlendMode.hue));
  });

  testWidgets('the original wallpaper has no colour filter, even with an accent on the chrome', (tester) async {
    await _installEmptyOfflineAssetStore();
    await pumpDetail(
      tester,
      WallpaperDetailLoaded(
        entity: _prism(),
        paletteLoading: false,
        colors: const <Color>[Colors.teal],
        accent: Colors.teal,
      ),
    );
    await _waitForThumbnailFallback(tester);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  group('colour variation as the source of Set, Download and Edit', () {
    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('detail_tint');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        pathChannel,
        (_) async => directory.path,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(pathChannel, null);
      directory.deleteSync(recursive: true);
    });

    List<Future<String> Function()?> preparers(WidgetTester tester) => <Future<String> Function()?>[
      tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton)).prepareSource,
      tester.widget<DownloadButton>(find.byType(DownloadButton)).variant?.prepare,
      tester.widget<EditButton>(find.byType(EditButton)).prepareSource,
    ];

    testWidgets('with a colour picked, each action renders this wallpaper in that hue', (tester) async {
      final File source = File('${directory.path}/wall.png');
      await tester.runAsync(() async => source.writeAsBytes(await _redAndBluePng()));
      final FeedItemEntity entity = FeedItemEntity.prism(
        id: 'prism-1',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: 'prism-1',
            source: WallpaperSource.prism,
            fullUrl: source.path,
            thumbnailUrl: 'https://img.test/thumb.jpg',
          ),
        ),
      );
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          entity: entity,
          paletteLoading: false,
          colors: const <Color>[Color(0xFF00FF00)],
          accent: const Color(0xFF00FF00),
          colorChanged: true,
        ),
      );

      for (final Future<String> Function()? prepare in preparers(tester)) {
        final List<double> hues = (await tester.runAsync(() async {
          final String path = await prepare!();
          return _hues(await File(path).readAsBytes());
        }))!;

        expect(hues, hasLength(2));
        expect(hues, everyElement(closeTo(120, 10)));
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('with the original showing, each action uses the wallpaper as it is', (tester) async {
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          entity: _prism(),
          paletteLoading: false,
          colors: const <Color>[Colors.teal],
          accent: Colors.teal,
        ),
      );

      expect(preparers(tester), everyElement(isNull));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('a detail download is acquired only after native save succeeds', () {
    const BasicMessageChannel<Object?> enqueueChannel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.enqueueDownload',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    const BasicMessageChannel<Object?> listChannel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    final CoinsTestBackend backend = CoinsTestBackend();
    late Directory directory;
    late File sourceFile;
    late List<DownloadRequest> requests;
    late List<Map<String, dynamic>> spendCalls;
    late Completer<void> nativeRequestStarted;
    late Completer<void> releaseNativeResponse;
    late Completer<void> saveFeedback;
    late Completer<void> failureToast;
    late bool nativeSaveSucceeds;
    late String failureMessage;

    setUp(() async {
      await backend.install();
      directory = Directory.systemTemp.createTempSync('detail_action_download');
      sourceFile = File('${directory.path}/source.png')..writeAsBytesSync(await _redAndBluePng());
      requests = <DownloadRequest>[];
      spendCalls = <Map<String, dynamic>>[];
      nativeRequestStarted = Completer<void>();
      releaseNativeResponse = Completer<void>();
      saveFeedback = Completer<void>();
      failureToast = Completer<void>();
      nativeSaveSucceeds = true;
      failureMessage = AppLocalizationsEn().economyAiDownloadFailed;
      CoinsService.instance.balanceNotifier.value = 100;
      backend.onCall = (String name, Map<String, dynamic> parameters) async {
        if (name == 'resolveOriginalAccess') {
          backend.originalCalls.add(parameters);
          if (parameters['mode'] == 'quote') {
            return <String, Object>{'status': 'quoted', 'requiredCoins': 0, 'currentBalance': 100};
          }
          return <String, Object>{
            'status': 'granted',
            'url': 'https://signed.test/prism-1',
            'expiresAt': DateTime.now().add(const Duration(minutes: 2)).millisecondsSinceEpoch,
          };
        }
        if (name == 'spendCoins') spendCalls.add(parameters);
        return <String, Object>{
          'success': true,
          'changed': true,
          'previousBalance': 100,
          'currentBalance': 95,
          'delta': -5,
          'transactionId': 'detail_download_tx',
        };
      };
      OfflineAssetStore.testOverride = _DetailTestAssetStore(
        directory: Directory('${directory.path}/retained'),
        sourceFile: sourceFile,
      );
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(pathChannel, (_) async => directory.path);
      messenger.setMockMethodCallHandler(toastChannel, (call) async {
        final Map<Object?, Object?> arguments = Map<Object?, Object?>.from(
          call.arguments as Map<Object?, Object?>? ?? {},
        );
        final String expectedMessage = nativeSaveSucceeds
            ? wallpaperSavedMessage(AppLocalizationsEn())
            : failureMessage;
        if (call.method == 'showToast' && arguments['msg'] == expectedMessage) {
          if (!saveFeedback.isCompleted) saveFeedback.complete();
          if (!nativeSaveSucceeds && !failureToast.isCompleted) failureToast.complete();
        }
        return true;
      });
      messenger.setMockDecodedMessageHandler<Object?>(enqueueChannel, (message) async {
        final DownloadRequest request = (message! as List<Object?>).single! as DownloadRequest;
        requests.add(request);
        if (!nativeRequestStarted.isCompleted) nativeRequestStarted.complete();
        await releaseNativeResponse.future;
        if (!nativeSaveSucceeds) {
          return <Object?>[OperationResult(success: false, message: 'No space')];
        }
        final File savedFile = File('${directory.path}/${request.filenameWithoutExtension}.png');
        return <Object?>[OperationResult(success: true, message: savedFile.path)];
      });
      messenger.setMockDecodedMessageHandler<Object?>(
        listChannel,
        (_) async => <Object?>[DownloadItemsResult(success: true, items: <String>[])],
      );
      await settings.set('notificationPermissionPromptedV2', true);
    });

    tearDown(() async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockDecodedMessageHandler<Object?>(enqueueChannel, null);
      messenger.setMockDecodedMessageHandler<Object?>(listChannel, null);
      messenger.setMockMethodCallHandler(pathChannel, null);
      messenger.setMockMethodCallHandler(toastChannel, null);
      OfflineAssetStore.testOverride = null;
      app_state.prismUser = app_constants.createGuestPrismUser();
      await settings.delete('notificationPermissionPromptedV2');
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    Future<void> tapAndWait(WidgetTester tester, String identity, {required bool expectAcquired}) async {
      await tester.tap(find.byType(DownloadButton));
      await tester.pump();
      await waitForRealIo(
        tester,
        () => nativeRequestStarted.isCompleted,
        reason: 'the granted original to render its requested variation and enqueue native save',
        pumpDuration: const Duration(milliseconds: 16),
      );
      expect(nativeRequestStarted.isCompleted, isTrue, reason: 'the native download request starts');
      expect(requests, hasLength(1));
      final DownloadRequest request = requests.single;
      expect(backend.originalCalls.where((call) => call['mode'] != 'quote'), hasLength(1));
      expect(backend.originalCalls.last['assetId'], 'prism-1');
      expect(backend.originalCalls.last['action'], 'download');
      if (nativeSaveSucceeds) {
        final List<int> bytes = (await tester.runAsync(
          () => request.isLocalFile ? File(request.link).readAsBytes() : sourceFile.readAsBytes(),
        ))!;
        await tester.runAsync(
          () => File('${directory.path}/${request.filenameWithoutExtension}.png').writeAsBytes(bytes),
        );
      }
      releaseNativeResponse.complete();
      await waitForRealIo(
        tester,
        () => saveFeedback.isCompleted,
        reason: 'native save to finish retaining and indexing the original before its localized feedback',
        pumpDuration: const Duration(milliseconds: 16),
      );
      expect(saveFeedback.isCompleted, isTrue, reason: 'the download flow reaches its success or failure feedback');
      if (!expectAcquired) expect(failureToast.isCompleted, isTrue);
      expect(downloaded.hasAcquired(link: identity, id: 'prism-1', source: WallpaperSource.prism), expectAcquired);
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('a tinted download saves valid prepared bytes and remembers only its variation identity', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        WallpaperDetailLoaded(
          entity: _prism(),
          paletteLoading: false,
          colors: const <Color>[Color(0xFF00FF00)],
          accent: const Color(0xFF00FF00),
          colorChanged: true,
        ),
      );
      await tapAndWait(tester, 'full_tint-00ff00.png', expectAcquired: true);

      expect(requests, hasLength(1));
      expect(requests.single.filenameWithoutExtension, 'full_tint-00ff00');
      expect(requests.single.link, isNot('https://img.test/full.jpg'));
      expect(requests.single.isLocalFile, isTrue);
      final List<int> savedBytes = (await tester.runAsync(() => File(requests.single.link).readAsBytes()))!;
      final List<double> hues = (await tester.runAsync(() => _hues(Uint8List.fromList(savedBytes))))!;
      expect(hues, hasLength(2));
      expect(hues, everyElement(closeTo(120, 10)));
      expect(spendCalls, isEmpty, reason: 'Prism originals use the server original-access grant, not spendCoins');
      expect(
        downloaded.hasAcquired(link: 'full_tint-00ff00.png', id: 'prism-1', source: WallpaperSource.prism),
        isTrue,
      );
      expect(
        downloaded.hasAcquired(link: 'https://img.test/full.jpg', id: 'prism-1', source: WallpaperSource.prism),
        isFalse,
      );
      final String ownerId = app_state.prismUser.id;
      expect(ownerId, backend.userId);
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'different-owner'
        ..loggedIn = true;
      expect(
        downloaded.hasAcquired(link: 'full_tint-00ff00.png', id: 'prism-1', source: WallpaperSource.prism),
        isFalse,
      );
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = ownerId
        ..loggedIn = true;
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets(
      'an original download saves only the granted URL and remembers the stable identity after native success',
      (tester) async {
        await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
        await tapAndWait(tester, 'https://img.test/full.jpg', expectAcquired: true);

        expect(requests, hasLength(1));
        expect(requests.single.link, 'https://signed.test/prism-1');
        expect(requests.single.isLocalFile, isFalse);
        expect(spendCalls, isEmpty, reason: 'the original-access grant owns charging');
        expect(
          downloaded.hasAcquired(link: 'https://img.test/full.jpg', id: 'prism-1', source: WallpaperSource.prism),
          isTrue,
        );
        expect(
          downloaded.hasAcquired(link: 'full_tint-00ff00.png', id: 'prism-1', source: WallpaperSource.prism),
          isFalse,
        );
        final File? retained = await tester.runAsync<File?>(
          () async => OfflineAssetStore.instance.lookup('https://img.test/full.jpg'),
        );
        expect(retained, isNotNull);
        final List<List<int>> retainedAndSourceBytes = (await tester.runAsync(() async {
          return <List<int>>[await retained!.readAsBytes(), await sourceFile.readAsBytes()];
        }))!;
        expect(retainedAndSourceBytes.first, retainedAndSourceBytes.last);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('a failed native save never records an acquisition', (tester) async {
      nativeSaveSucceeds = false;
      await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
      await tapAndWait(tester, 'https://img.test/full.jpg', expectAcquired: false);

      expect(requests, hasLength(1));
      expect(spendCalls, isEmpty, reason: 'the original-access grant owns charging');
      expect(
        downloaded.hasAcquired(link: 'https://img.test/full.jpg', id: 'prism-1', source: WallpaperSource.prism),
        isFalse,
      );
      expect(
        await tester.runAsync<File?>(() async => OfflineAssetStore.instance.lookup('https://img.test/full.jpg')),
        isNull,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a missing original grant never enqueues the preview URL or records an acquisition', (tester) async {
      nativeSaveSucceeds = false;
      failureMessage = AppLocalizationsEn().economyCoinSpendFailed;
      backend.onCall = (name, parameters) async {
        backend.originalCalls.add(parameters);
        if (parameters['mode'] == 'quote') {
          return <String, Object>{'status': 'quoted', 'requiredCoins': 0, 'currentBalance': 100};
        }
        return <String, Object>{'status': 'unavailable'};
      };
      await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
      await tester.tap(find.byType(DownloadButton));
      for (int i = 0; i < 100 && !failureToast.isCompleted; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(failureToast.isCompleted, isTrue);
      expect(backend.originalCalls.where((call) => call['mode'] != 'quote'), hasLength(1));
      expect(requests, isEmpty);
      expect(
        downloaded.hasAcquired(link: 'https://img.test/full.jpg', id: 'prism-1', source: WallpaperSource.prism),
        isFalse,
      );
      await tester.pump(const Duration(seconds: 2));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  testWidgets('a wall smaller than the screen shows the low resolution note', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(width: 100, height: 100), paletteLoading: false));

    expect(find.text('Low resolution for your screen'), findsOneWidget);
  });

  testWidgets('a large wall shows no low resolution note', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(width: 9000, height: 9000), paletteLoading: false));

    expect(find.text('Low resolution for your screen'), findsNothing);
  });

  testWidgets('the tags show as chips', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    expect(find.widgetWithText(ActionChip, 'space'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'stars'), findsOneWidget);
  });

  testWidgets('the similar strip stays hidden when it cannot load', (tester) async {
    await pumpDetail(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('More like this'), findsNothing);
  });
}
