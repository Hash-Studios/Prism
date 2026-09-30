import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_setups/biz/bloc/favourite_setups_bloc.j.dart';
import 'package:Prism/features/favourite_setups/domain/usecases/favourite_setups_usecases.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchUseCase extends Mock implements FetchFavouriteSetupsUseCase {}

class _MockToggleUseCase extends Mock implements ToggleFavouriteSetupUseCase {}

const SetupEntity _setup = SetupEntity(id: 'SETUP1', image: 'https://example.com/setup1.jpg');

void main() {
  setUpAll(() {
    registerFallbackValue(const FetchFavouriteSetupsParams(userId: 'user-1'));
    registerFallbackValue(const ToggleFavouriteSetupParams(userId: 'user-1', setup: _setup));
  });

  late _MockFetchUseCase fetchUseCase;
  late _MockToggleUseCase toggleUseCase;
  late FavouriteSetupsBloc bloc;

  setUp(() {
    fetchUseCase = _MockFetchUseCase();
    toggleUseCase = _MockToggleUseCase();
    bloc = FavouriteSetupsBloc(fetchUseCase, toggleUseCase);
    addTearDown(bloc.close);
  });

  test('loads the favourites of the started user', () async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(<SetupEntity>[_setup]));

    bloc.add(const FavouriteSetupsEvent.started(userId: 'user-1'));
    await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);

    expect(bloc.state.items, <SetupEntity>[_setup]);
    final params = verify(() => fetchUseCase(captureAny())).captured.single as FetchFavouriteSetupsParams;
    expect(params.userId, 'user-1');
  });

  test('a successful toggle replaces the items with the returned list', () async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <SetupEntity>[]));
    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(<SetupEntity>[_setup]));
    bloc.add(const FavouriteSetupsEvent.started(userId: 'user-1'));
    await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);

    bloc.add(const FavouriteSetupsEvent.toggleRequested(setup: _setup));
    await bloc.stream.firstWhere((state) => state.items.isNotEmpty);

    expect(bloc.state.actionStatus, ActionStatus.success);
    expect(bloc.state.items, <SetupEntity>[_setup]);
  });

  test('a failed toggle keeps the items and reports the failure', () async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(<SetupEntity>[_setup]));
    when(() => toggleUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('offline')));
    bloc.add(const FavouriteSetupsEvent.started(userId: 'user-1'));
    await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);

    bloc.add(const FavouriteSetupsEvent.toggleRequested(setup: _setup));
    await bloc.stream.firstWhere((state) => state.actionStatus == ActionStatus.failure);

    expect(bloc.state.items, <SetupEntity>[_setup]);
    expect(bloc.state.failure, isA<ServerFailure>());
  });
}
