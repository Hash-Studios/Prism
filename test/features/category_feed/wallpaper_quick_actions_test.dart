import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _MockFavouriteWallsBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState>
    implements FavouriteWallsBloc {}

const FeedItemEntity _item = PrismFeedItem(
  id: 'wall-1',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'wall-1',
      source: WallpaperSource.prism,
      fullUrl: 'https://example.test/wall-1.jpg',
      thumbnailUrl: '',
      authorName: 'Ana',
    ),
  ),
);

void main() {
  late FavoritesLocalDataSource favourites;
  late _MockFavouriteWallsBloc bloc;
  late StreamController<FavouriteWallsState> states;
  late FavouriteWallsState current;
  final List<FavouriteWallsEvent> events = <FavouriteWallsEvent>[];

  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'u'
      ..loggedIn = true;
    favourites = FavoritesLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<FavoritesLocalDataSource>(favourites);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (_) async => true,
    );

    events.clear();
    current = FavouriteWallsState.initial().copyWith(status: LoadStatus.success, userId: 'u');
    states = StreamController<FavouriteWallsState>.broadcast(sync: true);
    bloc = _MockFavouriteWallsBloc();
    when(() => bloc.state).thenAnswer((_) => current);
    when(() => bloc.stream).thenAnswer((_) => states.stream);
    when(() => bloc.add(any())).thenAnswer((Invocation invocation) {
      final FavouriteWallsEvent event = invocation.positionalArguments.single as FavouriteWallsEvent;
      events.add(event);
      final int? operationId = event.mapOrNull(toggleRequested: (e) => e.operationId);
      if (operationId == null) return;
      current = current.copyWith(actionStatus: ActionStatus.success, completedOperationId: operationId);
      states.add(current);
    });
  });

  setUpAll(() => registerFallbackValue(const FavouriteWallsEvent.refreshRequested()));

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    app_state.prismUser = app_constants.createGuestPrismUser();
    await states.close();
    await getIt.reset();
  });

  Future<void> pumpTile(WidgetTester tester, {bool quickActions = true, VoidCallback? onShowLess}) {
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: Scaffold(
            body: SizedBox(
              width: 120,
              height: 240,
              child: WallpaperTile(item: _item, index: 0, quickActions: quickActions, onShowLessLikeThis: onShowLess),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a long press opens the sheet with favourite, share and set on Android', (tester) async {
    await pumpTile(tester);

    await tester.longPress(find.byType(WallpaperTile));
    await tester.pumpAndSettle();

    expect(find.text('Favourite'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Set as wallpaper'), findsOneWidget);
    expect(find.text('Show less like this'), findsNothing);
  });

  testWidgets('iOS has no set row, because the app cannot set a wallpaper there', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpTile(tester);

      await tester.longPress(find.byType(WallpaperTile));
      await tester.pumpAndSettle();

      expect(find.text('Share link'), findsOneWidget);
      expect(find.text('Set as wallpaper'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Show less like this appears only when the grid passes a callback, and calls it', (tester) async {
    int calls = 0;
    await pumpTile(tester, onShowLess: () => calls++);

    await tester.longPress(find.byType(WallpaperTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show less like this'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Show less like this'), findsNothing);
  });

  testWidgets('a tile without the flag opens no sheet on a long press', (tester) async {
    registerFallbackValue(WallpaperDetailRoute());
    final router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    await tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: const Scaffold(
            body: SizedBox(width: 120, height: 240, child: WallpaperTile(item: _item, index: 0)),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(WallpaperTile));
    await tester.pumpAndSettle();

    expect(find.text('Share link'), findsNothing);
  });

  testWidgets('the Favourite row asks for a favourite, and the row reads Unfavourite for a favourite', (tester) async {
    await pumpTile(tester);
    await tester.longPress(find.byType(WallpaperTile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Favourite'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    final FavouriteWallsEvent event = events.single;
    expect(event.mapOrNull(toggleRequested: (e) => e.desired), isTrue);
    expect(event.mapOrNull(toggleRequested: (e) => e.wall.id), 'wall-1');

    await favourites.setWallFavourite('u', 'wall-1', true);
    await tester.longPress(find.byType(WallpaperTile));
    await tester.pumpAndSettle();
    expect(find.text('Unfavourite'), findsOneWidget);
    await tester.tap(find.text('Unfavourite'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(events.last.mapOrNull(toggleRequested: (e) => e.desired), isFalse);
  });

  testWidgets('a heart badge with a label marks a favourite tile, and never takes the tap', (tester) async {
    await favourites.setWallFavourite('u', 'wall-1', true);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpTile(tester);

    expect(find.byTooltip('In your favourites'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('In your favourites')), findsOneWidget);
    expect(find.ancestor(of: find.byIcon(Icons.favorite_rounded), matching: find.byType(IgnorePointer)), findsWidgets);
    semantics.dispose();
  });

  testWidgets('no heart badge for a wallpaper that is not a favourite, or on a tile without the flag', (tester) async {
    await pumpTile(tester);
    expect(find.byTooltip('In your favourites'), findsNothing);

    await favourites.setWallFavourite('u', 'wall-1', true);
    await pumpTile(tester, quickActions: false);
    expect(find.byTooltip('In your favourites'), findsNothing);
  });

  testWidgets('showWallpaperQuickActions can be opened straight from a grid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: Builder(
            builder: (context) =>
                TextButton(onPressed: () => showWallpaperQuickActions(context, _item), child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Share link'), findsOneWidget);
  });
}
