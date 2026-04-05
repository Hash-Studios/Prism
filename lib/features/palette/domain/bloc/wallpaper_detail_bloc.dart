import 'dart:io';

import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/palette/domain/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/palette/domain/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/palette/palette.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
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
    this._paletteBloc,
  ) : super(const WallpaperDetailInitial()) {
    on<LoadFromEntity>(_onLoadFromEntity);
    on<LoadFromId>(_onLoadFromId);
    on<FetchViews>(_onFetchViews);
    on<SelectAccentColor>(_onSelectAccentColor);
    on<CycleAccentColor>(_onCycleAccentColor);
    on<ResetAccentColor>(_onResetAccentColor);
    on<CaptureScreenshot>(_onCaptureScreenshot);
    on<OnPanelOpened>(_onPanelOpened);
    on<OnPanelClosed>(_onPanelClosed);
    on<OnPanelScrollStart>(_onPanelScrollStart);
    on<OnPanelScrollEnd>(_onPanelScrollEnd);
    on<UpdateColorsFromPalette>(_onUpdateColorsFromPalette);
  }

  final PrismWallpaperRepository _prismRepository;
  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;
  final RecordPrismWallpaperViewsUsecase _recordPrismWallpaperViewsUsecase;
  final PaletteBloc _paletteBloc;

  Future<void> _onLoadFromEntity(LoadFromEntity event, Emitter<WallpaperDetailState> emit) async {
    emit(WallpaperDetailLoaded(entity: event.entity));
    _requestPalette(event.entity.thumbnailUrl);
    _fetchAndUpdateViews(event.entity);
    await _enrichWallhavenFromFeedIfNeeded(event.entity, emit);
  }

  Future<void> _onLoadFromId(LoadFromId event, Emitter<WallpaperDetailState> emit) async {
    emit(WallpaperDetailLoading(thumbnailUrl: event.thumbnailUrl));

    try {
      final result = await _fetchWallpaper(wallId: event.wallId, source: event.source);

      emit(WallpaperDetailLoaded(entity: result));
      _requestPalette(result.thumbnailUrl);
      _fetchAndUpdateViews(result);
    } catch (e) {
      emit(WallpaperDetailError(message: e.toString()));
    }
  }

  Future<void> _onFetchViews(FetchViews event, Emitter<WallpaperDetailState> emit) async {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    if (currentState.entity.source != WallpaperSource.prism) {
      return;
    }

    emit(currentState.copyWith(viewsLoading: true));

    final entity = currentState.entity;
    final result = await _recordPrismWallpaperViewsUsecase(entity.id.toUpperCase());

    result.fold(
      onFailure: (failure) {
        final latestState = state;
        if (latestState is! WallpaperDetailLoaded) return;
        emit(latestState.copyWith(viewsLoading: false, viewsError: failure.message));
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
    if (!colors.contains(accent)) return;

    final currentIndex = colors.indexOf(accent);
    final nextColor = colors[(currentIndex + 1) % colors.length];

    emit(currentState.copyWith(accent: nextColor, colorChanged: true));
  }

  void _onResetAccentColor(ResetAccentColor event, Emitter<WallpaperDetailState> emit) {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    emit(currentState.copyWith(colorChanged: false));
  }

  void _onCaptureScreenshot(CaptureScreenshot event, Emitter<WallpaperDetailState> emit) {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    final imageFile = File.fromRawPath(event.imageBytes);
    emit(currentState.copyWith(screenshotTaken: true, imageFile: imageFile));
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

  void _onUpdateColorsFromPalette(UpdateColorsFromPalette event, Emitter<WallpaperDetailState> emit) {
    final currentState = state;
    if (currentState is! WallpaperDetailLoaded) return;

    final deduped = _deduplicateColors(event.colors.whereType<Color>().toList());
    final limitedColors = deduped.length > 5 ? deduped.sublist(0, 5) : deduped;
    final newAccent = limitedColors.isNotEmpty ? limitedColors[0] : currentState.accent;

    emit(currentState.copyWith(colors: limitedColors, accent: newAccent));
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

  Future<WallpaperDetailEntity> _fetchWallpaper({required String wallId, required WallpaperSource source}) async {
    switch (source) {
      case WallpaperSource.prism:
        final result = await _prismRepository.fetchById(wallId);
        return result.fold(
          onFailure: (failure) => throw Exception(failure.message),
          onSuccess: (wallpaper) {
            if (wallpaper == null) throw Exception('Wallpaper not found');
            return PrismDetailEntity(wallpaper: wallpaper) as WallpaperDetailEntity;
          },
        );

      case WallpaperSource.wallhaven:
        final result = await _wallhavenRepository.fetchById(wallId);
        return result.fold(
          onFailure: (failure) => throw Exception(failure.message),
          onSuccess: (wallpaper) {
            if (wallpaper == null) throw Exception('Wallpaper not found');
            return WallhavenDetailEntity(wallpaper: wallpaper);
          },
        );

      case WallpaperSource.pexels:
        final result = await _pexelsRepository.fetchById(wallId);
        return result.fold(
          onFailure: (failure) => throw Exception(failure.message),
          onSuccess: (wallpaper) {
            if (wallpaper == null) throw Exception('Wallpaper not found');
            return PexelsDetailEntity(wallpaper: wallpaper);
          },
        );

      default:
        throw Exception('Unsupported source: $source');
    }
  }

  void _requestPalette(String imageUrl) {
    if (imageUrl.trim().isEmpty) return;
    _paletteBloc.add(PaletteEvent.paletteCleared());
    _paletteBloc.add(PaletteEvent.paletteRequested(imageUrl: imageUrl));
  }

  Future<void> _fetchAndUpdateViews(WallpaperDetailEntity entity) async {
    if (entity.source != WallpaperSource.prism) {
      return;
    }
    add(const FetchViews());
  }

  /// Search/list responses often omit `uploader`; single-wall API includes it.
  Future<void> _enrichWallhavenFromFeedIfNeeded(
    WallpaperDetailEntity entity,
    Emitter<WallpaperDetailState> emit,
  ) async {
    if (entity is! WallhavenDetailEntity) {
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
        emit(latest.copyWith(entity: WallhavenDetailEntity(wallpaper: wallpaper)));
      },
    );
  }
}
