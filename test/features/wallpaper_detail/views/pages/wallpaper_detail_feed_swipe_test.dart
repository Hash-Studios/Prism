import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

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
  while (find.byType(CachedNetworkImage).evaluate().isEmpty && timeout.elapsed < const Duration(seconds: 2)) {
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

Future<void> _pumpFeed(
  WidgetTester tester, {
  required List<FeedItemEntity> feed,
  required FeedItemEntity open,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Directionality(
        textDirection: direction,
        child: Builder(
          builder: (context) => WallpaperDetailScreen(entity: open, feed: feed, heroTag: 'tile').wrappedRoute(context),
        ),
      ),
    ),
  );
  await _pumpOfflinePreview(tester);
}

void main() {
  setUpFavouriteCounts();
  late OfflineAssetFixture offlineAssets;
  final List<FeedItemEntity> blocWalls = <FeedItemEntity>[];
  final List<WallpaperDetailState> blocInitialStates = <WallpaperDetailState>[];

  setUp(() async {
    blocWalls.clear();
    blocInitialStates.clear();
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    getIt.registerFactory<WallpaperDetailBloc>(() {
      final bloc = _MockDetailBloc();
      final WallpaperDetailState initialState = blocInitialStates.isEmpty
          ? WallpaperDetailLoaded(
              entity: blocWalls.removeAt(0),
              paletteLoading: false,
              recommendations: const RecommendationState.exhausted(),
            )
          : blocInitialStates.removeAt(0);
      whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: initialState);
      return bloc;
    });
  });

  tearDown(() async {
    await offlineAssets.dispose();
    await getIt.reset();
  });

  testWidgets('a swipe left on the card shows the next wall of the feed', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([b, c]);
    await _pumpFeed(tester, feed: [a, b, c], open: b);

    List<String?> urls() =>
        tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl).toList();
    expect(urls(), contains('https://example.com/b-thumb.jpg'));
    expect(find.byType(Hero), findsOneWidget);

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await _pumpOfflinePreview(tester);

    expect(urls(), contains('https://example.com/c-thumb.jpg'));
    expect(urls().where((u) => u!.contains('b-thumb')), isEmpty);
    expect(find.byType(Hero), findsNothing);
    expect(blocWalls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a swipe right shows the previous wall', (tester) async {
    final a = _item('a');
    final b = _item('b');
    final c = _item('c');
    blocWalls.addAll([b, a]);
    await _pumpFeed(tester, feed: [a, b, c], open: b);

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(300, 0));
    await tester.pumpAndSettle();
    await _pumpOfflinePreview(tester);

    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
    expect(urls, contains('https://example.com/a-thumb.jpg'));
    expect(urls.where((u) => u.contains('b-thumb')), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a rapid A-B-A reversal keeps only the newest visit interactive', (tester) async {
    final a = _item('a');
    final b = _item('b');
    blocWalls.addAll([a, b, a]);
    await _pumpFeed(tester, feed: [a, b], open: a);

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-150, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final Finder originalVisit = find.byWidgetPredicate(
      (widget) => widget is WallpaperDetailScreen && widget.heroTag == 'tile',
    );
    final Finder originalCard = find.descendant(of: originalVisit, matching: find.byType(WallpaperQuickActionRegion));
    final double beforeReverse = tester.getRect(originalCard).left;
    final Finder originalTransition = find.ancestor(of: originalVisit, matching: find.byType(SlideTransition)).first;
    final Iterable<double> outgoingOffsets = tester
        .widgetList<SlideTransition>(find.ancestor(of: originalVisit, matching: find.byType(SlideTransition)))
        .map((transition) => transition.position.value.dx);
    expect(
      tester.widget<SlideTransition>(originalTransition).position.value.dx,
      lessThan(0),
      reason: 'outgoing A offsets $outgoingOffsets',
    );
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
    expect(tester.widget<SlideTransition>(originalTransition).position.value.dx, lessThan(0));

    final Finder screens = find.byType(WallpaperDetailScreen);
    expect(screens, findsNWidgets(3));
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
    expect(cardNodes.single.data.customSemanticsActionIds, hasLength(1));
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

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-150, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final Finder currentScreen = find.byWidgetPredicate(
      (widget) => widget is WallpaperDetailScreen && widget.entity?.id == 'b',
    );
    final Finder currentTransition = find.ancestor(of: currentScreen, matching: find.byType(SlideTransition)).first;
    final double beforeNextStep = tester.widget<SlideTransition>(currentTransition).position.value.dx;
    expect(beforeNextStep, greaterThan(0));
    final Semantics currentCard = tester
        .widgetList<Semantics>(find.descendant(of: currentScreen, matching: find.byType(Semantics)))
        .firstWhere((semantics) => semantics.properties.customSemanticsActions != null);
    currentCard.properties.customSemanticsActions!.entries
        .firstWhere((entry) => entry.key.label == 'Next wallpaper')
        .value();
    await tester.pump();

    final double afterNextStep = tester.widget<SlideTransition>(currentTransition).position.value.dx;
    expect(afterNextStep, closeTo(beforeNextStep, 0.02));
    await tester.pumpAndSettle();
    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
    expect(urls, contains('https://example.com/c-thumb.jpg'));
    expect(blocWalls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the last wall does not move past the end', (tester) async {
    final a = _item('a');
    final b = _item('b');
    blocWalls.addAll([b]);
    await _pumpFeed(tester, feed: [a, b], open: b);

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await _pumpOfflinePreview(tester);

    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
    expect(urls, contains('https://example.com/b-thumb.jpg'));
    expect(find.byType(Hero), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a swipe can advance the feed while canonical detail data loads', (tester) async {
    final a = _item('a');
    final b = _item('b');
    blocInitialStates.add(const WallpaperDetailInitial());
    blocWalls.add(b);
    await _pumpFeed(tester, feed: [a, b], open: a);

    await tester.dragFrom(tester.getCenter(find.byType(WallpaperQuickActionRegion).first), const Offset(-150, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await _pumpOfflinePreview(tester);

    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
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

    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
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

    await tester.drag(find.byType(WallpaperQuickActionRegion).first, const Offset(-150, 0));
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

    Widget app() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => WallpaperDetailScreen(entity: c, feed: feed, heroTag: 'tile').wrappedRoute(context),
      ),
    );

    await tester.pumpWidget(app());
    feed.removeAt(1);
    await tester.pumpWidget(app());

    expect(tester.takeException(), isNull);
    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
    expect(urls, contains('https://example.com/c-thumb.jpg'));
    await tester.pumpWidget(const SizedBox());
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

    final urls = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((i) => i.imageUrl);
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
      'Previous wallpaper',
      'Next wallpaper',
    ]);
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
