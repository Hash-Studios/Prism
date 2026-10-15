import 'dart:async';

import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_quick_tile_listener.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/session.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _SessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

FavouriteWallsState _favourites(String userId, String url) => FavouriteWallsState.initial().copyWith(
  status: LoadStatus.success,
  userId: userId,
  items: <FavouriteWallEntity>[
    LegacyFavouriteWall(id: url, source: WallpaperSource.prism, legacyPayload: <String, dynamic>{'url': url}),
  ],
);

SessionState _session(String userId) => SessionState.initial().copyWith(
  session: SessionEntity(userId: userId, loggedIn: true, premium: false, subscriptionTier: 'free'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tile tracks edits, retains refreshes and clears favourites across accounts and logout', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{PersistenceKeys.quickTileFavsTarget: 'both'});
    final favourites = _FavouriteBloc();
    final session = _SessionBloc();
    final favouriteStates = StreamController<FavouriteWallsState>();
    final sessionStates = StreamController<SessionState>();
    whenListen(favourites, favouriteStates.stream, initialState: _favourites('a', 'https://example.com/one.jpg'));
    whenListen(session, sessionStates.stream, initialState: _session('a'));

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<FavouriteWallsBloc>.value(value: favourites),
          BlocProvider<SessionBloc>.value(value: session),
        ],
        child: const FavouriteQuickTileListener(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/one.jpg']);

    favouriteStates.add(_favourites('a', 'https://example.com/two.jpg'));
    await tester.pump();
    await tester.pump();
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/two.jpg']);

    favouriteStates.add(_favourites('a', 'https://example.com/two.jpg').copyWith(status: LoadStatus.loading));
    await tester.pump();
    await tester.pump();
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/two.jpg']);

    sessionStates.add(_session('b'));
    await tester.pump();
    await tester.pump();
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, isEmpty);

    favouriteStates.add(_favourites('a', 'https://example.com/stale.jpg'));
    await tester.pump();
    await tester.pump();
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, isEmpty);

    favouriteStates.add(_favourites('b', 'https://example.com/three.jpg'));
    await tester.pump();
    await tester.pump();
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/three.jpg']);

    sessionStates.add(SessionState.initial());
    await tester.pump();
    await tester.pump();
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await favouriteStates.close();
    await sessionStates.close();
  });

  testWidgets('tile keeps the cached favourites on cold start until they load, and clears on logout', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{PersistenceKeys.quickTileFavsTarget: 'both'});
    await QuickTileConfigService.pushFavWallUrls(<String>['https://example.com/cached.jpg']);
    final favourites = _FavouriteBloc();
    final session = _SessionBloc();
    final favouriteStates = StreamController<FavouriteWallsState>();
    final sessionStates = StreamController<SessionState>();
    whenListen(favourites, favouriteStates.stream, initialState: FavouriteWallsState.initial());
    whenListen(session, sessionStates.stream, initialState: _session('a'));

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<FavouriteWallsBloc>.value(value: favourites),
          BlocProvider<SessionBloc>.value(value: session),
        ],
        child: const FavouriteQuickTileListener(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/cached.jpg']);

    favouriteStates.add(FavouriteWallsState.initial().copyWith(status: LoadStatus.loading, userId: 'a'));
    await tester.pump();
    await tester.pump();
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/cached.jpg']);

    favouriteStates.add(_favourites('a', 'https://example.com/fresh.jpg'));
    await tester.pump();
    await tester.pump();
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/fresh.jpg']);

    sessionStates.add(SessionState.initial());
    await tester.pump();
    await tester.pump();
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await favouriteStates.close();
    await sessionStates.close();
  });
}
