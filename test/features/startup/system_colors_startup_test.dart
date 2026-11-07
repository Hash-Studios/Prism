import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/system_color_schemes.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_bloc.j.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/domain/repositories/theme_repository.dart';
import 'package:Prism/features/theme_mode/domain/usecases/theme_usecases.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/main.dart' as app_main;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockThemeRepository extends Mock implements ThemeRepository {}

const _light = ThemeSelection(themeId: 'kLFrost White', accentColorValue: 0xff123456);
const _dark = ThemeSelection(themeId: 'kDMaterial Dark', accentColorValue: 0xff123456);
const _materialLight = ThemeSelection(themeId: 'kLMaterial You', accentColorValue: 0xff123456);
const _materialDark = ThemeSelection(themeId: 'kDMaterial You', accentColorValue: 0xff123456);

final _schemes = SystemColorSchemes(
  light: ColorScheme.fromSeed(seedColor: const Color(0xff3366cc)).copyWith(primary: const Color(0xff3366cc)),
  dark: ColorScheme.fromSeed(
    seedColor: const Color(0xff6699ff),
    brightness: Brightness.dark,
  ).copyWith(primary: const Color(0xff6699ff)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockThemeRepository repository;
  late Completer<SystemColorSchemes?> reader;
  late SystemColorSchemesSource source;
  late DebugPrintCallback originalDebugPrint;
  late List<String> marks;

  setUp(() {
    repository = _MockThemeRepository();
    reader = Completer<SystemColorSchemes?>();
    source = SystemColorSchemesSource.withReader(() => reader.future);
    getIt.registerSingleton<SystemColorSchemesSource>(source);
    getIt.registerSingleton<ThemeRepository>(repository);
    when(() => repository.accountChanges).thenAnswer((_) => const Stream<ThemePreferences>.empty());
    originalDebugPrint = debugPrint;
    marks = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message?.contains('startup.system_colors_ready') ?? false) marks.add(message!);
    };
  });

  tearDown(() async {
    debugPrint = originalDebugPrint;
    await getIt.reset();
  });

  for (final preferences in <ThemePreferences>[
    const ThemePreferences(light: _materialLight, dark: _dark, mode: ThemeMode.dark),
    const ThemePreferences(light: _light, dark: _materialDark, mode: ThemeMode.light),
  ]) {
    test(
      'waits for an inactive ${preferences.mode == ThemeMode.dark ? 'light' : 'dark'} Material You selection',
      () async {
        when(() => repository.readSync()).thenReturn(preferences);
        bool ready = false;
        final Future<void> starting = app_main.prepareStartupSystemColors().then((_) => ready = true);
        await Future<void>.value();

        expect(ready, isFalse);
        expect(marks, isEmpty);

        reader.complete(_schemes);
        await starting;
        final bloc = ThemeBloc(LoadThemeUseCase(repository), UpdateThemeUseCase(repository), repository, source);
        addTearDown(bloc.close);
        final Brightness materialBrightness = preferences.mode == ThemeMode.dark ? Brightness.light : Brightness.dark;

        expect(ready, isTrue);
        expect(marks, hasLength(1));
        expect(
          prismThemeFor(bloc.state, materialBrightness).colorScheme.primary,
          materialBrightness == Brightness.light ? const Color(0xff3366cc) : const Color(0xff6699ff),
        );
      },
    );
  }

  test('does not block a fixed theme or report system colours ready before the read finishes', () async {
    when(
      () => repository.readSync(),
    ).thenReturn(const ThemePreferences(light: _light, dark: _dark, mode: ThemeMode.light));

    await app_main.prepareStartupSystemColors();

    expect(source.current, isNull);
    expect(marks, isEmpty);

    reader.complete(_schemes);
    await Future<void>.delayed(Duration.zero);

    expect(source.current?.light.primary, const Color(0xff3366cc));
    expect(marks, hasLength(1));
  });

  test('a later Material You switch renders colours from the nonblocking launch read and resume refresh', () async {
    when(
      () => repository.readSync(),
    ).thenReturn(const ThemePreferences(light: _light, dark: _dark, mode: ThemeMode.light));
    when(() => repository.update(lightThemeId: 'kLMaterial You')).thenAnswer(
      (_) async => Result.success(const ThemePreferences(light: _materialLight, dark: _dark, mode: ThemeMode.light)),
    );
    await app_main.prepareStartupSystemColors();
    final bloc = ThemeBloc(LoadThemeUseCase(repository), UpdateThemeUseCase(repository), repository, source);
    addTearDown(bloc.close);
    final Future<ThemeState> coloursReady = bloc.stream.firstWhere((state) => state.system != null);

    reader.complete(_schemes);
    await coloursReady;
    final Future<ThemeState> selected = bloc.stream.firstWhere((state) => state.light.themeId == 'kLMaterial You');
    bloc.add(const ThemeEvent.lightThemeChanged(themeId: 'kLMaterial You'));
    await selected;

    expect(prismThemeFor(bloc.state, Brightness.light).colorScheme.primary, const Color(0xff3366cc));

    const Color changedPrimary = Color(0xffdd8844);
    reader = Completer<SystemColorSchemes?>();
    final Future<ThemeState> resumedColours = bloc.stream.firstWhere(
      (state) => state.system?.light.primary == changedPrimary,
    );
    reader.complete(
      SystemColorSchemes(
        light: _schemes.light.copyWith(primary: changedPrimary),
        dark: _schemes.dark,
      ),
    );
    await source.refresh();
    await resumedColours;

    expect(prismThemeFor(bloc.state, Brightness.light).colorScheme.primary, changedPrimary);
  });
}
