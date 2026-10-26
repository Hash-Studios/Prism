@Tags(<String>['qa_render'])
library;

import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/favourite_test_scope.dart';
import '../support/in_memory_local_store.dart';
import 'qa_harness.dart';

class _MockDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState> implements WallpaperDetailBloc {}

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState> implements ThemeBloc {}

/// The wallpaper detail palette with a colour picked, which shows "Use as app accent".
void main() {
  setUpFavouriteCounts();
  setUpAll(() async {
    registerFallbackValue(WallpaperDetailRoute());
    registerFallbackValue(const ThemeEvent.started());
    await loadFonts();
    final String temp = Directory.systemTemp.createTempSync('prism_qa').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => temp,
    );
  });

  qaScreen('detail palette use as app accent', (QaShot shot) async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    if (getIt.isRegistered<SettingsLocalDataSource>()) getIt.unregister<SettingsLocalDataSource>();
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
    const FeedItemEntity entity = FeedItemEntity.prism(
      id: 'prism-1',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'prism-1',
          source: WallpaperSource.prism,
          fullUrl: 'https://img.test/full.jpg',
          thumbnailUrl: 'https://img.test/thumb.jpg',
          authorName: 'Akshay',
        ),
        tags: <String>['space'],
      ),
    );
    final _MockDetailBloc detail = _MockDetailBloc();
    whenListen(
      detail,
      const Stream<WallpaperDetailState>.empty(),
      initialState: const WallpaperDetailLoaded(
        recommendations: RecommendationState.exhausted(),
        entity: entity,
        paletteLoading: false,
        colors: <Color>[Color(0xFF2A9D8F), Color(0xFFE0A458), Color(0xFF8FA6C1), Color(0xFF1C1F26)],
        accent: Color(0xFF2A9D8F),
        colorChanged: true,
      ),
    );
    final _MockThemeBloc theme = _MockThemeBloc();
    when(() => theme.state).thenReturn(ThemeState.initial());
    await shot.pump(
      BlocProvider<ThemeBloc>.value(
        value: theme,
        child: BlocProvider<WallpaperDetailBloc>.value(
          value: detail,
          child: const WallpaperDetailScreen(entity: entity),
        ),
      ),
    );
    await shot.tester.ensureVisible(find.text('Use as app accent'));
    await shot.settle();
    await shot.save('detail_use_as_app_accent');
    await shot.tester.pump(const Duration(seconds: 10));
  });
}
