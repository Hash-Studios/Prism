import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_archive_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wotd_past_pick.dart';
import 'package:Prism/features/wall_of_the_day/domain/usecases/fetch_wotd_archive_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchWotdArchive extends Mock implements FetchWotdArchiveUseCase {}

WotdPastPick _pick(String id) => WotdPastPick(
  date: DateTime.utc(2026),
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: '',
    ),
  ),
);

void main() {
  late _MockFetchWotdArchive fetch;
  late WotdArchiveBloc bloc;

  setUpAll(() => registerFallbackValue(const NoParams()));

  setUp(() {
    fetch = _MockFetchWotdArchive();
    bloc = WotdArchiveBloc(fetch);
  });

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('started loads the picks', () async {
    when(() => fetch(any())).thenAnswer((_) async => Result.success(<WotdPastPick>[_pick('a'), _pick('b')]));

    bloc.add(const WotdArchiveEvent.started());
    await settle();

    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.picks.map((pick) => pick.wallpaper.id), <String>['a', 'b']);
  });

  test('a failed first load is a failure with no picks', () async {
    when(() => fetch(any())).thenAnswer((_) async => Result.error(const ServerFailure('offline')));

    bloc.add(const WotdArchiveEvent.started());
    await settle();

    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.picks, isEmpty);
    expect(bloc.state.failure?.message, 'offline');
  });

  test('a failed refresh keeps the picks on screen', () async {
    when(() => fetch(any())).thenAnswer((_) async => Result.success(<WotdPastPick>[_pick('a')]));
    bloc.add(const WotdArchiveEvent.started());
    await settle();
    when(() => fetch(any())).thenAnswer((_) async => Result.error(const ServerFailure('offline')));

    bloc.add(const WotdArchiveEvent.refreshRequested());
    await settle();

    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.picks.map((pick) => pick.wallpaper.id), <String>['a']);
  });

  test('a refresh shows loading but keeps the old picks until the new ones arrive', () async {
    when(() => fetch(any())).thenAnswer((_) async => Result.success(<WotdPastPick>[_pick('a')]));
    bloc.add(const WotdArchiveEvent.started());
    await settle();
    final Completer<Result<List<WotdPastPick>>> slow = Completer<Result<List<WotdPastPick>>>();
    when(() => fetch(any())).thenAnswer((_) => slow.future);

    bloc.add(const WotdArchiveEvent.refreshRequested());
    await settle();
    expect(bloc.state.status, LoadStatus.loading);
    expect(bloc.state.picks, hasLength(1));

    slow.complete(Result.success(<WotdPastPick>[_pick('c'), _pick('a')]));
    await settle();
    expect(bloc.state.picks.map((pick) => pick.wallpaper.id), <String>['c', 'a']);
  });

  test('a slow earlier load cannot replace a newer one', () async {
    final Completer<Result<List<WotdPastPick>>> first = Completer<Result<List<WotdPastPick>>>();
    final Completer<Result<List<WotdPastPick>>> second = Completer<Result<List<WotdPastPick>>>();
    int calls = 0;
    when(() => fetch(any())).thenAnswer((_) => ++calls == 1 ? first.future : second.future);

    bloc.add(const WotdArchiveEvent.started());
    await settle();
    bloc.add(const WotdArchiveEvent.refreshRequested());
    await settle();
    second.complete(Result.success(<WotdPastPick>[_pick('new')]));
    await settle();
    first.complete(Result.success(<WotdPastPick>[_pick('old')]));
    await settle();

    expect(bloc.state.picks.map((pick) => pick.wallpaper.id), <String>['new']);
  });
}
