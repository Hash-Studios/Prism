import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {
  final StreamController<WallpaperDetailState> states = StreamController<WallpaperDetailState>.broadcast(sync: true);
}

class _DetailTestRouter extends AppRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('DetailHostRoute', builder: (_) => const Scaffold(body: Text('detail host'))),
    ),
    AutoRoute(path: '/wallpaper-detail', page: WallpaperDetailRoute.page),
  ];
}

FeedItemEntity _wall(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
    title: id,
  ),
);

void main() {
  setUpFavouriteCounts();

  final List<_MockDetailBloc> blocs = <_MockDetailBloc>[];
  final List<WallpaperDetailState> initialStates = <WallpaperDetailState>[];

  setUp(() {
    blocs.clear();
    initialStates.clear();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    getIt.registerFactory<WallpaperDetailBloc>(() {
      final bloc = _MockDetailBloc();
      final initialState = initialStates.removeAt(0);
      whenListen(bloc, bloc.states.stream, initialState: initialState);
      blocs.add(bloc);
      return bloc;
    });
  });

  tearDown(() async {
    for (final bloc in blocs) {
      await bloc.states.close();
    }
    await getIt.reset();
  });

  testWidgets('opening a recommendation passes its loaded recommendation page as the detail feed', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final FeedItemEntity current = _wall('current');
    final FeedItemEntity first = _wall('recommendation-1');
    final FeedItemEntity second = _wall('recommendation-2');
    initialStates.addAll(<WallpaperDetailState>[
      WallpaperDetailLoaded(
        entity: current,
        paletteLoading: false,
        recommendations: RecommendationState(
          items: <FeedItemEntity>[first, second],
          kind: RecommendationKind.related,
          status: RecommendationStatus.ready,
        ),
      ),
      WallpaperDetailLoaded(
        entity: first,
        paletteLoading: false,
        recommendations: const RecommendationState.exhausted(),
      ),
    ]);

    final _DetailTestRouter router = _DetailTestRouter();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      router.dispose();
    });
    await tester.pumpWidget(
      MaterialApp.router(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await router.navigatePath('/');
    await tester.pumpAndSettle();
    unawaited(router.push<void>(WallpaperDetailRoute(entity: current)));
    await tester.pumpAndSettle();

    final Finder firstTile = find.byKey(const ValueKey((WallpaperSource.prism, 'recommendation-1')));
    await tester.scrollUntilVisible(firstTile, 500, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(firstTile);
    await tester.pumpAndSettle();

    final WallpaperDetailRouteArgs args = router.current.argsAs<WallpaperDetailRouteArgs>();
    expect(args.entity?.id, 'recommendation-1');
    expect(args.feed?.map((item) => item.id), <String>['recommendation-1', 'recommendation-2']);
  });
}
