import 'dart:async';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/ios_shortcuts/views/widgets/shortcuts_favourites_listener.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/session.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../support/wait_for_real_io.dart';

class _FavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _SessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

class _GatedFirstWriteStore extends InMemorySharedPreferencesStore {
  _GatedFirstWriteStore() : super.empty();

  final Completer<void> firstWriteGate = Completer<void>();
  final List<Object> favouritesWrites = <Object>[];
  bool _gated = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!_gated) {
      _gated = true;
      await firstWriteGate.future;
    }
    final bool saved = await super.setValue(valueType, key, value);
    if (key == 'flutter.${PersistenceKeys.shortcutsFavourites}') favouritesWrites.add(value);
    return saved;
  }
}

class _RecordingStore extends InMemorySharedPreferencesStore {
  _RecordingStore(super.data) : super.withData();

  final List<Object> writes = <Object>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final bool saved = await super.setValue(valueType, key, value);
    if (key == 'flutter.${PersistenceKeys.shortcutsFavourites}') writes.add(value);
    return saved;
  }
}

class _EmptyOfflineAssetStore extends OfflineAssetStore {
  @override
  Future<Map<String, String>> localPaths() async => <String, String>{};
}

SessionState _resolvedGuest() => SessionState.initial().copyWith(status: LoadStatus.success);

FavouriteWallsState _favourites(String userId, String id) => FavouriteWallsState.initial().copyWith(
  status: LoadStatus.success,
  userId: userId,
  items: <FavouriteWallEntity>[
    LegacyFavouriteWall(
      id: id,
      source: WallpaperSource.prism,
      legacyPayload: <String, dynamic>{'url': 'https://example.com/$id.jpg'},
    ),
  ],
);

SessionState _session(String userId) => SessionState.initial().copyWith(
  status: LoadStatus.success,
  session: SessionEntity(userId: userId, loggedIn: true, premium: false, subscriptionTier: 'free'),
);

Future<void> _settle(WidgetTester tester, bool Function() isReady, {required String reason}) async {
  await tester.runAsync(() => Future<void>(() {}));
  await tester.pump();
  await waitForRealIo(tester, isReady, reason: reason);
  await tester.runAsync(() => Future<void>(() {}));
  await tester.pump();
}

Future<String?> _stored() async =>
    (await SharedPreferences.getInstance()).getString(PersistenceKeys.shortcutsFavourites);

Future<void> _installStore(WidgetTester tester, SharedPreferencesStorePlatform store) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferences.getInstance();
  });
  await tester.runAsync(() async {
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    await SharedPreferences.getInstance();
  });
}

Future<void> _installMockStore(WidgetTester tester) async {
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferences.getInstance();
  });
}

Future<void> _finish(
  WidgetTester tester,
  StreamController<FavouriteWallsState> favourites,
  StreamController<SessionState> session,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await favourites.close();
  await session.close();
  await tester.runAsync(() => Future<void>(() {}));
  await tester.pump();
}

