import 'dart:async';

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

class _FavouriteBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState> implements FavouriteWallsBloc {}

class _SessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

class _GatedFirstWriteStore extends InMemorySharedPreferencesStore {
  _GatedFirstWriteStore() : super.empty();

  final Completer<void> firstWriteGate = Completer<void>();
  bool _gated = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!_gated) {
      _gated = true;
      await firstWriteGate.future;
    }
    return super.setValue(valueType, key, value);
  }
}

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
  session: SessionEntity(userId: userId, loggedIn: true, premium: false, subscriptionTier: 'free'),
);

Future<String?> _stored() async =>
    (await SharedPreferences.getInstance()).getString(PersistenceKeys.shortcutsFavourites);

String _json(String id) => '[{"id":"$id","url":"https://example.com/$id.jpg"}]';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    await tester.pump();
    await tester.pump();
    return (favouriteStates, sessionStates);
  }

  testWidgets('on iOS it writes favourites, follows edits, and clears on account switch and sign-out', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final (favouriteStates, sessionStates) = await pump(tester, _favourites('a', 'one'), _session('a'));
    expect(await _stored(), _json('one'));

    favouriteStates.add(_favourites('a', 'two'));
    await tester.pump();
    await tester.pump();
    expect(await _stored(), _json('two'));

    favouriteStates.add(_favourites('a', 'two').copyWith(status: LoadStatus.loading));
    await tester.pump();
    await tester.pump();
    expect(await _stored(), _json('two'));

    sessionStates.add(_session('b'));
    await tester.pump();
    await tester.pump();
    expect(await _stored(), '[]');

    favouriteStates.add(_favourites('a', 'stale'));
    await tester.pump();
    await tester.pump();
    expect(await _stored(), '[]');

    favouriteStates.add(_favourites('b', 'three'));
    await tester.pump();
    await tester.pump();
    expect(await _stored(), _json('three'));

    sessionStates.add(SessionState.initial());
    await tester.pump();
    await tester.pump();
    expect(await _stored(), '[]');

    await tester.pumpWidget(const SizedBox.shrink());
    await favouriteStates.close();
    await sessionStates.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on iOS a guest start clears a stale favourites list', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{PersistenceKeys.shortcutsFavourites: _json('previous')});
    final (favouriteStates, sessionStates) = await pump(tester, FavouriteWallsState.initial(), SessionState.initial());
    expect(await _stored(), '[]');

    await tester.pumpWidget(const SizedBox.shrink());
    await favouriteStates.close();
    await sessionStates.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on iOS a slow save cannot overwrite the clear that follows sign-out', (tester) async {
    final _GatedFirstWriteStore store = _GatedFirstWriteStore();
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    final (favouriteStates, sessionStates) = await pump(tester, _favourites('a', 'one'), _session('a'));

    sessionStates.add(SessionState.initial());
    await tester.pump();
    await tester.pump();
    store.firstWriteGate.complete();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    SharedPreferences.resetStatic();
    expect(await _stored(), '[]');

    await tester.pumpWidget(const SizedBox.shrink());
    await favouriteStates.close();
    await sessionStates.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on Android it writes nothing', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final (favouriteStates, sessionStates) = await pump(tester, _favourites('a', 'one'), _session('a'));
    favouriteStates.add(_favourites('a', 'two'));
    await tester.pump();
    await tester.pump();
    sessionStates.add(SessionState.initial());
    await tester.pump();
    await tester.pump();
    expect(await _stored(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await favouriteStates.close();
    await sessionStates.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
