import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';

class _MockPrismRepository extends Mock implements PrismWallpaperRepository {}

class _MockWallhavenRepository extends Mock implements WallhavenWallpaperRepository {}

class _MockPexelsRepository extends Mock implements PexelsWallpaperRepository {}

class _MockRecordViews extends Mock implements RecordPrismWallpaperViewsUsecase {}

class _MockPalette extends Mock implements PaletteRepository {}

class _MockSetCount extends Mock implements GetWallpaperCountsUseCase {}

void main() {
  setUpFavouriteCounts();
  late FakeAppAnalytics analytics;
  late Directory catalogDirectory;

  setUp(() async {
    catalogDirectory = await Directory.systemTemp.createTemp('wall-open-failure-screen-');
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
    await catalogDirectory.delete(recursive: true);
  });

  testWidgets('a wall the Prism lookup cannot find sends one open failure from search', (tester) async {
    final _MockPrismRepository prism = _MockPrismRepository();
    when(() => prism.fetchCanonicalById(any())).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
    when(() => prism.fetchCanonicalByDocumentId(any())).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
    final _MockPalette palette = _MockPalette();
    when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const NetworkFailure('none')));
    final _MockRecordViews views = _MockRecordViews();
    when(() => views(any())).thenAnswer((_) async => Result.success('0'));
    final _MockSetCount setCount = _MockSetCount();
    when(() => setCount(any())).thenAnswer((_) async => Result.success<WallpaperCounts?>(null));
    final WallpaperDetailBloc bloc = WallpaperDetailBloc(
      prism,
      _MockWallhavenRepository(),
      _MockPexelsRepository(),
      views,
      palette,
      setCount,
      OfflineWallpaperCatalog(store: DurableJsonStore('catalog', directory: catalogDirectory)),
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: const WallpaperDetailScreen(
            wallId: 'wall-1',
            source: WallpaperSource.prism,
            entry: WallOpenEntryValue.search,
          ),
        ),
      ),
    );

    for (int frame = 0; frame < 20; frame++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    final List<WallOpenFailedEvent> failures = analytics.events.whereType<WallOpenFailedEvent>().toList();
    expect(failures, hasLength(1));
    expect(failures.single.entry, WallOpenEntryValue.search);
    expect(failures.single.error, WallOpenErrorValue.notFound);

    for (int frame = 0; frame < 5; frame++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(analytics.events.whereType<WallOpenFailedEvent>(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
}
