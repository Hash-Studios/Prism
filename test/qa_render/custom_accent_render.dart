@Tags(<String>['qa_render'])
library;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/shop/biz/bloc/shop_bloc.j.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/in_memory_local_store.dart';
import 'qa_harness.dart';

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState> implements ThemeBloc {}

/// The theme page with a stock accent and with a custom accent that is not one of the swatches.
void main() {
  setUpAll(() async {
    registerFallbackValue(WallpaperDetailRoute());
    registerFallbackValue(const ThemeEvent.started());
    await loadFonts();
  });

  for (final (String name, int accent) in <(String, int)>[('stock', 0xFFE57697), ('custom', 0xFF2A9D8F)]) {
    qaScreen('theme page $name accent', (QaShot shot) async {
      final bool light = shot.brightness == Brightness.light;
      final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
      if (getIt.isRegistered<SettingsLocalDataSource>()) getIt.unregister<SettingsLocalDataSource>();
      getIt.registerSingleton<SettingsLocalDataSource>(settings);
      if (!getIt.isRegistered<ShopBloc>()) getIt.registerFactory<ShopBloc>(() => ShopBloc(settings));
      final _MockThemeBloc bloc = _MockThemeBloc();
      final ThemeState state = ThemeState.initial().copyWith(
        mode: light ? ThemeMode.light : ThemeMode.dark,
        light: ThemeSelection(themeId: prismDefaultLightThemeId, accentColorValue: accent),
        dark: ThemeSelection(themeId: prismDefaultDarkThemeId, accentColorValue: accent),
      );
      when(() => bloc.state).thenReturn(state);
      await shot.pump(BlocProvider<ThemeBloc>.value(value: bloc, child: const ThemeView()));
      await shot.save('theme_page_$name');
      if (name != 'custom') return;
      await shot.tester.tap(find.bySemanticsLabel('Custom color').first);
      await shot.settle();
      await shot.save('custom_accent_sheet');
      await shot.tester.enterText(find.byType(TextField), light ? '#F2F2F2' : '#1A1A1A');
      await shot.settle();
      await shot.save('custom_accent_low_contrast');
    });
  }
}
