import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

class _MockFavouriteWallsBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {
  final List<FavouriteWallsEvent> events = <FavouriteWallsEvent>[];
  void Function(FavouriteWallsEvent)? handleEvent;

  @override
  void add(FavouriteWallsEvent event) {
    events.add(event);
    handleEvent?.call(event);
  }
}

const Size _screen = Size(390, 844);
const String _immersive = 'SystemUiMode.immersiveSticky';
const String _edgeToEdge = 'SystemUiMode.edgeToEdge';

FeedItemEntity _prism(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/$id-thumb.jpg',
    ),
  ),
);

WallpaperFeed _feedOf(BuildContext context, List<FeedItemEntity> items) => WallpaperFeed(
  grid: context,
  tiles: [for (final (i, item) in items.indexed) (item: item, index: i, heroTag: 'tile-$i')],
);

Finder get _card => find.byType(WallpaperQuickActionRegion).first;

String _cardId(WidgetTester tester) => tester.widget<WallpaperQuickActionRegion>(_card).item.id;

double _zoom(WidgetTester tester) => tester
    .widget<Transform>(
      find.ancestor(of: find.byType(WallpaperDetailHero).first, matching: find.byType(Transform)).first,
    )
    .transform
    .getMaxScaleOnAxis();

bool _controlsShown(WidgetTester tester) => find.byTooltip('Back').hitTestable().evaluate().isNotEmpty;

