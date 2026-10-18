import 'dart:async';
import 'dart:io';

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
import 'package:Prism/core/widgets/prism_glass.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_bloc.j.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
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
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    await settings.set('notificationPermissionPromptedV2', true);
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
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    await getIt.reset();
    AnalyticsRuntime.reset();
    aw.AsyncWallpaper.debugResetClient();
  });

  Future<void> pump(WidgetTester tester, WallpaperDetailLoaded state, {Size? surfaceSize}) async {
    if (surfaceSize != null) {
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
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

  testWidgets('the Live chip rides 12 px above the glass and fades out as the panel opens', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client(live: true));
    await pump(
      tester,
      WallpaperDetailLoaded(entity: _prism(), paletteLoading: false),
      surfaceSize: const Size(393, 852),
    );
    await tester.pump();
    final Finder pill = find.descendant(of: find.byType(MakeItLiveChip), matching: find.byType(PrismGlass));
    final Finder panelGlass = find.byType(PrismGlass).last;
    final Finder fade = find.byWidgetPredicate((widget) => widget is Opacity && widget.child is MakeItLiveChip);

    expect(tester.getRect(panelGlass).top - tester.getRect(pill).bottom, 12);
    expect(tester.getRect(pill).left, 34);
    expect(tester.widget<Opacity>(fade).opacity, 1);

    await tester.tap(find.bySemanticsLabel('Expand wallpaper details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final double midway = tester.widget<Opacity>(fade).opacity;
    expect(tester.getRect(panelGlass).top - tester.getRect(pill).bottom, 12);
    await tester.pumpAndSettle();

    expect(midway, inExclusiveRange(0, 1));
    expect(tester.widget<Opacity>(fade).opacity, 0);
    await tester.tap(pill, warnIfMissed: false);
    await tester.pump();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'in a wide window the glass is a centred 560 column clear of the side safe area, and the wallpaper stays full screen',
    (tester) async {
      aw.AsyncWallpaper.debugSetClient(_Client(live: true));
      tester.view.physicalSize = const Size(844 * 3, 390 * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(left: 47 * 3, right: 47 * 3, bottom: 21 * 3);
      tester.view.viewPadding = const FakeViewPadding(left: 47 * 3, right: 47 * 3, bottom: 21 * 3);
      addTearDown(tester.view.reset);
      await pump(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
      await tester.pump(const Duration(milliseconds: 200));

      final Rect glass = tester.getRect(find.byType(PrismGlass).last);
      expect(glass.left, 142);
      expect(glass.right, 844 - 142);
      expect(
        tester.getRect(find.descendant(of: find.byType(MakeItLiveChip), matching: find.byType(PrismGlass))).left,
        166,
      );
      expect(tester.getRect(find.byType(SetWallpaperButton)).left, 166);
      expect(tester.getRect(find.byType(SetWallpaperButton)).left, greaterThan(glass.left));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('tablet landscape keeps a dragged-open panel through rotation to portrait', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client(live: true));
    await pump(
      tester,
      WallpaperDetailLoaded(entity: _prism(), paletteLoading: false),
      surfaceSize: const Size(1024, 768),
    );

    final Finder glass = find.byType(PrismGlass).last;
    final Finder pill = find.descendant(of: find.byType(MakeItLiveChip), matching: find.byType(PrismGlass));
    final Finder chipOpacity = find.byWidgetPredicate((widget) => widget is Opacity && widget.child is MakeItLiveChip);
    expect(tester.getRect(glass), const Rect.fromLTRB(232, 656, 792, 758));
    expect(tester.getRect(pill).left, 256);
    expect(tester.getRect(glass).top - tester.getRect(pill).bottom, 12);

    await tester.drag(find.bySemanticsLabel('Expand wallpaper details'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getSize(glass).height, closeTo(768 * 0.55, 0.01));
    expect(tester.widget<Opacity>(chipOpacity).opacity, 0);

    tester.view.physicalSize = const Size(768, 1024);
    await tester.pumpAndSettle();
    expect(tester.getRect(glass).left, 104);
    expect(tester.getRect(glass).right, 664);
    expect(tester.getRect(glass).bottom, 1014);
    expect(tester.getRect(glass).top, closeTo(450.8, 0.01));
    expect(tester.widget<Opacity>(chipOpacity).opacity, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('asymmetric side safe area moves the controls, not the full-screen wallpaper', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client(live: true));
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(left: 47, bottom: 21);
    tester.view.viewPadding = const FakeViewPadding(left: 47, bottom: 21);
    addTearDown(tester.view.reset);
    await pump(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
    await tester.pump(const Duration(milliseconds: 200));

    final Finder glass = find.byType(PrismGlass).last;
    final Finder wallpaper = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Wallpaper',
    );
    expect(tester.getRect(glass), const Rect.fromLTRB(142, 257, 702, 359));
    expect(tester.getRect(find.byType(WallpaperActionBar)).left, 142);
    expect(tester.getRect(find.byType(WallpaperActionBar)).right, 702);
    expect(
      tester.getRect(find.descendant(of: find.byType(MakeItLiveChip), matching: find.byType(PrismGlass))).left,
      166,
    );
    expect(tester.getRect(wallpaper), const Rect.fromLTWH(0, 0, 844, 390));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('phone panel keeps the original 10 px side inset at both ends of the phone width range', (tester) async {
    for (final Size size in <Size>[const Size(320, 568), const Size(480, 960)]) {
      await pump(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false), surfaceSize: size);

      final Rect glass = tester.getRect(find.byType(PrismGlass).last);
      expect(glass.left, 10, reason: '$size left edge');
      expect(glass.right, size.width - 10, reason: '$size right edge');
      expect(tester.getRect(find.byType(WallpaperActionBar)).left, 10, reason: '$size action bar');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('no Live chip on iOS, where nothing can be set from the app', (tester) async {
    aw.AsyncWallpaper.debugSetClient(_Client(live: true));
    await pump(tester, WallpaperDetailLoaded(entity: _prism(), paletteLoading: false));
    await tester.pump();

    expect(find.byType(MakeItLiveChip), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
