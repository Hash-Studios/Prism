import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/data/repositories/wall_variant_repository_impl.dart';
import 'package:Prism/features/wallpaper_detail/data/repositories/wallpaper_recommendation_repository_impl.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/variant_group.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/wall_variant_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/wallpaper_recommendation_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@injectable
class WallpaperDetailBloc extends Bloc<WallpaperDetailEvent, WallpaperDetailState> {
  WallpaperDetailBloc(
    this._prismRepository,
    this._wallhavenRepository,
    this._pexelsRepository,
    this._recordPrismWallpaperViewsUsecase,
    this._paletteRepository,
    this._getWallpaperCountsUseCase, [
    @ignoreParam OfflineWallpaperCatalog? offlineCatalog,
    @ignoreParam WallpaperRecommendationRepository? recommendations,
    @ignoreParam WallVariantRepository? variants,
  ]) : _offlineCatalog = offlineCatalog ?? OfflineWallpaperCatalog.instance,
       _recommendations = recommendations ?? WallpaperRecommendationRepositoryImpl.fromGetIt(),
       _variants = variants ?? WallVariantRepositoryImpl(),
       super(const WallpaperDetailInitial()) {
    on<LoadFromEntity>(_onLoadFromEntity);
    on<LoadFromId>(_onLoadFromId);
    on<FetchViews>(_onFetchViews);
    on<FetchSetCount>(_onFetchSetCount);
    on<SelectAccentColor>(_onSelectAccentColor);
    on<ResetAccentColor>(_onResetAccentColor);
    on<OnPanelOpened>(_onPanelOpened);
    on<OnPanelClosed>(_onPanelClosed);
    on<OnPanelScrollStart>(_onPanelScrollStart);
    on<OnPanelScrollEnd>(_onPanelScrollEnd);
    on<LoadRecommendations>(_onLoadRecommendations);
    on<RefreshWallMetadata>(_onRefreshWallMetadata);
    on<LoadVariants>(_onLoadVariants);
    on<SelectVariant>(_onSelectVariant);
  }

  final PrismWallpaperRepository _prismRepository;
  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;
  final RecordPrismWallpaperViewsUsecase _recordPrismWallpaperViewsUsecase;
  final PaletteRepository _paletteRepository;
  final GetWallpaperCountsUseCase _getWallpaperCountsUseCase;
  final OfflineWallpaperCatalog _offlineCatalog;
  final WallpaperRecommendationRepository _recommendations;
  final WallVariantRepository _variants;

  /// View counts already recorded in this visit, so a colour variant seen twice counts one view.
  final Map<String, String> _views = <String, String>{};
  static int _nextVisit = 0;
  final String _recommendationSession = '${_nextVisit++}';
  bool _closing = false;
  int _metadataRefreshGeneration = 0;

  Future<void> _onRefreshWallMetadata(RefreshWallMetadata event, Emitter<WallpaperDetailState> emit) async {
    final WallpaperDetailState initial = state;
    if (initial is! WallpaperDetailLoaded || initial.entity is! PrismFeedItem) return;
    final PrismWallpaper wall = (initial.entity as PrismFeedItem).wallpaper;
    if (wall.firestoreDocumentId != event.wallDocId) return;
    final generation = ++_metadataRefreshGeneration;
    final saved = event.saved;
    if (saved != null) {
      final PrismWallpaper updated = PrismWallpaper(
        core: wall.core,
        title: saved.metadata.text.title,
        description: saved.metadata.text.description,
        tags: saved.metadata.text.tags,
        collections: wall.collections,
        review: wall.review,
        colors: wall.colors,
        aiMetadata: wall.aiMetadata,
        isStreakExclusive: wall.isStreakExclusive,
        requiredStreakDays: wall.requiredStreakDays,
        streakShopCoinCost: wall.streakShopCoinCost,
        firestoreDocumentId: wall.firestoreDocumentId,
        boostedUntil: wall.boostedUntil,
        depthTier: wall.depthTier,
        spatial: wall.spatial,
        live: wall.live,
        desktop: wall.desktop,
        aiSource: wall.aiSource,
        remixOf: wall.remixOf,
        remixCount: wall.remixCount,
        variantGroupId: wall.variantGroupId,
        variantIndex: wall.variantIndex,
        editorsChoiceAt: wall.editorsChoiceAt,
        byStudio: wall.byStudio,
      );
      emit(
        initial.copyWith(
          entity: PrismFeedItem(id: updated.id, wallpaper: updated),
          variants: initial.variants?.replace(updated),
        ),
      );
    }
    final result = await _prismRepository.fetchCanonicalByDocumentId(event.wallDocId);
    if (emit.isDone || _closing || generation != _metadataRefreshGeneration) return;
    final WallpaperDetailState latest = state;
    if (latest is! WallpaperDetailLoaded ||
        latest.entity is! PrismFeedItem ||
        (latest.entity as PrismFeedItem).wallpaper.firestoreDocumentId != event.wallDocId) {
      return;
    }
    final PrismWallpaper? current = result.data;
    if (result.isSuccess && current != null) {
      emit(
        latest.copyWith(
          entity: PrismFeedItem(id: current.id, wallpaper: current),
          variants: latest.variants?.replace(current),
        ),
      );
    }
  }

