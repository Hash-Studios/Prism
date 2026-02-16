import 'dart:async';

import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/quick_actions/biz/bloc/quick_actions_bloc.j.dart';
import 'package:Prism/features/quick_actions/domain/entities/quick_action_entity.dart';
import 'package:Prism/features/quick_actions/domain/usecases/quick_actions_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockInitializeQuickActionsUseCase extends Mock implements InitializeQuickActionsUseCase {}

class _MockSetQuickActionShortcutsUseCase extends Mock implements SetQuickActionShortcutsUseCase {}

class _MockObserveQuickActionsUseCase extends Mock implements ObserveQuickActionsUseCase {}

void main() {
  late _MockInitializeQuickActionsUseCase initUseCase;
  late _MockSetQuickActionShortcutsUseCase setUseCase;
  late _MockObserveQuickActionsUseCase observeUseCase;
  late StreamController<QuickActionEntity> controller;

  setUp(() {
    initUseCase = _MockInitializeQuickActionsUseCase();
    setUseCase = _MockSetQuickActionShortcutsUseCase();
    observeUseCase = _MockObserveQuickActionsUseCase();
    controller = StreamController<QuickActionEntity>.broadcast();

    when(() => initUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(null),
    );
    when(() => setUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(null),
    );
    when(() => observeUseCase()).thenAnswer((_) => controller.stream);
  });

  tearDown(() async {
    await controller.close();
  });

  blocTest<QuickActionsBloc, QuickActionsState>(
    'initializes shortcuts and captures quick action callbacks',
    build: () => QuickActionsBloc(initUseCase, setUseCase, observeUseCase),
    act: (bloc) async {
      bloc.add(const QuickActionsEvent.started());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.add(
        const QuickActionEntity(
          type: QuickActionType.collections,
          rawValue: 'Collections',
        ),
      );
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.latestAction?.type, QuickActionType.collections);
      expect(bloc.state.history.length, 1);
    },
  );
}