String _json(String id) => '[{"id":"$id","url":"https://example.com/$id.jpg"}]';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    OfflineAssetStore.testOverride = _EmptyOfflineAssetStore();
  });

  tearDown(() {
    OfflineAssetStore.testOverride = null;
  });

  Future<(StreamController<FavouriteWallsState>, StreamController<SessionState>)> pump(
    WidgetTester tester,
    FavouriteWallsState favouritesState,
    SessionState sessionState,
  ) async {
    final favourites = _FavouriteBloc();
    final session = _SessionBloc();
    final favouriteStates = StreamController<FavouriteWallsState>();
    final sessionStates = StreamController<SessionState>();
    whenListen(favourites, favouriteStates.stream, initialState: favouritesState);
    whenListen(session, sessionStates.stream, initialState: sessionState);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<FavouriteWallsBloc>.value(value: favourites),
          BlocProvider<SessionBloc>.value(value: session),
        ],
        child: const ShortcutsFavouritesListener(child: SizedBox.shrink()),
      ),
    );
    return (favouriteStates, sessionStates);
  }

  Future<void> accountSwitchAndSignOutScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{});
    await _installStore(tester, store);
    final (favouriteStates, sessionStates) = await pump(tester, _favourites('a', 'one'), _session('a'));
    await _settle(tester, () => store.writes.length == 1, reason: 'initial save');
    expect(store.writes, <Object>[_json('one')]);

    favouriteStates.add(_favourites('a', 'two'));
    await _settle(tester, () => store.writes.length == 2, reason: 'favourites edit');
    expect(store.writes, <Object>[_json('one'), _json('two')]);

    favouriteStates.add(_favourites('a', 'two').copyWith(status: LoadStatus.loading));
    await _settle(tester, () => true, reason: 'loading state to be ignored');
    expect(await _stored(), _json('two'));

    sessionStates.add(_session('b'));
    await _settle(tester, () => store.writes.length == 3, reason: 'account switch clear');
    expect(store.writes, <Object>[_json('one'), _json('two'), '[]']);

    favouriteStates.add(_favourites('a', 'stale'));
    await _settle(tester, () => true, reason: 'stale old-owner favourites to be ignored');
    expect(await _stored(), '[]');

    favouriteStates.add(_favourites('b', 'three'));
    await _settle(tester, () => store.writes.length == 4, reason: 'new-owner favourites');
    expect(store.writes, <Object>[_json('one'), _json('two'), '[]', _json('three')]);

    sessionStates.add(_resolvedGuest());
    await _settle(tester, () => store.writes.length == 5, reason: 'sign-out clear');
    expect(store.writes, <Object>[_json('one'), _json('two'), '[]', _json('three'), '[]']);

    await _finish(tester, favouriteStates, sessionStates);
  }

  Future<void> resolvedGuestStartupScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{
      'flutter.${PersistenceKeys.shortcutsFavourites}': _json('previous'),
    });
    await _installStore(tester, store);
    final (favouriteStates, sessionStates) = await pump(tester, FavouriteWallsState.initial(), _resolvedGuest());
    await _settle(tester, () => store.writes.length == 1, reason: 'resolved guest startup clear');
    expect(store.writes, <Object>['[]']);

    await _finish(tester, favouriteStates, sessionStates);
  }

  Future<void> unresolvedThenSignedInScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{
      'flutter.${PersistenceKeys.shortcutsFavourites}': _json('previous'),
    });
    await _installStore(tester, store);
    final (favouriteStates, sessionStates) = await pump(tester, FavouriteWallsState.initial(), SessionState.initial());
    expect(store.writes, isEmpty);

    sessionStates.add(SessionState.initial().copyWith(status: LoadStatus.loading));
    await _settle(tester, () => true, reason: 'unresolved session state to be ignored');
    expect(store.writes, isEmpty);

    sessionStates.add(_session('a'));
    favouriteStates.add(_favourites('a', 'one'));
    await _settle(tester, () => store.writes.length == 1, reason: 'signed-in favourites save');
    expect(store.writes, <Object>[_json('one')]);

    await _finish(tester, favouriteStates, sessionStates);
  }

  Future<void> unresolvedThenGuestScenario(WidgetTester tester) async {
    final _RecordingStore store = _RecordingStore(<String, Object>{
      'flutter.${PersistenceKeys.shortcutsFavourites}': _json('previous'),
    });
    await _installStore(tester, store);
    final (favouriteStates, sessionStates) = await pump(tester, FavouriteWallsState.initial(), SessionState.initial());
    expect(await _stored(), _json('previous'));

    sessionStates.add(_resolvedGuest());
    await _settle(tester, () => store.writes.length == 1, reason: 'guest resolution clear');
    expect(store.writes, <Object>['[]']);

    await _finish(tester, favouriteStates, sessionStates);
  }

  Future<void> slowSaveAfterSignOutScenario(WidgetTester tester) async {
    final _GatedFirstWriteStore store = _GatedFirstWriteStore();
    await _installStore(tester, store);
    final (favouriteStates, sessionStates) = await pump(tester, _favourites('a', 'one'), _session('a'));

    sessionStates.add(_resolvedGuest());
    await tester.runAsync(() => Future<void>(() {}));
    await tester.pump();
    store.firstWriteGate.complete();
    await _settle(tester, () => store.favouritesWrites.length == 1, reason: 'queued sign-out clear');

    SharedPreferences.resetStatic();
    expect(await _stored(), '[]');
    expect(store.favouritesWrites, <Object>['[]']);

    await _finish(tester, favouriteStates, sessionStates);
  }

  testWidgets('on iOS favourites scenarios preserve writes across session lifecycles', (tester) async {
    await accountSwitchAndSignOutScenario(tester);
    await resolvedGuestStartupScenario(tester);
    await unresolvedThenSignedInScenario(tester);
    await unresolvedThenGuestScenario(tester);
    await slowSaveAfterSignOutScenario(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on Android it writes nothing', (tester) async {
    await _installMockStore(tester);
    final (favouriteStates, sessionStates) = await pump(tester, _favourites('a', 'one'), _session('a'));
    favouriteStates.add(_favourites('a', 'two'));
    await _settle(tester, () => true, reason: 'Android favourites event');
    sessionStates.add(_resolvedGuest());
    await _settle(tester, () => true, reason: 'Android sign-out event');
    expect(await _stored(), isNull);

    await _finish(tester, favouriteStates, sessionStates);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