  Future<void> _onLoadRecommendations(LoadRecommendations event, Emitter<WallpaperDetailState> emit) async {
    if (_closing) return;
    final initial = state;
    if (initial is! WallpaperDetailLoaded || initial.recommendations.loading || !initial.recommendations.hasMore) {
      return;
    }
    final entity = initial.entity;
    emit(initial.copyWith(recommendations: initial.recommendations.loadingPage()));
    try {
      // Filtered pages still advance. Bound this burst so a hidden catalog cannot monopolize a visit.
      for (var attempt = 0; attempt < 4; attempt++) {
        final before = state as WallpaperDetailLoaded;
        final page = await _recommendations.load(
          current: entity,
          sessionKey: _recommendationSession,
          cursor: before.recommendations.cursor,
        );
        final latest = state;
        if (emit.isDone || latest is! WallpaperDetailLoaded || !_sameVisit(latest, entity)) {
          return;
        }
        final Iterable<FeedItemEntity> variantItems =
            latest.variants?.walls.map((wall) => PrismFeedItem(id: wall.id, wallpaper: wall)) ??
            const <FeedItemEntity>[];
        final RecommendationPage visiblePage = RecommendationPage(
          items: page.items
              .where((item) => !variantItems.any((variant) => variant.source == item.source && variant.id == item.id))
              .toList(),
          kind: page.kind,
          nextCursor: page.nextCursor,
        );
        final next = latest.recommendations.append(visiblePage, entity);
        final addedItems = next.items.length > before.recommendations.items.length;
        if (addedItems || !next.hasMore || attempt == 3) {
          emit(latest.copyWith(recommendations: next));
          return;
        }
        emit(latest.copyWith(recommendations: next.loadingPage()));
      }
    } catch (_) {
      final latest = state;
      if (emit.isDone || latest is! WallpaperDetailLoaded || !_sameVisit(latest, entity)) {
        return;
      }
      emit(latest.copyWith(recommendations: latest.recommendations.failure()));
    }
  }

  static const String notFoundMessage = 'Wallpaper not found';
  static const Duration _cachedLookupDecisionBudget = Duration(seconds: 2);
  static const Duration _wallpaperLookupTimeout = Duration(seconds: 30);

  @override
  Future<void> close() async {
    _closing = true;
    _recommendations.release(_recommendationSession);
    await super.close();
  }

  Future<void> _onLoadFromEntity(LoadFromEntity event, Emitter<WallpaperDetailState> emit) async {
    if (event.entity.source == WallpaperSource.prism &&
        !BundledWallpapers.isStarter(event.entity) &&
        !OriginalAccessService.isUnlockedDropUrl(event.entity.fullUrl, event.entity.id, event.entity.source)) {
      await _onLoadFromId(
        LoadFromId(
          wallId: event.entity.id,
          source: event.entity.source,
          thumbnailUrl: event.entity.thumbnailUrl,
          localFilePath: event.localFilePath,
        ),
        emit,
        allowDocumentIdFallback: switch (event.entity) {
          PrismFeedItem(:final wallpaper) => wallpaper.firestoreDocumentId == event.entity.id,
          _ => false,
        },
      );
      return;
    }
    emit(WallpaperDetailLoaded(entity: event.entity));
    _fetchAndUpdateViews(event.entity);
    await Future.wait([
      _loadPalette(event.entity, emit, event.localFilePath),
      _enrichWallhavenFromFeedIfNeeded(event.entity, emit),
    ]);
  }