void main() {
  setUpFavouriteCounts();
  late OfflineAssetFixture offlineAssets;
  late List<String> modes;
  late FakeAppAnalytics events;
  late SettingsLocalDataSource settings;
  late bool startLoading;
  final List<FeedItemEntity> blocWalls = <FeedItemEntity>[];
  final List<StreamController<WallpaperDetailState>> blocStates = <StreamController<WallpaperDetailState>>[];

  setUp(() async {
    blocWalls.clear();
    blocStates.clear();
    modes = <String>[];
    startLoading = false;
    events = FakeAppAnalytics();
    AnalyticsRuntime.reset();
    AnalyticsRuntime.instance = events;
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    // Most cases are not about the first-run hint.
    await settings.set('wallpaper_detail.immersive_hint_shown', true);
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    getIt.registerFactory<WallpaperDetailBloc>(() {
      final bloc = _MockDetailBloc();
      final FeedItemEntity item = blocWalls.removeAt(0);
      final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>.broadcast();
      blocStates.add(states);
      whenListen(
        bloc,
        states.stream,
        initialState: startLoading
            ? const WallpaperDetailInitial()
            : WallpaperDetailLoaded(
                entity: item,
                paletteLoading: false,
                recommendations: const RecommendationState.exhausted(),
              ),
      );
      return bloc;
    });
  });

  tearDown(() async {
    for (final StreamController<WallpaperDetailState> states in blocStates) {
      await states.close();
    }
    await offlineAssets.dispose();
    await getIt.reset();
  });

  /// Pumps a home page with a button that opens [open] from [feed], and opens it.
  Future<NavigatorState> pumpDetail(
    WidgetTester tester, {
    required List<FeedItemEntity> feed,
    required FeedItemEntity open,
    bool reduceMotion = false,
    bool failFirstEdgeToEdge = false,
    Completer<void>? deferFirstEdgeToEdgeFailureUntil,
    bool failFirstImmersive = false,
    Completer<void>? blockFirstImmersiveUntil,
    bool canonicalLoading = false,
    bool rtl = false,
    FavouriteWallsBloc? favouritesBloc,
    bool push = true,
    Size size = _screen,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    startLoading = canonicalLoading;
    addTearDown(tester.view.reset);
    bool shouldFailEdgeToEdge = failFirstEdgeToEdge;
    bool shouldDeferEdgeToEdgeFailure = deferFirstEdgeToEdgeFailureUntil != null;
    bool shouldFailImmersive = failFirstImmersive;
    bool shouldBlockImmersive = blockFirstImmersiveUntil != null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
        final String mode = call.arguments as String;
        modes.add(mode);
        if (mode == _edgeToEdge && shouldFailEdgeToEdge) {
          shouldFailEdgeToEdge = false;
          throw PlatformException(code: 'test_failure');
        }
        if (mode == _edgeToEdge && shouldDeferEdgeToEdgeFailure) {
          shouldDeferEdgeToEdgeFailure = false;
          await deferFirstEdgeToEdgeFailureUntil!.future;
          throw PlatformException(code: 'test_failure');
        }
        if (mode == _immersive && shouldFailImmersive) {
          shouldFailImmersive = false;
          throw PlatformException(code: 'test_failure');
        }
        if (mode == _immersive && shouldBlockImmersive) {
          shouldBlockImmersive = false;
          await blockFirstImmersiveUntil!.future;
        }
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    Widget detail(BuildContext context) => WallpaperDetailScreen(
      entity: open,
      feed: _feedOf(context, feed),
      heroTag: 'tile-${feed.indexOf(open)}',
    ).wrappedRoute(context);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          final Widget content = Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
          );
          return favouritesBloc == null
              ? content
              : BlocProvider<FavouriteWallsBloc>.value(value: favouritesBloc, child: content);
        },
        home: push ? const Scaffold(body: Text('grid')) : Builder(builder: detail),
      ),
    );
    if (push) {
      unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: detail)));
    }
    if (canonicalLoading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    } else {
      await tester.pumpAndSettle();
    }
    return navigator.currentState!;
  }

  Future<void> tapWall(WidgetTester tester) async {
    await tester.tapAt(tester.getCenter(_card));
    await tester.pumpAndSettle();
  }

  testWidgets('a tap hides the controls and system bars, and grows the same picture to the screen', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a);
    final State picture = tester.state(find.byType(ProgressiveWallpaperImage).first);
    expect(tester.getSize(_card), isNot(_screen));
    expect(_controlsShown(tester), isTrue);

    await tapWall(tester);

    expect(modes, <String>[_immersive]);
    expect(tester.getRect(_card), Offset.zero & _screen);
    expect(tester.widget<WallpaperDetailHero>(find.byType(WallpaperDetailHero).first).radius, 0);
    expect(_controlsShown(tester), isFalse);
    expect(find.byTooltip('Share').hitTestable(), findsNothing);
    expect(identical(tester.state(find.byType(ProgressiveWallpaperImage).first), picture), isTrue);
    expect(
      events.events.whereType<DetailImmersiveToggledEvent>().map((e) => (e.immersive, e.source)),
      <(bool, ImmersiveToggleSourceValue)>[(true, ImmersiveToggleSourceValue.tap)],
    );

    await tapWall(tester);

    expect(modes, <String>[_immersive, _edgeToEdge]);
    expect(tester.getSize(_card), isNot(_screen));
    expect(_controlsShown(tester), isTrue);
    expect(identical(tester.state(find.byType(ProgressiveWallpaperImage).first), picture), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the end of a pinch, a feed swipe or a page drag is not a tap', (tester) async {
    final FeedItemEntity a = _prism('a');
    final FeedItemEntity b = _prism('b');
    blocWalls.addAll(<FeedItemEntity>[a, b]);
    // A short window, so the page has room to scroll.
    final NavigatorState navigator = await pumpDetail(
      tester,
      feed: <FeedItemEntity>[a, b],
      open: a,
      size: const Size(390, 480),
    );
    final Offset centre = tester.getCenter(_card);

    final TestGesture first = await tester.startGesture(centre - const Offset(30, 0), pointer: 1);
    final TestGesture second = await tester.startGesture(centre + const Offset(30, 0), pointer: 2);
    await first.moveBy(const Offset(-40, 0));
    await second.moveBy(const Offset(40, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(modes, isEmpty, reason: 'a pinch');
    expect(_cardId(tester), 'a', reason: 'a pinch does not swipe the feed');

    await tester.drag(_card, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(modes, isEmpty, reason: 'a page drag');
    expect(tester.widget<CustomScrollView>(find.byType(CustomScrollView).first).controller!.offset, greaterThan(0));

    await tester.drag(_card, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(modes, isEmpty, reason: 'a feed swipe');
    expect(_cardId(tester), 'b');
    expect(navigator.canPop(), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('immersive, a feed swipe shows the next wall full screen and a pinch zooms it', (tester) async {
    final FeedItemEntity a = _prism('a');
    final FeedItemEntity b = _prism('b');
    blocWalls.addAll(<FeedItemEntity>[a, b]);
    await pumpDetail(tester, feed: <FeedItemEntity>[a, b], open: a);
    await tapWall(tester);

    await tester.drag(_card, const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(_cardId(tester), 'b');
    expect(tester.getRect(_card), Offset.zero & _screen);
    expect(modes, <String>[_immersive]);
    expect(_controlsShown(tester), isFalse);

    final Offset centre = tester.getCenter(_card);
    final TestGesture first = await tester.startGesture(centre - const Offset(30, 0), pointer: 1);
    final TestGesture second = await tester.startGesture(centre + const Offset(30, 0), pointer: 2);
    await first.moveBy(const Offset(-30, 0));
    await second.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(_zoom(tester), closeTo(2, 0.01));

    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(_zoom(tester), 1);
    expect(modes, <String>[_immersive], reason: 'the pinch did not leave immersive mode');
    expect(_cardId(tester), 'b');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a scrolled detail returns to its wall before immersive pinch zoom', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a, size: const Size(390, 480));

    await tester.drag(_card, const Offset(0, -120));
    await tester.pumpAndSettle();
    final ScrollController scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView).first).controller!;
    expect(scroll.offset, greaterThan(0));
    await tapWall(tester);
    expect(scroll.offset, 0);

    final Offset centre = tester.getCenter(_card);
    final TestGesture first = await tester.startGesture(centre - const Offset(30, 0), pointer: 1);
    final TestGesture second = await tester.startGesture(centre + const Offset(30, 0), pointer: 2);
    await first.moveBy(const Offset(-30, 0));
    await second.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(_zoom(tester), closeTo(2, 0.01));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a rightward RTL swipe advances to the next wall', (tester) async {
    final FeedItemEntity a = _prism('a');
    final FeedItemEntity b = _prism('b');
    blocWalls.addAll(<FeedItemEntity>[a, b]);
    await pumpDetail(tester, feed: <FeedItemEntity>[a, b], open: a, rtl: true);

    await tester.drag(_card, const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(_cardId(tester), 'b');
    expect(modes, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('canonical loading keeps the immersive wall interactive and preserves its image state', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a, canonicalLoading: true);
    final State picture = tester.state(find.byType(ProgressiveWallpaperImage).first);

    await tester.tapAt(tester.getCenter(_card));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(modes, <String>[_immersive]);
    expect(_controlsShown(tester), isFalse);

    blocStates.single.add(
      WallpaperDetailLoaded(entity: a, paletteLoading: false, recommendations: const RecommendationState.exhausted()),
    );
    await tester.pumpAndSettle();

    expect(identical(tester.state(find.byType(ProgressiveWallpaperImage).first), picture), isTrue);
    expect(tester.getRect(_card), Offset.zero & _screen);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('back shows the controls first, then a second back leaves', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a);
    await tapWall(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(modes, <String>[_immersive, _edgeToEdge]);
    expect(_controlsShown(tester), isTrue);
    expect(find.byType(WallpaperDetailScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WallpaperDetailScreen), findsNothing);
    expect(modes, <String>[_immersive, _edgeToEdge]);
  });

  testWidgets('a pop while immersive brings the system bars back', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    final NavigatorState navigator = await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a);
    await tapWall(tester);

    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.byType(WallpaperDetailScreen), findsNothing);
    expect(modes, <String>[_immersive, _edgeToEdge]);
  });

  testWidgets('a route pushed over immersive mode brings the system bars and controls back', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    final NavigatorState navigator = await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a);
    await tapWall(tester);

    unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('sheet')))));
    await tester.pumpAndSettle();
    expect(modes, <String>[_immersive, _edgeToEdge]);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(modes, <String>[_immersive, _edgeToEdge]);
    expect(_controlsShown(tester), isTrue);
  });

  testWidgets('sending the app to the background leaves immersive mode, and resume keeps the controls', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a);
    await tapWall(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(modes, <String>[_immersive], reason: 'a brief interruption, such as Control Centre, keeps it');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(modes, <String>[_immersive, _edgeToEdge]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(modes, <String>[_immersive, _edgeToEdge]);
    expect(_controlsShown(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stacked detail routes hand immersive ownership back without a stale bars restore', (tester) async {
    final FeedItemEntity a = _prism('a');
    final FeedItemEntity b = _prism('b');
    blocWalls.addAll(<FeedItemEntity>[a, b]);
    final NavigatorState navigator = await pumpDetail(tester, feed: <FeedItemEntity>[a, b], open: a);
    await tapWall(tester);

    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => WallpaperDetailScreen(
            entity: b,
            feed: _feedOf(context, <FeedItemEntity>[a, b]),
            heroTag: 'tile-1',
          ).wrappedRoute(context),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(modes, <String>[_immersive, _edgeToEdge]);

    await tapWall(tester);
    expect(modes, <String>[_immersive, _edgeToEdge, _immersive]);
    navigator.pop();
    await tester.pumpAndSettle();

    expect(modes, <String>[_immersive, _edgeToEdge, _immersive, _edgeToEdge]);
    expect(find.byType(WallpaperDetailScreen), findsOneWidget);
    expect(_controlsShown(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed covered-route restore cannot show bars over a newer immersive detail', (tester) async {
    final FeedItemEntity a = _prism('a');
    final FeedItemEntity b = _prism('b');
    blocWalls.addAll(<FeedItemEntity>[a, b]);
    final Completer<void> failCoveredRestore = Completer<void>();
    final NavigatorState navigator = await pumpDetail(
      tester,
      feed: <FeedItemEntity>[a, b],
      open: a,
      deferFirstEdgeToEdgeFailureUntil: failCoveredRestore,
    );
    await tapWall(tester);

    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => WallpaperDetailScreen(
            entity: b,
            feed: _feedOf(context, <FeedItemEntity>[a, b]),
            heroTag: 'tile-1',
          ).wrappedRoute(context),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapWall(tester);
    expect(modes, <String>[_immersive, _edgeToEdge, _immersive]);

    failCoveredRestore.complete();
    await tester.pumpAndSettle();
    expect(modes, <String>[_immersive, _edgeToEdge, _immersive]);
    expect(_controlsShown(tester), isFalse);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(modes, <String>[_immersive, _edgeToEdge, _immersive, _edgeToEdge]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an error on the wall brings the system bars back', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a);
    await tapWall(tester);

    blocStates.single.add(const WallpaperDetailError(failure: WallpaperDetailLoadFailure.unavailable));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(modes, <String>[_immersive, _edgeToEdge]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an inactive neighbour error does not exit immersive mode on the active wall', (tester) async {
    final FeedItemEntity a = _prism('a');
    final FeedItemEntity b = _prism('b');
    blocWalls.addAll(<FeedItemEntity>[a, b]);
    await pumpDetail(tester, feed: <FeedItemEntity>[a, b], open: a);
    await tapWall(tester);

    await tester.drag(_card, const Offset(-220, 0));
    await tester.pump();
    expect(
      find.byWidgetPredicate((widget) => widget is WallpaperQuickActionRegion && widget.item.id == 'b').hitTestable(),
      findsOneWidget,
    );

    blocStates.first.add(const WallpaperDetailError(failure: WallpaperDetailLoadFailure.unavailable));
    await tester.pumpAndSettle();

    expect(modes, <String>[_immersive]);
    expect(_controlsShown(tester), isFalse);
    expect(_cardId(tester), 'b');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed system-bar restore is retried when the detail route is disposed', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    final NavigatorState navigator = await pumpDetail(
      tester,
      feed: <FeedItemEntity>[a],
      open: a,
      failFirstEdgeToEdge: true,
    );
    await tapWall(tester);

    blocStates.single.add(const WallpaperDetailError(failure: WallpaperDetailLoadFailure.unavailable));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    navigator.pop();
    await tester.pumpAndSettle();

    expect(modes, <String>[_immersive, _edgeToEdge, _edgeToEdge]);
    expect(find.byType(WallpaperDetailScreen), findsNothing);
  });

  testWidgets('a transient failure during route disposal gets one restore retry', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    final NavigatorState navigator = await pumpDetail(
      tester,
      feed: <FeedItemEntity>[a],
      open: a,
      failFirstEdgeToEdge: true,
    );
    await tapWall(tester);
    navigator.pop();
    await tester.pumpAndSettle();

    expect(modes, <String>[_immersive, _edgeToEdge, _edgeToEdge]);
    expect(find.byType(WallpaperDetailScreen), findsNothing);
  });

  testWidgets('a failed immersive request still restores bars when the route is disposed', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    final NavigatorState navigator = await pumpDetail(
      tester,
      feed: <FeedItemEntity>[a],
      open: a,
      failFirstImmersive: true,
    );
    await tapWall(tester);
    navigator.pop();
    await tester.pumpAndSettle();

    expect(modes, <String>[_immersive, _edgeToEdge]);
    expect(find.byType(WallpaperDetailScreen), findsNothing);
  });

  testWidgets('stale immersive commands cannot lose a later bars restore', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    final Completer<void> releaseFirstImmersive = Completer<void>();
    final NavigatorState navigator = await pumpDetail(
      tester,
      feed: <FeedItemEntity>[a],
      open: a,
      blockFirstImmersiveUntil: releaseFirstImmersive,
    );

    await tester.tapAt(tester.getCenter(_card));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tapAt(tester.getCenter(_card));
    await tester.pumpAndSettle();
    releaseFirstImmersive.complete();
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();

    expect(modes, <String>[_immersive, _edgeToEdge, _immersive, _edgeToEdge]);
    expect(find.byType(WallpaperDetailScreen), findsNothing);
  });

  testWidgets('with reduced motion the wall fills the screen at once', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a, reduceMotion: true);

    await tester.tapAt(tester.getCenter(_card));
    await tester.pump();

    expect(tester.getRect(_card), Offset.zero & _screen);
    expect(_controlsShown(tester), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the first wall shows "Tap to hide controls" once, then never again', (tester) async {
    await settings.set('wallpaper_detail.immersive_hint_shown', false);
    final FeedItemEntity a = _prism('a');
    blocWalls.addAll(<FeedItemEntity>[a, a]);
    double hint() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: find.text('Tap to hide controls'), matching: find.byType(AnimatedOpacity)),
        )
        .opacity;

    await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a, push: false);
    expect(hint(), 1);
    expect(settings.get<bool>('wallpaper_detail.immersive_hint_shown', defaultValue: false), isTrue);
    expect(events.events.whereType<DetailImmersiveHintShownEvent>(), hasLength(1));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(hint(), 0);

    await tester.pumpWidget(const SizedBox());
    await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a, push: false);
    expect(hint(), 0);
    expect(events.events.whereType<DetailImmersiveHintShownEvent>(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a screen reader hides and shows the controls with an action on the wall', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a);
    final SemanticsFinder wall = find.semantics.byLabel(RegExp('^Wallpaper'));

    expect(find.semantics.byAction(SemanticsAction.customAction), isNotNull);
    tester.semantics.customAction(wall, const CustomSemanticsAction(label: 'Hide controls'));
    await tester.pumpAndSettle();
    expect(modes, <String>[_immersive]);
    expect(find.bySemanticsLabel('Share'), findsNothing, reason: 'hidden controls leave the semantics tree');

    tester.semantics.customAction(wall, const CustomSemanticsAction(label: 'Show controls'));
    await tester.pumpAndSettle();
    expect(modes, <String>[_immersive, _edgeToEdge]);

    tester.semantics.tap(wall);
    await tester.pumpAndSettle();
    expect(modes, <String>[_immersive, _edgeToEdge, _immersive]);
    expect(
      events.events.whereType<DetailImmersiveToggledEvent>().map((e) => e.source).toSet(),
      <ImmersiveToggleSourceValue>{ImmersiveToggleSourceValue.semantics},
    );
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('a cold detail hold menu loads the saved pin before choosing the action', (tester) async {
    final FeedItemEntity a = _prism('a');
    blocWalls.add(a);
    final DateTime pinnedAt = DateTime.utc(2026);
    final FavouriteWallEntity pinned = FavouriteWallEntity.fromFeedItem(a).withPinnedAt(pinnedAt);
    final StreamController<FavouriteWallsState> favouriteStates = StreamController<FavouriteWallsState>.broadcast(
      sync: true,
    );
    final _MockFavouriteWallsBloc favouritesBloc = _MockFavouriteWallsBloc();
    FavouriteWallsState favourites = FavouriteWallsState.initial();
    whenListen(favouritesBloc, favouriteStates.stream, initialState: favourites);
    favouritesBloc.handleEvent = (event) => event.maybeWhen<void>(
      started: (userId, operationId) {
        scheduleMicrotask(() {
          favourites = favourites.copyWith(
            status: LoadStatus.success,
            actionStatus: ActionStatus.success,
            userId: userId,
            items: <FavouriteWallEntity>[pinned],
            completedOperationId: operationId,
          );
          favouriteStates.add(favourites);
        });
      },
      pinRequested: (wallId, shouldPin, operationId) {
        scheduleMicrotask(() {
          favourites = favourites.copyWith(
            actionStatus: ActionStatus.success,
            items: favourites.items
                .map(
                  (wall) => wall.id == wallId ? wall.withPinnedAt(shouldPin ? DateTime.utc(2026, 1, 2) : null) : wall,
                )
                .toList(growable: false),
            completedOperationId: operationId,
          );
          favouriteStates.add(favourites);
        });
      },
      orElse: () {},
    );
    await getIt<FavoritesLocalDataSource>().setWallFavourite(app_state.prismUser.id, a.id, true);
    await pumpDetail(tester, feed: <FeedItemEntity>[a], open: a, favouritesBloc: favouritesBloc);

    final TestGesture hold = await tester.startGesture(tester.getCenter(_card));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    final Finder unpin = find.bySemanticsLabel('Unpin');
    expect(unpin, findsOneWidget);
    await hold.moveTo(tester.getCenter(unpin));
    await tester.pump();
    await hold.up();
    await tester.pumpAndSettle();

    expect(favourites.items.single.pinned, isFalse);
    expect(
      favouritesBloc.events.any(
        (event) => event.maybeWhen(pinRequested: (_, pinned, _) => !pinned, orElse: () => false),
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await favouriteStates.close();
  });
}
