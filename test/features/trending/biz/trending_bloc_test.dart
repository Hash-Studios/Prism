import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/domain/entities/trending_range.dart';
import 'package:Prism/features/trending/domain/usecases/fetch_trending_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchTrending extends Mock implements FetchTrendingUseCase {}

PrismWallpaper _wall(String id) => PrismWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: ''),
);

void main() {
  late _MockFetchTrending fetch;
  late TrendingBloc bloc;

  setUpAll(() => registerFallbackValue(TrendingRange.week));

  setUp(() {
    fetch = _MockFetchTrending();
    bloc = TrendingBloc(fetch);
  });

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('started loads the week and leaves all time alone', () async {
    when(() => fetch(TrendingRange.week)).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('a')]));

    bloc.add(const TrendingEvent.started());
    await settle();

    expect(bloc.state.range, TrendingRange.week);
    expect(bloc.state.week.status, LoadStatus.success);
    expect(bloc.state.week.walls.map((wall) => wall.id), <String>['a']);
    expect(bloc.state.allTime.status, LoadStatus.initial);
    verifyNever(() => fetch(TrendingRange.allTime));
  });

  test('selecting all time loads it once and a second pick reuses it', () async {
    when(() => fetch(any())).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('x')]));

    bloc.add(const TrendingEvent.rangeSelected(TrendingRange.allTime));
    await settle();
    bloc.add(const TrendingEvent.rangeSelected(TrendingRange.week));
    await settle();
    bloc.add(const TrendingEvent.rangeSelected(TrendingRange.allTime));
    await settle();

    expect(bloc.state.range, TrendingRange.allTime);
    expect(bloc.state.current.walls.single.id, 'x');
    verify(() => fetch(TrendingRange.allTime)).called(1);
  });

  test('a failed first load keeps the failure, and picking the range again retries', () async {
    when(() => fetch(TrendingRange.week)).thenAnswer((_) async => Result.error(const ServerFailure('offline')));

    bloc.add(const TrendingEvent.started());
    await settle();

    expect(bloc.state.week.status, LoadStatus.failure);
    expect(bloc.state.week.failure, isA<ServerFailure>());

    when(() => fetch(TrendingRange.week)).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('a')]));
    bloc.add(const TrendingEvent.rangeSelected(TrendingRange.week));
    await settle();

    expect(bloc.state.week.status, LoadStatus.success);
    expect(bloc.state.week.failure, isNull);
  });

  test('refresh reloads the selected range and keeps the walls on screen while it runs and when it fails', () async {
    when(() => fetch(TrendingRange.week)).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('a')]));
    bloc.add(const TrendingEvent.started());
    await settle();

    final Completer<Result<List<PrismWallpaper>>> pending = Completer<Result<List<PrismWallpaper>>>();
    when(() => fetch(TrendingRange.week)).thenAnswer((_) => pending.future);
    bloc.add(const TrendingEvent.refreshRequested());
    await settle();

    expect(bloc.state.week.status, LoadStatus.loading);
    expect(bloc.state.week.walls.map((wall) => wall.id), <String>['a']);

    pending.complete(Result.error(const ServerFailure('offline')));
    await settle();

    expect(bloc.state.week.status, LoadStatus.failure);
    expect(bloc.state.week.walls.map((wall) => wall.id), <String>['a']);
  });

  test('a late answer from an older request does not replace a newer one', () async {
    final Completer<Result<List<PrismWallpaper>>> first = Completer<Result<List<PrismWallpaper>>>();
    when(() => fetch(TrendingRange.week)).thenAnswer((_) => first.future);
    bloc.add(const TrendingEvent.started());
    await settle();

    when(() => fetch(TrendingRange.week)).thenAnswer((_) async => Result.success(<PrismWallpaper>[_wall('new')]));
    bloc.add(const TrendingEvent.refreshRequested());
    await settle();
    first.complete(Result.success(<PrismWallpaper>[_wall('old')]));
    await settle();

    expect(bloc.state.week.walls.single.id, 'new');
  });
}