  Future<void> _onLoadFromId(
    LoadFromId event,
    Emitter<WallpaperDetailState> emit, {
    bool allowDocumentIdFallback = true,
  }) async {
    emit(WallpaperDetailLoading(thumbnailUrl: event.thumbnailUrl));

    final result = await _fetchWallpaper(
      wallId: event.wallId,
      source: event.source,
      allowDocumentIdFallback: allowDocumentIdFallback,
    );
    if (_closing) return;
    final failure = result.failure;
    if (failure != null) {
      emit(WallpaperDetailError(failure: _loadErrorKind(failure), thumbnailUrl: event.thumbnailUrl));
      return;
    }

    final entity = result.data!;
    emit(WallpaperDetailLoaded(entity: entity));
    _fetchAndUpdateViews(entity);
    await _loadPalette(entity, emit, event.localFilePath);
  }

  /// Keep the server failure separate from its presentation so the view can localize it.
  WallpaperDetailLoadFailure _loadErrorKind(Failure failure) =>
      failure is UnknownFailure && failure.message == notFoundMessage
      ? WallpaperDetailLoadFailure.notFound
      : WallpaperDetailLoadFailure.unavailable;

  Future<void> _onFetchViews(FetchViews event, Emitter<WallpaperDetailState> emit) async {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    if (currentState.entity.source != WallpaperSource.prism || BundledWallpapers.isStarter(currentState.entity)) {
      return;
    }

    final String wallId = currentState.entity.id;
    final String? seen = _views[wallId];
    if (seen != null) {
      emit(currentState.copyWith(views: seen, viewsLoading: false));
      return;
    }
    emit(currentState.copyWith(viewsLoading: true));

    final result = await _recordPrismWallpaperViewsUsecase(wallId);

    result.fold(
      onFailure: (failure) {
        final latestState = state;
        if (latestState is! WallpaperDetailLoaded || latestState.entity.id != wallId) return;
        emit(latestState.copyWith(viewsLoading: false));
      },
      onSuccess: (views) {
        _views[wallId] = views;
        final latestState = state;
        if (latestState is! WallpaperDetailLoaded || latestState.entity.id != wallId) return;
        emit(latestState.copyWith(views: views, viewsLoading: false));
      },
    );
  }

  Future<void> _onFetchSetCount(FetchSetCount event, Emitter<WallpaperDetailState> emit) async {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded ||
        currentState.entity.source != WallpaperSource.prism ||
        BundledWallpapers.isStarter(currentState.entity)) {
      return;
    }

