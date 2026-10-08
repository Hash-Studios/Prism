import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
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
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
// ignore: implementation_imports
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/in_memory_local_store.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState> implements ThemeBloc {}

class _MockRecordAction extends Mock implements RecordWallpaperActionUseCase {}

class _Client implements WallpaperClient {
  _Client({this.live = false});

  final bool live;
  final List<aw.StaticWallpaperRequest> requests = <aw.StaticWallpaperRequest>[];

  @override
  Future<aw.WallpaperCapabilities> getCapabilities() async =>
      aw.WallpaperCapabilities(supportsOpenGlLiveWallpaper: live);

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

FeedItemEntity _prism({int? width, int? height}) => FeedItemEntity.prism(
  id: 'prism-1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'prism-1',
      source: WallpaperSource.prism,
      fullUrl: '/nonexistent/full.png',
      thumbnailUrl: '/nonexistent/thumb.png',
      width: width,
      height: height,
    ),
  ),
);

FeedItemEntity _wallhaven() => const FeedItemEntity.wallhaven(
  id: 'wh-1',
  wallpaper: WallhavenWallpaper(
    core: WallpaperCore(
      id: 'wh-1',
      source: WallpaperSource.wallhaven,
      fullUrl: '/nonexistent/full.png',
      thumbnailUrl: '/nonexistent/thumb.png',
      authorName: 'someone',
    ),
  ),
);

void main() {
  late _MockDetailBloc bloc;
  late _MockThemeBloc themeBloc;
  late _MockRecordAction recordAction;
  late FakeAppAnalytics analytics;
  late SettingsLocalDataSource settings;
  late _Client client;

  setUpAll(() {
    registerFallbackValue(WallpaperAction.set);
    registerFallbackValue(const ThemeEvent.started());
  });

  setUp(() async {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
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
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (call) async => true);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await getIt.reset();
    AnalyticsRuntime.reset();
    aw.AsyncWallpaper.debugResetClient();
  });

  Future<void> pump(WidgetTester tester, WallpaperDetailLoaded state) async {
    whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
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

  Future<void> tapSet(WidgetTester tester) async {
    await tester.tap(find.text('Set'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the Set button names its screen for analytics and carries the resolution notes', (tester) async {
    await pump(tester, WallpaperDetailLoaded(entity: _prism(width: 4000, height: 2000), paletteLoading: false));

    final SetWallpaperButton button = tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton));
    expect(button.entryPoint, 'wallpaper_detail');
    expect(button.notes, ['Landscape wallpaper: the sides will be cropped']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a Prism set is counted with the set action', (tester) async {
    await pump(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));

    await tapSet(tester);

    expect(client.requests.single.target, aw.WallpaperTarget.home);
    verify(() => recordAction('prism-1', WallpaperAction.set)).called(1);
    await tester.pump(const Duration(seconds: 10));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a Wallhaven set is not counted', (tester) async {
    await pump(tester, WallpaperDetailLoaded(entity: _wallhaven(), paletteLoading: false));

    await tapSet(tester);

    expect(client.requests, hasLength(1));
    verifyNever(() => recordAction(any(), any()));
    await tester.pump(const Duration(seconds: 10));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Match accent sets the light accent to the first palette colour', (tester) async {
    await pump(
      tester,
      WallpaperDetailLoaded(
        entity: _prism(),
        paletteLoading: false,
        colors: const <Color>[Color(0xFF008080), Color(0xFFFF0000)],
        accent: const Color(0xFF008080),
      ),
    );

    await tapSet(tester);
    await tester.tap(find.text('Match accent'));
    await tester.pump();

    verify(
      () => themeBloc.add(ThemeEvent.lightAccentChanged(accentColorValue: const Color(0xFF008080).toARGB32())),
    ).called(1);
    expect(analytics.events.whereType<AccentMatchedFromWallEvent>(), hasLength(1));
    await tester.pump(const Duration(seconds: 10));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Match accent sets the dark accent in a dark theme', (tester) async {
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(
        entity: _prism(),
        paletteLoading: false,
        colors: const <Color>[Color(0xFF008080)],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
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

    await tapSet(tester);
    await tester.tap(find.text('Match accent'));
    await tester.pump();

    verify(
      () => themeBloc.add(ThemeEvent.darkAccentChanged(accentColorValue: const Color(0xFF008080).toARGB32())),
    ).called(1);
    await tester.pump(const Duration(seconds: 10));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('with no palette yet there is no Match accent button', (tester) async {
    await pump(tester, WallpaperDetailLoaded(entity: _prism()));

    await tapSet(tester);

    expect(find.text('Match accent'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a Live chip sits on the image when the device supports live wallpapers', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client(live: true));
    await pump(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
    await tester.pump();

    expect(find.byType(MakeItLiveChip), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('no Live chip on iOS, where nothing can be set from the app', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client(live: true));
    await pump(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
    await tester.pump();

    expect(find.byType(MakeItLiveChip), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
