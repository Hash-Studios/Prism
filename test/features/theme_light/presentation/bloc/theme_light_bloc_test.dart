import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/theme_light/biz/bloc/theme_light_bloc.j.dart';
import 'package:Prism/features/theme_light/domain/entities/theme_light.dart';
import 'package:Prism/features/theme_light/domain/usecases/theme_light_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoadThemeLightUseCase extends Mock implements LoadThemeLightUseCase {}

class _MockUpdateThemeLightUseCase extends Mock implements UpdateThemeLightUseCase {}

class _MockUpdateThemeLightAccentUseCase extends Mock implements UpdateThemeLightAccentUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const UpdateThemeLightParams(themeId: 'kLFrost White'));
    registerFallbackValue(
      const UpdateThemeLightAccentParams(accentColorValue: 0xff000000),
    );
  });

  late _MockLoadThemeLightUseCase loadUseCase;
  late _MockUpdateThemeLightUseCase updateThemeUseCase;
  late _MockUpdateThemeLightAccentUseCase updateAccentUseCase;

  setUp(() {
    loadUseCase = _MockLoadThemeLightUseCase();
    updateThemeUseCase = _MockUpdateThemeLightUseCase();
    updateAccentUseCase = _MockUpdateThemeLightAccentUseCase();

    when(() => loadUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(
        const ThemeLightEntity(
          themeId: 'kLFrost White',
          accentColorValue: 0xffe57697,
        ),
      ),
    );

    when(() => updateThemeUseCase(any())).thenAnswer(
      (_) async => Result.success(
        const ThemeLightEntity(
          themeId: 'kLCoffee',
          accentColorValue: 0xffe57697,
        ),
      ),
    );

    when(() => updateAccentUseCase(any())).thenAnswer(
      (_) async => Result.success(
        const ThemeLightEntity(
          themeId: 'kLCoffee',
          accentColorValue: 0xff123456,
        ),
      ),
    );
  });

  ThemeLightBloc buildBloc() => ThemeLightBloc(
        loadUseCase,
        updateThemeUseCase,
        updateAccentUseCase,
      );

  blocTest<ThemeLightBloc, ThemeLightState>(
    'started loads saved light theme',
    build: buildBloc,
    act: (bloc) => bloc.add(const ThemeLightEvent.started()),
    expect: () => <ThemeLightState>[
      ThemeLightState.initial().copyWith(status: LoadStatus.loading),
      ThemeLightState.initial().copyWith(
        status: LoadStatus.success,
        theme: const ThemeLightEntity(
          themeId: 'kLFrost White',
          accentColorValue: 0xffe57697,
        ),
      ),
    ],
  );

  blocTest<ThemeLightBloc, ThemeLightState>(
    'themeChanged updates theme id',
    build: buildBloc,
    seed: () => ThemeLightState.initial().copyWith(status: LoadStatus.success),
    act: (bloc) => bloc.add(const ThemeLightEvent.themeChanged(themeId: 'kLCoffee')),
    expect: () => <ThemeLightState>[
      ThemeLightState.initial().copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.inProgress,
      ),
      ThemeLightState.initial().copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        theme: const ThemeLightEntity(
          themeId: 'kLCoffee',
          accentColorValue: 0xffe57697,
        ),
      ),
    ],
  );
}
