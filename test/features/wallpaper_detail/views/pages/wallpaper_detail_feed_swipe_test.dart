import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/features/wallpaper_history/data/history_wall_stores.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';
import '../../../../support/wallpaper_image_finders.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

class _FailingViewedStore extends RecentlyViewedStore {
  _FailingViewedStore() : super(SettingsLocalDataSource(InMemoryLocalStore()));

  @override
  Future<void> record(HistoryWall item) async => throw StateError('disk full');
}

class _DownloadHistory extends Fake implements SyncedHistoryStore {
  @override
  (String, int) recordingSession = ('owner-a', 0);
  final List<HistoryWall> recorded = [];

  @override
  Future<void> record(HistoryWall item) async => recorded.add(item);
}

class _SemanticsNodeEntry {
  const _SemanticsNodeEntry({required this.owner, required this.node, required this.data});

  final SemanticsOwner owner;
  final SemanticsNode node;
  final SemanticsData data;
}

List<_SemanticsNodeEntry> _semanticsNodes(WidgetTester tester) {
  final List<_SemanticsNodeEntry> entries = <_SemanticsNodeEntry>[];

  void visitNode(SemanticsOwner owner, SemanticsNode node) {
    entries.add(_SemanticsNodeEntry(owner: owner, node: node, data: node.getSemanticsData()));
    node.visitChildren((child) {
      visitNode(owner, child);
      return true;
    });
  }

  void visitOwner(PipelineOwner owner) {
    final SemanticsOwner? semanticsOwner = owner.semanticsOwner;
    final SemanticsNode? root = semanticsOwner?.rootSemanticsNode;
    if (semanticsOwner != null && root != null) visitNode(semanticsOwner, root);
    owner.visitChildren(visitOwner);
  }

  visitOwner(tester.binding.rootPipelineOwner);
  return entries;
}

Future<void> _pumpOfflinePreview(WidgetTester tester) async {
  final Stopwatch timeout = Stopwatch()..start();
  while (networkImageUrls(tester).isEmpty && timeout.elapsed < const Duration(seconds: 2)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)).timeout(const Duration(seconds: 2)),
    );
    await tester.pump();
  }
}

FeedItemEntity _item(String id) => FeedItemEntity.prism(
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

Future<void> _pumpFeed(
  WidgetTester tester, {
  required List<FeedItemEntity> feed,
  required FeedItemEntity open,
  TextDirection direction = TextDirection.ltr,
}) async {
  getIt<RecentlyViewedStore>();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Directionality(
        textDirection: direction,
        child: Builder(
          builder: (context) => WallpaperDetailScreen(
            entity: open,
            feed: _feedOf(context, feed),
            heroTag: 'tile-${feed.indexOf(open)}',
          ).wrappedRoute(context),
        ),
      ),
    ),
  );
  await _pumpOfflinePreview(tester);
}

