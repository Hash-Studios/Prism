import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/domain/usecases/fetch_trending_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_user_block_repository.dart';

class _MockFetchTrending extends Mock implements FetchTrendingUseCase {}

PrismWallpaper _wall(String id, {String? uid}) => PrismWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.prism,
    fullUrl: 'https://example.com/$id.jpg',
    thumbnailUrl: '',
    authorUid: uid,
  ),
);

void main() {
  late _MockFetchTrending fetch;
  late FakeUserBlockRepository blocks;
  late TrendingBloc bloc;

  setUpAll(() => registerFallbackValue(const NoParams()));

  setUp(() {
    fetch = _MockFetchTrending();
    blocks = FakeUserBlockRepository.pending()..completeInitial(<String>{});
    bloc = TrendingBloc(fetch, blocks);
  });

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('started loads the trending list', () async {
    when(() => fetch(any())).thenAnswer((_) async => TrendingFetch.success(<PrismWallpaper>[_wall('a')]));

    bloc.add(const TrendingEvent.started());
    await settle();

    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.walls.map((wall) => wall.id), <String>['a']);
    verify(() => fetch(any())).called(1);
  });

  test('started paints the saved walls before the network answers, then replaces them', () async {
    final Completer<TrendingFetch> pending = Completer<TrendingFetch>();
    when(() => fetch.readCached()).thenAnswer((_) async => <PrismWallpaper>[_wall('old')]);
    when(() => fetch(any())).thenAnswer((_) => pending.future);

    bloc.add(const TrendingEvent.started());
    await settle();

    expect(bloc.state.walls.map((wall) => wall.id), <String>['old']);
    expect(bloc.state.status, LoadStatus.loading);

    pending.complete(TrendingFetch.success(<PrismWallpaper>[_wall('new')]));
    await settle();

    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.walls.map((wall) => wall.id), <String>['new']);
  });

  test('started begins the network fetch before the saved walls are read', () async {
    final Completer<List<PrismWallpaper>> cache = Completer<List<PrismWallpaper>>();
    when(() => fetch.readCached()).thenAnswer((_) => cache.future);
    when(() => fetch(any())).thenAnswer((_) async => TrendingFetch.success(<PrismWallpaper>[_wall('new')]));

    bloc.add(const TrendingEvent.started());
    await settle();

    verify(() => fetch(any())).called(1);
    cache.complete(<PrismWallpaper>[]);
    await settle();
    expect(bloc.state.walls.map((wall) => wall.id), <String>['new']);
  });

  test('a network failure after the saved walls painted keeps them on screen', () async {
    when(() => fetch.readCached()).thenAnswer((_) async => <PrismWallpaper>[_wall('old')]);
    when(() => fetch(any())).thenAnswer((_) async => TrendingFetch.error(const ServerFailure('offline')));

    bloc.add(const TrendingEvent.started());
    await settle();

    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.walls.map((wall) => wall.id), <String>['old']);
  });

  test('a failed first load keeps the failure, and a refresh retries', () async {
    when(() => fetch(any())).thenAnswer((_) async => TrendingFetch.error(const ServerFailure('offline')));

    bloc.add(const TrendingEvent.started());
    await settle();

    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.failure, isA<ServerFailure>());

    when(() => fetch(any())).thenAnswer((_) async => TrendingFetch.success(<PrismWallpaper>[_wall('a')]));
    bloc.add(const TrendingEvent.refreshRequested());
    await settle();

    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.failure, isNull);
  });

  test('refresh reloads the list and keeps the walls on screen while it runs and when it fails', () async {
    when(() => fetch(any())).thenAnswer((_) async => TrendingFetch.success(<PrismWallpaper>[_wall('a')]));
    bloc.add(const TrendingEvent.started());
    await settle();

    final Completer<TrendingFetch> pending = Completer<TrendingFetch>();
    when(() => fetch(any())).thenAnswer((_) => pending.future);
    bloc.add(const TrendingEvent.refreshRequested());
    await settle();

    expect(bloc.state.status, LoadStatus.loading);
    expect(bloc.state.walls.map((wall) => wall.id), <String>['a']);

    pending.complete(TrendingFetch.error(const ServerFailure('offline')));
    await settle();

    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.walls.map((wall) => wall.id), <String>['a']);
  });

  test('a late answer from an older request does not replace a newer one', () async {
    final Completer<TrendingFetch> first = Completer<TrendingFetch>();
    when(() => fetch(any())).thenAnswer((_) => first.future);
    bloc.add(const TrendingEvent.started());
    await settle();

    when(() => fetch(any())).thenAnswer((_) async => TrendingFetch.success(<PrismWallpaper>[_wall('new')]));
    bloc.add(const TrendingEvent.refreshRequested());
    await settle();
    first.complete(TrendingFetch.success(<PrismWallpaper>[_wall('old')]));
    await settle();

    expect(bloc.state.walls.single.id, 'new');
  });

  group('blocking a creator', () {
    test('removes their walls at once', () async {
      when(() => fetch(any())).thenAnswer(
        (_) async => TrendingFetch.success(<PrismWallpaper>[_wall('a', uid: 'bad-uid'), _wall('b', uid: 'ok-uid')]),
      );
      bloc.add(const TrendingEvent.started());
      await settle();

      blocks.completeInitial(<String>{'bad-uid'});
      await settle();

      expect(bloc.state.walls.map((wall) => wall.id), <String>['b']);
      verify(() => fetch(any())).called(1);
    });

    test('an unknown block list hides creator walls, and recovery reloads the list', () async {
      when(() => fetch(any())).thenAnswer(
        (_) async => TrendingFetch.success(<PrismWallpaper>[_wall('a', uid: 'bad-uid'), _wall('b', uid: 'ok-uid')]),
      );
      bloc.add(const TrendingEvent.started());
      await settle();
      expect(bloc.state.walls.map((wall) => wall.id), <String>['a', 'b']);

      blocks.emitUnknown();
      await settle();

      expect(bloc.state.walls, isEmpty);

      blocks.completeInitial(<String>{'bad-uid'});
      await settle();
      await settle();

      expect(bloc.state.walls.map((wall) => wall.id), <String>['b']);
      verify(() => fetch(any())).called(2);
    });

    test('recovery during a load makes one bounded follow-up fetch', () async {
      final Completer<TrendingFetch> pending = Completer<TrendingFetch>();
      int calls = 0;
      when(() => fetch(any())).thenAnswer((_) {
        calls++;
        if (calls == 1) return pending.future;
        return Future.value(TrendingFetch.success(<PrismWallpaper>[_wall('restored', uid: 'creator')]));
      });
      bloc.add(const TrendingEvent.started());
      await settle();
      blocks.emitUnknown();
      await settle();
      blocks.timeOutInitialLoad();
      blocks.completeInitial(<String>{});
      await settle();

      pending.complete(TrendingFetch.success(<PrismWallpaper>[_wall('restored', uid: 'creator')]));
      await settle();
      await settle();

      expect(bloc.state.walls.map((wall) => wall.id), <String>['restored']);
      expect(calls, 2);
    });

    test('also hides their walls in a load that was already running', () async {
      final Completer<TrendingFetch> pending = Completer<TrendingFetch>();
      when(() => fetch(any())).thenAnswer((_) => pending.future);
      bloc.add(const TrendingEvent.started());
      await settle();

      blocks.completeInitial(<String>{'bad-uid'});
      await settle();
      pending.complete(TrendingFetch.success(<PrismWallpaper>[_wall('a', uid: 'bad-uid'), _wall('b')]));
      await settle();

      expect(bloc.state.walls.map((wall) => wall.id), <String>['b']);
    });

    test('unblocking them loads the list again and brings their walls back', () async {
      when(() => fetch(any())).thenAnswer(
        (_) async => TrendingFetch.success(<PrismWallpaper>[_wall('a', uid: 'bad-uid'), _wall('b', uid: 'ok-uid')]),
      );
      bloc.add(const TrendingEvent.started());
      await settle();
      blocks.completeInitial(<String>{'bad-uid'});
      await settle();
      expect(bloc.state.walls.map((wall) => wall.id), <String>['b']);

      blocks.completeInitial(<String>{});
      await settle();

      expect(bloc.state.walls.map((wall) => wall.id), <String>['a', 'b']);
      verify(() => fetch(any())).called(2);
    });

    test('unblocking them before the first load does not load the list', () async {
      blocks.completeInitial(<String>{'bad-uid'});
      await settle();
      blocks.completeInitial(<String>{});
      await settle();

      expect(bloc.state.status, LoadStatus.initial);
      verifyNever(() => fetch(any()));
    });

    test('leaves the list alone when the set is empty or hits no wall', () async {
      when(
        () => fetch(any()),
      ).thenAnswer((_) async => TrendingFetch.success(<PrismWallpaper>[_wall('a', uid: 'a-uid')]));
      bloc.add(const TrendingEvent.started());
      await settle();
      final TrendingState before = bloc.state;

      blocks.completeInitial(<String>{});
      blocks.completeInitial(<String>{'other-uid'});
      await settle();

      expect(bloc.state, before);
    });
  });
}
