import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_dark/domain/entities/theme_dark.dart';
import 'package:Prism/features/theme_light/domain/entities/theme_light.dart';
import 'package:Prism/features/theme_light/domain/repositories/theme_repository.dart';
import 'package:Prism/features/theme_light/domain/usecases/theme_light_usecases.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_mode.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeThemeRepository implements ThemeRepository {
  ThemeLightEntity _light = const ThemeLightEntity(themeId: 'kLFrost White', accentColorValue: 0xff123456);

  @override
  Future<Result<ThemeLightEntity>> getLightTheme() async => Result.success(_light);

  @override
  Future<Result<ThemeLightEntity>> setLightTheme(String themeId) async {
    _light = ThemeLightEntity(themeId: themeId, accentColorValue: _light.accentColorValue);
    return Result.success(_light);
  }

  @override
  Future<Result<ThemeLightEntity>> setLightAccent(int colorValue) async {
    _light = ThemeLightEntity(themeId: _light.themeId, accentColorValue: colorValue);
    return Result.success(_light);
  }

  @override
  Future<Result<ThemeDarkEntity>> getDarkTheme() {
    throw UnimplementedError();
  }

  @override
  Future<Result<ThemeDarkEntity>> setDarkAccent(int colorValue) {
    throw UnimplementedError();
  }

  @override
  Future<Result<ThemeDarkEntity>> setDarkTheme(String themeId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<ThemeModeEntity>> getThemeMode() {
    throw UnimplementedError();
  }

  @override
  Future<Result<ThemeModeEntity>> setThemeMode(String mode) {
    throw UnimplementedError();
  }
}

void main() {
  group('Theme light usecases', () {
    late _FakeThemeRepository repository;
    late LoadThemeLightUseCase loadUseCase;
    late UpdateThemeLightUseCase updateThemeUseCase;
    late UpdateThemeLightAccentUseCase updateAccentUseCase;

    setUp(() {
      repository = _FakeThemeRepository();
      loadUseCase = LoadThemeLightUseCase(repository);
      updateThemeUseCase = UpdateThemeLightUseCase(repository);
      updateAccentUseCase = UpdateThemeLightAccentUseCase(repository);
    });

    test('load returns current theme', () async {
      final result = await loadUseCase(const NoParams());

      expect(result.isSuccess, isTrue);
      expect(result.data?.themeId, 'kLFrost White');
    });

    test('update theme + accent persists through repository', () async {
      await updateThemeUseCase(const UpdateThemeLightParams(themeId: 'kLCoffee'));
      await updateAccentUseCase(const UpdateThemeLightAccentParams(accentColorValue: 0xffabcdef));

      final result = await loadUseCase(const NoParams());

      expect(result.data?.themeId, 'kLCoffee');
      expect(result.data?.accentColorValue, 0xffabcdef);
    });
  });
}
