import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/favourite_walls/views/widgets/fav_grid.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/favourite_test_scope.dart';
import 'support/fav_fixtures.dart';

class _MockFetchFavouriteWallsUseCase extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock implements ClearFavouriteWallsUseCase {}

class _MockSetFavouritePinUseCase extends Mock implements SetFavouritePinUseCase {}

class _MockCacheManager extends Mock implements BaseCacheManager {}

/// The Semantics widget with [label]. Tile labels are read from the widget tree, because the semantics-node finder
/// does not see them in this grid.
Finder _labelled(String label) =>
    find.byWidgetPredicate((Widget widget) => widget is Semantics && widget.properties.label == label);

/// True when [a] sits before [b] in reading order, as a grid lays them out.
bool _readsBefore(Offset a, Offset b) => a.dy < b.dy || (a.dy == b.dy && a.dx < b.dx);

void main() {
  setUpFavouriteCounts();
  late _MockFetchFavouriteWallsUseCase fetchUseCase;
  late FavouriteWallsBloc bloc;

  setUpAll(() {
    CachedNetworkImageProvider.defaultCacheManager = _MockCacheManager();
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'user_1'));
  });

  setUp(() {
    fetchUseCase = _MockFetchFavouriteWallsUseCase();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user_1'
      ..loggedIn = true;
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> pumpLoaded(WidgetTester tester, List<FavouriteWallEntity> items) async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(List<FavouriteWallEntity>.of(items)));
    bloc = FavouriteWallsBloc(
      fetchUseCase,
      _MockToggleFavouriteWallUseCase(),
      _MockClearFavouriteWallsUseCase(),
      _MockSetFavouritePinUseCase(),
    );
    addTearDown(bloc.close);

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: const Scaffold(body: FavouriteGrid()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('pinned walls render first in pin order with a pin badge, unpinned walls have none', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpLoaded(tester, <FavouriteWallEntity>[
      prismFav('free', author: 'Linus', createdAt: DateTime.utc(2026, 3)),
      prismFav('second', author: 'Grace', createdAt: DateTime.utc(2025)).withPinnedAt(DateTime.utc(2026, 2)),
      prismFav('first', author: 'Ada', createdAt: DateTime.utc(2024)).withPinnedAt(DateTime.utc(2026)),
    ]);

    final Offset first = tester.getTopLeft(_labelled('Wallpaper by Ada'));
    final Offset second = tester.getTopLeft(_labelled('Wallpaper by Grace'));
    final Offset free = tester.getTopLeft(_labelled('Wallpaper by Linus'));
    expect(_readsBefore(first, second), isTrue, reason: 'the first pin leads');
    expect(_readsBefore(second, free), isTrue, reason: 'pinned walls come before unpinned ones');

    expect(_labelled('Pinned'), findsNWidgets(2));
    expect(find.descendant(of: _labelled('Wallpaper by Ada'), matching: _labelled('Pinned')), findsOneWidget);
    expect(find.descendant(of: _labelled('Wallpaper by Linus'), matching: _labelled('Pinned')), findsNothing);
    semantics.dispose();
  });

  /// Holds the tile labelled [label] until its hold menu opens, then returns the finger.
  Future<TestGesture> hold(WidgetTester tester, String label) async {
    final TestGesture finger = await tester.startGesture(tester.getCenter(_labelled(label)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 200));
    return finger;
  }

  testWidgets("a pinned tile's hold menu offers Unpin and an unpinned tile's offers Pin to top", (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpLoaded(tester, <FavouriteWallEntity>[
      prismFav('free', author: 'Linus', createdAt: DateTime.utc(2025)),
      prismFav('pinned', author: 'Ada', createdAt: DateTime.utc(2024)).withPinnedAt(DateTime.utc(2026)),
    ]);

    TestGesture finger = await hold(tester, 'Wallpaper by Ada');
    expect(find.bySemanticsLabel('Unpin'), findsOneWidget);
    expect(find.bySemanticsLabel('Pin to top'), findsNothing);
    await finger.up();
    await tester.pump(const Duration(milliseconds: 500));

    finger = await hold(tester, 'Wallpaper by Linus');
    expect(find.bySemanticsLabel('Pin to top'), findsOneWidget);
    expect(find.bySemanticsLabel('Unpin'), findsNothing);
    await finger.up();
    await tester.pump(const Duration(milliseconds: 500));
    semantics.dispose();
  });
}
