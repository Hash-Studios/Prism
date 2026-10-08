import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_bloc.j.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/domain/repositories/theme_repository.dart';
import 'package:Prism/features/theme_mode/domain/usecases/theme_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoadThemeUseCase extends Mock implements LoadThemeUseCase {}

class _MockUpdateThemeUseCase extends Mock implements UpdateThemeUseCase {}

class _MockThemeRepository extends Mock implements ThemeRepository {}

const _light = ThemeSelection(themeId: 'kLCoffee', accentColorValue: 0xff123456);
const _dark = ThemeSelection(themeId: 'kDAMOLED', accentColorValue: 0xff654321);

void main() {
  setUpAll(() {
    registerFallbackValue(const UpdateThemeParams());
  });

  late _MockLoadThemeUseCase loadUseCase;
  late _MockUpdateThemeUseCase updateUseCase;
  late _MockThemeRepository repository;

  setUp(() {
    loadUseCase = _MockLoadThemeUseCase();
    updateUseCase = _MockUpdateThemeUseCase();
    repository = _MockThemeRepository();
    final defaults = ThemeState.initial();
    when(
      () => repository.readSync(),
    ).thenReturn(ThemePreferences(light: defaults.light, dark: defaults.dark, mode: defaults.mode));

    when(() => loadUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(const ThemePreferences(light: _light, dark: _dark, mode: ThemeMode.system)),
    );
    when(() => updateUseCase(any())).thenAnswer(
      (_) async => Result.success(const ThemePreferences(light: _light, dark: _dark, mode: ThemeMode.light)),
    );
  });

  ThemeBloc buildBloc() => ThemeBloc(loadUseCase, updateUseCase, repository);

  test('the first state already holds the stored selection, before any event', () {
    when(
      () => repository.readSync(),
    ).thenReturn(const ThemePreferences(light: _light, dark: _dark, mode: ThemeMode.dark));

    final bloc = buildBloc();
    addTearDown(bloc.close);

    expect(bloc.state.light, _light);
    expect(bloc.state.dark, _dark);
    expect(bloc.state.mode, ThemeMode.dark);
    expect(bloc.state.status, LoadStatus.initial);
  });

  final updated = ThemeState.initial().copyWith(
    status: LoadStatus.success,
    actionStatus: ActionStatus.success,
    light: _light,
    dark: _dark,
    mode: ThemeMode.light,
  );

  blocTest<ThemeBloc, ThemeState>(
    'started loads light, dark and mode',
    build: buildBloc,
    act: (bloc) => bloc.add(const ThemeEvent.started()),
    expect: () => <ThemeState>[
      ThemeState.initial().copyWith(status: LoadStatus.loading),
      ThemeState.initial().copyWith(status: LoadStatus.success, light: _light, dark: _dark, mode: ThemeMode.system),
    ],
  );

  blocTest<ThemeBloc, ThemeState>(
    'started reports a failure',
    build: () {
      when(() => loadUseCase(const NoParams())).thenAnswer((_) async => Result.error(const CacheFailure('boom')));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const ThemeEvent.started()),
    expect: () => <ThemeState>[
      ThemeState.initial().copyWith(status: LoadStatus.loading),
      ThemeState.initial().copyWith(
        status: LoadStatus.failure,
        actionStatus: ActionStatus.failure,
        failure: const CacheFailure('boom'),
      ),
    ],
  );

  blocTest<ThemeBloc, ThemeState>(
    'lightThemeChanged updates the light theme id',
    build: buildBloc,
    act: (bloc) => bloc.add(const ThemeEvent.lightThemeChanged(themeId: 'kLCoffee')),
    expect: () => <ThemeState>[ThemeState.initial().copyWith(actionStatus: ActionStatus.inProgress), updated],
    verify: (_) => verify(
      () => updateUseCase(any(that: isA<UpdateThemeParams>().having((p) => p.lightThemeId, 'id', 'kLCoffee'))),
    ).called(1),
  );

  blocTest<ThemeBloc, ThemeState>(
    'lightAccentChanged updates the light accent',
    build: buildBloc,
    act: (bloc) => bloc.add(const ThemeEvent.lightAccentChanged(accentColorValue: 0xff123456)),
    expect: () => <ThemeState>[ThemeState.initial().copyWith(actionStatus: ActionStatus.inProgress), updated],
    verify: (_) => verify(
      () => updateUseCase(
        any(that: isA<UpdateThemeParams>().having((p) => p.lightAccentColorValue, 'accent', 0xff123456)),
      ),
    ).called(1),
  );

  blocTest<ThemeBloc, ThemeState>(
    'darkThemeChanged updates the dark theme id',
    build: buildBloc,
    act: (bloc) => bloc.add(const ThemeEvent.darkThemeChanged(themeId: 'kDAMOLED')),
    expect: () => <ThemeState>[ThemeState.initial().copyWith(actionStatus: ActionStatus.inProgress), updated],
    verify: (_) => verify(
      () => updateUseCase(any(that: isA<UpdateThemeParams>().having((p) => p.darkThemeId, 'id', 'kDAMOLED'))),
    ).called(1),
  );

  blocTest<ThemeBloc, ThemeState>(
    'darkAccentChanged updates the dark accent',
    build: buildBloc,
    act: (bloc) => bloc.add(const ThemeEvent.darkAccentChanged(accentColorValue: 0xff654321)),
    expect: () => <ThemeState>[ThemeState.initial().copyWith(actionStatus: ActionStatus.inProgress), updated],
    verify: (_) => verify(
      () => updateUseCase(
        any(that: isA<UpdateThemeParams>().having((p) => p.darkAccentColorValue, 'accent', 0xff654321)),
      ),
    ).called(1),
  );

  blocTest<ThemeBloc, ThemeState>(
    'modeChanged stores the new mode',
    build: buildBloc,
    act: (bloc) => bloc.add(const ThemeEvent.modeChanged(mode: ThemeMode.light)),
    expect: () => <ThemeState>[ThemeState.initial().copyWith(actionStatus: ActionStatus.inProgress), updated],
    verify: (_) => verify(
      () => updateUseCase(any(that: isA<UpdateThemeParams>().having((p) => p.mode, 'mode', ThemeMode.light))),
    ).called(1),
  );
}
