import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/platform/system_color_schemes.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_bloc.j.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/domain/repositories/theme_repository.dart';
import 'package:Prism/features/theme_mode/domain/usecases/theme_usecases.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoadThemeUseCase extends Mock implements LoadThemeUseCase {}

class _MockUpdateThemeUseCase extends Mock implements UpdateThemeUseCase {}

class _MockThemeRepository extends Mock implements ThemeRepository {}

const _light = ThemeSelection(themeId: 'kLCoffee', accentColorValue: 0xff123456);
const _dark = ThemeSelection(themeId: 'kDAMOLED', accentColorValue: 0xff654321);

final SystemColorSchemes schemes = SystemColorSchemes(
  light: ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC)),
  dark: ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC), brightness: Brightness.dark),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const UpdateThemeParams());
  });

  late _MockLoadThemeUseCase loadUseCase;
  late _MockUpdateThemeUseCase updateUseCase;
  late _MockThemeRepository repository;
  late StreamController<ThemePreferences> accountChanges;
  late SystemColorSchemesSource systemColors;
  SystemColorSchemes? systemValue;

  setUp(() {
    loadUseCase = _MockLoadThemeUseCase();
    updateUseCase = _MockUpdateThemeUseCase();
    repository = _MockThemeRepository();
    accountChanges = StreamController<ThemePreferences>.broadcast();
    systemValue = null;
    systemColors = SystemColorSchemesSource.withReader(() async => systemValue);
    when(() => repository.accountChanges).thenAnswer((_) => accountChanges.stream);
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

  tearDown(() => accountChanges.close());

  ThemeBloc buildBloc() => ThemeBloc(loadUseCase, updateUseCase, repository, systemColors);

  test('the first state carries the schemes the source already holds', () async {
    systemValue = schemes;
    await systemColors.refresh();

    final bloc = buildBloc();
    addTearDown(bloc.close);

    expect(bloc.state.system, schemes);
  });

  test('new schemes from the source reach the state', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);
    final states = expectLater(bloc.stream, emits(ThemeState.initial().copyWith(system: schemes)));

    systemValue = schemes;
    await systemColors.refresh();
    await states;

    expect(bloc.state.system, schemes);
  });

  group('Material You selection', () {
    const ThemeSelection materialYouLight = ThemeSelection(themeId: 'kLMaterial You', accentColorValue: 0xff123456);
    const ThemeSelection materialYouDark = ThemeSelection(themeId: 'kDMaterial You', accentColorValue: 0xff123456);

    test('resolves to the default light theme when the phone has no schemes', () {
      final ThemeState state = ThemeState.initial().copyWith(light: materialYouLight);

      expect(state.themeOption(Brightness.light).id, 'kLFrost White');
    });

    test('resolves to Material You light when the phone gives schemes', () {
      final ThemeState state = ThemeState.initial().copyWith(light: materialYouLight, system: schemes);

      expect(state.themeOption(Brightness.light).id, 'kLMaterial You');
    });

    test('Material You light takes the phone primary and ignores the user accent', () {
      final ThemeState state = ThemeState.initial().copyWith(light: materialYouLight, system: schemes);

      expect(prismThemeFor(state, Brightness.light).colorScheme.primary, schemes.light.primary);
    });

    test('Material You light falls back to Frost White with the user accent when the phone has no schemes', () {
      final ThemeState state = ThemeState.initial().copyWith(light: materialYouLight);
      final ThemeData theme = prismThemeFor(state, Brightness.light);

      expect(theme.colorScheme.surface, kLightTheme.colorScheme.surface);
      expect(theme.colorScheme.primary, const Color(0xff123456));
    });

    test('Material You dark falls back to Material Dark with the user accent when the phone has no schemes', () {
      final ThemeState state = ThemeState.initial().copyWith(dark: materialYouDark);
      final ThemeData theme = prismThemeFor(state, Brightness.dark);

      expect(theme.colorScheme.surface, kDarkTheme.colorScheme.surface);
      expect(theme.colorScheme.primary, const Color(0xff123456));
    });
  });

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

  test('one Spooky selection persists its dark theme and dark mode together', () async {
    const ThemePreferences spooky = ThemePreferences(
      light: _light,
      dark: ThemeSelection(themeId: 'kDSpooky', accentColorValue: 0xff654321),
      mode: ThemeMode.dark,
    );
    when(
      () => repository.update(darkThemeId: 'kDSpooky', mode: ThemeMode.dark),
    ).thenAnswer((_) async => Result.success(spooky));
    final bloc = ThemeBloc(LoadThemeUseCase(repository), UpdateThemeUseCase(repository), repository, systemColors);
    addTearDown(bloc.close);
    final states = expectLater(
      bloc.stream,
      emitsInOrder(<ThemeState>[
        ThemeState.initial().copyWith(actionStatus: ActionStatus.inProgress),
        ThemeState.initial().copyWith(
          status: LoadStatus.success,
          actionStatus: ActionStatus.success,
          light: _light,
          dark: spooky.dark,
          mode: ThemeMode.dark,
        ),
      ]),
    );

    bloc.add(const ThemeEvent.darkThemeChanged(themeId: 'kDSpooky', mode: ThemeMode.dark));
    await states;

    verify(() => repository.update(darkThemeId: 'kDSpooky', mode: ThemeMode.dark)).called(1);
  });

  final updated = ThemeState.initial().copyWith(
    status: LoadStatus.success,
    actionStatus: ActionStatus.success,
    light: _light,
    dark: _dark,
    mode: ThemeMode.light,
  );

  test('an account copy on accountChanges replaces the selection', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);
    final states = expectLater(
      bloc.stream,
      emits(
        ThemeState.initial().copyWith(status: LoadStatus.success, light: _light, dark: _dark, mode: ThemeMode.light),
      ),
    );

    accountChanges.add(const ThemePreferences(light: _light, dark: _dark, mode: ThemeMode.light));
    await states;
  });

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
    'darkThemeChanged updates the dark theme and mode in one operation',
    build: () {
      when(() => updateUseCase(any())).thenAnswer(
        (_) async => Result.success(
          const ThemePreferences(
            light: _light,
            dark: ThemeSelection(themeId: 'kDSpooky', accentColorValue: 0xff654321),
            mode: ThemeMode.dark,
          ),
        ),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const ThemeEvent.darkThemeChanged(themeId: 'kDSpooky', mode: ThemeMode.dark)),
    expect: () => <ThemeState>[
      ThemeState.initial().copyWith(actionStatus: ActionStatus.inProgress),
      ThemeState.initial().copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        light: _light,
        dark: const ThemeSelection(themeId: 'kDSpooky', accentColorValue: 0xff654321),
        mode: ThemeMode.dark,
      ),
    ],
    verify: (_) => verify(
      () => updateUseCase(
        any(
          that: isA<UpdateThemeParams>()
              .having((p) => p.darkThemeId, 'dark theme id', 'kDSpooky')
              .having((p) => p.mode, 'mode', ThemeMode.dark),
        ),
      ),
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
