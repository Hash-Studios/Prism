import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:Prism/features/auto_rotate/views/widgets/auto_rotate_session_listener.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/main.dart' as app;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockAutoRotateBloc extends MockBloc<AutoRotateEvent, AutoRotateState> implements AutoRotateBloc {}

class _MockSessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

class _MockFavouriteWallsBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState>
    implements FavouriteWallsBloc {}

class _FakeAutoRotateRepository implements AutoRotateRepository {
  _FakeAutoRotateRepository({this.config = const AutoRotateConfig()});

  AutoRotateConfig config;
  bool running = false;
  bool nextStopResult = true;
  int stops = 0;

  @override
  Future<AutoRotateConfig> loadConfig() async => config;

  @override
  Future<void> saveConfig(AutoRotateConfig config) async => this.config = config;

  @override
  Future<bool> start(AutoRotateConfig config, List<String> imageUrls) async {
    running = true;
    return true;
  }

  @override
  Future<bool> stop() async {
    stops++;
    if (nextStopResult) running = false;
    return nextStopResult;
  }

  @override
  Future<AutoRotateStatus> status() async => AutoRotateStatus(isRunning: running);

  @override
  Future<bool> rotateNow() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });
  tearDown(AnalyticsRuntime.reset);

  testWidgets('first confirmed non-Pro session revokes rotation even with stale guest premium', (tester) async {
    final _MockAutoRotateBloc autoRotateBloc = _MockAutoRotateBloc();
    final _MockSessionBloc sessionBloc = _MockSessionBloc();
    final _MockFavouriteWallsBloc favouriteWallsBloc = _MockFavouriteWallsBloc();
    final StreamController<SessionState> states = StreamController<SessionState>();
    final SessionState initial = SessionState.initial();
    when(() => autoRotateBloc.state).thenReturn(AutoRotateState.initial());
    whenListen(autoRotateBloc, const Stream<AutoRotateState>.empty(), initialState: AutoRotateState.initial());
    whenListen(sessionBloc, states.stream, initialState: initial);
    whenListen(
      favouriteWallsBloc,
      const Stream<FavouriteWallsState>.empty(),
      initialState: FavouriteWallsState.initial(),
    );

    await tester.pumpWidget(_listenerTree(autoRotateBloc, sessionBloc, favouriteWallsBloc));
    states.add(
      const SessionState(
        status: LoadStatus.success,
        session: SessionEntity(userId: '', loggedIn: false, premium: true, subscriptionTier: 'pro'),
      ),
    );
    await tester.pump();

    verify(() => autoRotateBloc.add(const AutoRotateEvent.entitlementChanged(isPro: false, userId: ''))).called(1);
    await states.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('an already-successful initial snapshot still syncs entitlement', (tester) async {
    final _MockAutoRotateBloc autoRotateBloc = _MockAutoRotateBloc();
    final _MockSessionBloc sessionBloc = _MockSessionBloc();
    final _MockFavouriteWallsBloc favouriteWallsBloc = _MockFavouriteWallsBloc();
    const SessionState initial = SessionState(
      status: LoadStatus.success,
      session: SessionEntity(userId: 'account-a', loggedIn: true, premium: true, subscriptionTier: 'pro'),
    );
    when(() => autoRotateBloc.state).thenReturn(AutoRotateState.initial());
    whenListen(autoRotateBloc, const Stream<AutoRotateState>.empty(), initialState: AutoRotateState.initial());
    whenListen(sessionBloc, const Stream<SessionState>.empty(), initialState: initial);
    whenListen(
      favouriteWallsBloc,
      const Stream<FavouriteWallsState>.empty(),
      initialState: FavouriteWallsState.initial(),
    );

    await tester.pumpWidget(_listenerTree(autoRotateBloc, sessionBloc, favouriteWallsBloc));
    await tester.pump();

    verify(
      () => autoRotateBloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a')),
    ).called(1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('does not send auto-rotate events off Android', (tester) async {
    final _MockAutoRotateBloc autoRotateBloc = _MockAutoRotateBloc();
    final _MockSessionBloc sessionBloc = _MockSessionBloc();
    final _MockFavouriteWallsBloc favouriteWallsBloc = _MockFavouriteWallsBloc();
    const SessionState initial = SessionState(
      status: LoadStatus.success,
      session: SessionEntity(userId: 'account-a', loggedIn: true, premium: true, subscriptionTier: 'pro'),
    );
    when(() => autoRotateBloc.state).thenReturn(AutoRotateState.initial());
    whenListen(autoRotateBloc, const Stream<AutoRotateState>.empty(), initialState: AutoRotateState.initial());
    whenListen(sessionBloc, const Stream<SessionState>.empty(), initialState: initial);
    whenListen(
      favouriteWallsBloc,
      const Stream<FavouriteWallsState>.empty(),
      initialState: FavouriteWallsState.initial(),
    );

    await tester.pumpWidget(_listenerTree(autoRotateBloc, sessionBloc, favouriteWallsBloc));
    await tester.pump();

    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-a')));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('sign-out revokes rotation even when the prior entitlement still says premium', (tester) async {
    final _MockAutoRotateBloc autoRotateBloc = _MockAutoRotateBloc();
    final _MockSessionBloc sessionBloc = _MockSessionBloc();
    final _MockFavouriteWallsBloc favouriteWallsBloc = _MockFavouriteWallsBloc();
    final StreamController<SessionState> states = StreamController<SessionState>();
    const SessionState initial = SessionState(
      status: LoadStatus.success,
      session: SessionEntity(userId: 'account-a', loggedIn: true, premium: true, subscriptionTier: 'pro'),
    );
    when(() => autoRotateBloc.state).thenReturn(AutoRotateState.initial());
    whenListen(autoRotateBloc, const Stream<AutoRotateState>.empty(), initialState: AutoRotateState.initial());
    whenListen(sessionBloc, states.stream, initialState: initial);
    whenListen(
      favouriteWallsBloc,
      const Stream<FavouriteWallsState>.empty(),
      initialState: FavouriteWallsState.initial(),
    );

    await tester.pumpWidget(_listenerTree(autoRotateBloc, sessionBloc, favouriteWallsBloc));
    await tester.pump();
    states.add(
      const SessionState(
        status: LoadStatus.success,
        session: SessionEntity(userId: '', loggedIn: false, premium: true, subscriptionTier: 'pro'),
      ),
    );
    await tester.pump();

    verify(() => autoRotateBloc.add(const AutoRotateEvent.entitlementChanged(isPro: false, userId: ''))).called(1);
    await states.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('confirmed account switch sends the new identity to the shared bloc', (tester) async {
    final _MockAutoRotateBloc autoRotateBloc = _MockAutoRotateBloc();
    final _MockSessionBloc sessionBloc = _MockSessionBloc();
    final _MockFavouriteWallsBloc favouriteWallsBloc = _MockFavouriteWallsBloc();
    final StreamController<SessionState> states = StreamController<SessionState>();
    const SessionState initial = SessionState(
      status: LoadStatus.success,
      session: SessionEntity(userId: 'account-a', loggedIn: true, premium: true, subscriptionTier: 'pro'),
    );
    when(() => autoRotateBloc.state).thenReturn(AutoRotateState.initial());
    whenListen(autoRotateBloc, const Stream<AutoRotateState>.empty(), initialState: AutoRotateState.initial());
    whenListen(sessionBloc, states.stream, initialState: initial);
    whenListen(
      favouriteWallsBloc,
      const Stream<FavouriteWallsState>.empty(),
      initialState: FavouriteWallsState.initial(),
    );

    await tester.pumpWidget(_listenerTree(autoRotateBloc, sessionBloc, favouriteWallsBloc));
    await tester.pump();
    states.add(
      const SessionState(
        status: LoadStatus.success,
        session: SessionEntity(userId: 'account-b', loggedIn: true, premium: true, subscriptionTier: 'pro'),
      ),
    );
    await tester.pump();

    verify(
      () => autoRotateBloc.add(const AutoRotateEvent.entitlementChanged(isPro: true, userId: 'account-b')),
    ).called(1);
    await states.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('loading and failed sessions do not revoke rotation', (tester) async {
    final _MockAutoRotateBloc autoRotateBloc = _MockAutoRotateBloc();
    final _MockSessionBloc sessionBloc = _MockSessionBloc();
    final _MockFavouriteWallsBloc favouriteWallsBloc = _MockFavouriteWallsBloc();
    final StreamController<SessionState> states = StreamController<SessionState>();
    when(() => autoRotateBloc.state).thenReturn(AutoRotateState.initial());
    whenListen(autoRotateBloc, const Stream<AutoRotateState>.empty(), initialState: AutoRotateState.initial());
    whenListen(sessionBloc, states.stream, initialState: SessionState.initial());
    whenListen(
      favouriteWallsBloc,
      const Stream<FavouriteWallsState>.empty(),
      initialState: FavouriteWallsState.initial(),
    );

    await tester.pumpWidget(_listenerTree(autoRotateBloc, sessionBloc, favouriteWallsBloc));
    states
      ..add(const SessionState(status: LoadStatus.loading, session: SessionEntity.guest))
      ..add(const SessionState(status: LoadStatus.failure, session: SessionEntity.guest));
    await tester.pump();

    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.entitlementChanged(isPro: false, userId: '')));
    await states.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('favorites from the active account reach auto-rotate outside its screen', (tester) async {
    final _MockAutoRotateBloc autoRotateBloc = _MockAutoRotateBloc();
    final _MockSessionBloc sessionBloc = _MockSessionBloc();
    final _MockFavouriteWallsBloc favouriteWallsBloc = _MockFavouriteWallsBloc();
    final StreamController<FavouriteWallsState> favourites = StreamController<FavouriteWallsState>();
    const SessionState session = SessionState(
      status: LoadStatus.success,
      session: SessionEntity(userId: 'account-a', loggedIn: true, premium: true, subscriptionTier: 'pro'),
    );
    when(() => autoRotateBloc.state).thenReturn(AutoRotateState.initial());
    whenListen(autoRotateBloc, const Stream<AutoRotateState>.empty(), initialState: AutoRotateState.initial());
    whenListen(sessionBloc, const Stream<SessionState>.empty(), initialState: session);
    whenListen(favouriteWallsBloc, favourites.stream, initialState: FavouriteWallsState.initial());

    await tester.pumpWidget(_listenerTree(autoRotateBloc, sessionBloc, favouriteWallsBloc));
    favourites.add(
      const FavouriteWallsState(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        userId: 'account-a',
        items: <FavouriteWallEntity>[
          LegacyFavouriteWall(
            id: 'wall-a',
            source: WallpaperSource.prism,
            legacyPayload: <String, Object?>{'wallpaper_url': 'https://example.test/a.jpg'},
          ),
        ],
      ),
    );
    await tester.pump();

    verify(
      () => autoRotateBloc.add(const AutoRotateEvent.favouritesChanged(<String>['https://example.test/a.jpg'])),
    ).called(1);
    await favourites.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('favorites from a prior account are ignored', (tester) async {
    final _MockAutoRotateBloc autoRotateBloc = _MockAutoRotateBloc();
    final _MockSessionBloc sessionBloc = _MockSessionBloc();
    final _MockFavouriteWallsBloc favouriteWallsBloc = _MockFavouriteWallsBloc();
    final StreamController<FavouriteWallsState> favourites = StreamController<FavouriteWallsState>();
    const SessionState session = SessionState(
      status: LoadStatus.success,
      session: SessionEntity(userId: 'account-b', loggedIn: true, premium: true, subscriptionTier: 'pro'),
    );
    when(() => autoRotateBloc.state).thenReturn(AutoRotateState.initial());
    whenListen(autoRotateBloc, const Stream<AutoRotateState>.empty(), initialState: AutoRotateState.initial());
    whenListen(sessionBloc, const Stream<SessionState>.empty(), initialState: session);
    whenListen(favouriteWallsBloc, favourites.stream, initialState: FavouriteWallsState.initial());

    await tester.pumpWidget(_listenerTree(autoRotateBloc, sessionBloc, favouriteWallsBloc));
    favourites.add(
      const FavouriteWallsState(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        userId: 'account-a',
        items: <FavouriteWallEntity>[
          LegacyFavouriteWall(
            id: 'wall-a',
            source: WallpaperSource.prism,
            legacyPayload: <String, Object?>{'wallpaper_url': 'https://example.test/a.jpg'},
          ),
        ],
      ),
    );
    await tester.pump();

    verifyNever(
      () => autoRotateBloc.add(const AutoRotateEvent.favouritesChanged(<String>['https://example.test/a.jpg'])),
    );
    await favourites.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('session revocation survives app subtree restart without replacing the shared bloc', (tester) async {
    final _FakeAutoRotateRepository repository = _FakeAutoRotateRepository(
      config: const AutoRotateConfig(enabled: true),
    );
    final AutoRotateBloc bloc = AutoRotateBloc(repository);
    AutoRotateBloc? beforeRestart;
    await tester.pumpWidget(
      BlocProvider<AutoRotateBloc>.value(
        value: bloc,
        child: MaterialApp(
          home: Scaffold(
            body: app.RestartWidget(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    beforeRestart = context.read<AutoRotateBloc>();
                    app.RestartWidget.restartApp(context);
                  },
                  child: const Text('restart'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    bloc.add(
      const AutoRotateEvent.started(favouriteUrls: <String>['https://a.test/1', 'https://a.test/2'], isPro: true),
    );
    await tester.pumpAndSettle();
    expect(bloc.state.status.isRunning, isTrue);
    bloc.add(const AutoRotateEvent.entitlementChanged(isPro: false, userId: ''));
    await tester.pumpAndSettle();
    expect(bloc.state.loaded, isTrue);
    expect(bloc.state.config.enabled, isFalse);
    expect(bloc.state.status.isRunning, isFalse);

    expect(repository.stops, 1);
    expect(repository.config.enabled, isFalse);
    await tester.tap(find.text('restart'));
    await tester.pumpAndSettle();

    expect(tester.element(find.text('restart')).read<AutoRotateBloc>(), same(bloc));
    expect(bloc.isClosed, isFalse);
    expect(beforeRestart, same(bloc));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(bloc.close);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('resume retries a failed signed-out stop without RevenueCat refresh', (tester) async {
    final _FakeAutoRotateRepository repository = _FakeAutoRotateRepository(
      config: const AutoRotateConfig(enabled: true),
    );
    final AutoRotateBloc autoRotateBloc = AutoRotateBloc(repository);
    final _MockSessionBloc sessionBloc = _MockSessionBloc();
    final _MockFavouriteWallsBloc favouriteWallsBloc = _MockFavouriteWallsBloc();
    final StreamController<SessionState> sessions = StreamController<SessionState>();
    const SessionState proSession = SessionState(
      status: LoadStatus.success,
      session: SessionEntity(userId: 'account-a', loggedIn: true, premium: true, subscriptionTier: 'pro'),
    );
    whenListen(sessionBloc, sessions.stream, initialState: proSession);
    whenListen(
      favouriteWallsBloc,
      const Stream<FavouriteWallsState>.empty(),
      initialState: const FavouriteWallsState(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        userId: 'account-a',
        items: <FavouriteWallEntity>[
          LegacyFavouriteWall(
            id: 'wall-a',
            source: WallpaperSource.prism,
            legacyPayload: <String, Object?>{'wallpaper_url': 'https://example.test/a.jpg'},
          ),
          LegacyFavouriteWall(
            id: 'wall-b',
            source: WallpaperSource.prism,
            legacyPayload: <String, Object?>{'wallpaper_url': 'https://example.test/b.jpg'},
          ),
        ],
      ),
    );

    await tester.pumpWidget(_listenerTree(autoRotateBloc, sessionBloc, favouriteWallsBloc));
    await tester.pumpAndSettle();
    expect(autoRotateBloc.state.status.isRunning, isTrue);

    repository.nextStopResult = false;
    sessions.add(const SessionState(status: LoadStatus.success, session: SessionEntity.guest));
    await tester.pumpAndSettle();
    expect(repository.stops, 1);
    expect(autoRotateBloc.state.status.isRunning, isTrue);
    expect(autoRotateBloc.state.config.enabled, isFalse);

    repository.nextStopResult = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repository.stops, 2);
    expect(autoRotateBloc.state.status.isRunning, isFalse);
    expect(autoRotateBloc.state.config.enabled, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(autoRotateBloc.close);
    await sessions.close();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

Widget _listenerTree(AutoRotateBloc autoRotateBloc, SessionBloc sessionBloc, FavouriteWallsBloc favouriteWallsBloc) =>
    MultiBlocProvider(
      providers: [
        BlocProvider<AutoRotateBloc>.value(value: autoRotateBloc),
        BlocProvider<SessionBloc>.value(value: sessionBloc),
        BlocProvider<FavouriteWallsBloc>.value(value: favouriteWallsBloc),
      ],
      child: const MaterialApp(home: AutoRotateSessionListener(child: SizedBox())),
    );
