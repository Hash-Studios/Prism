import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/domain/usecases/fetch_wall_of_the_day_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchWallOfTheDayUseCase extends Mock implements FetchWallOfTheDayUseCase {}

const _oldWall = WallOfTheDayEntity(wallId: 'old', url: '', thumbnailUrl: '', photographer: 'Old');
const _newWall = WallOfTheDayEntity(wallId: 'new', url: '', thumbnailUrl: '', photographer: 'New');

void main() {
  test('a late earlier refresh cannot replace the latest wall', () async {
    final first = Completer<Result<WallOfTheDayEntity?>>();
    final second = Completer<Result<WallOfTheDayEntity?>>();
    final fetchUseCase = _MockFetchWallOfTheDayUseCase();
    var calls = 0;
    when(() => fetchUseCase(const NoParams())).thenAnswer((_) => ++calls == 1 ? first.future : second.future);
    final bloc = WotdBloc(fetchUseCase);
    addTearDown(bloc.close);

    bloc.add(const WotdEvent.started());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const WotdEvent.started());
    await Future<void>.delayed(Duration.zero);

    second.complete(
      Result.success(
        const WallOfTheDayEntity(wallId: 'new', url: 'https://example.com/new.jpg', thumbnailUrl: '', photographer: ''),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    first.complete(
      Result.success(
        const WallOfTheDayEntity(wallId: 'old', url: 'https://example.com/old.jpg', thumbnailUrl: '', photographer: ''),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.entity?.wallId, 'new');
  });

  test('a late empty response cannot clear the latest wall', () async {
    final first = Completer<Result<WallOfTheDayEntity?>>();
    final fetchUseCase = _MockFetchWallOfTheDayUseCase();
    var calls = 0;
    when(() => fetchUseCase(const NoParams())).thenAnswer((_) {
      calls++;
      return calls == 1 ? first.future : Future.value(Result.success(_newWall));
    });
    final bloc = WotdBloc(fetchUseCase);
    addTearDown(bloc.close);

    bloc.add(const WotdEvent.started());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const WotdEvent.started());
    await Future<void>.delayed(Duration.zero);
    first.complete(Result.success(null));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.entity?.wallId, 'new');
    expect(bloc.state.status, LoadStatus.success);
  });

  test('a late earlier failure cannot replace the latest success', () async {
    final first = Completer<Result<WallOfTheDayEntity?>>();
    final fetchUseCase = _MockFetchWallOfTheDayUseCase();
    var calls = 0;
    when(() => fetchUseCase(const NoParams())).thenAnswer((_) {
      calls++;
      return calls == 1 ? first.future : Future.value(Result.success(_newWall));
    });
    final bloc = WotdBloc(fetchUseCase);
    addTearDown(bloc.close);

    bloc.add(const WotdEvent.started());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const WotdEvent.started());
    await Future<void>.delayed(Duration.zero);
    first.complete(Result.error(const UnknownFailure('stale')));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.entity?.wallId, 'new');
    expect(bloc.state.status, LoadStatus.success);
  });

  test('refresh keeps the old wall through loading and failure, then retry recovers', () async {
    final refresh = Completer<Result<WallOfTheDayEntity?>>();
    final fetchUseCase = _MockFetchWallOfTheDayUseCase();
    var calls = 0;
    when(() => fetchUseCase(const NoParams())).thenAnswer((_) {
      calls++;
      return switch (calls) {
        1 => Future.value(Result.success(_oldWall)),
        2 => refresh.future,
        _ => Future.value(Result.success(_newWall)),
      };
    });
    final bloc = WotdBloc(fetchUseCase);
    addTearDown(bloc.close);

    bloc.add(const WotdEvent.started());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.entity?.wallId, 'old');

    bloc.add(const WotdEvent.started());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, LoadStatus.loading);
    expect(bloc.state.entity?.wallId, 'old');
    refresh.complete(Result.error(const UnknownFailure('offline')));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, LoadStatus.failure);
    expect(bloc.state.entity?.wallId, 'old');

    bloc.add(const WotdEvent.started());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.entity?.wallId, 'new');
    expect(calls, 3);
  });

  test('a successful empty response clears the previous wall', () async {
    final fetchUseCase = _MockFetchWallOfTheDayUseCase();
    var calls = 0;
    when(() => fetchUseCase(const NoParams())).thenAnswer((_) async {
      calls++;
      return Result.success(calls == 1 ? _oldWall : null);
    });
    final bloc = WotdBloc(fetchUseCase);
    addTearDown(bloc.close);

    bloc.add(const WotdEvent.started());
    await Future<void>.delayed(Duration.zero);
    bloc.add(const WotdEvent.started());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.status, LoadStatus.success);
    expect(bloc.state.entity, isNull);
  });
}
