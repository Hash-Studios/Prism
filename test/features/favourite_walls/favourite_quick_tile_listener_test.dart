import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_quick_tile_listener.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/session.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/wait_for_real_io.dart';

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

Future<void> _waitForUrls(WidgetTester tester, List<String> urls, {required String reason}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String expected = jsonEncode(urls);
  await waitForRealIo(tester, () => prefs.getString(PersistenceKeys.quickTileFavWallUrls) == expected, reason: reason);
}

Future<void> _drainNativeMirror(WidgetTester tester) async {
  await tester.pump();
  var drained = false;
  NativeAssetPathsStore.replaceGroup('category', const <String, String>{}).then((_) => drained = true);
  await waitForRealIo(tester, () => drained, reason: 'native mirror queue after ignored favourites state');
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory offlineDirectory;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    offlineDirectory = await Directory.systemTemp.createTemp('prism-tile-assets-test');
    OfflineAssetStore.testOverride = OfflineAssetStore(directory: offlineDirectory);
  });

  tearDown(() async {
    OfflineAssetStore.testOverride = null;
    if (await offlineDirectory.exists()) await offlineDirectory.delete(recursive: true);
  });

  testWidgets('tile tracks account changes, logout and cold-start cache', (tester) async {
    await tester.runAsync(() async {
      final File file = File('${offlineDirectory.path}/one.png')
        ..writeAsBytesSync(<int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      await OfflineAssetStore.instance.retain('https://example.com/one.jpg', file: file);
    });
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
    await _waitForUrls(tester, <String>['https://example.com/one.jpg'], reason: 'initial favourites tile URLs');
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/one.jpg']);
    final SharedPreferences initialPrefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> nativePaths =
        jsonDecode(initialPrefs.getString('offline.native_asset_paths')!) as Map<String, dynamic>;
    expect(nativePaths.keys, <String>['https://example.com/one.jpg']);
    expect(await tester.runAsync(() => File(nativePaths.values.single as String).exists()), isTrue);

    favouriteStates.add(_favourites('a', 'https://example.com/two.jpg'));
    await tester.pump();
    await _waitForUrls(tester, <String>['https://example.com/two.jpg'], reason: 'edited favourites tile URLs');
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/two.jpg']);

    favouriteStates.add(_favourites('a', 'https://example.com/two.jpg').copyWith(status: LoadStatus.loading));
    await _drainNativeMirror(tester);
    expect(favourites.state.status, LoadStatus.loading);
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/two.jpg']);

    sessionStates.add(_session('b'));
    await tester.pump();
    await _waitForUrls(tester, const <String>[], reason: 'account switch clears favourites tile URLs');
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, isEmpty);
    final SharedPreferences clearedPrefs = await SharedPreferences.getInstance();
    expect(clearedPrefs.getString('offline.native_asset_paths'), '{}');

    favouriteStates.add(_favourites('a', 'https://example.com/stale.jpg'));
    await _drainNativeMirror(tester);
    expect(favourites.state.userId, 'a');
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, isEmpty);

    favouriteStates.add(_favourites('b', 'https://example.com/three.jpg'));
    await tester.pump();
    await _waitForUrls(tester, <String>['https://example.com/three.jpg'], reason: 'new account favourites tile URLs');
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/three.jpg']);

    sessionStates.add(SessionState.initial());
    await tester.pump();
    await _waitForUrls(tester, const <String>[], reason: 'logout clears favourites tile URLs');
    expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await favouriteStates.close();
    await sessionStates.close();

    {
      SharedPreferences.setMockInitialValues(<String, Object>{PersistenceKeys.quickTileFavsTarget: 'both'});
      await tester.runAsync(() => QuickTileConfigService.pushFavWallUrls(<String>['https://example.com/cached.jpg']));
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
      await _drainNativeMirror(tester);
      expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/cached.jpg']);

      favouriteStates.add(FavouriteWallsState.initial().copyWith(status: LoadStatus.loading, userId: 'a'));
      await _drainNativeMirror(tester);
      expect(favourites.state.status, LoadStatus.loading);
      expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/cached.jpg']);

      favouriteStates.add(_favourites('a', 'https://example.com/fresh.jpg'));
      await tester.pump();
      await _waitForUrls(tester, <String>[
        'https://example.com/fresh.jpg',
      ], reason: 'loaded favourites replace cold cache');
      expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, <String>['https://example.com/fresh.jpg']);

      sessionStates.add(SessionState.initial());
      await tester.pump();
      await _waitForUrls(tester, const <String>[], reason: 'logout clears cold-start favourites URLs');
      expect((await QuickTileConfigService.loadFavsTileConfig())?.wallUrls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await favouriteStates.close();
      await sessionStates.close();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
