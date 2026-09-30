import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
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
  ) : super(const WallpaperDetailInitial()) {
    on<LoadFromEntity>(_onLoadFromEntity);
    on<LoadFromId>(_onLoadFromId);
    on<FetchViews>(_onFetchViews);
    on<SelectAccentColor>(_onSelectAccentColor);
    on<CycleAccentColor>(_onCycleAccentColor);
    on<ResetAccentColor>(_onResetAccentColor);
    on<OnPanelOpened>(_onPanelOpened);
    on<OnPanelClosed>(_onPanelClosed);
    on<OnPanelScrollStart>(_onPanelScrollStart);
    on<OnPanelScrollEnd>(_onPanelScrollEnd);
  }

  final PrismWallpaperRepository _prismRepository;
  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;
  final RecordPrismWallpaperViewsUsecase _recordPrismWallpaperViewsUsecase;
  final PaletteRepository _paletteRepository;

  Future<void> _onLoadFromEntity(LoadFromEntity event, Emitter<WallpaperDetailState> emit) async {
    emit(WallpaperDetailLoaded(entity: event.entity));
    _fetchAndUpdateViews(event.entity);
    await Future.wait([_loadPalette(event.entity, emit), _enrichWallhavenFromFeedIfNeeded(event.entity, emit)]);
  }

  Future<void> _onLoadFromId(LoadFromId event, Emitter<WallpaperDetailState> emit) async {
    emit(WallpaperDetailLoading(thumbnailUrl: event.thumbnailUrl));

    final result = await _fetchWallpaper(wallId: event.wallId, source: event.source);
    final failure = result.failure;
    if (failure != null) {
      emit(WallpaperDetailError(message: failure.message));
      return;
    }

    final entity = result.data!;
    emit(WallpaperDetailLoaded(entity: entity));
    _fetchAndUpdateViews(entity);
    await _loadPalette(entity, emit);
  }

  Future<void> _onFetchViews(FetchViews event, Emitter<WallpaperDetailState> emit) async {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    if (currentState.entity.source != WallpaperSource.prism) {
      return;
    }

    emit(currentState.copyWith(viewsLoading: true));

    final result = await _recordPrismWallpaperViewsUsecase(currentState.entity.id);

    result.fold(
      onFailure: (failure) {
        final latestState = state;
        if (latestState is! WallpaperDetailLoaded) return;
        emit(latestState.copyWith(viewsLoading: false));
      },
      onSuccess: (views) {
        final latestState = state;
        if (latestState is! WallpaperDetailLoaded) return;
        emit(latestState.copyWith(views: views, viewsLoading: false));
      },
    );
  }

  void _onSelectAccentColor(SelectAccentColor event, Emitter<WallpaperDetailState> emit) {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    emit(currentState.copyWith(accent: event.color, colorChanged: true));
  }

  void _onCycleAccentColor(CycleAccentColor event, Emitter<WallpaperDetailState> emit) {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    final colors = currentState.colors;
    final accent = currentState.accent;

    if (colors == null || colors.isEmpty) return;
    if (accent == null || !colors.contains(accent)) return;

    final nextColor = colors[(colors.indexOf(accent) + 1) % colors.length];

    emit(currentState.copyWith(accent: nextColor, colorChanged: true));
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

  Future<void> _loadPalette(FeedItemEntity entity, Emitter<WallpaperDetailState> emit) async {
    final imageUrl = entity.thumbnailUrl;
    if (imageUrl.trim().isEmpty) return;

    final result = await _paletteRepository.generatePalette(imageUrl);
    final latest = state;
    if (latest is! WallpaperDetailLoaded || latest.entity.thumbnailUrl != imageUrl) return;

    result.fold(
      onFailure: (_) => emit(latest.copyWith(paletteLoading: false)),
      onSuccess: (palette) {
        final colors = _deduplicateColors(palette.paletteColorValues.map(Color.new).toList()).take(5).toList();
        emit(
          latest.copyWith(
            paletteLoading: false,
            colors: colors,
            accent: colors.isNotEmpty ? colors.first : latest.accent,
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

  Future<Result<FeedItemEntity>> _fetchWallpaper({required String wallId, required WallpaperSource source}) async {
    Result<FeedItemEntity> wrap<W>(Result<W?> result, FeedItemEntity Function(W wallpaper) toEntity) {
      return result.fold(
        onFailure: Result.error,
        onSuccess: (wallpaper) => wallpaper == null
            ? Result.error(const UnknownFailure('Wallpaper not found'))
            : Result.success(toEntity(wallpaper)),
      );
    }

    return switch (source) {
      WallpaperSource.prism => wrap(
        await _prismRepository.fetchById(wallId),
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
  }

  void _fetchAndUpdateViews(FeedItemEntity entity) {
    if (entity.source == WallpaperSource.prism) add(const FetchViews());
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
