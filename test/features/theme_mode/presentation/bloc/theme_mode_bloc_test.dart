import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_mode_bloc.j.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_mode.dart';
import 'package:Prism/features/theme_mode/domain/usecases/theme_mode_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoadThemeModeUseCase extends Mock implements LoadThemeModeUseCase {}

class _MockUpdateThemeModeUseCase extends Mock implements UpdateThemeModeUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const UpdateThemeModeParams(mode: ThemeMode.dark));
  });

  late _MockLoadThemeModeUseCase loadUseCase;
  late _MockUpdateThemeModeUseCase updateUseCase;

  setUp(() {
    loadUseCase = _MockLoadThemeModeUseCase();
    updateUseCase = _MockUpdateThemeModeUseCase();

    when(
      () => loadUseCase(const NoParams()),
    ).thenAnswer((_) async => Result.success(const ThemeModeEntity(mode: ThemeMode.system)));
    when(
      () => updateUseCase(any()),
    ).thenAnswer((_) async => Result.success(const ThemeModeEntity(mode: ThemeMode.light)));
  });

  ThemeModeBloc buildBloc() => ThemeModeBloc(loadUseCase, updateUseCase);

  blocTest<ThemeModeBloc, ThemeModeState>(
    'started loads the saved mode',
    build: buildBloc,
    act: (bloc) => bloc.add(const ThemeModeEvent.started()),
    expect: () => <ThemeModeState>[
      ThemeModeState.initial().copyWith(status: LoadStatus.loading),
      ThemeModeState.initial().copyWith(
        status: LoadStatus.success,
        mode: const ThemeModeEntity(mode: ThemeMode.system),
      ),
    ],
  );

  blocTest<ThemeModeBloc, ThemeModeState>(
    'modeChanged stores the new mode',
    build: buildBloc,
    act: (bloc) => bloc.add(const ThemeModeEvent.modeChanged(mode: ThemeMode.light)),
    expect: () => <ThemeModeState>[
      ThemeModeState.initial().copyWith(actionStatus: ActionStatus.inProgress),
      ThemeModeState.initial().copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        mode: const ThemeModeEntity(mode: ThemeMode.light),
      ),
    ],
    verify: (_) => verify(() => updateUseCase(any())).called(1),
  );
}