    final result = await _getWallpaperCountsUseCase(currentState.entity.id);
    final latestState = state;
    if (emit.isDone || latestState is! WallpaperDetailLoaded || latestState.entity.id != currentState.entity.id) return;
    final WallpaperCounts? counts = result.data;
    if (result.isSuccess && counts != null) {
      emit(latestState.copyWith(setCount: counts.sets, tipperCount: counts.tippers));
    }
  }

  void _onSelectAccentColor(SelectAccentColor event, Emitter<WallpaperDetailState> emit) {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    emit(currentState.copyWith(accent: event.color, colorChanged: true));
  }

  void _onResetAccentColor(ResetAccentColor event, Emitter<WallpaperDetailState> emit) {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    emit(currentState.copyWith(colorChanged: false));
  }

  void _onPanelOpened(OnPanelOpened event, Emitter<WallpaperDetailState> emit) {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    emit(currentState.copyWith(panelCollapsed: false, panelClosed: false));
  }

  void _onPanelClosed(OnPanelClosed event, Emitter<WallpaperDetailState> emit) {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    emit(currentState.copyWith(panelCollapsed: true, panelClosed: true));
  }

  void _onPanelScrollStart(OnPanelScrollStart event, Emitter<WallpaperDetailState> emit) {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    emit(currentState.copyWith(panelScrollInProgress: true));
  }

  void _onPanelScrollEnd(OnPanelScrollEnd event, Emitter<WallpaperDetailState> emit) {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    emit(currentState.copyWith(panelScrollInProgress: false));
  }

  Future<void> _loadPalette(FeedItemEntity entity, Emitter<WallpaperDetailState> emit, String? localFilePath) async {
    final imageUrl = localFilePath?.trim().isNotEmpty == true ? localFilePath! : entity.thumbnailUrl;
    final latest = state;
    if (latest is! WallpaperDetailLoaded || latest.entity.id != entity.id || latest.entity.source != entity.source) {
      return;
    }
    if (imageUrl.trim().isEmpty) {
      emit(latest.copyWith(paletteLoading: false));
      return;
    }

    final result = await _paletteRepository.generatePalette(imageUrl);
    if (emit.isDone) return;
    final current = state;
    if (current is! WallpaperDetailLoaded || current.entity.id != entity.id || current.entity.source != entity.source) {
      return;
    }

    result.fold(
      onFailure: (_) => emit(current.copyWith(paletteLoading: false)),
      onSuccess: (palette) {
        final colors = _deduplicateColors(palette.paletteColorValues.map(Color.new).toList()).take(5).toList();
        emit(
          current.copyWith(
            paletteLoading: false,
            colors: colors,
            accent: colors.isNotEmpty ? colors.first : current.accent,
          ),
        );
      },
    );
  }

  /// Removes perceptually similar colors, keeping the first occurrence.
  /// Uses HSL space: achromatic colors are compared by lightness only;
  /// chromatic colors are compared by hue distance and lightness.
  List<Color> _deduplicateColors(List<Color> colors) {
    final unique = <Color>[];
    for (final color in colors) {
      final hsl = HSLColor.fromColor(color);
      final isDuplicate = unique.any((existing) {
        final e = HSLColor.fromColor(existing);
        if (hsl.saturation < 0.1 && e.saturation < 0.1) {
          return (hsl.lightness - e.lightness).abs() < 0.15;
        }
        final hueDiff = (hsl.hue - e.hue).abs();
        final hueDistance = hueDiff > 180 ? 360 - hueDiff : hueDiff;
        return hueDistance < 30 && (hsl.lightness - e.lightness).abs() < 0.2;
      });
      if (!isDuplicate) unique.add(color);
    }
    return unique;
  }

  Future<Result<FeedItemEntity>> _fetchWallpaper({
    required String wallId,
    required WallpaperSource source,
    bool allowDocumentIdFallback = false,
  }) async {
    if (BundledWallpapers.isStarterIdentity(wallId, source)) {
      try {
        final starters = await BundledWallpapers.load();
        return Result.success(starters.firstWhere((item) => item.id == wallId));
      } catch (error) {
        return Result.error(UnknownFailure('$error'));
      }
    }
    Result<FeedItemEntity> wrap<W>(Result<W?> result, FeedItemEntity Function(W wallpaper) toEntity) {
      return result.fold(
        onFailure: Result.error,
        onSuccess: (wallpaper) => wallpaper == null
            ? Result.error(const UnknownFailure(notFoundMessage))
            : Result.success(toEntity(wallpaper)),
      );
    }

    Future<Result<PrismWallpaper?>> fetchPrism() async {
      final canonical = await _prismRepository.fetchCanonicalById(wallId);
      if (canonical.isFailure || canonical.data != null || !allowDocumentIdFallback) return canonical;
      return _prismRepository.fetchCanonicalByDocumentId(wallId);
    }

    Future<Result<FeedItemEntity>> fetchRemote() async => switch (source) {
      WallpaperSource.prism => wrap(
        await fetchPrism(),
        (wallpaper) => PrismFeedItem(id: wallpaper.id, wallpaper: wallpaper),
      ),
      WallpaperSource.wallhaven => wrap(
        await _wallhavenRepository.fetchById(wallId),
        (wallpaper) => WallhavenFeedItem(id: wallpaper.id, wallpaper: wallpaper),
      ),
      WallpaperSource.pexels => wrap(
        await _pexelsRepository.fetchById(wallId),
        (wallpaper) => PexelsFeedItem(id: wallpaper.id, wallpaper: wallpaper),
      ),
      _ => Result.error(ValidationFailure('Unsupported source: $source')),
    };

    if (source == WallpaperSource.prism && !BundledWallpapers.isStarterIdentity(wallId, source)) {
      try {
        return await fetchRemote().timeout(_wallpaperLookupTimeout);
      } catch (error) {
        return Result.error(NetworkFailure('$error'));
      }
    }

    FeedItemEntity? cached;
    try {
      cached = await _offlineCatalog.find(source, wallId);
    } catch (_) {}
    final Future<Result<FeedItemEntity>> request = fetchRemote();
    final Result<FeedItemEntity> remote;
    try {
      remote = await request.timeout(
        cached == null ? _wallpaperLookupTimeout : _cachedLookupDecisionBudget,
        onTimeout: () =>
            cached == null ? Result.error(const NetworkFailure('Wallpaper lookup timed out')) : Result.success(cached),
      );
    } catch (error) {
      return cached == null ? Result.error(NetworkFailure('$error')) : Result.success(cached);
    }
    if (remote.isSuccess || remote.failure is! NetworkFailure) return remote;
    if (cached != null) return Result.success(cached);
    return remote;
  }

  void _fetchAndUpdateViews(FeedItemEntity entity) {
    if (_closing ||
        entity.source != WallpaperSource.prism ||
        BundledWallpapers.isStarterIdentity(entity.id, entity.source)) {
      return;
    }
    add(const FetchViews());
    add(const FetchSetCount());
    if (entity case PrismFeedItem(:final wallpaper) when wallpaper.variantGroupId != null) add(const LoadVariants());
  }

  /// The wall this visit opened, or one of its colour variants.
  bool _sameVisit(WallpaperDetailLoaded latest, FeedItemEntity entity) =>
      latest.entity.source == entity.source &&
      (latest.entity.id == entity.id || (latest.variants?.containsId(entity.id) ?? false));

  Future<void> _onLoadVariants(LoadVariants event, Emitter<WallpaperDetailState> emit) async {
    final WallpaperDetailState initial = state;
    if (initial is! WallpaperDetailLoaded || initial.variants != null) return;
    final FeedItemEntity entity = initial.entity;
    if (entity is! PrismFeedItem) return;
    final VariantGroup? group;
    try {
      group = await _variants.load(entity.wallpaper);
    } catch (error, stackTrace) {
      logger.w('Colour variants did not load', error: error, stackTrace: stackTrace);
      return;
    }
    final WallpaperDetailState latest = state;
    if (emit.isDone || _closing || group == null || latest is! WallpaperDetailLoaded || latest.entity.id != entity.id) {
      return;
    }
    final Iterable<FeedItemEntity> members = group.walls.map((wall) => PrismFeedItem(id: wall.id, wallpaper: wall));
    emit(latest.copyWith(variants: group, recommendations: latest.recommendations.excluding(members)));
  }

  /// Puts the colour variant at [SelectVariant.index] on screen as the wall itself: its image, palette, stats and
  /// actions. The panel, the recommendations and the set stay.
  Future<void> _onSelectVariant(SelectVariant event, Emitter<WallpaperDetailState> emit) async {
    final WallpaperDetailState current = state;
    if (current is! WallpaperDetailLoaded) return;
    final VariantGroup? group = current.variants;
    if (group == null || event.index < 0 || event.index >= group.length || event.index == current.variantIndex) return;
    final PrismWallpaper wall = group.walls[event.index];
    final FeedItemEntity entity = PrismFeedItem(id: wall.id, wallpaper: wall);
    emit(
      WallpaperDetailLoaded(
        entity: entity,
        views: _views[wall.id],
        panelClosed: current.panelClosed,
        panelCollapsed: current.panelCollapsed,
        panelScrollInProgress: current.panelScrollInProgress,
        recommendations: current.recommendations.excluding(
          group.walls.map((member) => PrismFeedItem(id: member.id, wallpaper: member)),
        ),
        variants: group,
      ),
    );
    _fetchAndUpdateViews(entity);
    await _loadPalette(entity, emit, null);
  }

  /// Search/list responses often omit `uploader`; single-wall API includes it.
  Future<void> _enrichWallhavenFromFeedIfNeeded(FeedItemEntity entity, Emitter<WallpaperDetailState> emit) async {
    if (entity is! WallhavenFeedItem) {
      return;
    }
    final String? author = entity.wallpaper.core.authorName;
    if (author != null && author.isNotEmpty) {
      return;
    }
    final String wallId = entity.wallpaper.id;
    final result = await _wallhavenRepository.fetchById(wallId);
    result.fold(
      onFailure: (_) {},
      onSuccess: (WallhavenWallpaper? wallpaper) {
        if (wallpaper == null) {
          return;
        }
        final String? enrichedAuthor = wallpaper.core.authorName;
        if (enrichedAuthor == null || enrichedAuthor.isEmpty) {
          return;
        }
        final WallpaperDetailState latest = state;
        if (latest is! WallpaperDetailLoaded) {
          return;
        }
        if (latest.entity.id != wallId || latest.entity.source != WallpaperSource.wallhaven) {
          return;
        }
        emit(
          latest.copyWith(
            entity: WallhavenFeedItem(id: wallpaper.id, wallpaper: wallpaper),
          ),
        );
      },
    );
  }
}
