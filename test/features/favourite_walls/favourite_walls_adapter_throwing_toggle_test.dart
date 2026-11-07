// Hash-Studios/Prism#542
import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_error_reporter.dart';
import '../../support/favourite_test_scope.dart';
import 'support/fav_fixtures.dart';

class _MockFetch extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggle extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClear extends Mock implements ClearFavouriteWallsUseCase {}

class _MockSetFavouritePinUseCase extends Mock implements SetFavouritePinUseCase {}

void main() {
  setUpFavouriteCounts();
  late _MockFetch fetch;
  late _MockToggle toggle;
  late _MockClear clear;
  late FavouriteWallsBloc bloc;
  late FavouriteWallsAdapter adapter;

  setUpAll(() {
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'u'));
    registerFallbackValue(ToggleFavouriteWallParams(userId: 'u', wall: legacyFav('x'), currentlyFavourited: false));
  });

  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'u'
      ..loggedIn = true;
    fetch = _MockFetch();
    toggle = _MockToggle();
    clear = _MockClear();
    when(() => fetch(any())).thenAnswer((_) async => Result.success(<FavouriteWallEntity>[]));
  });

  tearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

  Future<void> pumpAdapter(WidgetTester tester, {bool load = true}) async {
    bloc = FavouriteWallsBloc(fetch, toggle, clear, _MockSetFavouritePinUseCase());
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider<FavouriteWallsBloc>.value(
        value: bloc,
        child: Builder(
          builder: (BuildContext context) {
            adapter = context.favouriteWallsAdapter(listen: false);
            return const SizedBox();
          },
        ),
      ),
    );
    if (load) await adapter.getDataBase();
  }

  testWidgets('a favourite toggle whose use case throws still completes the heart tap', (tester) async {
    when(() => toggle(any())).thenThrow(StateError('boom'));
    await pumpAdapter(tester);

    bool? favourited;
    unawaited(adapter.favCheck(legacyFav('x')).then((bool value) => favourited = value));
    await tester.pump(const Duration(milliseconds: 50));

    expect(favourited, isFalse);
  });

  for (final bool refresh in <bool>[false, true]) {
    testWidgets('a throwing ${refresh ? 'refresh' : 'initial load'} fails and the next read retries', (tester) async {
      await pumpAdapter(tester, load: refresh);
      when(() => fetch(any())).thenThrow(StateError('load failed'));

      List<FavouriteWallEntity>? result = <FavouriteWallEntity>[legacyFav('sentinel')];
      unawaited(adapter.getDataBase(forceRefresh: refresh).then((value) => result = value));
      await tester.pump();

      expect(result, isNull);
      expect(bloc.state.status, LoadStatus.failure);
      when(() => fetch(any())).thenAnswer((_) async => Result.success(<FavouriteWallEntity>[legacyFav('retry')]));
      unawaited(adapter.getDataBase().then((value) => result = value));
      await tester.pump();

      expect(result?.single.id, 'retry');
      expect(bloc.state.status, LoadStatus.success);
    });
  }

  testWidgets('a caught handler exception reaches monitoring without a debug observer', (tester) async {
    final previous = MonitoringRuntime.reporter;
    final reporter = FakeErrorReporter();
    MonitoringRuntime.reporter = reporter;
    addTearDown(() => MonitoringRuntime.reporter = previous);
    final error = StateError('report this handler failure');
    when(() => toggle(any())).thenThrow(error);
    await pumpAdapter(tester);

    bool? result;
    unawaited(adapter.favCheck(legacyFav('x')).then((value) => result = value));
    await tester.pump();

    expect(result, isFalse);
    expect(reporter.capturedExceptions.single.exception, same(error));
    expect(reporter.capturedExceptions.single.stackTrace, isNotNull);
  });

  testWidgets('an operation without an id fails and the queue still runs the next action', (tester) async {
    when(() => toggle(any())).thenThrow(StateError('zero id'));
    await pumpAdapter(tester);
    bloc.add(FavouriteWallsEvent.toggleRequested(wall: legacyFav('x')));
    await tester.pump();
    expect(bloc.state.completedOperationId, 0);
    expect(bloc.state.actionStatus, ActionStatus.failure);

    when(() => toggle(any())).thenAnswer((_) async => Result.success(false));
    bool? result;
    unawaited(adapter.favCheck(legacyFav('x')).then((value) => result = value));
    await tester.pump();
    expect(result, isTrue);
    expect(bloc.state.actionStatus, ActionStatus.success);
  });

  test('an exception after close does not emit on the cancelled handler', () async {
    final pending = Completer<Result<bool>>();
    final started = Completer<void>();
    when(() => toggle(any())).thenAnswer((_) {
      started.complete();
      return pending.future;
    });
    bloc = FavouriteWallsBloc(fetch, toggle, clear, _MockSetFavouritePinUseCase());
    bloc.add(FavouriteWallsEvent.toggleRequested(wall: legacyFav('x'), operationId: 5));
    await started.future;
    await bloc.close();
    pending.completeError(StateError('closed handler'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.isClosed, isTrue);
    expect(bloc.state.completedOperationId, isNot(5));
  });
}
