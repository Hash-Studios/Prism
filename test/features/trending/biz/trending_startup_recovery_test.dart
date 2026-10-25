import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/domain/usecases/fetch_trending_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_user_block_repository.dart';

class _Fetch extends Mock implements FetchTrendingUseCase {}

class _Sessions extends Mock implements SessionRepository {}

PrismWallpaper _wall(String id) => PrismWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: ''),
);

void main() {
  setUpAll(() => registerFallbackValue(const NoParams()));

  late _Fetch fetch;
  late Completer<bool> initialization;
  late TrendingBloc bloc;
  late int calls;

  setUp(() {
    fetch = _Fetch();
    initialization = Completer<bool>();
    calls = 0;
    bloc = TrendingBloc(fetch, FakeUserBlockRepository.pending()..completeInitial(<String>{}));
    when(() => fetch.readCached()).thenAnswer((_) async => <PrismWallpaper>[]);
  });

  tearDown(() => bloc.close());

  for (final bool cached in <bool>[false, true]) {
    test('pre-init failure recovers once after ready with cached=$cached', () async {
      final saved = cached ? <PrismWallpaper>[_wall('saved')] : <PrismWallpaper>[];
      when(() => fetch.readCached()).thenAnswer((_) async => saved);
      when(() => fetch(any())).thenAnswer((_) async {
        calls++;
        if (calls > 1) return TrendingFetch.success(<PrismWallpaper>[_wall('fresh')]);
        return cached
            ? TrendingFetch.success(saved, retryAfterInitialization: initialization.future)
            : TrendingFetch.error(const ServerFailure('not ready'), retryAfterInitialization: initialization.future);
      });
      bloc.add(const TrendingEvent.started());
      await pumpEventQueue();
      expect(calls, 1);
      expect(bloc.state.status, cached ? LoadStatus.success : LoadStatus.failure);
      expect(bloc.state.walls.map((wall) => wall.id), cached ? <String>['saved'] : <String>[]);

      initialization.complete(true);
      await pumpEventQueue();
      expect(calls, 2);
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.walls.single.id, 'fresh');
      await pumpEventQueue();
      expect(calls, 2);
    });
  }

  test('a retry outcome cannot schedule another startup retry', () async {
    when(() => fetch(any())).thenAnswer((_) async {
      calls++;
      return TrendingFetch.error(const ServerFailure('not ready'), retryAfterInitialization: initialization.future);
    });
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    initialization.complete(true);
    await pumpEventQueue();
    expect(calls, 2);
    expect(bloc.state.status, LoadStatus.failure);
  });

  test('cached walls remain visible while the automatic retry waits for its network answer', () async {
    final automatic = Completer<TrendingFetch>();
    when(() => fetch.readCached()).thenAnswer((_) async => <PrismWallpaper>[_wall('saved')]);
    when(() => fetch(any())).thenAnswer((_) {
      calls++;
      return calls == 1
          ? Future.value(
              TrendingFetch.success(<PrismWallpaper>[_wall('saved')], retryAfterInitialization: initialization.future),
            )
          : automatic.future;
    });
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    initialization.complete(true);
    await pumpEventQueue();
    expect(calls, 2);
    expect(bloc.state.status, LoadStatus.loading);
    expect(bloc.state.walls.single.id, 'saved');
    automatic.complete(TrendingFetch.success(<PrismWallpaper>[_wall('fresh')]));
    await pumpEventQueue();
    expect(bloc.state.walls.single.id, 'fresh');
  });

  test('two starts allocate request ownership before their cache reads settle', () async {
    final firstCache = Completer<List<PrismWallpaper>>();
    final secondCache = Completer<List<PrismWallpaper>>();
    int cacheReads = 0;
    when(() => fetch.readCached()).thenAnswer((_) => ++cacheReads == 1 ? firstCache.future : secondCache.future);
    when(() => fetch(any())).thenAnswer((_) async {
      calls++;
      return TrendingFetch.success(<PrismWallpaper>[_wall(calls == 1 ? 'old' : 'new')]);
    });
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    firstCache.complete(<PrismWallpaper>[_wall('old-cache')]);
    await pumpEventQueue();
    secondCache.complete(<PrismWallpaper>[]);
    await pumpEventQueue();
    expect(calls, 2);
    expect(bloc.state.walls.single.id, 'new');
  });

  test('manual refresh racing readiness wins without a duplicate request', () async {
    when(() => fetch(any())).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? TrendingFetch.error(const ServerFailure('not ready'), retryAfterInitialization: initialization.future)
          : TrendingFetch.success(<PrismWallpaper>[_wall('manual')]);
    });
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    initialization.complete(true);
    scheduleMicrotask(() => bloc.add(const TrendingEvent.refreshRequested()));
    await pumpEventQueue();
    expect(calls, 2);
    expect(bloc.state.walls.single.id, 'manual');
  });

  test('manual request already in flight cancels the queued startup retry', () async {
    final manual = Completer<TrendingFetch>();
    when(() => fetch(any())).thenAnswer((_) {
      calls++;
      return calls == 1
          ? Future.value(
              TrendingFetch.error(const ServerFailure('not ready'), retryAfterInitialization: initialization.future),
            )
          : manual.future;
    });
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    bloc.add(const TrendingEvent.refreshRequested());
    await pumpEventQueue();
    initialization.complete(true);
    await pumpEventQueue();
    expect(calls, 2);
    manual.complete(TrendingFetch.success(<PrismWallpaper>[_wall('manual')]));
    await pumpEventQueue();
    expect(bloc.state.walls.single.id, 'manual');
  });

  test('manual refresh after automatic retry starts wins over its late response', () async {
    final automatic = Completer<TrendingFetch>();
    final manual = Completer<TrendingFetch>();
    when(() => fetch(any())).thenAnswer((_) {
      calls++;
      if (calls == 1) {
        return Future.value(
          TrendingFetch.error(const ServerFailure('not ready'), retryAfterInitialization: initialization.future),
        );
      }
      return calls == 2 ? automatic.future : manual.future;
    });
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    initialization.complete(true);
    await pumpEventQueue();
    expect(calls, 2);
    bloc.add(const TrendingEvent.refreshRequested());
    await pumpEventQueue();
    expect(calls, 3);
    manual.complete(TrendingFetch.success(<PrismWallpaper>[_wall('manual')]));
    await pumpEventQueue();
    automatic.complete(TrendingFetch.success(<PrismWallpaper>[_wall('stale-automatic')]));
    await pumpEventQueue();
    expect(bloc.state.walls.single.id, 'manual');
  });

  test('failed initialization leaves a settled error and does not retry', () async {
    when(() => fetch(any())).thenAnswer((_) async {
      calls++;
      return TrendingFetch.error(const ServerFailure('not ready'), retryAfterInitialization: initialization.future);
    });
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    initialization.complete(false);
    await pumpEventQueue();
    expect(calls, 1);
    expect(bloc.state.status, LoadStatus.failure);
  });

  test('initialization exceptions leave a settled error and do not retry', () async {
    when(() => fetch(any())).thenAnswer((_) async {
      calls++;
      return TrendingFetch.error(const ServerFailure('not ready'), retryAfterInitialization: initialization.future);
    });
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    initialization.completeError(StateError('initialization failed'));
    await pumpEventQueue();
    expect(calls, 1);
    expect(bloc.state.status, LoadStatus.failure);
  });

  test('disposing before initialization prevents the startup retry', () async {
    when(() => fetch(any())).thenAnswer((_) async {
      calls++;
      return TrendingFetch.error(const ServerFailure('not ready'), retryAfterInitialization: initialization.future);
    });
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    await bloc.close();
    initialization.complete(true);
    await pumpEventQueue();
    expect(calls, 1);
  });

  test('sign-out and sign-in to the same owner invalidate the startup retry', () async {
    await bloc.close();
    final sessions = _Sessions();
    final changes = StreamController<PrismUsersV2>.broadcast(sync: true);
    addTearDown(changes.close);
    PrismUsersV2 current = app_constants.createGuestPrismUser()..id = 'owner';
    current.loggedIn = true;
    when(() => sessions.currentUser).thenAnswer((_) => current);
    when(() => sessions.watchCurrentUser()).thenAnswer((_) => changes.stream);
    bloc = TrendingBloc(
      fetch,
      FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      sessionRepository: sessions,
    );
    when(() => fetch(any())).thenAnswer((_) async {
      calls++;
      return TrendingFetch.error(const ServerFailure('not ready'), retryAfterInitialization: initialization.future);
    });
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    current = app_constants.createGuestPrismUser();
    changes.add(current);
    current = app_constants.createGuestPrismUser()..id = 'owner';
    current.loggedIn = true;
    changes.add(current);
    initialization.complete(true);
    await pumpEventQueue();
    expect(calls, 1);
    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.failure, const ServerFailure('not ready'));
  });

  for (final bool automaticRetry in <bool>[false, true]) {
    for (final bool currentFails in <bool>[false, true]) {
      test('sign-out reloads and settles with automaticRetry=$automaticRetry, currentFails=$currentFails', () async {
        await bloc.close();
        final sessions = _Sessions();
        final changes = StreamController<PrismUsersV2>.broadcast(sync: true);
        addTearDown(changes.close);
        PrismUsersV2 current = app_constants.createGuestPrismUser()..id = 'owner';
        current.loggedIn = true;
        when(() => sessions.currentUser).thenAnswer((_) => current);
        when(() => sessions.watchCurrentUser()).thenAnswer((_) => changes.stream);
        bloc = TrendingBloc(
          fetch,
          FakeUserBlockRepository.pending()..completeInitial(<String>{}),
          sessionRepository: sessions,
        );
        final obsolete = Completer<TrendingFetch>();
        final currentRequest = Completer<TrendingFetch>();
        final emittedWalls = <List<String>>[];
        final subscription = bloc.stream.listen((state) {
          emittedWalls.add(state.walls.map((wall) => wall.id).toList());
        });
        addTearDown(subscription.cancel);
        when(() => fetch(any())).thenAnswer((_) {
          calls++;
          if (automaticRetry && calls == 1) {
            return Future.value(
              TrendingFetch.error(const ServerFailure('not ready'), retryAfterInitialization: initialization.future),
            );
          }
          return calls == (automaticRetry ? 2 : 1) ? obsolete.future : currentRequest.future;
        });
        bloc.add(const TrendingEvent.started());
        await pumpEventQueue();
        if (automaticRetry) {
          initialization.complete(true);
          await pumpEventQueue();
        }
        expect(calls, automaticRetry ? 2 : 1);
        expect(bloc.state.status, LoadStatus.loading);
        current = app_constants.createGuestPrismUser();
        changes.add(current);
        obsolete.complete(TrendingFetch.success(<PrismWallpaper>[_wall('old-owner')]));
        await pumpEventQueue();
        expect(bloc.state.walls, isEmpty);
        currentRequest.complete(
          currentFails
              ? TrendingFetch.error(
                  const ServerFailure('guest offline'),
                  retryAfterInitialization: initialization.future,
                )
              : TrendingFetch.success(<PrismWallpaper>[_wall('guest')]),
        );
        await pumpEventQueue();
        if (!initialization.isCompleted) initialization.complete(true);
        await pumpEventQueue();
        expect(bloc.state.status, currentFails ? LoadStatus.failure : LoadStatus.success);
        expect(bloc.state.failure, currentFails ? const ServerFailure('guest offline') : null);
        expect(bloc.state.walls.map((wall) => wall.id), currentFails ? <String>[] : <String>['guest']);
        expect(emittedWalls.expand((walls) => walls), isNot(contains('old-owner')));
        expect(calls, automaticRetry || currentFails ? 3 : 2);
        await pumpEventQueue();
        expect(calls, automaticRetry || currentFails ? 3 : 2);
      });
    }
  }

  test('a session boundary during the cache read discards old content and settles the current session', () async {
    await bloc.close();
    final sessions = _Sessions();
    final changes = StreamController<PrismUsersV2>.broadcast(sync: true);
    addTearDown(changes.close);
    PrismUsersV2 current = app_constants.createGuestPrismUser()..id = 'owner';
    current.loggedIn = true;
    when(() => sessions.currentUser).thenAnswer((_) => current);
    when(() => sessions.watchCurrentUser()).thenAnswer((_) => changes.stream);
    bloc = TrendingBloc(
      fetch,
      FakeUserBlockRepository.pending()..completeInitial(<String>{}),
      sessionRepository: sessions,
    );
    final cached = Completer<List<PrismWallpaper>>();
    final emittedWalls = <List<String>>[];
    final subscription = bloc.stream.listen((state) {
      emittedWalls.add(state.walls.map((wall) => wall.id).toList());
    });
    addTearDown(subscription.cancel);
    when(() => fetch.readCached()).thenAnswer((_) => cached.future);
    when(() => fetch(any())).thenAnswer((_) async {
      calls++;
      return TrendingFetch.success(<PrismWallpaper>[_wall(calls == 1 ? 'old-fresh' : 'current-owner')]);
    });
    bloc.add(const TrendingEvent.started());
    await pumpEventQueue();
    current = app_constants.createGuestPrismUser();
    changes.add(current);
    current = app_constants.createGuestPrismUser()..id = 'owner';
    current.loggedIn = true;
    changes.add(current);
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.walls.map((wall) => wall.id), <String>['current-owner']);
    cached.complete(<PrismWallpaper>[_wall('old-cache')]);
    await pumpEventQueue();
    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.walls.map((wall) => wall.id), <String>['current-owner']);
    expect(emittedWalls.expand((walls) => walls), isNot(anyOf(contains('old-cache'), contains('old-fresh'))));
    expect(calls, 3);
  });
}