void main() {
  setUpFavouriteCounts();
  setUpAll(() => registerFallbackValue(const OnPanelOpened()));
  late OfflineAssetFixture offlineAssets;
  final List<FeedItemEntity> blocWalls = <FeedItemEntity>[];
  final List<WallpaperDetailState> blocInitialStates = <WallpaperDetailState>[];
  final List<Stream<WallpaperDetailState>> blocStreams = <Stream<WallpaperDetailState>>[];
  final List<_MockDetailBloc> createdBlocs = <_MockDetailBloc>[];
  late RecentlyViewedStore viewed;

  setUp(() async {
    blocWalls.clear();
    blocInitialStates.clear();
    blocStreams.clear();
    createdBlocs.clear();
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    getIt.registerLazySingleton<RecentlyViewedStore>(
      () => viewed = RecentlyViewedStore(SettingsLocalDataSource(InMemoryLocalStore())),
    );
    getIt.registerFactory<WallpaperDetailBloc>(() {
      final bloc = _MockDetailBloc();
      createdBlocs.add(bloc);
      final WallpaperDetailState initialState = blocInitialStates.isEmpty
          ? WallpaperDetailLoaded(
              entity: blocWalls.removeAt(0),
              paletteLoading: false,
              recommendations: const RecommendationState.exhausted(),
            )
          : blocInitialStates.removeAt(0);
      whenListen(
        bloc,
        blocStreams.isEmpty ? const Stream<WallpaperDetailState>.empty() : blocStreams.removeAt(0),
        initialState: initialState,
      );
      return bloc;
    });
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await offlineAssets.dispose();
    await getIt.reset();
  });

  for (final String change in ['disposed', 'account', 'session']) {
    testWidgets('a late download callback does not record history after $change changes', (tester) async {
      final history = _DownloadHistory();
      getIt.registerSingleton<SyncedHistoryStore>(history);
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'owner-a'
        ..loggedIn = true;
      final a = _item('a');
      blocWalls.add(a);
      await _pumpFeed(tester, feed: [a], open: a);
      final VoidCallback completed = tester.widget<DownloadButton>(find.byType(DownloadButton)).onDownloaded!;
      if (change == 'disposed') {
        await tester.pumpWidget(const SizedBox());
      } else if (change == 'account') {
        app_state.prismUser = app_constants.createGuestPrismUser()
          ..id = 'owner-b'
          ..loggedIn = true;
      } else {
        history.recordingSession = ('owner-a', 1);
      }
      completed();
      await tester.pump();
      expect(history.recorded, isEmpty);
      expect(viewed.items(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a completed download in the same mounted session records its wall', (tester) async {
    final history = _DownloadHistory();
    getIt.registerSingleton<SyncedHistoryStore>(history);
    final a = _item('a');
    blocWalls.add(a);
    await _pumpFeed(tester, feed: [a], open: a);
    tester.widget<DownloadButton>(find.byType(DownloadButton)).onDownloaded!();
    await tester.pump();
    expect(history.recorded.map((wall) => wall.id), ['a']);
    expect(viewed.items().map((wall) => wall.id), ['a']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an already loaded detail records a view only after two seconds', (tester) async {
    final a = _item('a');
    blocWalls.add(a);
    await _pumpFeed(tester, feed: [a], open: a);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(viewed.items(), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(viewed.items().map((wall) => wall.id), ['a']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rapid feed steps record only the wall that remains active for two seconds', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([a, b, c]);
    await _pumpFeed(tester, feed: [a, b, c], open: a);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(viewed.items(), isEmpty);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(viewed.items().map((wall) => wall.id), ['c']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a viewing-history disk failure does not escape the detail dwell callback', (tester) async {
    await getIt.unregister<RecentlyViewedStore>();
    getIt.registerSingleton<RecentlyViewedStore>(_FailingViewedStore());
    final a = _item('a');
    blocWalls.add(a);
    await _pumpFeed(tester, feed: [a], open: a);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(WallpaperQuickActionRegion), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the detail set action never receives a Prism original as its thumbnail', (tester) async {
    const a = FeedItemEntity.prism(
      id: 'original-as-thumb',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'original-as-thumb',
          source: WallpaperSource.prism,
          fullUrl: 'https://example.com/original.jpg',
          thumbnailUrl: 'https://example.com/original.jpg',
        ),
      ),
    );
    blocWalls.add(a);
    await _pumpFeed(tester, feed: [a], open: a);
    expect(tester.widget<SetWallpaperButton>(find.byType(SetWallpaperButton)).thumbnailUrl, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a swipe left on the card shows the next wall of the feed', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([b, c]);
    await _pumpFeed(tester, feed: [a, b, c], open: b);

    List<String?> urls() => networkImageUrls(tester).toList();
    expect(urls(), contains('https://example.com/b-thumb.jpg'));
    expect(find.byType(Hero), findsOneWidget);

    await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await _pumpOfflinePreview(tester);

    expect(urls(), contains('https://example.com/c-thumb.jpg'));
    expect(urls().where((u) => u!.contains('b-thumb')), isEmpty);
    // The card of c carries c's tile tag, so it can fly back to that tile.
    expect(find.byType(Hero), findsOneWidget);
    expect(tester.widget<Hero>(find.byType(Hero)).tag, 'tile-2');
    expect(blocWalls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a swipe right shows the previous wall', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([b, a]);
    await _pumpFeed(tester, feed: [a, b, c], open: b);

    await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    await _pumpOfflinePreview(tester);

    final urls = networkImageUrls(tester);
    expect(urls, contains('https://example.com/a-thumb.jpg'));
    expect(urls.where((u) => u.contains('b-thumb')), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a rapid A-B-A reversal keeps only the newest visit interactive', (tester) async {
    final a = _item('a');
    final b = _item('b');
    blocWalls.addAll([a, b]);
    await _pumpFeed(tester, feed: [a, b], open: a);

    final Finder firstCard = find.byType(WallpaperQuickActionRegion).first;
    final double restLeft = tester.getRect(firstCard).left;
    await tester.fling(firstCard, const Offset(-300, 0), 1000);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    // A stays mounted while the feed moves, so pin its visit by its element.
    final Element originalElement = find
        .byWidgetPredicate((widget) => widget is WallpaperDetailScreen && widget.heroTag == 'tile-0')
        .evaluate()
        .single;
    final Finder originalVisit = find.byElementPredicate((element) => identical(element, originalElement));
    final Finder originalCard = find.descendant(of: originalVisit, matching: find.byType(WallpaperQuickActionRegion));
    final double beforeReverse = tester.getRect(originalCard).left;
    expect(beforeReverse, lessThan(restLeft), reason: 'outgoing A should be moving left');
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Finder currentScreen = find.byWidgetPredicate(
      (widget) => widget is WallpaperDetailScreen && widget.entity?.id == 'b',
    );
    final Semantics currentCard = tester
        .widgetList<Semantics>(find.descendant(of: currentScreen, matching: find.byType(Semantics)))
        .firstWhere((semantics) => semantics.properties.customSemanticsActions != null);
    currentCard.properties.customSemanticsActions!.entries
        .firstWhere((entry) => entry.key.label == 'Previous wallpaper')
        .value();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final double afterReverse = tester.getRect(originalCard).left;
    expect(afterReverse, lessThan(restLeft), reason: 'outgoing A should still be settling back, not snapped');

    final Finder screens = find.byType(WallpaperDetailScreen);
    expect(screens, findsNWidgets(2));
    final List<bool> transitionPointerStates = <bool>[
      for (int i = 0; i < screens.evaluate().length; i++)
        tester
            .widget<IgnorePointer>(find.ancestor(of: screens.at(i), matching: find.byType(IgnorePointer)).first)
            .ignoring,
    ];
    expect(
      transitionPointerStates.where((ignoring) => !ignoring),
      hasLength(1),
      reason: 'screen visits ${tester.widgetList<WallpaperDetailScreen>(screens).map((screen) => screen.entity?.id)}',
    );
    expect(
      (afterReverse - beforeReverse).abs(),
      lessThan(100),
      reason: 'outgoing A moved $beforeReverse -> $afterReverse',
    );
    final String cardLabel = currentCard.properties.label!;
    final List<_SemanticsNodeEntry> cardNodes = _semanticsNodes(
      tester,
    ).where((entry) => entry.data.label == cardLabel).toList();
    expect(cardNodes, hasLength(1));
    expect(
      cardNodes.single.data.customSemanticsActionIds,
      hasLength(3),
      reason: 'Hide controls, Previous wallpaper, and the tap hint override',
    );
    semantics.dispose();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a same-direction next step preserves the partially entered card position', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([a, b, c]);
    await _pumpFeed(tester, feed: [a, b, c], open: a);

    await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0), 1000);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final Finder currentScreen = find.byWidgetPredicate(
      (widget) => widget is WallpaperDetailScreen && widget.entity?.id == 'b',
    );
    final Finder currentCard = find.descendant(of: currentScreen, matching: find.byType(WallpaperQuickActionRegion));
    final double beforeNextStep = tester.getRect(currentCard).left;
    expect(beforeNextStep, greaterThan(0));
    final Semantics currentSemantics = tester
        .widgetList<Semantics>(find.descendant(of: currentScreen, matching: find.byType(Semantics)))
        .firstWhere((semantics) => semantics.properties.customSemanticsActions != null);
    currentSemantics.properties.customSemanticsActions!.entries
        .firstWhere((entry) => entry.key.label == 'Next wallpaper')
        .value();
    await tester.pump();

    final double afterNextStep = tester.getRect(currentCard).left;
    expect(afterNextStep, closeTo(beforeNextStep, 3));
    await tester.pumpAndSettle();
    final urls = networkImageUrls(tester);
    expect(urls, contains('https://example.com/c-thumb.jpg'));
    expect(blocWalls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the card follows the finger and shows the next wall beside it', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([b, c]);
    await _pumpFeed(tester, feed: [a, b, c], open: b);

    final Finder bScreen = find.byWidgetPredicate(
      (widget) => widget is WallpaperDetailScreen && widget.entity?.id == 'b',
    );
    final Finder cScreen = find.byWidgetPredicate(
      (widget) => widget is WallpaperDetailScreen && widget.entity?.id == 'c',
    );
    final Finder bCard = find.descendant(of: bScreen, matching: find.byType(WallpaperQuickActionRegion)).first;
    final double startLeft = tester.getRect(bCard).left;

    final TestGesture gesture = await tester.startGesture(tester.getCenter(bCard));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();

    expect(startLeft - tester.getRect(bCard).left, inInclusiveRange(150, 210));
    final Finder cCard = find.descendant(of: cScreen, matching: find.byType(WallpaperQuickActionRegion)).first;
    expect(cScreen, findsOneWidget);
    expect(tester.getRect(cCard).left, greaterThan(tester.getRect(bCard).left));

    // Hold still so the release carries no fling velocity and the card springs back.
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getRect(bCard).left, closeTo(startLeft, 1));
    expect(cScreen, findsNothing);
    expect(blocWalls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a neighbour shown during a drag does not load until the feed settles on it', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([b, c]);
    await _pumpFeed(tester, feed: [a, b, c], open: b);
    final Finder bCard = find.byType(WallpaperQuickActionRegion).first;

    final TestGesture gesture = await tester.startGesture(tester.getCenter(bCard));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();

    expect(createdBlocs, hasLength(2));
    final _MockDetailBloc cBloc = createdBlocs[1];
    verifyNever(() => cBloc.add(any(that: isA<LoadFromEntity>())));

    // Pass the halfway point, then hold still so the release carries no fling velocity.
    await gesture.moveBy(const Offset(-240, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();

    verify(() => cBloc.add(any(that: isA<LoadFromEntity>()))).called(1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the last wall does not move past the end', (tester) async {
    final a = _item('a');
    final b = _item('b');
    blocWalls.addAll([b]);
    await _pumpFeed(tester, feed: [a, b], open: b);

    await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await _pumpOfflinePreview(tester);

    final urls = networkImageUrls(tester);
    expect(urls, contains('https://example.com/b-thumb.jpg'));
    expect(find.byType(Hero), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a drag held while the wall finishes loading settles the feed', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final StreamController<WallpaperDetailState> loads = StreamController<WallpaperDetailState>();
    addTearDown(loads.close);
    blocInitialStates.add(const WallpaperDetailInitial());
    blocStreams.add(loads.stream);
    blocWalls.add(b);
    await _pumpFeed(tester, feed: [a, b], open: a);
    final Finder aCard = find.byWidgetPredicate(
      (widget) => widget is WallpaperQuickActionRegion && widget.item.id == 'a',
    );
    final double restLeft = tester.getRect(aCard).left;

    final TestGesture gesture = await tester.startGesture(tester.getCenter(aCard));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();
    expect(tester.getRect(aCard).left, lessThan(restLeft - 100));

    loads.add(
      WallpaperDetailLoaded(entity: a, paletteLoading: false, recommendations: const RecommendationState.exhausted()),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(aCard).left, closeTo(restLeft, 1));
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a swipe can advance the feed while canonical detail data loads', (tester) async {
    final a = _item('a');
    final b = _item('b');
    blocInitialStates.add(const WallpaperDetailInitial());
    blocWalls.add(b);
    await _pumpFeed(tester, feed: [a, b], open: a);

    await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0), 1000);
    await tester.pump(const Duration(milliseconds: 100));
    await _pumpOfflinePreview(tester);

    final urls = networkImageUrls(tester);
    expect(urls, contains('https://example.com/b-thumb.jpg'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('canonical loading exposes the next feed action to assistive technology', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final SemanticsHandle semantics = tester.ensureSemantics();
    blocInitialStates.add(const WallpaperDetailInitial());
    blocWalls.add(b);
    await _pumpFeed(tester, feed: [a, b], open: a);

    final Semantics card = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((node) => node.properties.customSemanticsActions != null);
    final String cardLabel = card.properties.label!;
    final List<_SemanticsNodeEntry> nodes = _semanticsNodes(tester)
        .where((entry) => entry.data.label == cardLabel && entry.data.customSemanticsActionIds?.isNotEmpty == true)
        .toList();
    expect(nodes, hasLength(1));
    final int nextActionId = nodes.single.data.customSemanticsActionIds!.singleWhere(
      (id) => CustomSemanticsAction.getAction(id)?.label == 'Next wallpaper',
    );
    nodes.single.owner.performAction(nodes.single.node.id, SemanticsAction.customAction, nextActionId);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    final urls = networkImageUrls(tester);
    expect(urls, contains('https://example.com/b-thumb.jpg'));
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a left swipe in RTL selects the previous wall and enters from the right', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([b, a]);
    await _pumpFeed(tester, feed: [a, b, c], open: b, direction: TextDirection.rtl);
    final double originalLeft = tester.getRect(find.byType(WallpaperQuickActionRegion).first).left;

    await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0), 1000);
    await tester.pump(const Duration(milliseconds: 16));

    final Finder previous = find.byWidgetPredicate(
      (widget) => widget is WallpaperQuickActionRegion && widget.item.id == 'a',
    );
    expect(tester.getRect(previous).left, greaterThan(originalLeft));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the feed snapshot stays valid if the caller shrinks its list during a rebuild', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    final List<FeedItemEntity> feed = <FeedItemEntity>[a, b, c];
    blocWalls.add(c);
    // The screen copies the feed when it is built, so later edits to [feed] must not reach it.
    WallpaperFeed? snapshot;

    Widget app() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          snapshot ??= _feedOf(context, feed);
          return WallpaperDetailScreen(entity: c, feed: snapshot, heroTag: 'tile-2').wrappedRoute(context);
        },
      ),
    );

    await tester.pumpWidget(app());
    feed.removeAt(1);
    await tester.pumpWidget(app());

    expect(tester.takeException(), isNull);
    final urls = networkImageUrls(tester);
    expect(urls, contains('https://example.com/c-thumb.jpg'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Back after a swipe scrolls the grid to the current wall', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final List<FeedItemEntity> items = <FeedItemEntity>[for (var i = 0; i < 60; i++) _item('w$i')];
    blocWalls.addAll(items.take(31));
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CustomScrollView(
          controller: scroll,
          slivers: [
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.5),
              delegate: SliverChildBuilderDelegate((context, index) {
                return Hero(
                  tag: 'tile-$index',
                  child: GestureDetector(
                    key: ValueKey<String>('tile-$index'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (ctx) => WallpaperDetailScreen(
                          entity: items[index],
                          heroTag: 'tile-$index',
                          feed: WallpaperFeed(
                            grid: context,
                            tiles: [for (final (i, item) in items.indexed) (item: item, index: i, heroTag: 'tile-$i')],
                          ),
                        ).wrappedRoute(ctx),
                      ),
                    ),
                    child: const ColoredBox(color: Colors.blue),
                  ),
                );
              }, childCount: items.length),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('tile-0')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 30; i++) {
      await tester.fling(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
    }
    expect(blocWalls, isEmpty);
    final Finder targetTile = find.byKey(const ValueKey<String>('tile-30'));
    expect(targetTile, findsNothing);

    Navigator.of(tester.element(find.byType(WallpaperDetailScreen))).pop();
    await tester.pumpAndSettle();

    expect(scroll.offset, greaterThan(0));
    expect(targetTile.hitTestable(), findsOneWidget);
    final Rect screen = tester.getRect(find.byType(CustomScrollView));
    final Rect tile = tester.getRect(targetTile);
    expect(tile.top, greaterThanOrEqualTo(screen.top));
    expect(tile.bottom, lessThanOrEqualTo(screen.bottom));
  });

  testWidgets('without a feed a swipe does nothing', (tester) async {
    final b = _item('b');
    blocWalls.addAll([b]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => WallpaperDetailScreen(entity: b, heroTag: 'tile').wrappedRoute(context),
        ),
      ),
    );
    await _pumpOfflinePreview(tester);

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await _pumpOfflinePreview(tester);

    final urls = networkImageUrls(tester);
    expect(urls, contains('https://example.com/b-thumb.jpg'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the card offers next and previous actions to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([b]);
    await _pumpFeed(tester, feed: [a, b, c], open: b);

    final Semantics card = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.customSemanticsActions != null);
    expect(card.properties.customSemanticsActions!.keys.map((a) => a.label), <String>[
      'Hide controls',
      'Previous wallpaper',
      'Next wallpaper',
    ]);
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
