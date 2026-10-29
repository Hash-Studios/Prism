import 'dart:async';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_bloc.j.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState> implements ThemeBloc {}

class _MockRecordAction extends Mock implements RecordWallpaperActionUseCase {}

class _Client implements WallpaperClient {
  _Client({this.live = false});

  final bool live;
  final List<aw.StaticWallpaperRequest> requests = <aw.StaticWallpaperRequest>[];
  final Completer<void> requestObserved = Completer<void>();

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async =>
      aw.WallpaperCapabilities(supportsOpenGlLiveWallpaper: live);

  @override
  Future<aw.WallpaperOperationResult> applyWallpaper(aw.StaticWallpaperRequest request) async {
    requests.add(request);
    if (!requestObserved.isCompleted) requestObserved.complete();
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

FeedItemEntity _prism({int? width, int? height}) => FeedItemEntity.prism(
  id: 'prism-1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'prism-1',
      source: WallpaperSource.prism,
      fullUrl: File('assets/images/prism.webp').absolute.path,
      thumbnailUrl: File('assets/images/prism.webp').absolute.path,
      width: width,
      height: height,
    ),
  ),
);

FeedItemEntity _wallhaven() => FeedItemEntity.wallhaven(
  id: 'wh-1',
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(
      id: 'wh-1',
      source: WallpaperSource.wallhaven,
      fullUrl: File('assets/images/prism.webp').absolute.path,
      thumbnailUrl: File('assets/images/prism.webp').absolute.path,
      authorName: 'someone',
    ),
  ),
);

