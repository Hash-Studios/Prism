import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/palette_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/wall_variant_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/wallpaper_recommendation_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrismRepository extends Mock implements PrismWallpaperRepository {}

class _MockWallhavenRepository extends Mock implements WallhavenWallpaperRepository {}

class _MockPexelsRepository extends Mock implements PexelsWallpaperRepository {}

class _MockRecordViews extends Mock implements RecordPrismWallpaperViewsUsecase {}

class _MockPaletteRepository extends Mock implements PaletteRepository {}

class _MockSetCount extends Mock implements GetWallpaperCountsUseCase {}

/// Records each load and answers with [group], or throws [error] when set.
class _FakeVariantRepository implements WallVariantRepository {
  VariantGroup? group;
  Object? error;
  final List<String> requested = <String>[];

  @override
  Future<VariantGroup?> load(PrismWallpaper wall) async {
    requested.add(wall.id);
    if (error != null) throw error!;
    return group;
  }
}

class _FakeRecommendations implements WallpaperRecommendationRepository {
  Future<RecommendationPage> Function(FeedItemEntity current)? loadPage;

  @override
  void release(String sessionKey) {}

  @override
  Future<RecommendationPage> load({
    required FeedItemEntity current,
    required String sessionKey,
    RecommendationCursor? cursor,
  }) =>
      loadPage?.call(current) ??
      Future<RecommendationPage>.value(RecommendationPage(items: const [], kind: RecommendationKind.discovery));
}

/// A member of the colour group `doc0`, one per index, all approved.
PrismWallpaper _variant(int index) => PrismWallpaper(
  core: WallpaperCore(
    id: 'v$index',
    source: WallpaperSource.prism,
    fullUrl: 'https://example.com/v$index.jpg',
    thumbnailUrl: 'https://example.com/v$index-thumb.jpg',
  ),
  title: 'Variant $index',
  review: true,
  firestoreDocumentId: 'doc$index',
  variantGroupId: 'doc0',
  variantIndex: index,
);

