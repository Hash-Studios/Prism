import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';

class _MockPrismRepository extends Mock implements PrismWallpaperRepository {}

class _MockWallhavenRepository extends Mock implements WallhavenWallpaperRepository {}

class _MockPexelsRepository extends Mock implements PexelsWallpaperRepository {}

class _MockRecordViews extends Mock implements RecordPrismWallpaperViewsUsecase {}

class _MockPalette extends Mock implements PaletteRepository {}

class _MockSetCount extends Mock implements GetWallpaperCountsUseCase {}

void main() {
  late _MockPrismRepository prism;
  late _MockPalette palette;
  late _MockRecordViews views;
  late _MockSetCount setCount;
  late FakeAppAnalytics analytics;
  late WallpaperDetailBloc bloc;
  late Directory catalogDirectory;

  setUp(() async {
    catalogDirectory = await Directory.systemTemp.createTemp('wall-open-failed-');
    prism = _MockPrismRepository();
    when(() => prism.fetchCanonicalById(any())).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
    when(() => prism.fetchCanonicalByDocumentId(any())).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
    palette = _MockPalette();
    when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const NetworkFailure('none')));
    views = _MockRecordViews();
    when(() => views(any())).thenAnswer((_) async => Result.success('7'));
    setCount = _MockSetCount();
    when(() => setCount(any())).thenAnswer((_) async => Result.success<WallpaperCounts?>(null));
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    addTearDown(AnalyticsRuntime.reset);
    bloc = WallpaperDetailBloc(
      prism,
      _MockWallhavenRepository(),
      _MockPexelsRepository(),
      views,
      palette,
      setCount,
      OfflineWallpaperCatalog(store: DurableJsonStore('catalog', directory: catalogDirectory)),
    );
    addTearDown(bloc.close);
    addTearDown(() => catalogDirectory.delete(recursive: true));
  });

  Future<WallpaperDetailState> load(WallpaperDetailEvent event) {
    bloc.add(event);
    return bloc.stream
        .firstWhere((state) => state is WallpaperDetailError || state is WallpaperDetailLoaded)
        .timeout(const Duration(seconds: 5));
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

  List<WallOpenFailedEvent> openFailures() => analytics.events.whereType<WallOpenFailedEvent>().toList();

  test('a Home wall the lookups cannot find sends one open failure with its entry, chip and document id', () async {
    const String documentId = 'document-42';
    const PrismWallpaper wall = PrismWallpaper(
      core: WallpaperCore(
        id: documentId,
        source: WallpaperSource.prism,
        fullUrl: 'https://example.test/full.jpg',
        thumbnailUrl: 'https://example.test/thumb.jpg',
      ),
      firestoreDocumentId: documentId,
    );

    final WallpaperDetailState state = await load(
      const LoadFromEntity(
        entity: PrismFeedItem(id: documentId, wallpaper: wall),
        origin: (entry: WallOpenEntryValue.home, homeTab: HomeFeedChip.latest),
      ),
    );
    await settle();

    expect(state, isA<WallpaperDetailError>());
    final List<WallOpenFailedEvent> failures = openFailures();
    expect(failures, hasLength(1));
    final WallOpenFailedEvent failure = failures.single;
    expect(failure.entry, WallOpenEntryValue.home);
    expect(failure.homeTab, HomeFeedChip.latest);
    expect(failure.idKind, WallIdKindValue.documentId);
    expect(failure.error, WallOpenErrorValue.notFound);
    expect(failure.fallbackRan, isTrue);
    expect(failure.wallId, documentId);
    expect(failure.source, 'prism');
  });

  test('a link wall with an ambiguous id sends one open failure without the document fallback', () async {
    const String wallId = 'wall-9';
    when(
      () => prism.fetchCanonicalById(any()),
    ).thenAnswer((_) async => Result.error(const ServerFailure(ambiguousWallpaperIdentity)));

    final WallpaperDetailState state = await load(
      const LoadFromId(
        wallId: wallId,
        source: WallpaperSource.prism,
        origin: (entry: WallOpenEntryValue.link, homeTab: null),
      ),
    );
    await settle();

    expect(state, isA<WallpaperDetailError>());
    final List<WallOpenFailedEvent> failures = openFailures();
    expect(failures, hasLength(1));
    final WallOpenFailedEvent failure = failures.single;
    expect(failure.entry, WallOpenEntryValue.link);
    expect(failure.homeTab, isNull);
    expect(failure.idKind, WallIdKindValue.id);
    expect(failure.error, WallOpenErrorValue.ambiguous);
    expect(failure.fallbackRan, isFalse);
    expect(failure.wallId, wallId);
    verifyNever(() => prism.fetchCanonicalByDocumentId(any()));
  });

  test('a wall that loads sends no open failure', () async {
    const String wallId = 'wall-ok';
    const PrismWallpaper wall = PrismWallpaper(
      core: WallpaperCore(
        id: wallId,
        source: WallpaperSource.prism,
        fullUrl: 'https://example.test/ok.jpg',
        thumbnailUrl: 'https://example.test/ok-thumb.jpg',
      ),
    );
    when(() => prism.fetchCanonicalById(wallId)).thenAnswer((_) async => Result.success<PrismWallpaper?>(wall));

    final WallpaperDetailState state = await load(
      const LoadFromId(
        wallId: wallId,
        source: WallpaperSource.prism,
        origin: (entry: WallOpenEntryValue.search, homeTab: null),
      ),
    );
    await settle();

    expect(state, isA<WallpaperDetailLoaded>());
    expect(openFailures(), isEmpty);
  });
}