void main() {
  setUpFavouriteCounts();
  late _MockDetailBloc bloc;
  late _MockThemeBloc themeBloc;
  late _MockRecordAction recordAction;
  late FakeAppAnalytics analytics;
  late SettingsLocalDataSource settings;
  late _Client client;
  late List<String> toastMessages;

  setUpAll(() {
    registerFallbackValue(WallpaperAction.set);
    registerFallbackValue(const ThemeEvent.started());
  });

  setUp(() async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'detail-set-owner'
      ..loggedIn = true;
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    await settings.set('notificationPermissionPromptedV2', true);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
    final downloaded = DownloadedWallIndex(settings);
    getIt.registerSingleton<DownloadedWallIndex>(downloaded);
    await downloaded.remember(link: _prism().fullUrl, id: 'prism-1', source: WallpaperSource.prism);
    recordAction = _MockRecordAction();
    when(() => recordAction(any(), any())).thenAnswer((_) async => Result.success(null));
    getIt.registerSingleton<RecordWallpaperActionUseCase>(recordAction);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    client = _Client();
    aw.AsyncWallpaper.debugSetClient(client);
    bloc = _MockDetailBloc();
    themeBloc = _MockThemeBloc();
    whenListen(themeBloc, const Stream<ThemeState>.empty(), initialState: ThemeState.initial());
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
        PrismMediaHostApi.pigeonChannelCodec,
      ),
      (_) async => <Object?>[
        DownloadItemsResult(success: true, items: <String>[_prism().fullUrl]),
      ],
    );
    toastMessages = <String>[];
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (call) async {
      final Object? arguments = call.arguments;
      if (call.method == 'showToast' && arguments is Map) {
        final Object? message = arguments['msg'];
        if (message is String) toastMessages.add(message);
      }
      return true;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
        PrismMediaHostApi.pigeonChannelCodec,
      ),
      null,
    );
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await getIt.reset();
    AnalyticsRuntime.reset();
    aw.AsyncWallpaper.debugResetClient();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> pump(WidgetTester tester, WallpaperDetailLoaded state, {Size? surfaceSize}) async {
    if (surfaceSize != null) {
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state.copyWith(panelCollapsed: false));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: MultiBlocProvider(
          providers: [
            BlocProvider<WallpaperDetailBloc>.value(value: bloc),
            BlocProvider<ThemeBloc>.value(value: themeBloc),
          ],
          child: WallpaperDetailScreen(entity: state.entity),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapSet(WidgetTester tester, {bool expectMatchAccent = false}) async {
    await tester.tap(find.text('Set'));
    await tester.pump();
    for (int i = 0; i < 40 && !client.requestObserved.isCompleted; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(client.requestObserved.isCompleted, isTrue, reason: 'setting waits for the offline image to resolve');
    expect(client.requests, hasLength(1));
    for (
      int i = 0;
      i < 40 &&
          (expectMatchAccent
              ? find.text('Match accent').evaluate().isEmpty
              : !toastMessages.contains('Wallpaper set successfully!'));
      i++
    ) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    if (expectMatchAccent) {
      expect(find.text('Wallpaper set'), findsOneWidget, reason: 'the native apply reports success');
      expect(find.text('Match accent'), findsOneWidget);
    } else {
      expect(toastMessages, contains('Wallpaper set successfully!'), reason: 'the native apply reports success');
    }
    await tester.pump();
  }

  Future<void> waitForMatchAccent(WidgetTester tester) async {
    for (int i = 0; i < 40 && find.text('Match accent').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(find.text('Match accent'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the Set button names its screen for analytics and carries the resolution notes', (tester) async {
    await pump(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(width: 4000, height: 2000),
        paletteLoading: false,
      ),
    );

    final SetWallpaperButton button = tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton));
    expect(button.entryPoint, 'wallpaper_detail');
    expect(button.notes, ['Landscape wallpaper: the sides will be cropped']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a Prism set is counted with the set action', (tester) async {
    await pump(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
    );

    await tapSet(tester);

    expect(client.requests.single.target, aw.WallpaperTarget.home);
    verify(() => recordAction('prism-1', WallpaperAction.set)).called(1);
    await tester.pump(const Duration(seconds: 10));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a Wallhaven set is not counted', (tester) async {
    await pump(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _wallhaven(),
        paletteLoading: false,
      ),
    );

    await tapSet(tester);

    expect(client.requests, hasLength(1));
    verifyNever(() => recordAction(any(), any()));
    await tester.pump(const Duration(seconds: 10));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Match accent sets the light accent to the first palette colour', (tester) async {
    await pump(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
        colors: const <Color>[Color(0xFF008080), Color(0xFFFF0000)],
        accent: const Color(0xFF008080),
      ),
      surfaceSize: const Size(800, 1000),
    );

    await tapSet(tester, expectMatchAccent: true);
    await waitForMatchAccent(tester);
    await tester.tap(find.text('Match accent'));
    await tester.pump();

    verify(
      () => themeBloc.add(ThemeEvent.lightAccentChanged(accentColorValue: const Color(0xFF008080).toARGB32())),
    ).called(1);
    expect(analytics.events.whereType<AccentMatchedFromWallEvent>(), hasLength(1));
    await tester.pump(const Duration(seconds: 10));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Match accent sets the dark accent in a dark theme', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
        colors: const <Color>[Color(0xFF008080)],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        theme: ThemeData.dark(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<WallpaperDetailBloc>.value(value: bloc),
            BlocProvider<ThemeBloc>.value(value: themeBloc),
          ],
          child: WallpaperDetailScreen(entity: _prism()),
        ),
      ),
    );
    await tester.pump();

    await tapSet(tester, expectMatchAccent: true);
    await waitForMatchAccent(tester);
    await tester.tap(find.text('Match accent'));
    await tester.pump();

    verify(
      () => themeBloc.add(ThemeEvent.darkAccentChanged(accentColorValue: const Color(0xFF008080).toARGB32())),
    ).called(1);
    await tester.pump(const Duration(seconds: 10));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('with no palette yet there is no Match accent button', (tester) async {
    await pump(tester, WallpaperDetailLoaded(recommendations: const RecommendationState.exhausted(), entity: _prism()));

    await tapSet(tester);

    expect(find.text('Match accent'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a Live chip sits on the image when the device supports live wallpapers', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client(live: true));
    await pump(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
    );
    await tester.pump();

    expect(find.byType(MakeItLiveChip), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the Live chip stays within the bounded wallpaper header', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client(live: true));
    await pump(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
      surfaceSize: const Size(393, 852),
    );
    await tester.pump();
    final image = tester.getRect(
      find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Wallpaper'),
    );
    final chip = tester.getRect(find.byType(MakeItLiveChip));
    expect(chip.bottom, lessThanOrEqualTo(image.bottom));
    expect(chip.top, greaterThan(image.top));
    expect(image.height, closeTo(852 * 0.66, 0.01));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('wide safe areas inset the inline actions, and a tall wall gets a centred card instead of a strip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 47, right: 47, bottom: 21);
    tester.view.viewPadding = const FakeViewPadding(left: 47, right: 47, bottom: 21);
    addTearDown(tester.view.reset);
    await pump(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
    );
    // The rows under the card keep the 560 point panel width, centred in the safe area.
    final actions = tester.getRect(find.byType(WallpaperActionBar));
    expect(actions.width, 560);
    expect(actions.center.dx, 844 / 2);
    final card = tester.getRect(
      find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Wallpaper'),
    );
    // A 9:16 wall in landscape keeps a portrait card, at most 0.85 as wide as it is tall, centred in the safe area.
    expect(card.height, closeTo(390 * 0.66, 0.01));
    expect(card.width, closeTo(card.height * 0.85, 0.01));
    expect(card.center.dx, closeTo(844 / 2, 0.01));
    expect(tester.getRect(find.byTooltip('Back')).topLeft, card.topLeft + const Offset(4, 4));
    expect(tester.getRect(find.byTooltip('Preview on your screen')).topRight, card.topRight + const Offset(-4, 4));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('no Live chip on iOS, where nothing can be set from the app', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client(live: true));
    await pump(
      tester,
      WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: _prism(),
        paletteLoading: false,
      ),
    );
    await tester.pump();

    expect(find.byType(MakeItLiveChip), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('the Set screen opens from each entry point', () {
    Future<void> waitUntil(WidgetTester tester, bool Function() done) async {
      for (int i = 0; i < 80 && !done(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
    }

    void stubSetScreen(List<SetScreenRequest> opened, {SetWallpaperChoice? choice}) {
      final original = SetWallpaperFlow.screenOpener;
      SetWallpaperFlow.screenOpener = (context, request) async {
        opened.add(request);
        return choice;
      };
      addTearDown(() => SetWallpaperFlow.screenOpener = original);
    }

    testWidgets('the Set button opens the Set screen when no default is saved', (tester) async {
      await settings.set(PersistenceKeys.defaultApplyTarget, 'ask');
      final List<SetScreenRequest> opened = <SetScreenRequest>[];
      stubSetScreen(opened);
      await pump(
        tester,
        WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: _prism(),
          paletteLoading: false,
        ),
      );

      await tester.tap(find.text('Set'));
      await tester.pump();
      await waitUntil(tester, () => opened.isNotEmpty);

      expect(opened, hasLength(1));
      expect(opened.single.url, _prism().fullUrl);
      expect(opened.single.thumbnailUrl, isEmpty, reason: 'a thumbnail identical to the Prism original is withheld');
      expect(opened.single.onAdjust, isNotNull);
      expect(client.requests, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Preview on your screen opens the Set screen as wallpaper_preview', (tester) async {
      final List<SetScreenRequest> opened = <SetScreenRequest>[];
      stubSetScreen(opened, choice: const SetWallpaperChoice(WallpaperTarget.home));
      await pump(
        tester,
        WallpaperDetailLoaded(
          recommendations: const RecommendationState.exhausted(),
          entity: _prism(),
          paletteLoading: false,
        ),
      );

      await tester.tap(find.byTooltip('Preview on your screen'));
      await tester.pump();
      await waitUntil(tester, () => analytics.events.whereType<SetWallEvent>().isNotEmpty);

      expect(opened, hasLength(1));
      expect(opened.single.url, _prism().fullUrl);
      expect(opened.single.onAdjust, isNotNull);
      final List<SetWallEvent> events = analytics.events.whereType<SetWallEvent>().toList();
      expect(events, hasLength(1));
      expect(events.single.entryPoint, 'wallpaper_preview');
      expect(events.single.wallpaperTarget, WallpaperTarget.home);
      expect(client.requests, hasLength(1));
      await tester.pump(const Duration(seconds: 10));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('on iOS Preview on your screen opens the preview with Save to Photos, not the Set screen', (
      tester,
    ) async {
      // A wall nobody has saved yet. A saved one shows Saved on the button instead of Save to Photos.
      const FeedItemEntity unsaved = FeedItemEntity.prism(
        id: 'prism-unsaved',
        wallpaper: PrismWallpaper(
          core: WallpaperCore(
            id: 'prism-unsaved',
            source: WallpaperSource.prism,
            fullUrl: 'https://example.com/prism-unsaved.jpg',
            thumbnailUrl: '',
          ),
        ),
      );
      final List<SetScreenRequest> opened = <SetScreenRequest>[];
      stubSetScreen(opened);
      await pump(
        tester,
        const WallpaperDetailLoaded(
          recommendations: RecommendationState.exhausted(),
          entity: unsaved,
          paletteLoading: false,
        ),
      );

      await tester.tap(find.byTooltip('Preview on your screen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Save to Photos'), findsOneWidget);
      expect(opened, isEmpty);
      Navigator.of(tester.element(find.textContaining('Save to Photos'))).pop();
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