void main() {
  late _MockPrismRepository prism;
  late _MockPaletteRepository palette;
  late _MockRecordViews views;
  late _MockSetCount setCount;
  late _FakeVariantRepository variants;
  late _FakeRecommendations recommendations;
  late WallpaperDetailBloc bloc;
  late Directory catalogDirectory;

  final PrismWallpaper v0 = _variant(0);
  final PrismWallpaper v1 = _variant(1);
  final PrismWallpaper v2 = _variant(2);

  setUp(() async {
    catalogDirectory = await Directory.systemTemp.createTemp('wallpaper-detail-variants-');
    prism = _MockPrismRepository();
    when(() => prism.fetchCanonicalByDocumentId(any())).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
    when(() => prism.fetchCanonicalById(any())).thenAnswer((_) async => Result.success<PrismWallpaper?>(null));
    palette = _MockPaletteRepository();
    views = _MockRecordViews();
    setCount = _MockSetCount();
    when(() => setCount(any())).thenAnswer((_) async => Result.success<WallpaperCounts?>(null));
    when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const NetworkFailure('x')));
    when(() => views(any())).thenAnswer((_) async => Result.success('7'));
    variants = _FakeVariantRepository();
    recommendations = _FakeRecommendations();
    final OfflineWallpaperCatalog catalog = OfflineWallpaperCatalog(
      store: DurableJsonStore('catalog', directory: catalogDirectory),
    );
    bloc = WallpaperDetailBloc(
      prism,
      _MockWallhavenRepository(),
      _MockPexelsRepository(),
      views,
      palette,
      setCount,
      catalog,
      recommendations,
      variants,
    );
    addTearDown(bloc.close);
    addTearDown(() => catalogDirectory.delete(recursive: true));
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

  /// Waits for a loaded state that matches [done], checking the current state first.
  Future<WallpaperDetailLoaded> waitUntil(bool Function(WallpaperDetailLoaded state) done) async {
    final WallpaperDetailState current = bloc.state;
    if (current is WallpaperDetailLoaded && done(current)) return current;
    return await bloc.stream
            .firstWhere((state) => state is WallpaperDetailLoaded && done(state))
            .timeout(const Duration(seconds: 10))
        as WallpaperDetailLoaded;
  }

  /// Opens `v0` with the group `doc0` (v0, v1, v2) and waits until its lookups settle.
  Future<void> openV0() async {
    variants.group = VariantGroup(id: 'doc0', walls: [v0, v1, v2]);
    when(() => prism.fetchCanonicalById('v0')).thenAnswer((_) async => Result.success(v0));
    bloc.add(
      LoadFromEntity(
        entity: PrismFeedItem(id: 'v0', wallpaper: v0),
      ),
    );
    await waitUntil((s) => s.variants != null && !s.paletteLoading && !s.viewsLoading);
  }

  group('colour variants', () {
    test('loading a wall in a group exposes all its members with v0 selected', () async {
      await openV0();
      final WallpaperDetailLoaded state = bloc.state as WallpaperDetailLoaded;
      expect(state.variants?.length, 3);
      expect(state.variants?.walls.map((w) => w.id), ['v0', 'v1', 'v2']);
      expect(state.variantIndex, 0);
      expect(variants.requested, ['v0']);
    });

    test('a wall without a variant group never asks the repository and keeps variants null', () async {
      when(() => prism.fetchCanonicalById('solo')).thenAnswer(
        (_) async => Result.success(
          const PrismWallpaper(
            core: WallpaperCore(
              id: 'solo',
              source: WallpaperSource.prism,
              fullUrl: 'https://example.com/solo.jpg',
              thumbnailUrl: 'https://example.com/solo-thumb.jpg',
            ),
            firestoreDocumentId: 'solo-doc',
          ),
        ),
      );
      bloc.add(
        const LoadFromEntity(
          entity: PrismFeedItem(
            id: 'solo',
            wallpaper: PrismWallpaper(
              core: WallpaperCore(
                id: 'solo',
                source: WallpaperSource.prism,
                fullUrl: 'https://example.com/solo.jpg',
                thumbnailUrl: 'https://example.com/solo-thumb.jpg',
              ),
              firestoreDocumentId: 'solo-doc',
            ),
          ),
        ),
      );
      await waitUntil((s) => !s.paletteLoading && !s.viewsLoading);
      await settle();
      expect(variants.requested, isEmpty);
      expect((bloc.state as WallpaperDetailLoaded).variants, isNull);
    });

    test('a repository that returns null or throws leaves variants null and the wall shown', () async {
      when(() => prism.fetchCanonicalById('v0')).thenAnswer((_) async => Result.success(v0));
      bloc.add(
        LoadFromEntity(
          entity: PrismFeedItem(id: 'v0', wallpaper: v0),
        ),
      );
      variants.group = null;
      await waitUntil((s) => !s.paletteLoading && !s.viewsLoading);
      await settle();
      expect(variants.requested, ['v0']);
      expect(bloc.state, isA<WallpaperDetailLoaded>());
      expect((bloc.state as WallpaperDetailLoaded).variants, isNull);
      expect((bloc.state as WallpaperDetailLoaded).entity.id, 'v0');
    });

    test('a repository that throws leaves variants null and the wall shown', () async {
      variants.error = StateError('offline');
      when(() => prism.fetchCanonicalById('v0')).thenAnswer((_) async => Result.success(v0));
      bloc.add(
        LoadFromEntity(
          entity: PrismFeedItem(id: 'v0', wallpaper: v0),
        ),
      );
      await waitUntil((s) => !s.paletteLoading && !s.viewsLoading);
      await settle();
      expect(variants.requested, ['v0']);
      expect(bloc.state, isA<WallpaperDetailLoaded>());
      expect((bloc.state as WallpaperDetailLoaded).variants, isNull);
      expect((bloc.state as WallpaperDetailLoaded).entity.id, 'v0');
    });

    test('a pending recommendation page does not show another member of the selected variant set', () async {
      final Completer<RecommendationPage> page = Completer<RecommendationPage>();
      recommendations.loadPage = (_) => page.future;
      await openV0();

      bloc.add(const LoadRecommendations());
      await waitUntil((s) => s.recommendations.loading);
      bloc.add(const SelectVariant(index: 1));
      await waitUntil((s) => s.entity.id == 'v1');
      page.complete(
        RecommendationPage(
          items: [v1, _variant(3)].map((wall) => PrismFeedItem(id: wall.id, wallpaper: wall)).toList(),
          kind: RecommendationKind.related,
        ),
      );

      final WallpaperDetailLoaded result = await waitUntil((s) => s.recommendations.items.isNotEmpty);
      expect(result.recommendations.items.map((item) => item.id), ['v3']);
    });

    test('selecting another member swaps the wall and keeps the panel, the recommendations and the group', () async {
      await openV0();
      bloc.add(const OnPanelOpened());
      await settle();
      bloc.add(const SelectAccentColor(color: Color(0xff00ff00)));
      await settle();
      final WallpaperDetailLoaded before = bloc.state as WallpaperDetailLoaded;
      expect(before.colorChanged, isTrue);

      bloc.add(const SelectVariant(index: 1));
      final WallpaperDetailLoaded after = await waitUntil((s) => s.entity.id == 'v1' && !s.viewsLoading);

      expect(after.entity.id, 'v1');
      expect((after.entity as PrismFeedItem).wallpaper.firestoreDocumentId, 'doc1');
      expect(after.variantIndex, 1);
      expect(after.colorChanged, isFalse);
      expect(after.variants, same(before.variants));
      expect(after.panelCollapsed, isFalse);
      expect(after.panelClosed, isFalse);
      expect(after.recommendations, before.recommendations);
    });

    test('an out-of-range index or the index already shown emits nothing', () async {
      await openV0();
      final List<WallpaperDetailState> emitted = <WallpaperDetailState>[];
      final StreamSubscription<WallpaperDetailState> sub = bloc.stream.listen(emitted.add);
      final WallpaperDetailState before = bloc.state;

      bloc.add(const SelectVariant(index: 3));
      bloc.add(const SelectVariant(index: -1));
      bloc.add(const SelectVariant(index: 0));
      await settle();

      expect(emitted, isEmpty);
      expect(bloc.state, same(before));
      await sub.cancel();
    });

    test('each variant records its view once per visit and shows the first count when revisited', () async {
      when(() => views('v0')).thenAnswer((_) async => Result.success('10'));
      when(() => views('v1')).thenAnswer((_) async => Result.success('20'));
      await openV0();
      expect((bloc.state as WallpaperDetailLoaded).views, '10');

      bloc.add(const SelectVariant(index: 1));
      await waitUntil((s) => s.entity.id == 'v1' && s.views == '20' && !s.viewsLoading);

      bloc.add(const SelectVariant(index: 0));
      await waitUntil((s) => s.entity.id == 'v0' && s.views == '10' && !s.viewsLoading);

      bloc.add(const SelectVariant(index: 1));
      final WallpaperDetailLoaded back = await waitUntil((s) => s.entity.id == 'v1' && !s.viewsLoading);
      expect(back.views, '20');

      verify(() => views('v0')).called(1);
      verify(() => views('v1')).called(1);
    });

    test('a pending view failure for the previous variant does not clear the selected variant loading state', () async {
      final Completer<Result<String>> firstView = Completer<Result<String>>();
      final Completer<Result<String>> secondView = Completer<Result<String>>();
      when(() => views('v0')).thenAnswer((_) => firstView.future);
      when(() => views('v1')).thenAnswer((_) => secondView.future);
      variants.group = VariantGroup(id: 'doc0', walls: [v0, v1, v2]);
      when(() => prism.fetchCanonicalById('v0')).thenAnswer((_) async => Result.success(v0));
      bloc.add(
        LoadFromEntity(
          entity: PrismFeedItem(id: 'v0', wallpaper: v0),
        ),
      );
      await waitUntil((s) => s.variants != null && !s.paletteLoading && s.viewsLoading);

      bloc.add(const SelectVariant(index: 1));
      await waitUntil((s) => s.entity.id == 'v1' && s.viewsLoading);

      firstView.complete(Result.error(const NetworkFailure('offline')));
      await settle();

      expect((bloc.state as WallpaperDetailLoaded).viewsLoading, isTrue);
      secondView.complete(Result.success('20'));
      await waitUntil((s) => s.entity.id == 'v1' && !s.viewsLoading);
    });

    test('switching variants clears the old palette while the new palette is loading', () async {
      final Completer<Result<PaletteEntity>> secondPalette = Completer<Result<PaletteEntity>>();
      when(() => palette.generatePalette(v0.thumbnailUrl)).thenAnswer(
        (_) async => Result.success(
          const PaletteEntity(
            imageUrl: 'https://example.com/v0-thumb.jpg',
            dominantColorValue: 0xff0000ff,
            paletteColorValues: [0xff0000ff],
          ),
        ),
      );
      when(() => palette.generatePalette(v1.thumbnailUrl)).thenAnswer((_) => secondPalette.future);
      await openV0();
      expect((bloc.state as WallpaperDetailLoaded).colors, [const Color(0xff0000ff)]);

      bloc.add(const SelectVariant(index: 1));
      final WallpaperDetailLoaded loading = await waitUntil((s) => s.entity.id == 'v1' && s.paletteLoading);

      expect(loading.colors, isNull);
      expect(loading.accent, isNull);
      secondPalette.complete(
        Result.success(
          const PaletteEntity(
            imageUrl: 'https://example.com/v1-thumb.jpg',
            dominantColorValue: 0xffff0000,
            paletteColorValues: [0xffff0000],
          ),
        ),
      );
      final WallpaperDetailLoaded loaded = await waitUntil((s) => s.entity.id == 'v1' && !s.paletteLoading);
      expect(loaded.colors, [const Color(0xffff0000)]);
      expect(loaded.accent, const Color(0xffff0000));
    });

    test('a metadata refresh of the selected member updates it and its place in the group', () async {
      await openV0();
      when(
        () => prism.fetchCanonicalByDocumentId('doc1'),
      ).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
      bloc.add(const SelectVariant(index: 1));
      await waitUntil((s) => s.entity.id == 'v1' && !s.viewsLoading);

      const saved = WallMetadataSnapshot(
        metadata: PendingWallMetadata(
          text: WallTextMetadata(title: 'New title', description: 'New description', tags: ['new']),
        ),
        approved: true,
        revision: 'rev-2',
      );
      bloc.add(const RefreshWallMetadata(wallDocId: 'doc1', saved: saved));
      final WallpaperDetailLoaded state = await waitUntil(
        (s) => (s.entity as PrismFeedItem).wallpaper.title == 'New title',
      );

      expect((state.entity as PrismFeedItem).wallpaper.title, 'New title');
      expect(state.variants?.walls[1].title, 'New title');
      expect(state.variants?.walls[0].title, 'Variant 0');
      expect(state.variants?.walls[2].title, 'Variant 2');
    });
  });
}
