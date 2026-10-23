import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

sealed class WallpaperDetailState extends Equatable {
  const WallpaperDetailState();

  @override
  List<Object?> get props => [];
}

enum WallpaperDetailLoadFailure { notFound, unavailable }

final class WallpaperDetailInitial extends WallpaperDetailState {
  const WallpaperDetailInitial();
}

final class WallpaperDetailLoading extends WallpaperDetailState {
  const WallpaperDetailLoading({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  List<Object?> get props => [thumbnailUrl];
}

final class WallpaperDetailLoaded extends WallpaperDetailState {
  const WallpaperDetailLoaded({
    required this.entity,
    this.views,
    this.setCount,
    this.viewsLoading = false,
    this.paletteLoading = true,
    this.colors,
    this.accent,
    this.colorChanged = false,
    this.panelClosed = true,
    this.panelCollapsed = true,
    this.panelScrollInProgress = false,
    this.recommendations = const RecommendationState.initial(),
  });

  final FeedItemEntity entity;
  final String? views;

  /// Times the wall was set, from `wallpaper_stats`. Null until known.
  final int? setCount;
  final bool viewsLoading;
  final bool paletteLoading;
  final List<Color>? colors;
  final Color? accent;
  final bool colorChanged;
  final bool panelClosed;
  final bool panelCollapsed;
  final bool panelScrollInProgress;
  final RecommendationState recommendations;

  /// The colour variation applied to the wallpaper, or null while the original shows.
  Color? get tint => colorChanged ? accent : null;

  WallpaperDetailLoaded copyWith({
    FeedItemEntity? entity,
    String? views,
    int? setCount,
    bool? viewsLoading,
    bool? paletteLoading,
    List<Color>? colors,
    Color? accent,
    bool? colorChanged,
    bool? panelClosed,
    bool? panelCollapsed,
    bool? panelScrollInProgress,
    RecommendationState? recommendations,
  }) {
    return WallpaperDetailLoaded(
      entity: entity ?? this.entity,
      views: views ?? this.views,
      setCount: setCount ?? this.setCount,
      viewsLoading: viewsLoading ?? this.viewsLoading,
      paletteLoading: paletteLoading ?? this.paletteLoading,
      colors: colors ?? this.colors,
      accent: accent ?? this.accent,
      colorChanged: colorChanged ?? this.colorChanged,
      panelClosed: panelClosed ?? this.panelClosed,
      panelCollapsed: panelCollapsed ?? this.panelCollapsed,
      panelScrollInProgress: panelScrollInProgress ?? this.panelScrollInProgress,
      recommendations: recommendations ?? this.recommendations,
    );
  }

  @override
  List<Object?> get props => [
    entity,
    views,
    setCount,
    viewsLoading,
    paletteLoading,
    colors,
    accent,
    colorChanged,
    panelClosed,
    panelCollapsed,
    panelScrollInProgress,
    recommendations,
  ];
}

final class WallpaperDetailError extends WallpaperDetailState {
  const WallpaperDetailError({required this.failure, this.thumbnailUrl});

  final WallpaperDetailLoadFailure failure;

  /// The thumbnail the link or tile carried, shown behind the message.
  final String? thumbnailUrl;

  @override
  List<Object?> get props => [failure, thumbnailUrl];
}
