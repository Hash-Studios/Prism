import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/favourite_test_scope.dart';
import '../../support/in_memory_local_store.dart';

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
  setUpFavouriteCounts();
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

  Future<void> pumpTile(WidgetTester tester, {VoidCallback? onShowLess}) {
    return tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: Scaffold(
            body: SizedBox(
              width: 120,
              height: 240,
              child: WallpaperTile(item: _item, index: 0, onShowLessLikeThis: onShowLess),
            ),
          ),
        ),
      ),
    );
  }

  Future<TestGesture> hold(WidgetTester tester) async {
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PrismImageTile)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 180));
    return gesture;
  }

  testWidgets('all tiles offer favourite and share while held, never set or fake see less', (tester) async {
    await pumpTile(tester);
    final gesture = await hold(tester);
    expect(find.bySemanticsLabel('Favourite'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Share link'), findsOneWidget);
    expect(find.text('Set as wallpaper'), findsNothing);
    expect(find.text('Show less like this'), findsNothing);
    await gesture.up();
    await tester.pump();
    expect(find.bySemanticsLabel('Share link'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(find.bySemanticsLabel('Share link'), findsNothing);
    expect(events, isEmpty);
  });

  testWidgets('release on see less calls the real callback once on the closing frame', (tester) async {
    var calls = 0;
    await pumpTile(
      tester,
      onShowLess: () {
        expect(find.bySemanticsLabel('Share link'), findsOneWidget);
        calls++;
      },
    );
    final gesture = await hold(tester);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Show less like this')));
    await tester.pump();
    expect(find.text('Show less like this'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(calls, 1);
    expect(find.bySemanticsLabel('Share link'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(find.bySemanticsLabel('Share link'), findsNothing);
  });

  testWidgets('favourite and unfavourite release map to adapter desired state, not detail or set', (tester) async {
    await pumpTile(tester);
    var gesture = await hold(tester);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Favourite').last));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(events.single.mapOrNull(toggleRequested: (e) => e.desired), isTrue);
    expect(events.single.mapOrNull(toggleRequested: (e) => e.wall.id), 'wall-1');

    await favourites.setWallFavourite('u', 'wall-1', true);
    gesture = await hold(tester);
    expect(find.bySemanticsLabel('Unfavourite'), findsOneWidget);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Unfavourite')));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(events.last.mapOrNull(toggleRequested: (e) => e.desired), isFalse);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the labelled interactive favourite footer stays outside the image', (tester) async {
    await favourites.setWallFavourite('u', 'wall-1', true);
    current = current.copyWith(items: [FavouriteWallEntity.fromFeedItem(_item)]);
    final semantics = tester.ensureSemantics();
    await pumpTile(tester);
    final label = AppLocalizationsEn().wallpaperUnfavourite;
    expect(find.byTooltip(label), findsOneWidget);
    expect(
      tester.getRect(find.byIcon(Icons.favorite_rounded)).top,
      greaterThan(tester.getRect(find.byType(PrismImageTile)).bottom),
    );
    semantics.dispose();
  });

  testWidgets('guest favourite keeps the adapter path without a sign-in gate', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    current = current.copyWith(userId: '');
    await pumpTile(tester);
    final gesture = await hold(tester);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Favourite').last));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(events.single.mapOrNull(toggleRequested: (e) => e.desired), isTrue);
    expect(find.text('Sign in'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('share release uses the existing clipboard link flow and does not share the original URL', (
    tester,
  ) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpTile(tester);
    final gesture = await hold(tester);
    await gesture.moveTo(tester.getCenter(find.bySemanticsLabel('Share link')));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(seconds: 5));
    expect(clipboard, contains('id=wall-1'));
    expect(clipboard, contains('source=prism'));
    expect(clipboard, isNot(contains('https://example.test/wall-1.jpg')));
    expect(events, isEmpty);
  });
}
