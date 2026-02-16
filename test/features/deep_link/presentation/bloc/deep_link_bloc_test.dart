import 'dart:async';

import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/deep_link/biz/bloc/deep_link_bloc.j.dart';
import 'package:Prism/features/deep_link/domain/entities/deep_link_action_entity.dart';
import 'package:Prism/features/deep_link/domain/usecases/deep_link_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetInitialDeepLinkActionUseCase extends Mock implements GetInitialDeepLinkActionUseCase {}

class _MockObserveDeepLinkActionsUseCase extends Mock implements ObserveDeepLinkActionsUseCase {}

void main() {
  late _MockGetInitialDeepLinkActionUseCase getInitialUseCase;
  late _MockObserveDeepLinkActionsUseCase observeUseCase;
  late StreamController<DeepLinkActionEntity> controller;

  const initialAction = DeepLinkActionEntity(
    type: DeepLinkActionType.share,
    route: '/share',
    arguments: <dynamic>['id', 'Prism', 'url', 'thumb'],
    rawUri: 'https://prism/share',
  );

  const streamAction = DeepLinkActionEntity(
    type: DeepLinkActionType.user,
    route: '/fprofile',
    arguments: <dynamic>['user@test.com'],
    rawUri: 'https://prism/user',
  );

  setUp(() {
    getInitialUseCase = _MockGetInitialDeepLinkActionUseCase();
    observeUseCase = _MockObserveDeepLinkActionsUseCase();
    controller = StreamController<DeepLinkActionEntity>.broadcast();

    when(() => getInitialUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(initialAction),
    );

    when(() => observeUseCase()).thenAnswer((_) => controller.stream);
  });

  tearDown(() async {
    await controller.close();
  });

  blocTest<DeepLinkBloc, DeepLinkState>(
    'stores initial action and appends incoming deep links',
    build: () => DeepLinkBloc(getInitialUseCase, observeUseCase),
    act: (bloc) async {
      bloc.add(const DeepLinkEvent.started());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.add(streamAction);
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.initialAction, initialAction);
      expect(bloc.state.latestAction, streamAction);
      expect(bloc.state.history.length, 2);
    },
  );
}
