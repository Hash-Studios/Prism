import 'dart:async';

import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/connectivity/biz/bloc/connectivity_bloc.j.dart';
import 'package:Prism/features/connectivity/domain/entities/connectivity_entity.dart';
import 'package:Prism/features/connectivity/domain/usecases/connectivity_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCheckConnectionUseCase extends Mock implements CheckConnectionUseCase {}

class _MockWatchConnectionUseCase extends Mock implements WatchConnectionUseCase {}

void main() {
  late _MockCheckConnectionUseCase checkUseCase;
  late _MockWatchConnectionUseCase watchUseCase;
  late StreamController<ConnectivityEntity> streamController;

  setUp(() {
    checkUseCase = _MockCheckConnectionUseCase();
    watchUseCase = _MockWatchConnectionUseCase();
    streamController = StreamController<ConnectivityEntity>.broadcast();

    when(() => checkUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(const ConnectivityEntity(isConnected: true)),
    );

    when(() => watchUseCase()).thenAnswer((_) => streamController.stream);
  });

  tearDown(() async {
    await streamController.close();
  });

  blocTest<ConnectivityBloc, ConnectivityState>(
    'emits latest stream status after start',
    build: () => ConnectivityBloc(checkUseCase, watchUseCase),
    act: (bloc) async {
      bloc.add(const ConnectivityEvent.started());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      streamController.add(const ConnectivityEntity(isConnected: false));
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.connectivity.isConnected, isFalse);
    },
  );
}
