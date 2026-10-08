import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:flutter/material.dart';

abstract class ThemeRepository {
  /// Reads the stored selection without waiting, so the first frame already uses it.
  ThemePreferences readSync();

  Future<Result<ThemePreferences>> load();

  Future<Result<ThemePreferences>> update({
    String? lightThemeId,
    int? lightAccentColorValue,
    String? darkThemeId,
    int? darkAccentColorValue,
    ThemeMode? mode,
  });
}
